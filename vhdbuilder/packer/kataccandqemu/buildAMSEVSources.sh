#!/bin/bash
set -ex
cd $HOME
git clone https://github.com/AMDESE/AMDSEV.git --branch=sev-snp-devel AMDSEV
pushd AMDSEV
sudo ./build.sh qemu
sudo ./build.sh ovmf
popd

# rebuild qemu
pushd $HOME/AMDSEV/qemu
DEST="$HOME/AMDSEV/usr/local"
sudo tdnf install -y libcap-ng-devel libattr-devel liburing-devel
./configure --enable-virtfs --disable-virtiofsd --target-list=x86_64-softmmu --enable-debug --prefix=$DEST --enable-linux-io-uring
make -j "$(nproc)"
make install
popd