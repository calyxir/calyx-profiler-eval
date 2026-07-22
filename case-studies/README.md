# Case Studies

This directory contains
- `sec-03`-`sec-11`: Original Calyx/Calyx-Py/Dahlia files and data files (for simulation) for producing figures in the paper.
- `performance-benchmark-order.txt`: A file used by `reproduce-performance.sh` to determine the case study programs to run performance benchmarking on.
- `performance-results.csv`: A copy of our output from `reproduce-performance.sh` used to describe performance in Section 7 of the paper.

**NOTE:** `sec-11/sandpile-original.fuse` and `sec-11/sandpile-optimized.fuse` were adapted from `abelian-sandpile/sandpile.fuse.m4` from the [`dahlia-cookbook` repository](https://github.com/Mark1626/dahlia-cookbook) by [Mark1626](https://github.com/Mark1626). There is no license listed in the repository.

After running `../run-case-studies.sh`, the following directories will be created:
- `results`: A directory containing the flame graphs and timeline views used for figures in the paper.
- `logs`: Log files generated while running the script for any troubleshooting
