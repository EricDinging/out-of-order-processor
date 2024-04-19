#!/bin/bash

# Check if two filenames are provided as arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

script="$1"
dir="/home/weixinyu/eecs470"


cp ${dir}/p4/programs/${script}.s ${dir}/p3_original/programs/${script}.s
cd ${dir}/p3_original
make ${script}.out && cp ${dir}/p3_original/output/${script}.wb ${dir}/p4/correct_out/${script}.wb
cd ${dir}/p4
make ${script}.out && ./script/compare.sh ${script}.wb