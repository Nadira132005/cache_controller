#!/bin/bash

# Find the vvp process ID and kill it
PID=$(ps -aux | grep "[v]vp" | awk '{print $2}')
if [ -n "$PID" ]; then
    echo "Killing vvp process with PID: $PID"
    kill -9 $PID
    echo "Process killed"
else
    echo "No vvp process found"
fi
