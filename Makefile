##########################
# ---- Introduction ---- #
##########################

# Welcome to the Project 3 VeriSimpleV Processor makefile!
# this file will build and run a fully synthesizable RISC-V verilog processor
# and is an extended version of the EECS 470 standard makefile

# NOTE: this file should need no changes for project 3
# but it will be reused for project 4, where you will likely add your own new files and functionality

# reference table of all make targets:

# make  <- runs the default target, set explicitly below as 'make no_hazard.out'
.DEFAULT_GOAL = mult.pass
# ^ this overrides using the first listed target as the default

# ---- Module Testbenches ---- #
# NOTE: these require files like: 'verilog/rob.sv' and 'test/rob_test.sv'
#       which implement and test the module: 'rob'

# make <module>.pass   <- greps for "@@@ Passed" or "@@@ Failed" in the output
# make <module>.out    <- run the testbench (via build/<module>.simv)
# make <module>.verdi  <- run in verdi (via <module>.simv)
# make build/<module>.simv  <- compile the testbench executable

# make <module>.syn.pass   <- greps for "@@@ Passed" or "@@@ Failed" in the output
# make <module>.syn.out    <- run the synthesized module on the testbench
# make <module>.syn.verdi  <- run in verdi (via <module>.syn.simv)
# make synth/<module>.vg        <- synthesize the module
# make build/<module>.syn.simv  <- compile the synthesized module with the testbench

# make slack     <- grep the slack status of any synthesized modules

# ---- module testbench coverage ---- #
# make <module>.cov        <- print the coverage hierarchy report to the terminal
# make <module>.cov.verdi  <- open the coverage report in verdi
# make build/<module>.cov.simv  <- compiles a coverage executable for the testbench
# make build/<module>.cov.vdb   <- runs the executable and makes a coverage output dir
# make cov_report_<module>      <- run urg to create human readable coverage reports

# ---- Program Execution ---- #
# These are your main commands for running programs and generating output
# make <my_program>.out      <- run a program on build/cpu.simv and output *.out, *.cpi, *.wb, and *.ppln files
# make <my_program>.syn.out  <- run a program on build/cpu.syn.simv and do the same
# make simulate_all          <- run every program on simv at once (in parallel with -j)
# make simulate_all_syn      <- run every program on syn_simv at once (in parallel with -j)

# ---- Executable Compilation ---- #
# make simv      <- compiles build/cpu.simv from the CPU_TESTBENCH and CPU_SOURCES
# make syn_simv  <- compiles syn_simv from CPU_TESTBENCH and CPU_SYNTH
# make synth/cpu.vg  <- synthesize modules in CPU_SOURCES for use in syn_simv

# ---- Program Memory Compilation ---- #
# Programs to run are in the programs/ directory
# make programs/<my_program>.mem  <- compile a program to a RISC-V memory file
# make compile_all                <- compile every program at once (in parallel with -j)

# ---- Dump Files ---- #
# make <my_program>.dump  <- disassembles compiled memory into RISC-V assembly dump files
# make *.debug.dump       <- for a .c program, creates dump files with a debug flag
# make programs/<my_program>.dump_x    <- numeric dump files use x0-x31 as register names
# make programs/<my_program>.dump_abi  <- abi dump files use the abi register names (sp, a0, etc.)
# make dump_all  <- create all dump files at once (in parallel with -j)

# ---- Verdi ---- #
# make <my_program>.verdi     <- run a program in verdi via build/cpu.simv
# make <my_program>.syn.verdi <- run a program in verdi via build/cpu.syn.simv

# ---- Cleanup ---- #
# make clean            <- remove per-run files and compiled executable files
# make nuke             <- remove all files created from make rules
# make clean_run_files  <- remove per-run output files
# make clean_exe        <- remove compiled executable files
# make clean_synth      <- remove generated synthesis files
# make clean_output     <- remove the entire output/ directory
# make clean_programs   <- remove program memory and dump files

# Credits:
# VeriSimpleV was adapted by Jielun Tan for RISC-V from the original 470 VeriSimple Alpha language processor
# however I cannot find the original authors or the major editors of the project :/
# so to everyone I can't credit: thank you!
# the current layout of the Makefile was made by Ian Wrzesinski in 2023
# VeriSimpleV has also been edited by at least:
# Nevil Pooniwala, Xueyang Liu, Cassie Jones, James Connolly

######################################################
# ---- Compilation Commands and Other Variables ---- #
######################################################

# these are various build flags for different parts of the makefile, VCS and LIB should be
# familiar, but there are new variables for supporting the compilation of assembly and C
# source programs into riscv machine code files to be loaded into the processor's memory

# don't be afraid to change these, but be diligent about testing changes and using git commits
# there should be no need to change anything for project 3

