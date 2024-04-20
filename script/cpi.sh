#!/bin/bash
set -e

# Define a function to calculate CPI
calculate_cpi() {
    cycles=$1
    instrs=$2
    cpi=$(bc <<< "scale=6; $cycles / $instrs")
    echo "$cpi"
}

# List of filenames in an array
file_list=(
    "alexnet" \
    "alu_add" \
    "backtrack" \
    "basic_malloc"
    "bfs"
    "branch"
    "btest1" \
    "btest2" \
    "copy_long" \
    "copy" \
    "countdown" \
    "dft" \
    "evens_long" \
    "evens" \
    "fc_forward" \
    "fib_long" \
    "fib_rec" \
    "fib" \
    "gcd" \
    "gcd_strict" \
    "graph" \
    "haha" \
    "hw_test_ipc" \
    "insertion" \
    "insertionsort" \
    "load_simple" \
    "load_store_simple" \
    "loop_big" \
    "loop_simple" \
    "matrix_mult_rec" \
    "mem_evict" \
    "mergesort" \
    "mult_no_lsq" \
    "mult_orig" \
    "mult_simple" \
    "mult_test" \
    "no_hazard" \
    "omegalul" \
    "outer_product" \
    "parallel" \
    "priority_queue" \
    "quicksort" \
    "sampler" \
    "saxpy" \
    "sort_search" \
    "store_simple" \
    "sw_align" \
    "sw_lw" \
    "write_evict_load" \
)

# Initialize variables to hold total cycles and instructions
total_cycles=0
total_instrs=0

working_path=$(pwd)
# Iterate over the list of filenames
for filename in "${file_list[@]}"; do
    make "$filename.out"
    # Extract cycles, instructions, and CPI from the file
    if [ -e "$working_path/output/$filename.cpi" ]; then

        cycles=$(grep -oP '@@@  \K[0-9]+(?= cycles)' "$working_path/output/$filename.cpi")
        instrs=$(grep -oP '@@@  [0-9]+ cycles / \K[0-9]+(?= instrs)' "$working_path/output/$filename.cpi")
        cpi=$(calculate_cpi "$cycles" "$instrs")
        echo "@@@  $cycles cycles / $instrs instrs = $cpi CPI"
        total_cycles=$((total_cycles + cycles))
        total_instrs=$((total_instrs + instrs))
    else
        echo "File not found: output/$filename.cpi"
    fi
done

# Calculate the average CPI
average_cpi=$(calculate_cpi "$total_cycles" "$total_instrs")

# Print the average CPI
echo "Average CPI: $average_cpi"
