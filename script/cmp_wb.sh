#!/bin/bash

# Check if two filenames are provided as arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

file="$1"

diff "output/$file.wb"  "correct_out/$file.wb"