# this is a global clock period variable used in the tcl script and referenced in testbenches
export CLOCK_PERIOD = 20.0

# the Verilog Compiler command and arguments
VCS = SW_VCS=2020.12-SP2-1 vcs -sverilog -xprop=tmerge +vc -Mupdate -Mdir=build/csrc -line -full64 -kdb -lca -nc \
      -debug_access+all+reverse $(VCS_BAD_WARNINGS) +define+CLOCK_PERIOD=$(CLOCK_PERIOD) +incdir+verilog/
# a SYNTH define is added when compiling for synthesis that can be used in testbenches

RUN_VERDI = -gui=verdi -verdi_opts "-ultra"

# remove certain warnings that generate MB of text but can be safely ignored
VCS_BAD_WARNINGS = +warn=noTFIPC +warn=noDEBUG_DEP +warn=noENUMASSIGN +warn=noLCA_FEATURES_ENABLED

# a reference library of standard structural cells that we link against when synthesizing
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v

# the EECS 470 synthesis script
TCL_SCRIPT = synth/470synth.tcl

# Set the shell's pipefail option: causes return values through pipes to match the last non-zero value
# (useful for, i.e. piping to `tee`)
SHELL := $(SHELL) -o pipefail

# The following are new in project 3:

# you might need to update these build flags for project 4, but make sure you know what they do:
# https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html
CFLAGS     = -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -std=gnu11 -mstrict-align -mno-div
# adjust the optimization if you want programs to run faster; this may obfuscate/change their instructions
OFLAGS     = -O0
ASFLAGS    = -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -Wno-main -mstrict-align
OBJFLAGS   = -SD -M no-aliases
OBJCFLAGS  = --set-section-flags .bss=contents,alloc,readonly
OBJDFLAGS  = -SD -M numeric,no-aliases
DEBUG_FLAG = -g

# this is our RISC-V compiler toolchain
# NOTE: you can use a local riscv install to compile programs by setting CAEN to 0
CAEN = 1
ifeq (1, $(CAEN))
    GCC     = riscv gcc
    OBJCOPY = riscv objcopy
    OBJDUMP = riscv objdump
    AS      = riscv as
    ELF2HEX = riscv elf2hex
else
    GCC     = riscv64-unknown-elf-gcc
    OBJCOPY = riscv64-unknown-elf-objcopy
    OBJDUMP = riscv64-unknown-elf-objdump
    AS      = riscv64-unknown-elf-as
    ELF2HEX = elf2hex
endif

GREP = grep -E --color=auto

####################################
# ---- Milestone 1 Submission ---- #
####################################

# Update this section with your main module for milestone 1

# The autograder will give some feedback if you output "@@@ Passed" and "@@@ Failed"
# This is mostly so you can know that your module builds and runs on the ag
# Your actual milestone 1 grade will be done manually

MS_1_MODULE = rs

autograder_milestone_1_simulation: $(MS_1_MODULE).out ;
autograder_milestone_1_synthesis: $(MS_1_MODULE).syn.out ;
autograder_milestone_1_coverage: $(MS_1_MODULE).cov ;
.PHONY: autograder_%

################################
# ---- Module Testbenches ---- #
################################

# This section adds Make targets for running individual module testbenches
# It requires using the following naming convention:
# 1. the source file: 'verilog/rob.sv'
# 2. should declare a module: 'rob'
# 3. with a testbench file: 'test/rob_test.sv'
# 4. and added to the MODULES variable as: 'rob'
# 5. with extra sources specified for: 'build/rob.simv', 'build/rob.cov', and 'synth/rob.vg'


# This allows you to use the following make targets:

# Simulation
# make <module>.pass   <- greps for "@@@ Passed" or "@@@ Failed" in the output
# make <module>.out    <- run the testbench (via build/<module>.simv)
# make <module>.verdi  <- run in verdi (via <module>.simv)
# make build/<module>.simv  <- compile the testbench executable

# Synthesis
# make <module>.syn.pass   <- greps for "@@@ Passed" or "@@@ Failed" in the output
# make <module>.syn.out    <- run the synthesized module on the testbench
# make <module>.syn.verdi  <- run in verdi (via <module>.syn.simv)
# make synth/<module>.vg        <- synthesize the module
# make build/<module>.syn.simv  <- compile the synthesized module with the testbench

# We have also added targets for checking testbench coverage:

# make <module>.cov        <- print the coverage hierarchy report to the terminal
# make <module>.cov.verdi  <- open the coverage report in verdi
# make build/<module>.cov.simv  <- compiles a coverage executable for the testbench
# make build/<module>.cov.vdb   <- runs the executable and makes a coverage output dir
# make cov_report_<module>      <- run urg to create human readable coverage reports

