if [ $# -lt 1 ]; then
    echo "USAGE: bash $0 CALYX_DIR"
    exit
fi

CALYX_DIR=$1

if [ ! -d ${CALYX_DIR} ]; then
    echo "${CALYX_DIR} is not a valid directory!"
    exit 1
fi

SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

BENCHMARKS_DIR=${SCRIPT_DIR}/benchmarks
DATA_DIR=${SCRIPT_DIR}/data/generated-data
GEN_CALYX_BENCH_DIR=${DATA_DIR}/futil-files
LOGS_DIR=${DATA_DIR}/logs
SCRATCH_DIR=${DATA_DIR}/scratch

WARMUP_COUNT=5 # copied from sundew eval
RUN_COUNT=10 # 30 in sundew eval


# create new data directory

if [ -d ${DATA_DIR} ]; then
    echo "Moving existing ${DATA_DIR}..."
    mv ${DATA_DIR} ${DATA_DIR}-`date +%Y-%m-%d-%H-%M`
fi
mkdir -p ${DATA_DIR}
mkdir -p ${LOGS_DIR}
mkdir -p ${GEN_CALYX_BENCH_DIR}

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
    elif [[ "${bench_file}" == *"strict_6flow_test.py" ]]; then
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
	local bench_dir=$3
	
	# baseline: no instrumentation
	local fud2_baseline_dir=${bench_dir}/fud2-baseline
	local fud2_baseline_fst_dir=${bench_dir}/fud2-baseline-fst
	# inst: instrumentation
	local fud2_inst_dir=${bench_dir}/fud2-instrumented
	local fud2_inst_fst_dir=${bench_dir}/fud2-instrumented-fst

	local sim_run_results=${bench_dir}/sim_run_results.csv
	echo "config,mean,stddev,median,user,system,min,max" > ${sim_run_results}
	
	if [[ "${bench_name}" == ffnn-par ]]; then
	    extra_args="-d papercut -d cell-share"
	fi
	
	default_args="-d group2seq ${extra_args}"
	profiler_args="-p profiler ${extra_args}"
	
	# run verilator --> dat first to get all files necessary
        fud2 ${bench_file} -o ${bench_dir}/baseline-sim-result.json --to dat --through verilator -s calyx.args="${default_args}" -s sim.data=${BENCHMARKS_DIR}/${bench_name}.data --dir ${fud2_baseline_dir} &> ${LOGS_DIR}/gol-build-baseline-${bench_name}
	fud2 ${bench_file} -o ${bench_dir}/inst-sim-result.json --to dat --through verilator -s calyx.args="${profiler_args}" -s sim.data=${BENCHMARKS_DIR}/${bench_name}.data --dir ${fud2_inst_dir} &> ${LOGS_DIR}/gol-build-inst-${bench_name}
	# fst is weird
	(
	    cp -r ${fud2_baseline_dir} ${fud2_baseline_fst_dir}
	    cd ${fud2_baseline_fst_dir}
	    rm sim_1.exe
	    verilator verilog_1.sv tb.sv --trace-fst --binary --top-module toplevel -fno-inline -Mdir verilator-fst-out
	    cp verilator-fst-out/Vtoplevel sim_1.exe
	) &> ${LOGS_DIR}/gol-build-bl-fst-${bench_name}
	(
	    cp -r ${fud2_inst_dir} ${fud2_inst_fst_dir}
	    cd ${fud2_inst_fst_dir}
	    rm sim_1.exe
	    verilator verilog_1.sv tb.sv --trace-fst --binary --top-module toplevel -fno-inline -Mdir verilator-fst-out
	    cp verilator-fst-out/Vtoplevel sim_1.exe
	) &> ${LOGS_DIR}/gol-build-inst-fst-${bench_name}
	

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
	# run verilator on baseline with fst
	(
	    cd ${fud2_baseline_fst_dir}
	    hf_with_fst=${bench_dir}/hf-sim-baseline-fst.csv
	    # with fst
	    ( hyperfine "./sim_1.exe +DATA=sim_data +CYCLE_LIMIT=500000000 +NOTRACE=0 +OUT=../sim-result.fst" --warmup $WARMUP_COUNT --runs $RUN_COUNT --export-csv ${hf_with_fst} ) &> ${LOGS_DIR}/gol-sim-baseline-fst-${bench_name}
	    echo "bl-with-fst,"$( tail -n +2 ${hf_with_fst} | cut -d, -f2- ) >> ${sim_run_results}
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
	(
	    cd ${fud2_inst_fst_dir}
	    hf_with_fst=${bench_dir}/hf-sim-inst-fst.csv
	    # with fst
	    ( hyperfine "./sim_1.exe +DATA=sim_data +CYCLE_LIMIT=500000000 +NOTRACE=0 +OUT=../sim-result.fst" --warmup $WARMUP_COUNT --runs $RUN_COUNT --export-csv ${hf_with_fst} ) &> ${LOGS_DIR}/gol-sim-inst-fst-${bench_name}
	    echo "inst-with-fst,"$( tail -n +2 ${hf_with_fst} | cut -d, -f2- ) >> ${sim_run_results}
	)
	
    )
}

