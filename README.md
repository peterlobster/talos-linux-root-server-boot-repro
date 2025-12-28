```bash
docker run --rm -it \
        --network host \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$PWD":/work \
        talosctl
```

```bash
export CONTROL_PLANE_IP=152.53.168.188
export WORKER_IP=("152.53.171.85" "152.53.170.86")
```

```bash
talosctl get disks --insecure --nodes $CONTROL_PLANE_IP
```

```bash
export CLUSTER_NAME=Lab
export DISK_NAME=sda
```

```bash
talosctl gen config $CLUSTER_NAME https://$CONTROL_PLANE_IP:6443 --install-disk /dev/$DISK_NAME
```
or (if Force is needed)

```bash
talosctl gen config $CLUSTER_NAME https://$CONTROL_PLANE_IP:6443 --install-disk /dev/$DISK_NAME --force
```

```bash
talosctl apply-config --insecure --nodes $CONTROL_PLANE_IP --file controlplane.yaml
```
