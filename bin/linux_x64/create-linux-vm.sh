#!/bin/bash

if [ $# -eq 0 ]
then
	echo "No arguments provided."
	echo "Usage: $0 [-d ubuntu(default)/centos ] [ -g ] [ -p ] [ -r ] -n VMname"
	echo "-d Select OS dist, ubuntu | centos, default is ubuntu"
	echo "-g if set VM starts with vnc and websock ports."
	echo "-n Set your VM name."
	echo "-p Set port need to be exposed for VM.Multi ports seperated by , if you want to specify which host port to map use this style for example: -p 2181:2181,28881:2888,38881:3888"
	echo "-r Remove everything of VM."
	exit
fi
dist="ubuntu"
expose=0
vnc=0
forceremove=0

while getopts "d:gn:p:r" arg
do
	case "${arg}" in
		d )
			if [ z"${OPTARG:0:1}" == "z-" ]
			then
				echo "option ${arg} need a parameter..."
				exit 1
			fi
			user_dist=$OPTARG
			lower_user_dist=${user_dist,,}
			if [[ "$lower_user_dist" =~ ^(ubuntu|centos)$ ]]
			then
				dist=$lower_user_dist
			else
				echo "Not supported Distribution $user_dist"
				exit
			fi
			;;
		g )
			vnc=1
			;;
		n )
			if [ z"${OPTARG:0:1}" == "z-" ]
			then
				echo "option ${arg} need a parameter..."
				exit 1
			fi
			user_vm_name=$OPTARG
			if [ -z $user_vm_name ]
			then
				echo "Please provide a VM name."
				exit
			fi
			;;
		p )
			if [ z"${OPTARG:0:1}" == "z-" ]
			then
				echo "option ${arg} need a parameter..."
				exit 1
			fi
			expose=1
			expose_ports=$OPTARG
			echo "Need map $expose_ports for VM"
			;;
		r )
			forceremove=1
			;;
		\? )
			echo "Invalid Option:-$arg" 1>&2
			bash $0
			exit
			;;
	esac
done


if [ -z $user_vm_name ]
then
	echo "Please provide a valid VMname with -n name option"
	exit
fi

arch="x86_64"
date_str=$(date +%Y%m%d%H%M%S)
if [ $dist == "ubuntu" ]
then
	base_img="/home/disk1/base-images/ubuntu-server-16.04.3.qcow2"
elif [ $dist == "centos" ]
then
	base_img="/home/disk1/base-images/centos-6.9.qcow2"
fi
vm_name="${dist}-${user_vm_name}"
working_img_dir="/home/disk1/working-images"
host_share_dir="/home/work/$vm_name"
working_img="$working_img_dir/$vm_name.img"
working_img_info="$working_img.txt"
vm_sock_file="$working_img.sock"
vm_pid_file="$working_img_dir/$vm_name.pid"

if [ $forceremove -eq 1 ]
then
	if [ ! -f $working_img ]
	then
		echo "No VM exist with name $vm_name."
		exit
	fi
	ps aux|grep 'qemu-system-'|grep -v grep|grep "$vm_name " &> /dev/null
	if [ $? -eq 0 ]
	then
		echo "VM $vm_name is still running , if you say Yes here, it will be killed."
		read vm_pid < $vm_pid_file
	fi
	echo "Are you sure you want to delete everything of VM $vm_name?"
	select yn in "Yes" "No"; do
	case $yn in
		Yes ) 
			if [ ! -z $vm_pid ]
			then
				echo "Killing VM $vm_name"
				kill $vm_pid
			fi
			echo "Deleting $host_share_dir/* $working_img $working_img_info $vm_sock_file $vm_pid_file"
			rm -fr $host_share_dir $working_img $working_img_info $vm_sock_file $vm_pid_file
			exit
			;;
		No ) exit;;
    esac
	exit
done
fi

function map_port
{
	start_port=$1
	range_n=1000
	end_port=$(( $start_port + $range_n ))
	if [ $end_port -gt 65536 ]
	then
		end_port=65536
	fi
	for port in $(seq $start_port $end_port)
	do
		if [ -f $working_img_info ]
		then
			grep "host port:$port" $working_img_info &> /dev/null
			exist=$?
			if [ $exist -eq 0 ]
			then
				continue
			fi
		fi
		(netstat -tapln 2>/dev/null | grep LISTEN |grep ":${port} " &> /dev/null)
		if [[ $? -eq 1 ]]
		then
			break
		fi
	done
	if (( $port == $end_port - 1 ))
	then
		echo "Port mapping failed in range $start_port $end_port"
		return 1
	fi
	echo "$port"
}