function run_profiler() {
    local bench_file=$1
    local bench_name=$2
    local bench_dir=$3

    local sim_run_results=${bench_dir}/sim_run_results.csv
    
    if [[ "${bench_file}" == *".fuse" ]]; then
	profiler_type="dahlia-profiler"
	profscript_extra_args="--dahlia-parent-map parent-map.json --adl-mapping-file adl-metadata.json"
    elif [[ "${bench_file}" == *".py" ]]; then
	profiler_type="calyx-py-profiler"
	profscript_extra_args="--adl-mapping-file adl-metadata.json"
    else
	profiler_type="profiler"
	profscript_extra_args=""
    fi
    echo "Profiler type: ${profiler_type}"

    if [[ "${bench_name}" == "strict_6flow_test" ]]; then
	extra_args="-s profiler.py-args=\"20000 --keepgoing\""
    elif [[ "${bench_name}" == ffnn-par ]]; then
	extra_args="-s profiler.compilation-passes=\"-p pre-opt -p compile -p post-opt -p lower -d papercut -d cell-share\""
    fi

    fud2_dir=${bench_dir}/fud2
    hf_file=${bench_dir}/hf-profiler-e2e.csv
    svg_file=${bench_dir}/f.svg
	
    command="fud2 ${bench_file} -o ${svg_file} --through ${profiler_type} -s sim.data=${BENCHMARKS_DIR}/${bench_name}.data ${extra_args}"
    prep_command="rm -f ${svg_file}}"
    echo "Running e2e profiler runs..."

    ( hyperfine "${command}" --prepare "${prep_command}" --warmup ${WARMUP_COUNT} --runs ${RUN_COUNT} --export-csv ${hf_file} ) &> ${bench_dir}/gol-profiler-e2e-hyperfine # --show-output to debug
    echo "profiler-e2e,"$( tail -n +2 ${hf_file} | cut -d, -f2- ) >> ${sim_run_results}

    echo "Running profiler once and keeping directory to check runtime of script..."
    # run fud2 once to get all relevant files
    local fud2_profiler=${bench_dir}/fud2-profiler
    (
	eval "${command} --dir ${fud2_profiler}"
    ) &> ${bench_dir}/gol-collect-profiler-fud2

    echo "Running hyperfine runs for profiler script..."
    python_command="profiler instrumented.vcd cells.json fsm.json shared-cells.json enable-par-track.json path-descriptors.json profiler-out2 f.folded --ctrl-pos-file ctrl-pos.json  ${profscript_extra_args}"
    hf_profscript=${bench_dir}/hf-profiler-script.csv

    (
	cd ${fud2_profiler}
	hyperfine "${python_command}" --warmup ${WARMUP_COUNT} --runs ${RUN_COUNT} --export-csv ${hf_profscript}
    ) &> ${bench_dir}/gol-profiler-script-hyperfine
    echo "profiler-script,"$( tail -n +2 ${hf_profscript} | cut -d, -f2- ) >> ${sim_run_results}
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
    bl_fst=$( grep "bl-with-fst" ${sim_run_results} | cut -d, -f2 )
    it_normal=$( grep "inst-wo-vcd" ${sim_run_results} | cut -d, -f2 )
    it_vcd=$( grep "inst-with-vcd" ${sim_run_results} | cut -d, -f2 )
    it_fst=$( grep "inst-with-fst" ${sim_run_results} | cut -d, -f2 )
    p_e2e=$( grep "profiler-e2e" ${sim_run_results} | cut -d, -f2 )
    p_script=$( grep "profiler-script" ${sim_run_results} | cut -d, -f2 )
    
    echo "${bench_name},${probe_count},$bl_normal,$it_normal,$bl_vcd,$it_vcd,$bl_fst,$it_fst,${p_script},${p_e2e}" >> ${results_csv}
}

function main() {

    results_csv=${DATA_DIR}/results.csv
    echo "benchmark,probe-count,bl-wo-vcd,inst-wo-vcd,bl-with-vcd,inst-with-vcd,bl-with-fst,inst-with-fst,profiler-script,profiler-e2e" > ${results_csv}
    
    for bench_short_file in $( cat ${BENCHMARKS_DIR}/order.txt | grep -v "#"  ); do
	bench_file=${BENCHMARKS_DIR}/${bench_short_file}
	bench_name=$( basename "${bench_file}" | cut -d. -f1 )
	echo =============${bench_name}
	bench_dir=${DATA_DIR}/${bench_name}
	mkdir ${bench_dir}	
	
	generate_calyx_file ${bench_file} ${bench_name}
	calyx_file=${GEN_CALYX_BENCH_DIR}/${bench_name}.futil

	produce_probe_nums ${calyx_file} ${bench_dir} ${bench_name}
	run_verilator ${calyx_file} ${bench_name} ${bench_dir}
	run_profiler ${bench_file} ${bench_name} ${bench_dir}
	process_results ${bench_name} ${bench_dir} ${results_csv}

    done
}

main
