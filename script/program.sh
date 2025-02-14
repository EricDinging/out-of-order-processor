#!/bin/bash

# Check if two filenames are provided as arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

script="$1"
dir="/home/$USER/Documents/eecs470"

group="group9"


cp ${dir}/p4-w24.${group}/programs/${script}.s ${dir}/p3-w24.${USER}/programs/${script}.s || true
cp ${dir}/p4-w24.${group}/programs/${script}.c ${dir}/p3-w24.${USER}/programs/${script}.c || true
cd ${dir}/p3-w24.${USER}
make ${script}.out
cp ${dir}/p3-w24.${USER}/output/${script}.wb ${dir}/p4-w24.${group}/correct_out/${script}.wb
cp ${dir}/p3-w24.${USER}/output/${script}.out ${dir}/p4-w24.${group}/correct_out/${script}.out
cp ${dir}/p3-w24.${USER}/output/${script}.cpi ${dir}/p4-w24.${group}/correct_out/${script}.cpi
cd ${dir}/p3-w24.${USER}
make ${script}.out
