#!/bin/bash -eu

# Take one argument from the commandline: VM name
if ! [ $# -eq 1 ]; then
    echo "Usage: $0 <cluster-name>"
    exit 1
fi

CWD=`dirname $0`
source $CWD/funcs.sh

# Check all binaries exist
BAZEL_BUILD_DIR="${KUBE_ROOT}/bazel-bin/build"
DOCKER_IMGS="kube-apiserver.tar kube-controller-manager.tar kube-proxy.tar kube-scheduler.tar"
DEBS="cri-tools kubeadm kubectl kubelet kubernetes-cni"

# Get Git version
pushd $KUBE_ROOT
bazel build //build:docker-artifacts
source "${KUBE_ROOT}/hack/lib/version.sh"
kube::version::get_version_vars
popd

echo "Git version is ${KUBE_GIT_VERSION-}"

if [ -z "${KUBE_GIT_VERSION}" ]; then
    echo "No Git version set. Exiting..."
    exit 1
fi

for file in ${DOCKER_IMGS} ; do
    filepath="${BAZEL_BUILD_DIR}/$file"
    if [ ! -f ${filepath} ]; then
	echo "${filepath} doesn't exist. Exiting..."
	exit 1
    fi
done

mkdir -p "${BAZEL_BUILD_DIR}/debs_backup" || true

for file in ${DEBS} ; do
    filepath="${BAZEL_BUILD_DIR}/debs/${file}.deb"
    if [ ! -f ${filepath} ]; then
	echo "${filepath} doesn't exist. Exiting..."
	exit 1
    fi
    cp -f ${filepath} "${BAZEL_BUILD_DIR}/debs_backup/${file}.deb"
done

CLUSTER=$1

MASTER="${CLUSTER}-master"
WORKERS="${CLUSTER}-worker1 ${CLUSTER}-worker2 ${CLUSTER}-worker3"

IMAGE_NAME="bionic-docker-server-cloudimg-amd64.img"
CLOUD_CONFIG="cloud-config-tpl.yaml"
IMAGE="${IMAGE_DIR}/${IMAGE_NAME}"

for domain in "${MASTER} ${WORKERS}" ; do
    libvirt_check_domain ${domain}
done

for machine_name in ${MASTER} ${WORKERS} ; do
    create_machine_from_image $machine_name $IMAGE $CLOUD_CONFIG
done

sleep 5

MASTER_IP=$(get_ip_address $MASTER)

wait_until_ready ${MASTER_IP}

$SSH "ubuntu@${MASTER_IP}" sudo kubeadm init --kubernetes-version=${KUBE_GIT_VERSION}
TOKEN=$($SSH "ubuntu@${MASTER_IP}" sudo kubeadm token list | tail -n1 | awk '{print $1}')

for machine_name in $WORKERS ; do
    node_ip=$(get_ip_address $machine_name)
    wait_until_ready ${node_ip}
    $SSH "ubuntu@${node_ip}" sudo kubeadm join "${MASTER_IP}:6443" --token $TOKEN --discovery-token-unsafe-skip-ca-verification
done

$SSH "ubuntu@${MASTER_IP}" sudo "kubectl apply -f \"https://cloud.weave.works/k8s/net?k8s-version=\$(kubectl version | base64 | tr -d '\n')\""

echo "Success"