mkdir -p $host_share_dir
if [ ! -f $working_img ]
then
	echo "Creating a fresh new VM image..."
	qemu-img create -f qcow2 -b $base_img $working_img &> /dev/null
	if [ $? -ne 0 ]
	then
		echo "Create working images for VM failed!" 
		echo "Command :qemu-img create -f qcow2 -b $base_img $working_img"
		echo "Exiting..."
		exit
	fi
fi

ps aux|grep -v grep|grep "$vm_name " &> /dev/null
if [ $? -eq 0 ]
then
	echo "VM $vm_name already running:"
	cat $working_img_info
	exit
else
	rm -f $working_img_info
	echo "Starting VM $vm_name...:"
fi

ssh_port=$(map_port 22000)
hostfwd_str=",hostfwd=::$ssh_port-:22"
echo "VM SSH port mapped to host port:$ssh_port" >> $working_img_info
echo "Login using this command: ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null work@$(hostname) -p $ssh_port">> $working_img_info
echo "(default password for users : work/baidu123  root/baidu123)">> $working_img_info

if [ $expose -eq 1 ]
then
	IFS_bak=$IFS
	export IFS=','
	read -ra expose_ports_array <<< "$expose_ports"
	export IFS=$IFS_bak
	for ep in "${expose_ports_array[@]}"
	do
		if [ ! -z $ep ]
		then
			if [[ $ep == *:* ]]
			then
				host_port=${ep%:*}
				vm_port=${ep#*:}
			else
				host_port=$ep
				vm_port=$ep
			fi
			new_host_port=$(map_port $host_port)
			hostfwd_str="$hostfwd_str,hostfwd=::$new_host_port-:$vm_port"
			echo "VM port:$vm_port mapped to host port:$new_host_port" >> $working_img_info
		fi
	done
fi

OPTS="-name $vm_name"
OPTS="$OPTS -pidfile $vm_pid_file"
OPTS="$OPTS -cpu qemu64,kvm=off"
OPTS="$OPTS -smp 2"
OPTS="$OPTS -enable-kvm"
OPTS="$OPTS -machine accel=kvm"
OPTS="$OPTS -m 8G"
OPTS="$OPTS -balloon virtio"
OPTS="$OPTS -rtc clock=host,base=localtime"
OPTS="$OPTS -k en-us"
OPTS="$OPTS -boot order=c"
OPTS="$OPTS -drive id=disk0,if=none,cache=unsafe,format=qcow2,file=$working_img"
OPTS="$OPTS -device virtio-blk-pci,drive=disk0,scsi=off,config-wce=off"
OPTS="$OPTS -fsdev local,id=share1,path=$host_share_dir,security_model=mapped"
OPTS="$OPTS -device virtio-9p-pci,fsdev=share1,mount_tag=host_share"
OPTS="$OPTS -netdev user,id=eth0,hostname=$vm_name$hostfwd_str"
OPTS="$OPTS -device virtio-net-pci,netdev=eth0"
if [ $vnc -eq 1 ]
then
	OPTS="$OPTS -vga std"
	vnc_port=$(map_port 8000)
	echo "VNC running on host port:$vnc_port" >> $working_img_info
	ws_port=$(map_port $vnc_port)
	echo "websock running on host port:$ws_port" >> $working_img_info
	OPTS="$OPTS -vnc :$(( $vnc_port - 5900 )),share=force-shared,websocket=$ws_port"
else
	OPTS="$OPTS -nographic"
	OPTS="$OPTS -display none"
	OPTS="$OPTS -monitor none"
fi
OPTS="$OPTS -chardev socket,path=$vm_sock_file,server,nowait,id=qga0"
OPTS="$OPTS -device virtio-serial-pci"
OPTS="$OPTS -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"
OPTS="$OPTS -daemonize"
echo "VM start command:"
echo "qemu-system-x86_64 $OPTS"
qemu-system-x86_64 $OPTS
echo "VM port mapping information:"
cat $working_img_info
