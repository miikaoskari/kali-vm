#!/usr/bin/env sh
## REF: https://developer.hashicorp.com/vagrant/docs/boxes/format
##      https://developer.hashicorp.com/vagrant/docs/boxes/info

set -eu

provider=${1}
image=${2}
artifacts="${image}.*"
metadata=

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

fail() { echo "ERROR: $@" >&2; exit 1; }
info() { echo "INFO:" "$@"; }

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cd ${ARTIFACTDIR}/

## QEMU
if [ ${provider} = "libvirt" ]; then
  metadata='"disks": [{"format": "qcow2", "path": "'${image}'.img"}],'
elif [ ${provider} = "hyperv" ]; then
  mkdir -p "${image}/Virtual Hard Disks/" "${image}/Virtual Machines/"
  mv "${image}.vhdx" "${image}/Virtual Hard Disks/${image}.vhdx"
  mv info.json metadata.json Vagrantfile "${image}"
  cd "${image}/"
  artifacts="'Virtual Hard Disks'* 'Virtual Machines'*"
elif [ ${provider} = "virtualbox" ]; then
  artifacts="${artifacts} box.ovf box.mf"
elif [ ${provider} = "vmware_desktop" ]; then
  cd "$image.vmwarevm/"
  artifacts="${image}*"
else
  fail "Unknown provider: ${provider}"
fi
info "Vagrant: ${provider}"

## $ vagrant box list -i
info "Generate: info.json"
cat <<EOF | python3 -c 'import json, sys; json.dump(json.load(sys.stdin), sys.stdout)' > info.json
{
  "author": "Kali Linux",
  "homepage": "https://www.kali.org/",
  "build-script": "https://gitlab.com/kalilinux/build-scripts/kali-vm",
  "vagrant-cloud": "https://portal.cloud.hashicorp.com/vagrant/discover/kalilinux"
}
EOF


info "Generate: metadata.json"
cat <<EOF | python3 -c 'import json, sys; json.dump(json.load(sys.stdin), sys.stdout)' > metadata.json
{
  "architecture": "amd64",
  ${metadata}
  "provider": "${provider}"
}
EOF


info "Generate: Vagrantfile"
cat <<EOF>Vagrantfile
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.provider :virtualbox do |vb, override|
    vb.gui = false
    vb.customize ["modifyvm", :id, "--vram", "128"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
  end
  config.vm.provider :vmware_desktop do |vmware|
    vmware.gui = true
    vmware.vmx["ide0:0.clientdevice"] = "FALSE"
    vmware.vmx["ide0:0.devicetype"] = "cdrom-raw"
    vmware.vmx["ide0:0.filename"] = "auto detect"
  end
  config.vm.provider :libvirt do |libvirt|
    libvirt.disk_bus = "virtio"
    libvirt.driver = "kvm"
    libvirt.video_vram = 256
  end
end
EOF


info "Compress to ${image}.box"
tar -czf ${image}.box ${artifacts} info.json metadata.json Vagrantfile


if [ "${provider}" = "vmware_desktop" ]; then
  mv ${image}.box ${ARTIFACTDIR}/
fi
