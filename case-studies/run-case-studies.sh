SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
RESULTS_DIR=${SCRIPT_DIR}/results

rm -rf ${RESULTS_DIR}; mkdir -p ${RESULTS_DIR}

# cleanup?

function setup_dir() {
    # cleanup if directories existed before
    rm -rf petal-runs; mkdir -p petal-runs
    rm -rf outputs; mkdir -p outputs
    rm -rf svgs; mkdir -p svgs
}

# Section 3
echo "Reproducing figures from Section 3: Example"
(
    cd ${SCRIPT_DIR}/sec-03
    setup_dir
    # Run verilator on original program
    fud2 switch-case-par.futil -o outputs/switch-case-par.json --through verilator -s sim.data=switch-case.data
    # Run verilator on optimized program
    fud2 switch-case-nested-if.futil -o outputs/switch-case-nested-if.json --through verilator -s sim.data=switch-case.data
    # Run petal on original program
    fud2 switch-case-par.futil -o svgs/switch-case-par.svg --through profiler -s sim.data=switch-case.data --dir petal-runs/switch-case-par
    # copy flame graph for easier viewing (Figure 4: switch-case example flame graph)
    cp petal-runs/switch-case-par/profiler-out/scaled-flame.svg ${RESULTS_DIR}/fig-4.svg
    # copy timeline view for easier viewing (Figure 5: switch-case example timeline view)
    cp petal-runs/switch-case-par/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-5.pftrace
)

# Section 8
echo "Reproducing figures from Section 8: Source-level Profiling"
(
    cd ${SCRIPT_DIR}/sec-08
    setup_dir
    # Run petal on Dahlia program
    fud2 dahlia-example.fuse -o svgs/dahlia-example.svg --through dahlia-profiler -s sim.data=dahlia-example.fuse.data --dir petal-runs/dahlia-example
    # copy timeline view for easier viewing (Figure 9d: Calyx timeline view for example Dahlia program)
    cp petal-runs/dahlia-example/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-9d.pftrace
    # copy timeline view for easier viewing (Figure 9e: Dahlia timeline view for example Dahlia program)
    cp petal-runs/dahlia-example/profiler-out/dahlia_timeline_trace.pftrace ${RESULTS_DIR}/fig-9d.pftrace
)

# Section 9
echo "Reproducing figures from Section 9: Case Studies: Understanding Compiler Choices"
(
    cd ${SCRIPT_DIR}/sec-09
    setup_dir
    # Run Petal on linear-algebra-2mm
    fud2 linear-algebra-2mm.fuse -o svgs/linear-algebra-2mm.svg --through dahlia-profiler -s sim.data=linear-algebra-2mm.data --dir petal-runs/linear-algebra-2mm
    # copy timeline view for easier viewing (Figure 11c: Zoomed in timeline view with static promotion)
    cp petal-runs/linear-algebra-2mm/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-11c.pftrace
    
    # Run Petal on linear-algebra-2mm without static promotion
    fud2 linear-algebra-2mm.fuse -o svgs/linear-algebra-2mm-disable-static-promotion.svg --through dahlia-profiler -s sim.data=linear-algebra-2mm.data -s profiler.compilation-passes="-p pre-opt -p compile -p post-opt -p lower -d static-promotion" --dir petal-runs/linear-algebra-2mm-disable-static-promotion
    # copy timeline view for easier viewing (Figure 11a: Zoomed in timeline view without static promotion)
    cp petal-runs/linear-algebra-2mm-disable-static-promotion/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-11a.pftrace
    
    # Run Petal on linear-algebra-3mm
    fud2 linear-algebra-3mm.fuse -o svgs/linear-algebra-3mm.svg --through dahlia-profiler -s sim.data=linear-algebra-3mm.data --dir petal-runs/linear-algebra-3mm
    # copy timeline view for easier viewing (Figure 12a: Full timeline view for linear-algebra-3mm with resource sharing)
    cp petal-runs/linear-algebra-3mm/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-12a.pftrace
    
    # Run Petal on linear-algebra-3mm without resource sharing
    fud2 linear-algebra-3mm.fuse -o svgs/linear-algebra-3mm-disable-cell-share.svg --through dahlia-profiler -s profiler.compilation-passes="-p pre-opt -p compile -p post-opt -p lower -d cell-share" -s sim.data=linear-algebra-3mm.data --dir petal-runs/linear-algebra-3mm-disable-cell-share
    # copy timeline view for easier viewing (Figure 12b: Full timeline view for linear-algebra-3mm without resource sharing)
    cp petal-runs/linear-algebra-3mm-disable-cell-share/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-12b.pftrace
)