# ---- Modules to Test ---- #

# TODO: add more modules here
MODULES = cpu mult rob rs rrat icache dcache rat prf free_list fu cdb fu_cdb onehot_mux ooo stage_decode stage_fetch store_queue load_queue branch_predictor sign_align mem lru onehotdec prefetcher ras

# TODO: update this if you add more header files
ALL_HEADERS = $(CPU_HEADERS)

# TODO: add extra source file dependencies below

ICACHE_FILES = verilog/sys_defs.svh verilog/psel_gen.sv verilog/prefetcher.sv verilog/lru.sv verilog/onehotdec.sv
build/icache.simv: $(ICACHE_FILES)
build/icache.cov.simv: $(ICACHE_FILES)
synth/icache.vg: $(ICACHE_FILES)

DCACHE_FILES = verilog/sys_defs.svh verilog/psel_gen.sv verilog/lru.sv verilog/onehotdec.sv
build/dcache.simv: $(DCACHE_FILES)
build/dcache.cov.simv: $(DCACHE_FILES)
synth/dcache.vg: $(DCACHE_FILES)

MULT_FILES = verilog/sys_defs.svh
build/mult.simv: $(MULT_FILES)
build/mult.cov.simv: $(MULT_FILES)
synth/mult.vg: $(MULT_FILES)

# TODO: add any files required for the RS here (besides test/rs_test.sv and verilog/rs.sv)
RS_FILES = verilog/sys_defs.svh verilog/psel_gen.sv
build/rs.simv: $(RS_FILES)
build/rs.cov.simv: $(RS_FILES)
synth/rs.vg: $(RS_FILES)

# TODO: add any files required for the ROB here (besides test/rob_test.sv and verilog/rob.sv)
ROB_FILES = verilog/sys_defs.svh
build/rob.simv: $(ROB_FILES)
build/rob.cov.simv: $(ROB_FILES)
synth/rob.vg: $(ROB_FILES)

# PRF
PRF_FILES = verilog/sys_defs.svh
build/prf.simv: $(PRF_FILES)
build/prf.cov.simv: $(PRF_FILES)
synth/prf.vg: $(PRF_FILES)

# FU_CDB
FU_CDB_FILES = verilog/sys_defs.svh verilog/ISA.svh verilog/fu.sv verilog/cdb.sv verilog/mult.sv verilog/onehot_mux.sv verilog/psel_gen.sv verilog/store_queue.sv verilog/load_queue.sv verilog/sign_align.sv verilog/lru.sv
build/fu_cdb.simv: $(FU_CDB_FILES)
build/fu_cdb.cov.simv: $(FU_CDB_FILES)
synth/fu_cdb.vg: $(FU_CDB_FILES)

# FREE_LIST
FREE_LIST_FILES = verilog/sys_defs.svh
build/prf.simv: $(FREE_LIST_FILES)
build/prf.cov.simv: $(FREE_LIST_FILES)
synth/prf.vg: $(FREE_LIST_FILES)

# RAT
RAT_FILES = verilog/sys_defs.svh verilog/free_list.sv
build/rat.simv: $(RAT_FILES)
build/rat.cov.simv: $(RAT_FILES)
synth/rat.vg: $(RAT_FILES)

# RRAT
RRAT_FILES = verilog/sys_defs.svh verilog/free_list.sv
build/rrat.simv: $(RRAT_FILES)
build/rrat.cov.simv: $(RRAT_FILES)
synth/rrat.vg: $(RRAT_FILES)

# OOO
OOO_FILES = verilog/sys_defs.svh verilog/ISA.svh verilog/rs.sv verilog/fu_cdb.sv verilog/prf.sv verilog/rob.sv verilog/rat.sv verilog/rrat.sv verilog/psel_gen.sv verilog/fu.sv verilog/cdb.sv verilog/free_list.sv verilog/mult.sv verilog/onehot_mux.sv verilog/dcache.sv verilog/store_queue.sv verilog/load_queue.sv verilog/sign_align.sv verilog/onehotdec.sv verilog/lru.sv
build/ooo.simv: $(OOO_FILES)
build/ooo.cov.simv: $(OOO_FILES)
synth/ooo.vg: $(OOO_FILES)

# STAGE_DECODE
STAGE_DECODE_FILES = verilog/sys_defs.svh verilog/stage_decode.sv verilog/decoder.sv
build/stage_decode.simv: $(STAGE_DECODE_FILES)
build/stage_decode.cov.simv: $(STAGE_DECODE_FILES)
synth/stage_decode.vg: $(STAGE_DECODE_FILES)

