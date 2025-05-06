#!/bin/sh
odin build . -debug && i3-msg workspace 4 
cp alarm ~/bin/alarm

# && ./alarm 10s and so yeah & ./alarm -l
# ./alarm --all 
