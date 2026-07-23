SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
CASE_STUDIES_DIR=${SCRIPT_DIR}/case-studies
RESULTS_DIR=${CASE_STUDIES_DIR}/results
LOGS_DIR=${CASE_STUDIES_DIR}/logs
echo "===CASE STUDY DATA CREATION==="
echo "Results will be written to ${RESULTS_DIR}"
echo "Logs will be writen to: ${LOGS_DIR}"
echo

rm -rf ${RESULTS_DIR}; mkdir -p ${RESULTS_DIR}
rm -rf ${LOGS_DIR}; mkdir -p ${LOGS_DIR}
CYCLE_COUNTS_RES=${RESULTS_DIR}/cycle-counts.csv
echo "PROGRAM,CYCLES" > ${CYCLE_COUNTS_RES}

function setup_dir() {
    # cleanup if directories existed before
    rm -rf petal-runs; mkdir -p petal-runs
    rm -rf outputs; mkdir -p outputs
    rm -rf svgs; mkdir -p svgs
}

# rounding scheme
function round() {
    echo $(printf %.$2f $(echo "scale=$2;(((10^$2)*$1)+0.5)/(10^$2)" | bc))
};

function get_cycles() {
    jq ".cycles" $1
}

function run_cmd() {
    local cmd="$1"
    local log_filename=$2
    local log_file=${LOGS_DIR}/${log_filename}
    (
	echo "Current Directory: "$(pwd)
	set -o xtrace # or echo "${cmd}"
	eval "${cmd}"
    ) &> ${log_file}

    ret=$?
    if [ $ret -ne 0 ]; then
	echo "FAILURE! Please check output at ${log_file}"
    fi
}

function reproduce_section_3() {
    # Section 3
    echo "Reproducing figures from Section 3: Example"
    (
	sec=sec-03
	cd ${CASE_STUDIES_DIR}/${sec}
	setup_dir
	# Run verilator on original program and obtain cycle counts
	echo -e "\tRunning Verilator on original switch-case program..."
	run_cmd "fud2 switch-case-par.futil -o outputs/switch-case-par.json --through verilator -s sim.data=switch-case.data" ${sec}-verilator-switch-case-original.txt
	echo "switch-case-original,"$( get_cycles outputs/switch-case-par.json ) >> ${CYCLE_COUNTS_RES}
	
	# Run verilator on optimized program and obtain cycle counts
	echo -e "\tRunning Verilator on optimized switch-case program..."
	run_cmd "fud2 switch-case-nested-if.futil -o outputs/switch-case-nested-if.json --through verilator -s sim.data=switch-case.data" ${sec}-verilator-switch-case-optimized.txt
	echo "switch-case-optimized,"$( get_cycles outputs/switch-case-nested-if.json ) >> ${CYCLE_COUNTS_RES}

	# Run petal on original program
	echo -e "\tRunning Petal on optimized switch-case program..."
	run_cmd "fud2 switch-case-par.futil -o svgs/switch-case-par.svg --through petal -s sim.data=switch-case.data --dir petal-runs/switch-case-par" ${sec}-petal-switch-case.txt
	# copy flame graph for easier viewing (Figure 4: switch-case example flame graph)
	cp petal-runs/switch-case-par/profiler-out/scaled-flame.svg ${RESULTS_DIR}/fig-4.svg
	# copy timeline view for easier viewing (Figure 5: switch-case example timeline view)
	cp petal-runs/switch-case-par/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-5.pftrace
    )
}

function reproduce_section_8() {
    # Section 8
    echo "Reproducing figures from Section 8: Source-level Profiling"
    (
	local sec=sec-08
	cd ${CASE_STUDIES_DIR}/${sec}
	setup_dir
	echo -e "\tRunning Petal on example Dahlia program..."
	# Run petal on Dahlia program
	run_cmd "fud2 dahlia-example.fuse -o svgs/dahlia-example.svg --through petal-dahlia -s sim.data=dahlia-example.fuse.data --dir petal-runs/dahlia-example" ${sec}-petal-dahlia-example.txt
	# copy timeline view for easier viewing (Figure 9d: Calyx timeline view for example Dahlia program)
	cp petal-runs/dahlia-example/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-9d.pftrace
	# copy timeline view for easier viewing (Figure 9e: Dahlia timeline view for example Dahlia program)
	cp petal-runs/dahlia-example/profiler-out/dahlia_timeline_trace.pftrace ${RESULTS_DIR}/fig-9e.pftrace
    )
}

