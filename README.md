# Talos on Netcup Root Server (KVM) – talosctl helper container + bootstrap notes

This repo is a reproducible “driver kit” for installing / bootstrapping Talos on Netcup Root Servers using `talosctl`, but running `talosctl` from a Docker container to keep tooling consistent.

It is especially useful when you are repeatedly reinstalling, wiping, and testing different Talos install media and want a predictable CLI environment.

## What you need before running these commands

1. Your server must be booted into **Talos maintenance mode** (usually by booting a Talos ISO/DVD in the provider console).
2. From the machine where you run `talosctl`, you must be able to reach the node’s Talos API:
   - Talos API is on **port 50000** (and clusters often need 50000/50001 reachable between nodes).
3. You must know:
   - Control plane public IP
   - Worker public IPs (if any)

### Common gotcha: `talosconfig` location

`talosctl gen config` creates a `talosconfig` file in the current directory, but `talosctl` often defaults to `~/.talos/config`.
To avoid accidentally using the wrong client config, this README always uses either:

- `--talosconfig ./talosconfig`, or
- `export TALOSCONFIG=/work/talosconfig` (inside the container)

## Build the talosctl container

From this repo root:

```bash
docker build -t talosctl .
````

## Run talosctl (container)

### Example A: Linux (host networking works)

```bash
docker run --rm -it \
  --network host \
  -v "$PWD":/work \
  -w /work \
  talosctl
```

### Example B: macOS / Docker Desktop (recommended: no host network)

Docker Desktop’s networking is already NAT’d; you usually do NOT need `--network host` for public IPs.

```bash
docker run --rm -it \
  -v "$PWD":/work \
  -w /work \
  talosctl
```

> Tip: Only mount the Docker socket if you truly need it. Most Talos workflows do not.

## Set your node IPs

Inside the container:

```bash
export CONTROL_PLANE_IP="168.63.128.455"

# Bash array of worker IPs (optional)
export WORKER_IPS=( \
  "168.63.188.85" \
  "168.63.188.86" \
)
```

## Verify you can talk to the node (maintenance mode)

```bash
talosctl --talosconfig ./talosconfig version --insecure --nodes "$CONTROL_PLANE_IP"
```

If this hangs or times out, it is almost always networking/firewall/port 50000 reachability.

## Discover the correct install disk

Before generating configs or applying configs, verify the disk name Talos sees:

```bash
talosctl --talosconfig ./talosconfig get disks --insecure --nodes "$CONTROL_PLANE_IP"
```

Pick the disk Talos reports (common examples):

* VirtIO: `/dev/vda`
* SATA/SCSI: `/dev/sda`

Your current machine configs in this repo are set to install to `/dev/vda`.
If your server shows `/dev/sda` instead, you must update the install disk accordingly.

```bash
export DISK="/dev/vda"
# or: export DISK="/dev/sda"
```

## Generate fresh cluster configs (optional)

If you want to regenerate from scratch (this will create `controlplane.yaml`, `worker.yaml`, and `talosconfig`):

```bash
export CLUSTER_NAME="Lab"

talosctl gen config \
  "$CLUSTER_NAME" \
  "https://${CONTROL_PLANE_IP}:6443" \
  --install-disk "$DISK"
```

If you need to overwrite existing files:

```bash
talosctl gen config \
  "$CLUSTER_NAME" \
  "https://${CONTROL_PLANE_IP}:6443" \
  --install-disk "$DISK" \
  --force
```

## Apply config to the control plane node (maintenance mode)

```bash
talosctl --talosconfig ./talosconfig apply-config \
  --insecure \
  --nodes "$CONTROL_PLANE_IP" \
  --file controlplane.yaml
```

## Apply config to worker nodes (maintenance mode)

```bash
for ip in "${WORKER_IPS[@]}"; do
  talosctl --talosconfig ./talosconfig apply-config \
    --insecure \
    --nodes "$ip" \
    --file worker.yaml
done
```

After applying config, the nodes should reboot into the installed Talos system (remove/detach ISO media if needed).

## Bootstrap etcd (run once)

Pick ONE control plane node (usually the first / only one) and bootstrap etcd:

```bash
talosctl --talosconfig ./talosconfig bootstrap \
  --nodes "$CONTROL_PLANE_IP" \
  --endpoints "$CONTROL_PLANE_IP"
```

## Fetch kubeconfig

```bash
talosctl --talosconfig ./talosconfig kubeconfig \
  --nodes "$CONTROL_PLANE_IP" \
  --endpoints "$CONTROL_PLANE_IP" \
  ./kubeconfig
```

Then:

```bash
export KUBECONFIG="$PWD/kubeconfig"
kubectl get nodes -A
```

## Troubleshooting quick notes

* If `apply-config` says the install disk does not exist, re-run `get disks` and ensure `install.disk` matches what Talos reports.
* If `talosctl` seems to ignore the generated `talosconfig`, explicitly pass `--talosconfig ./talosconfig`.
* If you cannot reach the node in maintenance mode, check routing/firewalls and that port 50000 is reachable.
