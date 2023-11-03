#!/bin/bash
set -ex

echo "Modifying containerd config"
cat > append_config.txt <<EOF
[proxy_plugins]
  [proxy_plugins.tardev]
    type = "snapshot"
    address = "/run/containerd/tardev-snapshotter.sock"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
  snapshotter = "tardev"
  disable_snapshot_annotations = false
  runtime_type = "io.containerd.kata.v2"
  privileged_without_host_devices = true
  pod_annotations = ["io.katacontainers.*"]
EOF

cat append_config.txt >> /etc/containerd/config.toml
cat /etc/containerd/config.toml
rm append_config.txt
echo "restarting containerd"
systemctl restart containerd
systemctl status containerd | cat
echo "Done!"
