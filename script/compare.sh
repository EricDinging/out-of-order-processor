#!/bin/bash

# Check if two filenames are provided as arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

file="$1"

diff "output/$file.out" "correct_out/$file.out" | grep "@@@" > "diff/$file.out.diff" || true
diff "output/$file.wb"  "correct_out/$file.wb"  > "diff/$file.wb.diff"  || true
diff "output/$file.cpi" "correct_out/$file.cpi" > "diff/$file.cpi.diff" || true
