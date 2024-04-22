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
    "backtrack" \
    "basic_malloc" \
    "bfs" \
    "btest1" \
    "btest2" \
    "copy_long" \
    "copy" \
    "crt" \
    "dft" \
    "evens_long" \
    "evens" \
    "fc_forward" \
    "fib_long" \
    "fib_rec" \
    "fib" \
    "graph" \
    "haha" \
    "halt" \
    "hw_test_ipc" \
    "insertion" \
    "insertionsort" \
    "load_simple" \
    "load_store_simple" \
    "matrix_mult_rec" \
    "mergesort" \
    "mult_no_lsq" \
    "mult_orig" \
    "no_hazard" \
    "omegalul" \
    "outer_product" \
    "parallel" \
    "priority_queue" \
    "quicksort" \
    "sampler" \
    "saxpy" \
    "sort_search" \
    "loop_big" \
    # "loop_simple" \
    # "sw_align" \
    # "sw_lw" \
)

# Initialize variables to hold total cycles and instructions
total_cycles=0
total_instrs=0

working_path=$(pwd)
# Iterate over the list of filenames
for filename in "${file_list[@]}"; do
    make "$filename.out" -j
    # Extract cycles, instructions, and CPI from the file
    if [ -e "$working_path/output/$filename.cpi" ]; then

        cycles=$(grep -oP '@@@  \K[0-9]+(?= cycles)' "$working_path/output/$filename.cpi")
        instrs=$(grep -oP '@@@  [0-9]+ cycles / \K[0-9]+(?= instrs)' "$working_path/output/$filename.cpi")
        cpi=$(calculate_cpi "$cycles" "$instrs")
        echo "@@@  $cycles cycles / $instrs instrs = $cpi CPI"
        total_cycles=$((total_cycles + cycles))
        total_instrs=$((total_instrs + instrs))

        correct=$(grep -oP 'predictor hit rate: \K[0-9]+(?= correct)' "$working_path/output/$filename.cpi")
        branches=$(grep -oP 'predictor hit rate: [0-9]+ correct / \K[0-9]+(?= branches)' "$working_path/output/$filename.cpi")
        hit=$(calculate_cpi "$correct" "$branches")
        echo "@@@  $correct correct / $branches branches = $hit hit"
        total_correct=$((total_correct + correct))
        total_branches=$((total_branches + branches))
    else
        echo "File not found: output/$filename.cpi"
    fi
done

# Calculate the average CPI
average_cpi=$(calculate_cpi "$total_cycles" "$total_instrs")
average_hit=$(calculate_cpi "$total_correct" "$total_branches")

# Print the average CPI
echo "Average CPI: $average_cpi"
echo "Average hit: $average_hit"

