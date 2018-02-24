#!/bin/bash
if [ -z $1 ]
then
	echo "Usage: $0 taskid action"
	exit
fi
taskid=$1
action=$2

rec_running=0
#echo $taskid $action
output=$(bash $(cd "$(dirname "$0")"; pwd -P)/start-qemu.sh -s -t $taskid)
#echo $output
echo $output |grep 'not running'
ret=$?
if [ $ret -eq 0 ]
then
	echo "VM with taskid $taskid is not running, exiting..."
	exit
fi

read vm_name vm_pid_file vm_result_dir video_file rec_pid_file vm_ports_file vm_sock_file os_booted_file <<< $output

if [ ! -f $vm_pid_file ] 
then
	echo "VM reports running ,but vm_pid_file not exist..."
	vm_pid=$(ps aux|grep "$vm_name "|grep 'qemu-system-'|grep -v 'grep'| awk '{print $2}')
	if [ -z $vm_pid ]
	then
		echo "VM for this taskid:$taskid is not running, exiting..."
		exit
	else
		echo "Got pid:$pid from ps command, restoring to pid file.."
		echo $pid > $vm_pid_file
	fi
fi
#basically , if we are here , it's sure that the VM is running , and we have correct pid in vm_pid_file.

if [ -f $vm_ports_file ]
then
	read vnc_port ws_port < $vm_ports_file
	disp_num=$(( $vnc_port - 5900 ))
	ps aux|grep "$vm_name "|grep 'qemu-system-'|grep -v 'grep'|grep $disp_num &> /dev/null
	ret_vnc=$?
	ps aux|grep "$vm_name "|grep 'qemu-system-'|grep -v 'grep'|grep $ws_port &> /dev/null
	ret_ws=$?
	if [ $ret_vnc -eq 1 ] || [ $ret_ws -eq 1 ]
	then
		echo "VM ports file have incorrect port number:$vnc_port,$ws_port, please verify.."
		exit
	fi
else
	echo "VM ports file doesn't exist, please verify.."
	exit
fi

#here we have vm running and vm_pid_file correct, vm_ports_file correct.

if [ ! -f $rec_pid_file ]
then
	echo "rec_pid_file not exist..."
	rec_pid=$(ps aux|grep "$vm_name"|grep 'flvrec'|grep -v grep| awk '{print $2}')
	if [ ! -z $rec_pid ]
	then
		echo "But recorder for this taskid:$taskid is running as rec_pid:$rec_pid, creating rec_pid_file.."
		echo $rec_pid > $rec_pid_file
		rec_running=1
	else
		echo "VNC recorder is not running."
		rec_running=0
	fi
else
	echo "rec_pid_file exist, verfiying the pid"
	read rd_rec_pid < $rec_pid_file
	rec_pid=$(ps aux|grep "$vm_name"|grep 'flvrec'|grep -v grep| awk '{print $2}')
	if [ ! -z $rec_pid ]
        then
		if [ $rec_pid == $rd_rec_pid ]
		then
			echo "rec_pid_file have correct pid value for recorder."
			rec_running=1
		else
			echo "updating the pid file in the rec_pid_file to :$rec_pid"
			echo $rec_pid > $rec_pid_file
			rec_running=1
		fi	
	else
		echo "rec_pid_file exist but recorder process not running, deleting the $rec_pid_file"
		rm -f $rec_pid_file
		rec_running=0
	fi
fi

#echo $video_file $vnc_port $vm_pid 

function rec_status
{
	if [ $rec_running -eq 1 ]
	then
		echo "Recorder process running,pid=$rec_pid"
		return 0
	else
		echo "Recorder process not running."
		return 1
	fi
}

function start
{
	if [ -f $video_file ]
	then
		archive_video $video_file
	fi
        #/usr/local/bin/flvrec.py -g 1280x960 -o $video_file localhost $vnc_port &> /dev/null &
        /usr/local/bin/flvrec.py -g 1024x768 -o $video_file localhost $vnc_port &> /dev/null &
        rec_pid=$!
        echo $rec_pid > $rec_pid_file
}

function stop
{
        read rec_pid < $rec_pid_file
        kill -2 $rec_pid
	rm -f $rec_pid_file
}

function archive_video
{
	old_video_file=$1
	datestring=$(date +%Y%m%d%H%M%S)
	extension=${old_video_file##*.}
	filename=${old_video_file%.*}
	new_video_file="${filename}-${datestring}.${extension}"
	mv $old_video_file $new_video_file
	echo "Video file archived from $old_video_file to $new_video_file"
}

case $action in
        status )
                rec_status
                ;;
        start )
		rec_status
		check=$?
		if [ $check -eq 0 ]
		then
			echo "Recorder already running."
			exit
		else
			echo "Starting Recorder..."
                	start
			exit
		fi
                ;;
        stop )
		rec_status
		check=$?
		if [ $check -eq 0 ]
		then
			echo "Stopping Recorder."
                	stop
			echo "Recorder stopped."
			archive_video $video_file
			exit
		else
			echo "Recorder already stopped."
			exit
		fi
                ;;
	restart )
		rec_status
		check=$?
		if [ $check -eq 0 ]
		then
			echo "Recorder running on $rec_pid, stopping..."
			stop
			echo "Recorder stopped."
			archive_video $video_file
			echo "Starting Recorder..."
			start
			echo "Done."
			exit
		else
			echo "Recorder not running, starting..."
			start
			exit
		fi
		
		;;
        *)
                echo "Usage: $0 taskid {start|stop|restart|status}"
                exit 2
                ;;
esac
