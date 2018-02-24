#!/bin/bash

vm_name=$1
working_img=$2
vm_pid_file=$3
vm_pid=$(cat $vm_pid_file)
vm_ports_file=$4
rec_pid_file=$5
video_file=$6
vm_sock_file=$7
os_booted_file=$8

echo "clean up process for VM:$vm_name started."
while true
do 
	ps aux |grep -v grep |grep -v qemu-monitor |grep -v flvrec.py| grep "$vm_name " > /dev/null 2>&1
	if [ $? -eq 1 ]
	then
		echo "VM $vm_name is stopped."
		read rec_pid < $rec_pid_file
		sleep 3
		ps --no-header $rec_pid
		ret=$?
		if [ $ret -eq 0 ]
		then
			echo "VNC recording process $rec_pid still running ,killing.."
			kill -2 $rec_pid
		fi
		rm -f $working_img $vm_pid_file $vm_ports_file $rec_pid_file $vm_sock_file $os_booted_file
		echo "files cleaned up:$working_img $vm_pid_file $vm_ports_file $vm_sock_file $os_booted_file"
		break
	fi

	echo "VM $vm_name still running."
	sleep 5
	continue
done
echo "Clean up done, exiting."
