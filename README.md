# Out-of-order Processor
This is a processor implementation of one of the
most classic register renaming out-of-order execution schemes, R10K.

## Exploiting Instruction Level Parallelism
Related advanced features include:
1. Superscalar Machine
2. Tournament Branch Predictor
3. Issue Memory Accesses Out-Of-Order (Load-Store Queue)
## Exploiting Locality of Memory Accesses
1. Instruction Prefetching
2. Associative Cache
3. Non-blocking ICache and DCache
4. Data Forwarding from Stores to Loads

## Usage
To run the design file, verdi synthesis tool is required.
``` make
# ---- Module Testbenches ---- #
# NOTE: these require files like: 'verilog/rob.sv' and 'test/rob_test.sv'
#       which implement and test the module: 'rob'
make <module>.pass   <- greps for "@@@ Passed" or "@@@ Failed" in the output
make <module>.out    <- run the testbench (via build/<module>.simv)
make <module>.verdi  <- run in verdi (via build/<module>.simv)
make build/<module>.simv  <- compile the testbench executable

make <module>.syn.pass   <- greps for "@@@ Passed" or "@@@ Failed" in the output
make <module>.syn.out    <- run the synthesized module on the testbench
make <module>.syn.verdi  <- run in verdi (via <module>.syn.simv)
make synth/<module>.vg        <- synthesize the module
make build/<module>.syn.simv  <- compile the synthesized module with the testbench

# ---- module testbench coverage ---- #
make <module>.cov        <- print the coverage hierarchy report to the terminal
make <module>.cov.verdi  <- open the coverage report in verdi
make cov_report_<module>      <- run urg to create human readable coverage reports
make build/<module>.cov.vdb   <- runs the executable and makes a coverage output dir
make build/<module>.cov.simv  <- compiles a coverage executable for the testbench
```



The following Makefile rules are available to run programs on the
processor:

``` make
# ---- Program Execution ---- #
# These are your main commands for running programs and generating output
make <my_program>.out      <- run a program on build/cpu.simv
                              output *.out, *.cpi, *.wb, and *.ppln files
make <my_program>.syn.out  <- run a program on build/cpu.syn.simv and do the same

# ---- Program Memory Compilation ---- #
# Programs to run are in the programs/ directory
make programs/<my_program>.mem  <- compile a program to a RISC-V memory file
make compile_all                <- compile every program at once (in parallel with -j)

# ---- Dump Files ---- #
make <my_program>.dump  <- disassembles compiled memory into RISC-V assembly dump files
make *.debug.dump       <- for a .c program, creates dump files with a debug flag
make dump_all           <- create all dump files at once (in parallel with -j)

# ---- Verdi ---- #
make <my_program>.verdi     <- run a program in verdi via build/cpu.simv
make <my_program>.syn.verdi <- run a program in verdi via build/cpu.syn.simv

# ---- Cleanup ---- #
make clean            <- remove per-run files and compiled executable files
make nuke             <- remove all files created from make rules
```
