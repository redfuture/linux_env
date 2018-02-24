#!/bin/bash

source $(dirname "$0")/start-qemu.sh

echo "VM $vm_name started at VNC port:$vnc_port and websocket port:$ws_port using command:"
echo "$qcmd $OPTS"
