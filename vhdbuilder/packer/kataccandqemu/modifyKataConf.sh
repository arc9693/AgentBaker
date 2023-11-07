#!/bin/bash
set -ex

configfilename="/usr/share/defaults/kata-containers/configuration-qemu.toml"
current_directory="/root"
sed -i 's/kernel = "\/usr\/share\/kata-containers\/vmlinux.container"/kernel = "\/usr\/share\/kata-containers\/vmlinuz-snp.container"/' $configfilename
sed -i "s|path = \"/usr/bin/qemu-system-x86_64\"|path = \"$current_directory/AMDSEV/usr/local/bin/qemu-system-x86_64\"|" $configfilename
sed -i 's/^image = /# image = /' $configfilename
sed -i 's/^# initrd = /initrd = /' $configfilename
sed -i 's/^# confidential_guest = true/confidential_guest = true/' $configfilename
sed -i 's/^# sev_snp_guest = true/sev_snp_guest = true/' $configfilename
sed -i "s|valid_hypervisor_paths = \[\"/usr/bin/qemu-system-x86_64\"\]|valid_hypervisor_paths = [\"$current_directory/AMDSEV/usr/local/bin/qemu-system-x86_64\"]|" $configfilename
sed -i "s|firmware = \"\"|firmware = \"$current_directory/AMDSEV/ovmf/Build/OvmfX64/DEBUG_GCC5/FV/OVMF.fd\"|" $configfilename
sed -i 's/shared_fs = "virtio-fs"/shared_fs = "virtio-9p"/' $configfilename
sed -i 's/^virtio_fs_daemon =/# virtio_fs_daemon =/' $configfilename
sed -i 's/^#disable_image_nvdimm = /disable_image_nvdimm = /' $configfilename
sed -i 's/^#file_mem_backend = ""/file_mem_backend = ""/' $configfilename
sed -i 's/^#disable_nesting_checks = true/disable_nesting_checks = true/' $configfilename

refConfigPathInContainerd="/opt/confidential-containers/share/defaults/kata-containers/configuration-clh-snp.toml"
directoryToCreate=$(dirname "$refConfigPathInContainerd")

echo "Creating directory if it doesn't exist"
mkdir -p "$directoryToCreate"

echo "Creating symlink"
ln -sf "$configfilename" "$refConfigPathInContainerd"

ls -la /opt/confidential-containers/share/defaults/kata-containers