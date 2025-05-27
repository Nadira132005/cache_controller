#!/bin/bash                                                                     
set -e                                                                          
                                                                                
# Compile the Verilog files                                                     
iverilog -g2012 -o cache_simulator cache_controller.v cache_controller_tb.sv flipflop_d.v replacer.v block_selector.v                            
vvp cache_simulator
                                                                                
# Open the waveform with GTKWave                                                
# if [ -f "cache_controller_tb.vcd" ]; then                                       
#     gtkwave cache_controller_tb.vcd &                                           
# fi                                        