# STAGE_FETCH
STAGE_FETCH_FILES = verilog/sys_defs.svh verilog/stage_fetch.sv verilog/icache.sv verilog/psel_gen.sv verilog/branch_predictor.sv verilog/prefetcher.sv
build/stage_fetch.simv: $(STAGE_FETCH_FILES)
build/stage_fetch.cov.simv: $(STAGE_FETCH_FILES)
synth/stage_fetch.vg: $(STAGE_FETCH_FILES)

# ONEHOT_MUX
ONEHHOT_MUX_FILES = verilog/sys_defs.svh verilog/onehot_mux.sv
build/onehot_mux.simv: $(ONEHHOT_MUX_FILES)
build/onehot_mux.cov.simv: $(ONEHHOT_MUX_FILES)
synth/onehot_mux.vg: $(ONEHHOT_MUX_FILES)

# STORE_QUEUE
STORE_QUEUE_FILES = verilog/sys_defs.svh verilog/store_queue.sv
build/store_queue.simv: $(STORE_QUEUE_FILES)
build/store_queue.cov.simv: $(STORE_QUEUE_FILES)
synth/store_queue.vg: $(STORE_QUEUE_FILES)

# LOAD_QUEUE
LOAD_QUEUE_FILES = verilog/sys_defs.svh verilog/load_queue.sv verilog/sign_align.sv verilog/onehot_mux.sv verilog/psel_gen.sv
build/load_queue.simv: $(LOAD_QUEUE_FILES)
build/load_queue.cov.simv: $(LOAD_QUEUE_FILES)
synth/load_queue.vg: $(LOAD_QUEUE_FILES)

BRANCH_PREDICTOR_FILES = verilog/sys_defs.svh verilog/branch_predictor.sv
build/branch_predictor.simv: $(BRANCH_PREDICTOR_FILES)
build/branch_predictor.cov.simv: $(BRANCH_PREDICTOR_FILES)
synth/branch_predictor.vg: $(BRANCH_PREDICTOR_FILES)

MEM_FILES = verilog/sys_defs.svh verilog/mem.sv
build/mem.simv: $(MEM_FILES)
build/mem.cov.simv: $(MEM_FILES)
synth/mem.vg: $(MEM_FILES)

LRU_FILES = verilog/lru.sv
build/lru.simv: $(LRU_FILES)
build/lru.cov.simv: $(LRU_FILES)
synth/lru.vg: $(LRU_FILES)

RAS_FILES = verilog/sys_defs.svh verilog/ras.sv
build/ras.simv: $(RAS_FILES)
build/ras.cov.simv: $(RAS_FILES)
synth/ras.vg: $(RAS_FILES)

#################################
# ---- Main CPU Definition ---- #
#################################

# We also reuse this section to compile the cpu, but not to run it
# You should still run programs in the same way as project 3

CPU_HEADERS = verilog/sys_defs.svh \
              verilog/ISA.svh

# test/cpu_test.sv is implicit
CPU_TESTBENCH = test/pipeline_print.c \
                test/mem.sv
# NOTE: you CANNOT alter the given memory module

# verilog/cpu.sv is implicit
CPU_SOURCES = verilog/regfile.sv \
              verilog/icache.sv \
              verilog/mult.sv \
              verilog/cdb.sv \
              verilog/decoder.sv \
              verilog/FIFO.sv \
              verilog/free_list.sv \
              verilog/fu_cdb.sv \
              verilog/fu.sv \
              verilog/icache.sv \
              verilog/ooo.sv \
              verilog/prf.sv \
              verilog/psel_gen.sv \
              verilog/rat.sv \
              verilog/rob.sv \
              verilog/rrat.sv \
              verilog/rs.sv \
              verilog/stage_decode.sv \
              verilog/stage_fetch.sv \
              verilog/onehot_mux.sv \
              verilog/dcache.sv \
              verilog/branch_predictor.sv \
              verilog/store_queue.sv \
              verilog/load_queue.sv \
              verilog/sign_align.sv \
              verilog/lru.sv \
              verilog/onehotdec.sv \
              verilog/prefetcher.sv





build/cpu.simv: $(CPU_SOURCES) $(CPU_HEADERS) $(CPU_TESTBENCH)
synth/cpu.vg: $(CPU_SOURCES) $(CPU_HEADERS)
build/cpu.syn.simv: $(CPU_TESTBENCH)
# Don't need coverage for the CPU

# Connect the simv and syn_simv targets for the autograder
simv: build/cpu.simv ;
syn_simv: build/cpu.syn.simv ;

# You shouldn't need to change things below here

#####################
# ---- Running ---- #
#####################

# The following Makefile targets heavily use pattern substitution and static pattern rules
# See these links if you want to hack on them and understand how they work:
# - https://www.gnu.org/software/make/manual/html_node/Text-Functions.html
# - https://www.gnu.org/software/make/manual/html_node/Static-Usage.html
# - https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html

