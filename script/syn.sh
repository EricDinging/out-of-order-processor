#!/bin/bash

# Check if an argument is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: \$0 <module>"
    exit 1
fi

module=$1

# Make sure the syn_log directory exists
mkdir -p syn_log

# Run the command and redirect its output to a log file
make synth/$module.vg > syn_log/$module.syn.log
