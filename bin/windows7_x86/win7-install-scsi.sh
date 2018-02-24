OPTS="-name quzheng-windows7-pro"
#OPTS="$OPTS -cpu host,kvm=off"
OPTS="$OPTS -cpu qemu32,kvm=off"
#OPTS="$OPTS -smp 2"
OPTS="$OPTS -nodefaults"
OPTS="$OPTS -enable-kvm"
OPTS="$OPTS -machine accel=kvm"
OPTS="$OPTS -m 3G"
OPTS="$OPTS -balloon virtio"
#OPTS="$OPTS -mem-path /dev/hugepages"
#OPTS="$OPTS -mem-prealloc"
#OPTS="$OPTS -balloon none"

OPTS="$OPTS -rtc clock=host,base=localtime"
export QEMU_PA_SAMPLES=128
export QEMU_AUDIO_DRV=pa
OPTS="$OPTS -soundhw hda"
OPTS="$OPTS -k en-us"
OPTS="$OPTS -boot order=c"
OPTS="$OPTS -usbdevice tablet"

#OPTS="$OPTS -drive id=disk0,if=none,discard=on,cache=unsafe,format=raw,file=/home/disk4/vm-video-evidence/base-images/windows7-prod-1024-768.img"
#OPTS="$OPTS -device driver=virtio-scsi-pci,id=scsi0"
#OPTS="$OPTS -device scsi-hd,drive=disk0"

#OPTS="$OPTS -drive id=disk0,if=none,cache=unsafe,format=raw,file=/dev/shm/vm-video-evidence/base_images/windows7-prod-1024-768.img"
#OPTS="$OPTS -drive id=disk0,if=none,cache=none,aio=native,format=raw,file=/home/disk4/vm-video-evidence/base-images/windows7-8G.img"
OPTS="$OPTS -drive id=disk0,if=none,cache=none,format=raw,file=/home/disk4/vm-video-evidence/base-images/windows7-prod-1024-768.img"
OPTS="$OPTS -device virtio-blk-pci,drive=disk0,scsi=off,config-wce=off"


OPTS="$OPTS -drive id=cd0,if=none,format=raw,readonly,file=/home/disk4/vm-video-evidence/iso-images/GRMCENVOL_ZH-CN_PIP.iso"
OPTS="$OPTS -device driver=ide-cd,bus=ide.0,drive=cd0"
OPTS="$OPTS -drive id=virtiocd,if=none,format=raw,file=/home/disk4/vm-video-evidence/iso-images/virtio-win.iso"
OPTS="$OPTS -device driver=ide-cd,bus=ide.1,drive=virtiocd"

#OPTS="$OPTS -net nic,model=virtio"
OPTS="$OPTS -netdev user,id=eth0,hostname=quzheng-windows7-pro,smb=/tmp"
OPTS="$OPTS -device virtio-net-pci,netdev=eth0"
OPTS="$OPTS -vga std"
OPTS="$OPTS -vnc :$(( 8222 - 5900 )),share=force-shared,websocket=8223"

OPTS="$OPTS -chardev socket,path=/tmp/win7-test-qga.sock,server,nowait,id=qga0"
OPTS="$OPTS -device virtio-serial-pci"
OPTS="$OPTS -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0"
qemu-system-i386 $OPTS
#qemu-system-x86_64 $OPTS
