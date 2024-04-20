#!/bin/bash

echo "Comparing ground truth outputs to new processor"

original_output_dir="/home/sylei/eecs470/proj/p4_cache/correct_out"
impl_output_dir="/home/sylei/eecs470/proj/p4_cache/output"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
RESET='\033[0m'

# This only runs *.s files. How could you add *.c files?
for source_file in programs/*.{s,c}; do
  if [ "$source_file" = "programs/crt.s" ]; then
    continue
  fi
  program=$(echo "$source_file" | cut -d '.' -f1 | cut -d '/' -f 2)
  echo -e "${BLUE}Running ${program}${RESET}"
  make "${program}.out"

  # echo "Comparing writeback output for $program"
  diff_wb=$(diff ${original_output_dir}/${program}.wb ${impl_output_dir}/${program}.wb)

  # echo "Comparing memory output for $program"
  ground_truth_lines=$(grep '@@@' ${original_output_dir}/${program}.out)
  your_lines=$(grep '@@@' ${impl_output_dir}/${program}.out)
  diff_mem=$(diff <(echo "$ground_truth_lines") <(echo "$your_lines"))
  # diff_mem=""

  # echo "Printing Passed or Failed"
  if [ -z "$diff_mem" ] && [ -z "$diff_wb" ]; then
    echo -e "${GREEN}Passed${RESET}"
  else
    echo -e "${RED}Failed${RESET}"
    echo -e "${YELLOW}writeback output diff${RESET}"
    echo $diff_wb
    echo -e "${YELLOW}memory output diff${RESET}"
    echo $diff_mem
    exit 1
  fi
done

echo -e ${GREEN}"All Programs Passed"${RESET}
