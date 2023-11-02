#!/bin/bash
set -ex

sudo dnf install -y libcap-ng-devel libattr-devel liburing-devel
git clone https://github.com/AMDESE/AMDSEV.git --branch=sev-snp-devel AMDSEV
DEST="/usr/local"
pushd AMDSEV
sudo ./build.sh qemu --install $DEST
sudo ./build.sh ovmf --install $DEST
pushd qemu
./configure --enable-virtfs --disable-virtiofsd --target-list=x86_64-softmmu --enable-debug --prefix=$DEST --enable-linux-io-uring
make -j "$(nproc)"
make install
popd