function reproduce_section_9() {
    # Section 9
    echo "Reproducing figures from Section 9: Case Studies: Understanding Compiler Choices"
    (
	local sec=sec-09
	cd ${CASE_STUDIES_DIR}/${sec}
	setup_dir
	
	# Run Petal on linear-algebra-2mm
	echo -e "\tRunning Petal on linear-algebra-2mm (static promotion enabled)..."
	run_cmd "fud2 linear-algebra-2mm.fuse -o svgs/linear-algebra-2mm.svg --through petal-dahlia -s sim.data=linear-algebra-2mm.data --dir petal-runs/linear-algebra-2mm -s profiler.compilation-passes=\"-p pre-opt -p compile -p post-opt -p lower -d group2seq\"" ${sec}-petal-2mm-sp-enabled.txt
	# copy timeline view for easier viewing (Figure 12: Zoomed in timeline view with static promotion)
	cp petal-runs/linear-algebra-2mm/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-12.pftrace
	
	# Run Petal on linear-algebra-2mm without static promotion
	echo -e "\tRunning Petal on linear-algebra-2mm (static promotion disabled)..."
	run_cmd "fud2 linear-algebra-2mm.fuse -o svgs/linear-algebra-2mm-disable-static-promotion.svg --through dahlia-profiler -s sim.data=linear-algebra-2mm.data -s profiler.compilation-passes=\"-p pre-opt -p compile -p post-opt -p lower -d static-promotion -d group2seq\" --dir petal-runs/linear-algebra-2mm-disable-static-promotion" ${sec}-petal-2mm-sp-disabled.txt
	# copy timeline view for easier viewing (Figure 10: Zoomed in timeline view without static promotion)
	cp petal-runs/linear-algebra-2mm-disable-static-promotion/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-10.pftrace
	
	# Run Petal on linear-algebra-3mm
	echo -e "\tRunning Petal on linear-algebra-3mm (resource sharing enabled)..."
	run_cmd "fud2 linear-algebra-3mm.fuse -o svgs/linear-algebra-3mm.svg --through petal-dahlia -s sim.data=linear-algebra-3mm.data --dir petal-runs/linear-algebra-3mm" ${sec}-petal-3mm-rs-enabled.txt
	# copy timeline view for easier viewing (Figure 13a: Full timeline view for linear-algebra-3mm with resource sharing)
	cp petal-runs/linear-algebra-3mm/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-13a.pftrace
	
	# Run Petal on linear-algebra-3mm without resource sharing
	echo -e "\tRunning Petal on linear-algebra-3mm (resource sharing disabled)..."
	run_cmd "fud2 linear-algebra-3mm.fuse -o svgs/linear-algebra-3mm-disable-cell-share.svg --through petal-dahlia -s profiler.compilation-passes=\"-p pre-opt -p compile -p post-opt -p lower -d cell-share\" -s sim.data=linear-algebra-3mm.data --dir petal-runs/linear-algebra-3mm-disable-cell-share" ${sec}-petal-3mm-rs-disabled.txt
	# copy timeline view for easier viewing (Figure 13b: Full timeline view for linear-algebra-3mm without resource sharing)
	cp petal-runs/linear-algebra-3mm-disable-cell-share/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-13b.pftrace
    )
}

# helper for generating table 2
function create_table_2() {
    table_2_file=${RESULTS_DIR}/table2.csv
    total_cycles=$( jq ".cycles" outputs/queues-original.json )
    echo "Strategy,Cycles-reduced,%-cycles-reduced" > ${table_2_file}
    sc_reduced=$( jq ".cycles" outputs/queues-switch-case-opt.json | xargs -I {} echo "${total_cycles} - {}" | bc -l)
    sc_reduced_p=$( round $( echo "(${sc_reduced} / ${total_cycles}) * 100" | bc -l ) 1 )
    while_reduced=$( jq ".cycles" outputs/queues-while-opt.json | xargs -I {} echo "(${total_cycles} - ${sc_reduced}) - {}" | bc -l )
    while_reduced_p=$( round $( echo "(${while_reduced} / ${total_cycles}) * 100" | bc -l ) 1 )
    static_reduced=$( jq ".cycles" outputs/queues-static-opt.json | xargs -I {} echo "(${total_cycles} - (${sc_reduced} + ${while_reduced})) - {}"  | bc -l )
    static_reduced_p=$( round $( echo "(${static_reduced} / ${total_cycles}) * 100" | bc -l ) 1 )
    total_reduced=$( jq ".cycles" outputs/queues-full-opt.json | xargs -I {} echo "${total_cycles} - {}" | bc -l )
    other_reduced=$( echo "${total_reduced} - (${sc_reduced} + ${static_reduced} + ${while_reduced})" | bc -l )
    other_reduced_p=$( round $( echo "(${other_reduced} / ${total_cycles}) * 100" | bc -l ) 1 )
    total_reduced_p=$( round $( echo "(${total_reduced} / ${total_cycles}) * 100" | bc -l ) 1 )
    echo "switch-case,${sc_reduced},${sc_reduced_p}" >> ${table_2_file}
    echo "while,${while_reduced},${while_reduced_p}" >> ${table_2_file}
    echo "static,${static_reduced},${static_reduced_p}" >> ${table_2_file}
    echo "other,${other_reduced},${other_reduced_p}" >> ${table_2_file}
    echo "total,${total_reduced},${total_reduced_p}" >> ${table_2_file}
}

