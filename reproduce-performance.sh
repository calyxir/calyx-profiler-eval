if [ $# -lt 1 ]; then
    echo "USAGE: bash $0 CALYX_DIR"
    exit
fi

CALYX_DIR=$1
RUSTED_PETAL=${CALYX_DIR}/target/release/petal
echo ${RUSTED_PETAL}

if [ ! -d ${CALYX_DIR} ]; then
    echo "${CALYX_DIR} is not a valid directory!"
    exit 1
fi

if [ ! -e ${RUSTED_PETAL} ]; then
    echo "Petal needs to be compiled in release mode! Run `cargo build --all --release` from ${CALYX_DIR}."
    exit 1
fi

SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

CASE_STUDIES_DIR=${SCRIPT_DIR}/case-studies
DATA_DIR=${SCRIPT_DIR}/performance-data/generated-data
GEN_CALYX_BENCH_DIR=${DATA_DIR}/futil-files
LOGS_DIR=${DATA_DIR}/logs
SCRATCH_DIR=${DATA_DIR}/scratch

WARMUP_COUNT=5 # set to 5 after testing.
RUN_COUNT=30 # set to 30 after testing.


# create new data directory

if [ -d ${DATA_DIR} ]; then
    echo "Moving existing ${DATA_DIR}..."
    mv ${DATA_DIR} ${DATA_DIR}-`date +%Y-%m-%d-%H-%M`
fi
mkdir -p ${DATA_DIR}
mkdir -p ${LOGS_DIR}
mkdir -p ${GEN_CALYX_BENCH_DIR}

# rounding scheme
function round() {
    echo $(printf %.$2f $(echo "scale=$2;(((10^$2)*$1)+0.5)/(10^$2)" | bc))
};

function produce_probe_nums() {
    (
	local bench_file=$1
	local bench_dir=$2
	local bench_name=$3

	( ${CALYX_DIR}/target/debug/calyx ${bench_file} -p compile-invoke -p uniquefy-enables -p profiler-instrumentation -x profiler-instrumentation:emit-probe-stats=${bench_dir}/probe-stats.json ) &> ${LOGS_DIR}/gol-compile-${bench_name}
    )
}

function generate_calyx_file() {
    local bench_file=$1
    local bench_name=$2

    echo "generating calyx file..."

    if [[ "${bench_file}" == *".futil" ]]; then
	cp ${bench_file} ${GEN_CALYX_BENCH_DIR}
	return
    elif [[ "${bench_file}" == *"queues-original.py" ]]; then
	extra_opt="-s py.args=\"20000 --keepgoing\""
    fi

    cmd="fud2 ${bench_file} -o ${GEN_CALYX_BENCH_DIR}/${bench_name}.futil ${extra_opt}"

    (
	set -o xtrace
	eval "${cmd}"
	set +o xtrace
    ) &> ${bench_dir}/gol-generate-calyx
}

function run_verilator() {
    (
	local bench_file=$1
	local bench_name=$2
	local bench_data=$3
	local bench_dir=$4
	
	# baseline: no instrumentation
	local fud2_baseline_dir=${bench_dir}/fud2-baseline
	# inst: instrumentation
	local fud2_inst_dir=${bench_dir}/fud2-instrumented

	local sim_run_results=${bench_dir}/sim_run_results.csv
	echo "config,mean,stddev,median,user,system,min,max" > ${sim_run_results}
	
	if [[ "${bench_name}" == "ffnn-original" ]]; then
	    extra_args="-d papercut -d cell-share"
	fi
	
	default_args="${extra_args}"
	profiler_args="-p profiler ${extra_args}"
	
	# run verilator --> dat first to get all files necessary
        fud2 ${bench_file} -o ${bench_dir}/baseline-sim-result.json --to dat --through verilator -s calyx.args="${default_args}" -s sim.data=${bench_data} --dir ${fud2_baseline_dir} &> ${LOGS_DIR}/gol-build-baseline-${bench_name}
	fud2 ${bench_file} -o ${bench_dir}/inst-sim-result.json --to dat --through verilator -s calyx.args="${profiler_args}" -s sim.data=${bench_data} --dir ${fud2_inst_dir} &> ${LOGS_DIR}/gol-build-inst-${bench_name}	

	echo "Running verilator on baseline..."
	# run verilator on baseline
	(
	    cd ${fud2_baseline_dir}
	    hf_wo_vcd=${bench_dir}/hf-sim-baseline-normal.csv
	    hf_with_vcd=${bench_dir}/hf-sim-baseline-vcd.csv
	    # without vcd
	    ( hyperfine "./sim_1.exe +DATA=sim_data +CYCLE_LIMIT=500000000 +NOTRACE=1" --warmup $WARMUP_COUNT --runs $RUN_COUNT --export-csv ${hf_wo_vcd} ) &> ${LOGS_DIR}/gol-sim-baseline-normal-${bench_name}
	    echo "bl-wo-vcd,"$(tail -n +2 ${hf_wo_vcd} | cut -d, -f2-) >> ${sim_run_results}
	    # with vcd
	    ( hyperfine "./sim_1.exe +DATA=sim_data +CYCLE_LIMIT=500000000 +NOTRACE=0 +OUT=../sim-result.vcd" --warmup $WARMUP_COUNT --runs $RUN_COUNT --export-csv ${hf_with_vcd} ) &> ${LOGS_DIR}/gol-sim-baseline-vcd-${bench_name}
	    echo "bl-with-vcd,"$( tail -n +2 ${hf_with_vcd} | cut -d, -f2- ) >> ${sim_run_results}
	)
	# run verilator on instrumented
	echo "Running verilator on instrumented..."
	(
	    cd ${fud2_inst_dir}
	    hf_wo_vcd=${bench_dir}/hf-sim-inst-normal.csv
	    hf_with_vcd=${bench_dir}/hf-sim-inst-vcd.csv
	    
	    # without vcd
	    ( hyperfine "./sim_1.exe +DATA=sim_data +CYCLE_LIMIT=500000000 +NOTRACE=1"  --warmup $WARMUP_COUNT --runs $RUN_COUNT --export-csv ${hf_wo_vcd} ) &> ${LOGS_DIR}/gol-sim-inst-normal-${bench_name}
	    echo "inst-wo-vcd,"$(tail -n +2 ${hf_wo_vcd} | cut -d, -f2-) >> ${sim_run_results}
	    # with vcd
	    ( hyperfine "./sim_1.exe +DATA=sim_data +CYCLE_LIMIT=500000000 +NOTRACE=0 +OUT=../sim-result.vcd" --warmup $WARMUP_COUNT --runs $RUN_COUNT --export-csv ${hf_with_vcd} ) &> ${LOGS_DIR}/gol-sim-inst-vcd-${bench_name}
	    echo "inst-with-vcd,"$( tail -n +2 ${hf_with_vcd} | cut -d, -f2- ) >> ${sim_run_results}
	)	
    )
}

function run_profiler() {
    local bench_file=$1
    local bench_name=$2
    local bench_data=$3
    local bench_dir=$4

    local sim_run_results=${bench_dir}/sim_run_results.csv
    
    if [[ "${bench_file}" == *".fuse" ]]; then
	profiler_type="petal-dahlia"
	profscript_extra_args="--dahlia-parent-map parent-map.json --adl-file adl-metadata.json"
    elif [[ "${bench_file}" == *".py" ]]; then
	profiler_type="petal-calyx-py"
	profscript_extra_args="--adl-file adl-metadata.json"
    else
	profiler_type="petal"
	profscript_extra_args=""
    fi

    if [[ "${bench_name}" == "queues-original" ]]; then
	local extra_args="-s profiler.py-args=\"20000 --keepgoing\""
    elif [[ "${bench_name}" == "ffnn-original" ]]; then
	local extra_args="-s profiler.compilation-passes=\"-p pre-opt -p compile -p post-opt -p lower -d papercut -d cell-share\""
    fi

    fud2_dir=${bench_dir}/fud2
    hf_file=${bench_dir}/hf-profiler-e2e.csv
    svg_file=${bench_dir}/f.svg
	
    command="fud2 ${bench_file} -o ${svg_file} --through ${profiler_type} -s sim.data=${bench_data} ${extra_args} -s rusted_petal=${RUSTED_PETAL}"
    prep_command="rm -f ${svg_file}"
    echo "Running e2e Petal runs..."

    ( hyperfine "${command}" --prepare "${prep_command}" --warmup ${WARMUP_COUNT} --runs ${RUN_COUNT} --export-csv ${hf_file} ) &> ${bench_dir}/gol-profiler-e2e-hyperfine # --show-output to debug
    echo "petal-e2e,"$( tail -n +2 ${hf_file} | cut -d, -f2- ) >> ${sim_run_results}

    echo "Running profiler once and keeping directory to check runtime of script..."
    # run fud2 once to get all relevant files
    local fud2_profiler=${bench_dir}/fud2-profiler
    (
	eval "${command} --dir ${fud2_profiler}"
    ) &> ${bench_dir}/gol-collect-profiler-fud2

    echo "Running hyperfine runs for trace reconstruction..."
    reconstruction_command="${RUSTED_PETAL} instrumented.vcd fsm.json path-descriptors.json ctrl-pos.json shared-cells.json enable-par-track.json rusted-petal-out --scaled-flame-out rs.folded --flat-flame-out rf.folded ${profscript_extra_args}"
    hf_profscript=${bench_dir}/hf-trace-reconstruction.csv

    (
	cd ${fud2_profiler}
	hyperfine "${reconstruction_command}" --warmup ${WARMUP_COUNT} --runs ${RUN_COUNT} --export-csv ${hf_profscript}
    ) &> ${bench_dir}/gol-trace-reconstruction-hyperfine
    echo "trace-reconstruction,"$( tail -n +2 ${hf_profscript} | cut -d, -f2- ) >> ${sim_run_results}
}

function process_results() {
    local bench_name=$1
    local bench_dir=$2
    local results_csv=$3

    local sim_run_results=${bench_dir}/sim_run_results.csv
    
    # actually write a python script to process the vcd
    probe_count=$( grep -E "group_probe|structural_enable_probe|cell_probe|primitive_probe" ${bench_dir}/probe-stats.json | cut -d, -f1 | rev | cut -d' ' -f1 | rev | paste -sd+ | bc -l )
    # using means for now
    bl_normal=$( grep "bl-wo-vcd" ${sim_run_results} | cut -d, -f2 )
    bl_vcd=$( grep "bl-with-vcd" ${sim_run_results} | cut -d, -f2 )
    it_normal=$( grep "inst-wo-vcd" ${sim_run_results} | cut -d, -f2 )
    it_vcd=$( grep "inst-with-vcd" ${sim_run_results} | cut -d, -f2 )
    p_e2e=$( grep "petal-e2e" ${sim_run_results} | cut -d, -f2 )
    p_script=$( grep "trace-reconstruction" ${sim_run_results} | cut -d, -f2 )

    # oh-vcd,oh-inst,oh-reconstruction
    # VCD vs non-VCD
    oh_vcd=$( round $( echo "${bl_vcd} / ${bl_normal}" | bc -l ) 2 )
    # VCD of inst vs VCD of og program
    oh_inst=$( round $( echo "${it_vcd} / ${it_normal}" | bc -l ) 2 )
    # trace reconstruction time vs non-VCD baseline
    oh_trace=$( round $( echo "${p_script} / ${bl_normal}" | bc -l ) 2 )
    
    
    echo "${bench_name},${probe_count},$bl_normal,$it_normal,$bl_vcd,$it_vcd,${p_script},${p_e2e},${oh_vcd},${oh_inst},${oh_trace}" >> ${results_csv}
}

function main() {

    results_csv=${DATA_DIR}/results.csv
    echo "benchmark,probe-count,bl-wo-vcd,inst-wo-vcd,bl-with-vcd,inst-with-vcd,trace-reconstruction,petal-e2e,oh-vcd,oh-inst,oh-reconstruction" > ${results_csv}
    
    for bench_info in $( cat ${CASE_STUDIES_DIR}/performance-benchmark-order.txt | grep -v "#"  ); do
	bench_file=${CASE_STUDIES_DIR}/$( echo "${bench_info}" | cut -d';' -f1 )
	bench_data=${CASE_STUDIES_DIR}/$( echo "${bench_info}" | cut -d';' -f2 )
	bench_name=$( basename "${bench_file}" | cut -d'.' -f1 )
	echo =============${bench_name}
	bench_dir=${DATA_DIR}/${bench_name}
	mkdir ${bench_dir}	
	
	generate_calyx_file ${bench_file} ${bench_name}
	calyx_file=${GEN_CALYX_BENCH_DIR}/${bench_name}.futil

	produce_probe_nums ${calyx_file} ${bench_dir} ${bench_name}
	run_verilator ${calyx_file} ${bench_name} ${bench_data} ${bench_dir}
	run_profiler ${bench_file} ${bench_name} ${bench_data} ${bench_dir}
	process_results ${bench_name} ${bench_dir} ${results_csv}

    done
}

main
