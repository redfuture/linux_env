#!/bin/bash
#usage: start-qemu.sh [-c -r -m -k -s] -t taskid
need_clean=0
with_vncrecord=0
runinmemory=0
killvm=0
showonly=0
checkboot=0
ip_addr="10.151.199.29"

if [ $# -eq 0 ]
then
	echo "No arguments supplied."
	echo "Usage: start-qemu.sh [ -b ] [-c ] [ -r ] [ -m ] [ -k ] -t taskid"
	echo "-b: Check the VM boot status file:booted.txt, exist and with content 1 means OS is ready for operating."
	echo "-c: start up a cleanup monintor process with the VM."
	echo "-k: Kill the VM,specified by taskid."
	echo "-r: start up a vnc recorder process with the VM."
	echo "-s: Olny display the vm information for taskid.Output sequence:vm_name vm_pid_file vm_result_dir video_file rec_pid_file vm_ports_file vm_sock_file"
	echo "-m: working image will be put in tmpfs."
	exit
fi

while getopts "bckmrst:" arg
do
	case "${arg}" in
		b )
			checkboot=1
			;;
		c )
			need_clean=1
			;;
		k )
			killvm=1
			;;
		m )
			runinmemory=1
			;;
		r )
			with_vncrecord=1
			;;
		s )
			showonly=1
			;;
		t )
			if [ z"${OPTARG:0:1}" == "z-" ]
			then
				echo "option ${arg} need a parameter..."
				exit 1
			fi
			taskid=$OPTARG
			if [ -z taskid ]
			then
				echo "Please provide a taskid string."
				exit
			fi
			;;
		\? )
			echo "Invalid Option:-$arg" 1>&2
			bash $0
			exit
			;;
		
	esac
done
shift "$(($OPTIND -1))"

if [ -z $taskid ]
then
	echo "You must set a valid taskid with option -t taskid."
	exit
fi

function get_free_port
{
	exclude_port=$1
	start_port=8100
	end_port=8200
	for port in `seq $start_port $end_port`
	do
		if [[ $port == $exclude_port ]]
		then
			continue
		fi
		(netstat -tapln | grep LISTEN |grep ":${port} " > /dev/null)
		if [[ $? -eq 1 ]]
		then
			break
		fi
		if (( $port == $end_port - 1 ))
		then
			echo "Port mapping faile in range $start_port $end_port"
			return 1
		fi
	done
	echo $port
}

ostype="windows7"
arch="x86"
#base_img="/home/disk4/vm-video-evidence/base-images/windows7.img"
#base_img="/home/disk4/vm-video-evidence/base-images/windows7-prod-1024-768.qcow2"
#base_img="/home/disk4/vm-video-evidence/base-images/windows7-prod-1024-768.img"
#base_img="/dev/shm/vm-video-evidence/base_images/windows7-prod-1024-768.img"
base_img="/dev/shm/vm-video-evidence/base_images/windows7-8G-prod-1024-768.img"
if [ ! -f $base_img ]
then
	base_img="/home/disk4/vm-video-evidence/base-images/windows7-8G.img"
fi

if [ $runinmemory -eq 1 ]
then
	working_img_dir="/dev/shm/vm-video-evidence/working_images"
else
	working_img_dir="/home/disk4/vm-video-evidence/working_images"
fi

result_dir="/home/disk4/video_evidence_web/interactive-results"
vm_name="quzheng-${ostype}-$taskid"
working_img="$working_img_dir/$vm_name.img"
vm_result_dir="$result_dir/$taskid"
working_usr_dir="$vm_result_dir/user_files"
os_booted_file="$working_usr_dir/booted.txt"
vm_pid_file="$vm_result_dir/$vm_name.pid"
vm_sock_file="$vm_result_dir/$vm_name.sock"
vm_ports_file="$vm_result_dir/vmstarted.txt"
rec_pid_file="$vm_result_dir/rec.pid"
video_file="$vm_result_dir/screenrecord-$vm_name.flv"

ps aux|grep 'qemu-system-'|grep -v grep|grep "$vm_name " &> /dev/null
if [ $? -eq 0 ]
then
	#echo "VM with this taskid already started as $vm_name"
	if [ $killvm -eq 1 ]
	then
		echo "Kill option specified."
		ps aux|grep -v grep|grep "$vm_name "|grep 'flvrec' &> /dev/null
		if [ $? -eq 0 ]
		then
			echo "Stopping VNC recorder..."
			bash $(cd "$(dirname "$0")"; pwd -P)/vnc-recorder.sh $taskid stop &> /dev/null &
		fi
		echo "Killing VM: $vm_name..."
		read vm_pid < $vm_pid_file
		kill $vm_pid
		exit
	fi
	if [ $showonly -eq 1 ]
	then
		echo "$vm_name $vm_pid_file $vm_result_dir $video_file $rec_pid_file $vm_ports_file $vm_sock_file $os_booted_file"
		exit
	fi
	if [ $checkboot -eq 1 ]
	then
		read vnc_port ws_port < $vm_ports_file
		echo -n "qemu-running"
		if [ ! -f $os_booted_file ]
		then
			echo -n " os-booting"
		else
			read booted others< $os_booted_file
			if [ $booted -eq 1 ]
			then
				echo -n " os-booted"
			else
				echo -n " os-booting"
			fi
		fi
		echo -n " $ip_addr $ws_port"
		bash $(cd "$(dirname "$0")"; pwd -P)/vnc-recorder.sh $taskid status &> /dev/null 
		retcode=$?
		echo -n " $retcode"
		exit
	fi
	#echo "VM $taskid already running..."
	exit
