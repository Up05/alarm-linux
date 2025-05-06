#!/bin/sh
nohup bash -c "sleep $1; notify-send $2 -a alarm" &> /dev/null &
