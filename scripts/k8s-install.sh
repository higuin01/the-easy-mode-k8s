#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

sudo swapoff -a                   # Desativa swap temporariamente
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab  # Comenta swap no fstab (desativa permanentemente)

# Carregar módulos
sudo modprobe overlay
sudo modprobe br_netfilter

# Configurar sysctl
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

# Aplicar configurações
sudo sysctl --system


# Instalar dependências
# Install all required packages in one go to reduce apt operations
sudo apt-get update
sudo apt-get install -y containerd apt-transport-https ca-certificates curl gpg

# Criar arquivo de configuração padrão
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Configurar cgroup driver como systemd (obrigatório)
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Reiniciar containerd
sudo systemctl enable --now containerd

# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg


# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet


output_file="crictl.yaml"

cat << EOF > "/etc/$output_file"
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF


sudo systemctl restart containerd
sudo echo 'source <(kubectl completion bash)' >>~/.bashrc
sudo echo 'alias k=kubectl' >>~/.bashrc
sudo echo 'complete -o default -F __start_kubectl k' >>~/.bashrc


CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}


apt upgrade -y

