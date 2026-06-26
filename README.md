# Petal (Calyx Profiler) Evaluation

This repository contains the evaluation materials for our OOPSLA 2026 paper, "Understanding Accelerator Compilers via Performance Profiling".

## Setup

VM : In `Settings > Display`, set Graphics Controller to VMSVGA.

In terminal:
```
eval $( fud2 env activate )
```

# Kick the tires

### Petal's basic functionality

(1) In the terminal:
```
cd ~/calyx
mkdir svgs fud2-runs
fud2 tests/correctness/pipelined-mac.futil -s svgs/pipelined-mac.svg --through profiler -s sim.data=tests/correctness/pipelined-mac.futil.data
```

(2) View the flame graph

(3) View the timeline view

### Vivado kick-the-tires

# Step-by-step guide

- **Case study data creation**: Generate the figures found in the paper using pre-supplied data.

- **Performance comparison**: Run experiments to reproduce Petal's performance (briefly described in Section 7).

- (Optional) **Profiling with Petal**

## Outline: Figures and numbers to reproduce

- Section 3
  - Original vs new cycle counts
  - Figure 4: switch-case example flame graph
  - Figure 5: switch-case example timeline view
- Section 7
  - Petal profiling performance
    - # of probes
    - Time to obtain RTL trace with instrumentation probes
    - Trace reconstruction time
- Section 8
  - Figure 9d: Calyx timeline view for example Dahlia program
  - Figure 9e: Dahlia timeline view for example Dahlia program
- Section 9
  - Section 9.1: static promotion with linear-algebra-2mm
    - Figure 11a: Zoomed in timeline view without static promotion
    - Figure 11c: Zoomed in timeline view with static promotion
  - Section 9.2: resource sharing with linear-algebra-3mm
    - Figure 12a: Full timeline view for linear-algebra-3mm with resource sharing
    - Figure 12b: Full timeline view for linear-algebra-3mm without resource sharing
- Section 10
  - Section 10.1: ffnn
    - Original cycle count
    - Optimized cycle count
    - Figure 13a: Zoomed in timeline view before optimization
    - Figure 13b: Zoomed in timeline view after optimization
    - Table 1: Snippet of group statistics obtained from ffnn (bb_1-6)
  - Section 10.2: Packet scheduling
    - Original cycle count
    - Figure 14a: Flame graph of original program
    - Figure 14b: Zoomed in timeline view of original program
    - Figure 17a: Timeline view of example while program
    - Figure 17b: Timeline view of manually transformed while program
    - Figure 17c: Timeline view of par optimized while program
    - Table 2: optimization strategies and number of cycle reductions they made on packet scheduling queues
    - Vivado:
      - worst slack
      - area - LUT decrease
- Section 11: Dahlia Sandpile example
    - Original cycle count
    - Optimized program cycle count
    - Figure 18a: Flame graph of original sandpile program
    - Figure 18b: Timeline view of inner for loop iteration in the original program
    - Figure 18c: Timeline view of inner for loop iteration in optimized program
    - Vivado (for both programs)
      - worst slack
      - area - LUT increase

# Performance Experiments