# run compiled executables ('make %.out' is linked to 'make output/%.out' further below)
# using this syntax avoids overlapping with the 'make <my_program>.out' targets
$(MODULES:%=build/%.out) $(MODULES:%=build/%.syn.out): build/%.out: build/%.simv
	@$(call PRINT_COLOR, 5, running $<)
	cd build && ./$(<F) | tee $(@F)

# Connect 'make build/mod.out' to 'make mod.out'
$(MODULES:%=./%.out) $(MODULES:%=./%.syn.out): ./%.out: build/%.out
	@$(call PRINT_COLOR, 2, Finished $* testbench output is in: $<)

# Print in green or red the pass/fail status (must $display() "@@@ Passed" or "@@@ Failed")
%.pass: build/%.out
	@$(call PRINT_COLOR, 6, Grepping for pass/fail in $<:)
	@GREP_COLOR="01;31" $(GREP) -i '@@@ ?Failed' $< || \
	GREP_COLOR="01;32" $(GREP) -i '@@@ ?Passed' $<
.PHONY: %.pass

# run the module in verdi
./%.verdi: build/%.simv
	@$(call PRINT_COLOR, 5, running $< with verdi )
	cd build && ./$(<F) $(RUN_VERDI)
.PHONY: %.verdi

###############################
# ---- Compiling Verilog ---- #
###############################

# The normal simulation executable will run your testbench on simulated modules
$(MODULES:%=build/%.simv): build/%.simv: test/%_test.sv verilog/%.sv | build
	@$(call PRINT_COLOR, 5, compiling the simulation executable $@)
	@$(call PRINT_COLOR, 3, NOTE: if this is slow to startup: run '"module load vcs verdi synopsys-synth"')
	$(VCS) $(filter-out $(ALL_HEADERS),$^) -o $@
	@$(call PRINT_COLOR, 6, finished compiling $@)

# This also generates many other files, see the tcl script's introduction for info on each of them
synth/%.vg: verilog/%.sv $(TCL_SCRIPT)
	@$(call PRINT_COLOR, 5, synthesizing the $* module)
	@$(call PRINT_COLOR, 3, this might take a while...)
	@$(call PRINT_COLOR, 3, NOTE: if this is slow to startup: run '"module load vcs verdi synopsys-synth"')
	cd synth && \
	MODULE=$* SOURCES="$(filter-out $(TCL_SCRIPT) $(ALL_HEADERS),$^)" \
	dc_shell-t -f $(notdir $(TCL_SCRIPT)) | tee $*_synth.out
	@$(call PRINT_COLOR, 6, finished synthesizing $@)

