sudo dnf makecache -y
sudo dnf install -y git ninja-build build-essential glib-devel pixman-devel libgcrypt-devel nasm flex-devel vim acpica-tools openssl-devel cdrkit rsync zip
sudo ln -s /usr/bin/python3 /usr/bin/python

cd $HOME
git clone https://github.com/AMDESE/AMDSEV.git --branch=sev-snp-devel AMDSEV
pushd AMDSEV
sudo ./build.sh kernel guest
sudo ./build.sh qemu
sudo ./build.sh ovmf
popd

umask 022
export LOCALVERSION=$(sudo strings $HOME/AMDSEV/linux/guest/vmlinux | grep -i 'linux version' | cut -d' ' -f3)
sudo mkdir -p /lib/modules/$LOCALVERSION
pushd $HOME/AMDSEV/linux/guest
sudo make modules_install
popd

echo "--add-drivers \"virtio_blk virtio_scsi virtio-rng virtio_console virtio_crypto virtio_mem vmw_vsock_virtio_transport vmw_vsock_virtio_transport_common 9pnet_virtio vrf\"" | sudo tee -a /var/lib/initramfs/kernel/$LOCALVERSION

cd $HOME
sudo mkinitrd $PWD/initrd.img-$LOCALVERSION $LOCALVERSION
sudo chown $USER:$USER -R $HOME/AMDSEV
pushd $HOME/AMDSEV/linux/guest
sudo make headers_install
popd

echo "export PATH=$HOME/AMDSEV/usr/local/bin:$PATH" > ~/.bashrc
source ~/.bashrc

mkdir -p $HOME/kata-bits
pushd $HOME/kata-bits
sudo cp $HOME/initrd.img-$LOCALVERSION .
sudo cp $HOME/AMDSEV/linux/guest/arch/x86_64/boot/bzImage ./vmlinuz-$LOCALVERSION
popd

which qemu-img

exit 0
