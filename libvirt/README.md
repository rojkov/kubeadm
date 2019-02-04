This is a set of scripts that can be used to quickly set up a multi-node
cluster built from your local source tree on VMs running on top of libvirt.

Currently the scripts expects that

1. your local Kubernetes source tree can be found at
   `$GOPATH/src/k8s.io/kubernetes`;
2. a cloud image of Ubuntu Bionic is placed at
   `$HOME/work/qemu-imgs/bionic-server-cloudimg-amd64.img`;
3. there are `virsh`, `virt-install` and `genisoimage` are
   installed on your host;
4. `virsh` can connect to `qemu://session` non-interactively.

First you need to generate a Docker-enabled image with
```sh
$ ./mk-vm-image-with-docker.sh
```

The image will be placed to `$HOME/work/qemu-imgs/bionic-docker-server-cloudimg-amd64.img`.

Then create a cluster with
```sh
$ ./mk-cluster.sh <cluster-name>
```

The script creates one control plane node and three workers. Currently they are
hardcoded.

To tear down the cluster run
```sh
$ ./teardown-cluster <cluster-name>
```