fi

if [ $killvm -eq 1 ]
then
	echo "VM with this taskid $taskid is not running, but Kill option:-k specified, exiting..."
	exit 1
fi

if [ $showonly -eq 1 ]
then
	echo "VM with this taskid $taskid is not running, but Show option:-s specified, exiting..."
	exit 1
fi

if [ $checkboot -eq 1 ]
then
	#echo "VM with this taskid $taskid is not running, but Check OS boot status option:-b specified, exiting..."
	echo "qemu-down os-down null null false"
	exit 1
fi

mkdir -p $working_img_dir
mkdir -p $vm_result_dir
mkdir -p $working_usr_dir

qemu-img create -f qcow2 -o compat=1.1,lazy_refcounts=on -b $base_img $working_img &> /dev/null
if [[ $? -ne 0 ]]
then
	echo "Creating working images for VM failed! Exiting..."
	exit
fi

OPTS=""
OPTS="$OPTS -pidfile $vm_pid_file"
#OPTS="$OPTS -serial none"
OPTS="$OPTS -parallel none"
OPTS="$OPTS -nodefaults"
if [[ $arch == "x86" ]]
then
	OPTS="$OPTS -cpu qemu32,kvm=off"
else
	OPTS="$OPTS -cpu qemu64,kvm=off"
fi
#OPTS="$OPTS -smp 2"
OPTS="$OPTS -name $vm_name"
OPTS="$OPTS -enable-kvm"
OPTS="$OPTS -machine accel=kvm"
OPTS="$OPTS -m 3G"
OPTS="$OPTS -balloon virtio"
OPTS="$OPTS -rtc clock=host,base=localtime"
export QEMU_PA_SAMPLES=128
export QEMU_AUDIO_DRV=pa
OPTS="$OPTS -soundhw hda"
OPTS="$OPTS -k en-us"
OPTS="$OPTS -boot order=c"
OPTS="$OPTS -usbdevice tablet"
#OPTS="$OPTS -drive id=disk0,if=none,cache=unsafe,format=qcow2,file=$working_img"
#OPTS="$OPTS -device driver=virtio-scsi-pci,id=scsi0"
#OPTS="$OPTS -device scsi-hd,drive=disk0"
#OPTS="$OPTS -drive id=disk0,if=none,cache=unsafe,format=qcow2,file=$working_img,l2-cache-size=13107200"
OPTS="$OPTS -drive id=disk0,if=none,cache=unsafe,format=qcow2,file=$working_img"
OPTS="$OPTS -device virtio-blk-pci,drive=disk0,scsi=off,config-wce=off"
#OPTS="$OPTS -net nic,model=virtio"
OPTS="$OPTS -netdev user,id=eth0,hostname=$taskid,smb=$working_usr_dir"
OPTS="$OPTS -device virtio-net-pci,netdev=eth0"
OPTS="$OPTS -vga std"
vnc_port=$(get_free_port)
ws_port=$(get_free_port $vnc_port)
OPTS="$OPTS -vnc :$(( $vnc_port - 5900 )),share=force-shared,websocket=$ws_port"
OPTS="$OPTS -chardev socket,path=$vm_sock_file,server,nowait,id=qga0"
OPTS="$OPTS -device virtio-serial-pci"
OPTS="$OPTS -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"
OPTS="$OPTS -daemonize"
#taskset -c 1-2 qemu-system-x86_64 $OPTS
if [[ $arch == "x86" ]]
then
	qcmd="qemu-system-i386"
	qemu-system-i386 $OPTS &> /dev/null
else
	qcmd="qemu-system-x86_64"
	qemu-system-x86_64 $OPTS &> /dev/null
fi
echo "$vnc_port $ws_port" > $vm_ports_file
echo "$vnc_port $ws_port"


if [ $with_vncrecord -eq 1 ]
then
	#/usr/local/bin/flvrec.py -g 1280x960 -o $video_file localhost $vnc_port >/dev/null 2>&1 &
	bash $(cd "$(dirname "$0")"; pwd -P)/vnc-recorder.sh $taskid start &> /dev/null &
	sleep 1
	rec_pid=$!
	echo $rec_pid > $rec_pid_file
fi

if [ $need_clean -eq 1 ]
then
	#echo "$(cd "$(dirname $0)";pwd -P)/cleanup-qemu.sh $vm_name $working_img $vm_pid_file $vm_ports_file"
	bash $(cd "$(dirname "$0")"; pwd -P)/qemu-monitor.sh $vm_name $working_img $vm_pid_file $vm_ports_file $rec_pid_file $video_file $vm_sock_file &>/dev/null &
fi