# A phony target to view the slack in all the *.rep synthesis reports
slack:
	$(GREP) "slack" synth/*.rep
.PHONY: slack

# The synthesis executable runs your testbench on the synthesized versions of your modules
$(MODULES:%=build/%.syn.simv): build/%.syn.simv: test/%_test.sv synth/%.vg | build
	@$(call PRINT_COLOR, 5, compiling the synthesis executable $@)
	$(VCS) +define+SYNTH $(filter-out $(ALL_HEADERS),$^) $(LIB) -o $@
	@$(call PRINT_COLOR, 6, finished compiling $@)

##############################
# ---- Coverage targets ---- #
##############################

# This section adds targets to run module testbenches with coverage output

# Additional VCS argument for both building and running with coverage output
VCS_COVG = -cm line+tgl+cond+branch

$(MODULES:%=build/%.cov.simv): build/%.cov.simv: test/%_test.sv verilog/%.sv | build
	@$(call PRINT_COLOR, 5, compiling the coverage executable $@)
	@$(call PRINT_COLOR, 3, NOTE: if this is slow to startup: run '"module load vcs verdi synopsys-synth"')
	$(VCS) $(VCS_COVG) $(filter-out $(ALL_HEADERS),$^) -o $@
	@$(call PRINT_COLOR, 6, finished compiling $@)

# Run the testbench to produce a *.vdb directory with coverage info
$(MODULES:%=build/%.cov.simv.out): %.cov.simv.out: %.cov.simv | build
	@$(call PRINT_COLOR, 5, running $<)
	cd build && ./$(<F) $(VCS_COVG) | tee $(@F)
	@$(call PRINT_COLOR, 2, created coverage dir $<.vdb and saved output to $@)

# A layer of indirection for the coverage output dir
build/%.cov.simv.vdb: build/%.cov.simv.out ;

# Use urg to generate human-readable reports in text mode (alternative is html)
$(MODULES:%=cov_report_%): cov_report_%: build/%.cov.simv.vdb
	@$(call PRINT_COLOR, 5, outputting coverage report in $@)
	# module load vcs  # not sure why this is necessary for 'urg'
	module load vcs && cd build && urg -format text -dir $*.cov.simv.vdb -report ../$@
	@$(call PRINT_COLOR, 2, coverage report is in $@)

# view the coverage hierarchy report
$(MODULES:=.cov): %.cov: cov_report_%
	@$(call PRINT_COLOR, 2, printing coverage hierarchy - open '$<' for more)
	cat $</hierarchy.txt

# open the coverage info in verdi
$(MODULES:=.cov.verdi): %.cov.verdi: build/%.cov.simv
	@$(call PRINT_COLOR, 5, running verdi for $* coverage)
	cd build && ./$(<F) $(RUN_VERDI) -cov -covdir $(<F).vdb
	./$< $(RUN_VERDI) -cov -covdir $<.vdb

.PHONY: %.cov %.cov.verdi

#############################
# ---- Visual Debugger ---- #
#############################

# Add your own GUI debugger here!

VTUBER = test/vtuber_test.sv \
         test/vtuber.cpp \
		 test/mem.sv

VISFLAGS = -lncurses

vis_simv: $(CPU_HEADERS) $(VTUBER) $(CPU_SOURCES)
	@$(call PRINT_COLOR, 5, compiling visual debugger testbench)
	$(VCS) $(VISFLAGS) $^ -o vis_simv
	@$(call PRINT_COLOR, 6, finished compiling visual debugger testbench)

%.vis: programs/%.mem vis_simv
	./vis_simv +MEMORY=$<
.PHONY: %.vis

####################################
# ---- Executable Compilation ---- #
####################################

########################################
# ---- Program Memory Compilation ---- #
########################################

# this section will compile programs into .mem files to be loaded into memory
# you start with either an assembly or C program in the programs/ directory
# those compile into a .elf link file via the riscv assembler or compiler
# then that link file is converted to a .mem hex file

# find the test program files and separate them based on suffix of .s or .c
# filter out files that aren't themselves programs
NON_PROGRAMS = $(CRT)
ASSEMBLY = $(filter-out $(NON_PROGRAMS),$(wildcard programs/*.s))
C_CODE   = $(filter-out $(NON_PROGRAMS),$(wildcard programs/*.c))

# concatenate ASSEMBLY and C_CODE to list every program
PROGRAMS = $(ASSEMBLY:%.s=%) $(C_CODE:%.c=%)

# NOTE: this is Make's pattern substitution syntax
# see: https://www.gnu.org/software/make/manual/html_node/Text-Functions.html#Text-Functions
# this reads as: $(var:pattern=replacement)
# a percent sign '%' in pattern is as a wildcard, and can be reused in the replacement
# if you don't include the percent it automatically attempts to replace just the suffix of the input

# C and assembly compilation files. These link and setup the runtime for the programs
CRT        = programs/crt.s
LINKERS    = programs/linker.lds
ASLINKERS  = programs/aslinker.lds

# make elf files from assembly code
%.elf: %.s $(ASLINKERS)
	@$(call PRINT_COLOR, 5, compiling assembly file $<)
	$(GCC) $(ASFLAGS) $< -T $(ASLINKERS) -o $@

# make elf files from C source code
%.elf: %.c $(CRT) $(LINKERS)
	@$(call PRINT_COLOR, 5, compiling C code file $<)
	$(GCC) $(CFLAGS) $(OFLAGS) $(CRT) $< -T $(LINKERS) -o $@

# C programs can also be compiled in debug mode, this is solely meant for use in the .dump files below
%.debug.elf: %.c $(CRT) $(LINKERS)
	@$(call PRINT_COLOR, 5, compiling debug C code file $<)
	$(GCC) $(CFLAGS) $(OFLAGS) $(CRT) $< -T $(LINKERS) -o $@
	$(GCC) $(DEBUG_FLAG) $(CFLAGS) $(OFLAGS) $(CRT) $< -T $(LINKERS) -o $@

# declare the .elf files as intermediate files.
# Make will automatically rm intermediate files after they're used in a recipe
# and it won't remake them until their sources are updated or they're needed again
.INTERMEDIATE: %.elf

# turn any elf file into a hex memory file ready for the testbench
%.mem: %.elf
	$(ELF2HEX) 8 8192 $< > $@
	@$(call PRINT_COLOR, 6, created memory file $@)
	@$(call PRINT_COLOR, 3, NOTE: to see RISC-V assembly run: '"make $*.dump"')
	@$(call PRINT_COLOR, 3, for \*.c sources also try: '"make $*.debug.dump"')

# compile all programs in one command (use 'make -j' to run multithreaded)
compile_all: $(PROGRAMS:=.mem)
.PHONY: compile_all

########################
# ---- Dump Files ---- #
########################

# when debugging a program, the dump files will show you the disassembled RISC-V
# assembly code that your processor is actually running

# this creates the <my_program>.debug.elf targets, which can be used in: 'make <my_program>.debug.dump_*'
# these are useful for the C sources because the debug flag makes the assembly more understandable
# because it includes some of the original C operations and function/variable names

DUMP_PROGRAMS = $(ASSEMBLY:.c=) $(C_CODE:.c=.debug)

# 'make <my_program>.dump' will create both files at once!
./%.dump: programs/%.dump_x programs/%.dump_abi ;
.PHONY: ./%.dump
# Tell Make to treat the .dump_* files as "precious" and not to rm them as intermediaries to %.dump
.PRECIOUS: %.dump_x %.dump_abi

# use the numberic x0-x31 register names
%.dump_x: %.elf
	@$(call PRINT_COLOR, 5, disassembling $<)
	$(OBJDUMP) $(OBJDFLAGS) $< > $@
	@$(call PRINT_COLOR, 6, created numeric dump file $@)

# use the Application Binary Interface register names (sp, a0, etc.)
%.dump_abi: %.elf
	@$(call PRINT_COLOR, 5, disassembling $<)
	$(OBJDUMP) $(OBJFLAGS) $< > $@
	@$(call PRINT_COLOR, 6, created abi dump file $@)

# create all dump files in one command (use 'make -j' to run multithreaded)
dump_all: $(DUMP_PROGRAMS:=.dump_x) $(DUMP_PROGRAMS:=.dump_abi)
.PHONY: dump_all

###############################
# ---- Program Execution ---- #
###############################

# run one of the executables (simv/syn_simv) using the chosen program
# e.g. 'make sampler.out' does the following from a clean directory:
#   1. compiles simv
#   2. compiles programs/sampler.s into its .elf and then .mem files (in programs/)
#   3. runs ./simv +MEMORY=programs/sampler.mem +OUTPUT=output/sampler > output/sampler.out
#   4. which creates the sampler.out, sampler.cpi, sampler.wb, and sampler.ppln files in output/
# the same can be done for synthesis by doing 'make sampler.syn.out'
# which will also create .syn.cpi, .syn.wb, and .syn.ppln files in output/

# run a program and produce output files
output/%.out: programs/%.mem build/cpu.simv | output
	@$(call PRINT_COLOR, 5, running simv on $<)
	./build/cpu.simv +MEMORY=$< +OUTPUT=output/$* > $@
	@$(call PRINT_COLOR, 6, finished running simv on $<)
	@$(call PRINT_COLOR, 2, output is in output/$*.{out cpi wb ppln})
# NOTE: this uses a 'static pattern rule' to match a list of known targets to a pattern
# and then generates the correct rule based on the pattern, where % and $* match
# so for the target 'output/sampler.out' the % matches 'sampler' and depends on programs/sampler.mem
# see: https://www.gnu.org/software/make/manual/html_node/Static-Usage.html
# $(@D) is an automatic variable for the directory of the target, in this case, 'output'

# this does the same as simv, but adds .syn to the output files and compiles syn_simv instead
# run synthesis with: 'make <my_program>.syn.out'
output/%.syn.out: programs/%.mem build/cpu.syn.simv | output
	@$(call PRINT_COLOR, 5, running syn_simv on $<)
	@$(call PRINT_COLOR, 3, this might take a while...)
	./build/cpu.syn.simv +MEMORY=$< +OUTPUT=output/$*.syn > $@
	@$(call PRINT_COLOR, 6, finished running syn_simv on $<)
	@$(call PRINT_COLOR, 2, output is in output/$*.syn.{out cpi wb ppln})

# Allow us to type 'make <my_program>.out' instead of 'make output/<my_program>.out'
./%.out: output/%.out ;
.PHONY: ./%.out

# Declare that creating a %.out file also creates both %.cpi, %.wb, and %.ppln files
%.cpi %.wb %.ppln: %.out ;

.PRECIOUS: %.out %.cpi %.wb %.ppln

# run all programs in one command (use 'make -j' to run multithreaded)
simulate_all: build/cpu.simv compile_all $(PROGRAMS:programs/%=output/%.out)
simulate_all_syn: build/cpu.syn.simv compile_all $(PROGRAMS:programs/%=output/%.syn.out)
.PHONY: simulate_all simulate_all_syn

###################
# ---- Verdi ---- #
###################

# run verdi on a program with: 'make <my_program>.verdi' or 'make <my_program>.syn.verdi'

# this creates a directory verdi will use if it doesn't exist yet
verdi_dir:
	mkdir -p /tmp/$${USER}470
.PHONY: verdi_dir

novas.rc: initialnovas.rc
	sed s/UNIQNAME/$$USER/ initialnovas.rc > novas.rc

%.verdi: programs/%.mem build/cpu.simv novas.rc verdi_dir | output
	./build/cpu.simv $(RUN_VERDI) +MEMORY=$< +OUTPUT=output/verdi_output

%.syn.verdi: programs/%.mem build/cpu.syn.simv novas.rc verdi_dir | output
	./build/cpu.syn.simv $(RUN_VERDI) +MEMORY=$< +OUTPUT=output/syn_verdi_output

.PHONY: %.verdi

#######################
# ---- Comparing ---- #
#######################

correct_out/%.out:
	./script/program.sh $(basename $(notdir $@))

p3_generate_all: $(PROGRAMS:%=correct_out/%.out)
.PHONY: p3_generate_all

diff/%.out.diff: output/%.out correct_out/%.out
	./script/compare.sh $(basename $(notdir $<))

compare_all: $(PROGRAMS:programs/%=diff/%.out.diff)
.PHONY: compare_all

################################
# ---- Output Directories ---- #
################################

# Specific directories for holding build files or run outputs
# Targets that add files to these directories must add them after a pipe: "| build"
# i.e. build/simv: $(SOURCES) ... $(TESTBENCH) | build
# i.e. output/program.out: $(SOURCES) ... $(TESTBENCH) | output
# note the "| build" and "| output"

# NOTE: these are deleted entirely by 'make clean' and 'make nuke' respectively
build:
	mkdir -p build
output:
	mkdir -p output

#####################
# ---- Cleanup ---- #
#####################

# You should only clean your directory if you think something has built incorrectly
# or you want to prepare a clean directory for e.g. git (first check your .gitignore).
# Please avoid cleaning before every build. The point of a makefile is to
# automatically determine which targets have dependencies that are modified,
# and to re-build only those as needed; avoiding re-building everything everytime.

# 'make clean' removes build/output files, 'make nuke' removes all generated files
# 'make clean' does not remove .mem or .dump files
# clean_* commands remove certain groups of files

clean: clean_exe clean_run_files clean_diff_files
	@$(call PRINT_COLOR, 6, note: clean is split into multiple commands you can call separately: $^)

# removes all extra synthesis files and the entire output directory
# use cautiously, this can cause hours of recompiling in project 4
nuke: clean clean_output clean_synth clean_programs
	@$(call PRINT_COLOR, 6, note: nuke is split into multiple commands you can call separately: $^)

clean_exe:
	@$(call PRINT_COLOR, 3, removing compiled executable files)
	rm -rf build/                         # remove the entire 'build' folder
	rm -rf *simv *.daidir csrc *.key      # created by simv/syn_simv/vis_simv
	rm -rf vcdplus.vpd vc_hdrs.h          # created by simv/syn_simv/vis_simv
	rm -rf unifiedInference.log xprop.log # created by simv/syn_simv/vis_simv
	rm -rf *.cov cov_report_* cm.log      # coverage files
	rm -rf verdi* novas* *fsdb*           # verdi files
	rm -rf dve* inter.vpd DVEfiles        # old DVE debugger

clean_run_files:
	@$(call PRINT_COLOR, 3, removing per-run outputs)
	rm -rf output/*.out output/*.cpi output/*.wb output/*.ppln

clean_diff_files:
	@$(call PRINT_COLOR, 3, removing per-run diff outputs)
	rm -rf diff/*.diff

clean_synth:
	@$(call PRINT_COLOR, 1, removing synthesis files)
	cd synth && rm -rf *.vg *_svsim.sv *.res *.rep *.ddc *.chk *.syn *.out *.db *.svf *.mr *.pvl command.log

clean_output:
	@$(call PRINT_COLOR, 1, removing entire output directory)
	rm -rf output/

clean_programs:
	@$(call PRINT_COLOR, 3, removing program memory files)
	rm -rf programs/*.mem
	@$(call PRINT_COLOR, 3, removing dump files)
	rm -rf programs/*.dump*

.PHONY: clean nuke clean_%

######################
# ---- Printing ---- #
######################

# this is a GNU Make function with two arguments: PRINT_COLOR(color: number, msg: string)
# it does all the color printing throughout the makefile
PRINT_COLOR = if [ -t 0 ]; then tput setaf $(1) ; fi; echo $(2); if [ -t 0 ]; then tput sgr0; fi
# colors: 0:black, 1:red, 2:green, 3:yellow, 4:blue, 5:magenta, 6:cyan, 7:white
# other numbers are valid, but aren't specified in the tput man page

# Make functions are called like this:
# $(call PRINT_COLOR,3,Hello World!)
# NOTE: adding '@' to the start of a line avoids printing the command itself, only the output