# Section 10
echo "Reproducing figures from Section 10: Case Studies: Optimizing Calyx User Programs"
(
    cd ${SCRIPT_DIR}/sec-10
    # NOTE: Maybe worth adding an option to disable ffnn runs because this will take forever
    # Run Petal on original ffnn program
    fud2 ffnn-original.futil -o svgs/ffnn-original.svg --through profiler -s sim.data=ffnn-original.data --dir petal-runs/ffnn-original
    # copy timeline view for easier viewing (Figure 13a: Zoomed in timeline view before optimization)
    cp petal-runs/ffnn-original/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-13a.pftrace
    
    # Run Petal on optimized ffnn program
    fud2 ffnn-optimized.futil -o svgs/ffnn-optimized.svg --through profiler -s sim.data=ffnn-optimized.data --dir petal-runs/ffnn-optimized
    # copy timeline view for easier viewing (Figure 13b: Zoomed in timeline view after optimization)
    cp petal-runs/ffnn-optimized/profiler-out/timeline_trace.pftrace ${RESULTS_DIR}/fig-13b.pftrace

    # Run Petal on original example while program
    
    # Run Petal on manually transformed while program

    # Run Petal on par optimized while program
    

    # Run Petal on original queues program
    fud2 queues-original.futil -o svgs/queues-original.svg --through profiler -s sim.data=queues.data --dir petal-runs/queues-original
    # Run Verilator on original queues program
    fud2 queues-original.futil -o outputs/queues-original.json --through verilator -s sim.data=queues.data
    # Run Verilator on switch-case optimized queues program
    fud2 queues-switch-case-opt.futil -o outputs/queues-switch-case-opt.json --through verilator -s sim.data=queues.data
    # Run Verilator on static-ed queues program
    fud2 queues-static-opt.futil -o outputs/queues-static-opt.json --through verilator -s sim.data=queues.data    
    # Run Verilator on while-optimized queues program
    fud2 queues-while-opt.futil -o outputs/queues-while-opt.json --through verilator -s sim.data=queues.data    
    # Run Verilator on fully optimized packet scheduling program
    fud2 queues-full-opt.futil -o outputs/queues-full-opt.json --through verilator -s sim.data=queues.data
    # TODO: Process intermediate output to reproduce Table 2
)

# Section 11
echo "Reproducing figures from Section 11: Case Studies: Optimizing ADL programs"
(
    cd ${SCRIPT_DIR}/sec-11
    setup_dir
    # Run Verilator on original program
    fud2 sandpile-original.futil -o outputs/sandpile-original.json --through verilator -s sim.data=sandpile.data
    # Run Verilator on optimized program
    fud2 sandpile-optimized.futil -o outputs/sandpile-original.json --through verilator -s sim.data=sandpile.data
    # Run Petal on original program
    fud2 sandpile-original.futil -o svgs/sandpile-original.svg --through dahlia-profiler -s sim.data=sandpile.data --dir petal-runs/sandpile-original
    # Run Petal on optimized program
    fud2 sandpile-optimized.futil -o svgs/sandpile-optimized.svg --through dahlia-profiler -s sim.data=sandpile.data --dir petal-runs/sandpile-optimized
)