function reproduce_section_10() {
    # Section 10
    echo "Reproducing figures from Section 10: Case Studies: Optimizing Calyx User Programs"
    (
	local sec=sec-10
	cd ${CASE_STUDIES_DIR}/${sec}
	setup_dir

	# ffnn Verilator runs for unified cycle collection
	echo -e "\tRunning Verilator on ffnn (original)..."
	run_cmd "fud2 ffnn-original.futil -o outputs/ffnn-original.json --through verilator -s sim.data=ffnn.data -s calyx.args=\"-d papercut -d cell-share -d group2seq\"" ${sec}-verilator-ffnn-original.txt
	echo "ffnn-original,"$( get_cycles outputs/ffnn-original.json ) >> ${CYCLE_COUNTS_RES}
	
	echo -e "\tRunning Verilator on ffnn (optimized)..."
	run_cmd "fud2 ffnn-optimized.futil -o outputs/ffnn-optimized.json --through verilator -s sim.data=ffnn.data -s calyx.args=\"-d papercut -d cell-share -d group2seq\"" ${sec}-verilator-ffnn-original.txt
	echo "ffnn-optimized,"$( get_cycles outputs/ffnn-optimized.json ) >> ${CYCLE_COUNTS_RES}

	# ffnn Petal runs
	# NOTE: Maybe worth adding an option to disable ffnn runs because this will take a while.
	echo -e "\tRunning Petal on ffnn (original)..."
	run_cmd "fud2 ffnn-original.futil -o svgs/ffnn-original.svg --through petal -s sim.data=ffnn.data -s profiler.compilation-passes=\"-p pre-opt -p compile -p post-opt -p lower -d papercut -d cell-share\" --dir petal-runs/ffnn-original" ${sec}-petal-ffnn-original.txt
	# copy timeline view for easier viewing (Figure 14a: Zoomed in timeline view before optimization)
	cp petal-runs/ffnn-original/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-14a.pftrace
	# copy group table for easier viewing (Table 1: Snippet of group statistics obtained from ffnn (bb_1-6))
	cp petal-runs/ffnn-original/profiler-out/group-stats.csv ${RESULTS_DIR}/table1.csv
	
	# Run Petal on optimized ffnn program
	echo -e "\tRunning Petal on ffnn (optimized)..."
	run_cmd "fud2 ffnn-optimized.futil -o svgs/ffnn-optimized.svg --through petal -s sim.data=ffnn.data -s profiler.compilation-passes=\"-p pre-opt -p compile -p post-opt -p lower -d papercut -d cell-share\" --dir petal-runs/ffnn-optimized" ${sec}-petal-ffnn-optimized.txt
	# copy timeline view for easier viewing (Figure 14b: Zoomed in timeline view after optimization)
	cp petal-runs/ffnn-optimized/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-14b.pftrace

	###########################
	
	# Example while program: Petal runs
	echo -e "\tRunning Petal on example while program (original)..."
	# Run Petal on original example while program
	run_cmd "fud2 while-original.futil -o svgs/while-original.svg --through petal -s sim.data=while.data --dir petal-runs/while-original" ${sec}-petal-while-original.txt
	# copy timeline view for easier viewing (Figure 18: Timeline view of example while program)
	cp petal-runs/while-original/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-18.pftrace
	
	echo -e "\tRunning Petal on example while program (manually transformed)..."
	run_cmd "fud2 while-manual.futil -o svgs/while-manual.svg --through petal -s sim.data=while.data --dir petal-runs/while-manual" ${sec}-petal-while-manual.txt
	# copy timeline view for easier viewing (Figure 19: Timeline view of manually transformed while program)
	cp petal-runs/while-manual/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-19.pftrace

	echo -e "\tRunning Petal on example while program (optimized)..."
	run_cmd "fud2 while-optimized.futil -o svgs/while-optimized.svg --through petal -s sim.data=while.data --dir petal-runs/while-optimized" ${sec}-petal-while-optimized.txt
	# copy timeline view for easier viewing (Figure 20: Timeline view of par optimized while program)
	cp petal-runs/while-optimized/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-20.pftrace

	###########################

	echo -e "\tRunning Verilator on queues (original)..."
	run_cmd "fud2 queues-original.futil -o outputs/queues-original.json --through verilator -s sim.data=queues.data" ${sec}-verilator-queues-original.txt
	echo -e "\tRunning Verilator on queues (switch-case optimized)..."
	# Run Verilator on switch-case optimized queues program
	run_cmd "fud2 queues-switch-case-opt.futil -o outputs/queues-switch-case-opt.json --through verilator -s sim.data=queues.data" ${sec}-verilator-queues-switch-case-opt.txt
	# Run Verilator on static-ed queues program
	echo -e "\tRunning Verilator on queues (static optimized)..."
	run_cmd "fud2 queues-static-opt.futil -o outputs/queues-static-opt.json --through verilator -s sim.data=queues.data" ${sec}-verilator-queues-static-opt.txt
	# Run Verilator on while-optimized queues program
	echo -e "\tRunning Verilator on queues (while optimized)..."	
	run_cmd "fud2 queues-while-opt.futil -o outputs/queues-while-opt.json --through verilator -s sim.data=queues.data" ${sec}-verilator-queues-while-opt.txt
	# Run Verilator on fully optimized packet scheduling program
	echo -e "\tRunning Verilator on queues (fully optimized)..."	
	run_cmd "fud2 queues-full-opt.futil -o outputs/queues-full-opt.json --through verilator -s sim.data=queues.data" ${sec}-verilator-queues-full-opt.txt
	# Process intermediate output to reproduce Table 2
	create_table_2
	echo "queues-original,"$( get_cycles outputs/queues-original.json ) >> ${CYCLE_COUNTS_RES}	
	echo "queues-optimized,"$( get_cycles outputs/queues-full-opt.json ) >> ${CYCLE_COUNTS_RES}

	echo -e "\tRunning Petal on queues (original)..."
	run_cmd "fud2 queues-original.futil -o svgs/queues-original.svg --through petal -s sim.data=queues.data --dir petal-runs/queues-original" ${sec}-petal-queues-original.txt
	# copy timeline view for easier viewing (Figure 15a: Flame graph of the packet scheduling program)
	cp petal-runs/queues-original/profiler-out/scaled-flame.svg ${RESULTS_DIR}/fig-15a.svg
	# copy timeline view for easier viewing (Figure 15b: Timeline of groups active during one call of the myqueue cell)
	cp petal-runs/queues-original/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-15b.pftrace
    )
}

