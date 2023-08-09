#!/bin/bash
#
# Takes standard Ubuntu 18.04 cloudimg and creates VM configured with cloud-init
# 
# uses snapshot and increases size of root filesystem so base image not affected
# inserts cloud-init user, network, metadata into disk
# creates 2nd data disk
# then uses cloud-init to configure OS
#
set -x

os_variant="ubuntu20.04"
baseimg=focal-server-cloudimg-amd64.img

if [ ! -n "$1" ];then
  echo "you have to give me vm name."
  exit 2
else
  hostname=$1
fi

# vnc|none
graphicsType=vnc

if [ ! -f ~/Downloads/$baseimg ]; then
  echo "ERROR did not find ~/Downloads/$baseimg"
  echo "Doing download...."
  wget https://cloud-images.ubuntu.com/focal/current/$baseimg -O ~/Downloads/$baseimg
  echo ""
  echo "$baseimg downloaded now.  Run again"
  exit 2
fi

# create working snapshot, increase size to 5G
mkdir -p $hostname
snapshot=$hostname-snapshot-cloudimg.qcow2
sudo rm $hostname/$snapshot
qemu-img create -b ~/Downloads/$baseimg -f qcow2 -F qcow2 $hostname/$snapshot 500G
qemu-img info $hostname/$snapshot

# insert metadata into seed image
seed=$hostname-seed.img
echo "instance-id: $(uuidgen || echo i-abcdefg)" > $hostname/$hostname-metadata
# cloud-localds - create a disk for cloud-init to utilize the nocloud datasource
cloud-localds -v $hostname/$seed  cloud_init.cfg $hostname/$hostname-metadata --network-config=network_config_static.cfg

# ensure file permissions belong to kvm group
sudo chmod 666 ~/Downloads/$baseimg
sudo chmod 666 $hostname/$snapshot
sudo chown $USER:kvm $hostname/$snapshot $hostname/$seed 

# create VM using libvirt
virt-install --name $hostname \
  --virt-type kvm --memory 2048 --vcpus 2 \
  --boot hd,menu=on \
  --disk path=$hostname/$seed,device=cdrom \
  --disk path=$hostname/$snapshot,device=disk \
  --graphics $graphicsType \
  --os-type Linux --os-variant $os_variant \
  --network bridge=virbr0  \
  --console pty,target_type=serial \
  --noautoconsole


