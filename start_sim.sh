#!/bin/bash
set -e

# Create work directory
vlib work

# Compile all Verilog files in the current directory
vlog -sv *.v

# Run the simulation
vsim -c -do "run -all" cache_controller_tb