function reproduce_section_11() {
    # Section 11
    echo "Reproducing figures from Section 11: Case Studies: Optimizing ADL programs"
    (
	local sec=sec-11
	cd ${CASE_STUDIES_DIR}/${sec}
	setup_dir
	
	echo -e "\tRunning Verilator on sandpile (original)..."
	run_cmd "fud2 sandpile-original.fuse -o outputs/sandpile-original.json --through verilator -s sim.data=sandpile.data" ${sec}-verilator-sandpile-original.txt
	echo "sandpile-original,"$( get_cycles outputs/sandpile-original.json ) >> ${CYCLE_COUNTS_RES}
	echo -e "\tRunning Verilator on sandpile (optimized)..."
	run_cmd "fud2 sandpile-optimized.fuse -o outputs/sandpile-optimized.json --through verilator -s sim.data=sandpile.data" ${sec}-verilator-sandpile-optimized.txt
	echo "sandpile-optimized,"$( get_cycles outputs/sandpile-optimized.json ) >> ${CYCLE_COUNTS_RES}

 	echo -e "\tRunning Petal on sandpile (original)..."
	run_cmd "fud2 sandpile-original.fuse -o svgs/sandpile-original.svg --through petal-dahlia -s sim.data=sandpile.data --dir petal-runs/sandpile-original" ${sec}-petal-sandpile-original.txt
	# Copy flame graph for easier viewing (Figure 21a: Flame graph of original sandpile program)
	cp petal-runs/sandpile-original/profiler-out/dahlia-scaled-flame.svg ${RESULTS_DIR}/fig-21a.svg
	# Copy timeline view for easier viewing (Figure 21b: Timeline view of inner for loop iteration in the original program)
	cp petal-runs/sandpile-original/profiler-out/dahlia_timeline_trace.pftrace ${RESULTS_DIR}/fig-21b.pftrace
	
 	echo -e "\tRunning Petal on sandpile (optimized)..."
	run_cmd "fud2 sandpile-optimized.fuse -o svgs/sandpile-optimized.svg --through petal-dahlia -s sim.data=sandpile.data --dir petal-runs/sandpile-optimized" ${sec}-petal-sandpile-optimized.txt
	# Copy timeline view for easier viewing (Figure 21c: Timeline view of inner for loop iteration in optimized program)
	cp petal-runs/sandpile-optimized/profiler-out/dahlia_timeline_trace.pftrace ${RESULTS_DIR}/fig-21c.pftrace
    )
}

reproduce_section_3
reproduce_section_8
reproduce_section_9
reproduce_section_10
reproduce_section_11
