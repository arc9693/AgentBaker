#!/bin/bash
set -ex

# Install necessary libraries for building the sources
echo "Installing necessary libraries"
if [ -f /etc/yum.repos.d/preview.repo ]; then
   mv /etc/yum.repos.d/preview.repo /
fi
sudo dnf install -y git build-essential protobuf-compiler protobuf-devel expect curl openssl-devel clang-devel rust vim libseccomp-devel
sudo dnf install -y parted golang btrfs-progs-devel device-mapper-devel cmake acpica-tools python3* fuse-devel veritysetup
sudo dnf install -y git ninja-build build-essential glib-devel pixman-devel libgcrypt-devel nasm flex-devel vim acpica-tools openssl-devel cdrkit rsync zip
sudo ln -sf /usr/bin/python3 /usr/bin/python

GUESTKERNELVERSION=""
GUESTKERNELDIR=""
GOPATH=$HOME/go

# Make a directory for the sources
mkdir work
cd work/

# Download the kata-containers sources
git clone --branch cc-msft-prototypes https://github.com/microsoft/kata-containers.git

# Build utarfs
echo "Building utarfs"
pushd kata-containers/src/utarfs/
cargo build --release
popd

# Build overlay
echo "Building overlay"
pushd kata-containers/src/overlay/
cargo build --release
popd

# Build kata runtime
# This will install binaries: /usr/bin/kata-runtime and /usr/bin/containerd-shim-kata-v2
pushd kata-containers/src/runtime/
make SKIP_GO_VERSION_CHECK=1 DEFSTATICRESOURCEMGMT=true
popd

# Build tardev-snapshotter
pushd kata-containers/src/tardev-snapshotter
make
popd


# Now comes the tricky part, build the guest kernel from kata-containers/tools/packaging/kernel utility
echo "Building guest kernel"
export PATH="$PATH:$GOPATH/bin"
pushd kata-containers/tools/packaging/kernel
echo "CONFIG_MODULES=y" >> configs/fragments/x86_64/snp/snp.conf
echo "CONFIG_MODULE_UNLOAD=y" >> configs/fragments/x86_64/snp/snp.conf
sed -i '/CONFIG_CRYPTO_FIPS/d' configs/fragments/common/crypto.conf
KATA_BUILD_CC=yes ./build-kernel.sh -a x86_64 -x snp setup
KATA_BUILD_CC=yes ./build-kernel.sh -a x86_64 -x snp build
sudo -E PATH="${PATH}" ./build-kernel.sh -x snp install
pushd $(ls | grep kata-linux)
GUESTKERNELDIR=$PWD
GUESTKERNELVERSION=$(cat include/config/kernel.release)
sudo -E PATH=$PATH make modules_install
popd
popd

echo "Building tarfs"
pushd kata-containers/src/tarfs
make KDIR=$GUESTKERNELDIR
make KDIR=$GUESTKERNELDIR install
popd

KERNEL_MODULES_DIR=$PWD/kata-containers/src/tarfs/_install/lib/modules/$GUESTKERNELVERSION

echo "Building kata agent"
pushd kata-containers/src/agent
make LIBC=gnu SECURITY_POLICY=yes AGENT_POLICY=yes
agent_bin="./target/x86_64-unknown-linux-gnu/release/kata-agent"
[ -f "${agent_bin}" ] || die "Agent binary (${agent_bin}) is not present"
strip "${agent_bin}"
agent_bin="$(readlink -f ${agent_bin})"
[ -f "${agent_bin}" ] || die "Agent binary (${agent_bin}) is not present"
ls -l "${agent_bin}"
popd

echo "Building rootfs"
pushd kata-containers/tools/osbuilder
rm -f .cbl-mariner_rootfs.done
sudo -E PATH=$PATH SECURITY_POLICY=yes AGENT_POLICY=yes AGENT_SOURCE_BIN="${agent_bin}" make DISTRO=cbl-mariner rootfs
rootfs_path="$(sudo readlink -f ./cbl-mariner_rootfs)"

MODULE_ROOTFS_DEST_DIR="${rootfs_path}/lib/modules"
mkdir -p ${MODULE_ROOTFS_DEST_DIR}

cp -a ${KERNEL_MODULES_DIR} "${MODULE_ROOTFS_DEST_DIR}/"
depmod -a -b ${rootfs_path} ${GUESTKERNELVERSION}

echo "Installing kata agent services in rootfs"
pushd ../../src/agent
sudo -E PATH=$PATH make install-services DESTDIR="${rootfs_path}"
popd

echo "Building initrd"
sudo -E PATH=$PATH make DISTRO=cbl-mariner initrd
echo "Installing initrd"
commit="$(git log --format=%h -1 HEAD)"
date="$(date +%Y-%m-%d-%T.%N%z)"
image="kata-containers-initrd-${date}-${commit}"
sudo install -o root -g root -m 0640 -D kata-containers-initrd.img "/usr/share/kata-containers/${image}"
(cd /usr/share/kata-containers && sudo ln -sf "$image" kata-containers-initrd.img)
popd

# Build containerd
git clone --depth 1 --branch archana1/tardev https://github.com/arc9693/confidential-containers-containerd
pushd confidential-containers-containerd/
GODEBUG=1 make
popd

# Install
echo "Collecting pieces"

echo "Installing kata-cc"
cp kata-containers/src/runtime/containerd-shim-kata-v2 /usr/local/bin/containerd-shim-kata-cc-v2
sha256sum /usr/local/bin/containerd-shim-kata-cc-v2

echo "Installing utarfs"
cp kata-containers/src/utarfs/target/release/utarfs /usr/sbin/mount.tar

echo "Installing overlay"
cp kata-containers/src/overlay/target/release/kata-overlay /usr/bin/kata-overlay

echo "Installing tardev-snapshotter"
if [ -f /usr/bin/tardev-snapshotter ]; then
   mv /usr/bin/tardev-snapshotter /usr/bin/tardev-snapshotter.bak
fi
cp kata-containers/src/tardev-snapshotter/target/release/tardev-snapshotter /usr/bin/tardev-snapshotter
cp kata-containers/src/tardev-snapshotter/tardev-snapshotter.service /usr/lib/systemd/system

systemctl enable tardev-snapshotter
systemctl daemon-reload
systemctl restart tardev-snapshotter
systemctl status tardev-snapshotter | cat

echo "Installing containerd"
sha256sum confidential-containers-containerd/bin/containerd
if [ -f /usr/bin/containerd ]; then
   mv /usr/bin/containerd /usr/bin/containerd.bak
fi
cp confidential-containers-containerd/bin/containerd /usr/bin/containerd
sha256sum /usr/bin/containerd

echo "List containerd config"
ls /etc/containerd/

systemctl status containerd | cat

echo "Deleting work directory"
cd ..
rm -rf work

echo "Done!"
