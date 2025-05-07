#!/bin/bash
#########################################################################
# Kubernetes Cluster Setup Script
# 
# This script automates the setup of a Kubernetes cluster using Vagrant VMs.
# It dynamically discovers all master and worker nodes and configures them.
#
# Author: Improved version based on original script
# Date: Updated script
#########################################################################

set -e  # Exit on error

# Start timing the execution
start_time=$(date +%s)

# Configuration variables
export DEBIAN_FRONTEND=noninteractive
PREFIX_IP="192.168.56"
MYDOMAIN="high.sh"
MACHINES_FILE="machines.txt"
HOSTS_FILE="hosts"
POD_NETWORK_CIDR="192.168.0.0/16"
CILIUM_VERSION="1.15.13"
METALLB_VERSION="v0.14.9"
WORKER_SUBNET_PREFIX="10.200"

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#########################################################################
# Helper Functions
#########################################################################

# Display colorful log messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Display banner
function banner() {
cat << "EOF"
                                                                                                                                  
    ___      ,---,                                                                                                                
  ,--.'|_  ,--.' |                                                                                                                
  |  | :,' |  |  :                                                                    .---.                       
  :  : ' : :  :  :                                               .--.--.                             /. ./|                       
.;__,'  /  :  |  |,--.   ,---.             ,---.     ,--.--.    /  /    '       .--,              .-'-. ' |  ,--.--.        .--,  
|  |   |   |  :  '   |  /     \           /     \   /       \  |  :  /`./     /_ ./|             /___/ \: | /       \     /_ ./|  
:__,'| :   |  |   /' : /    /  |         /    /  | .--.  .-. | |  :  ;_    , ' , ' :          .-'.. '   ' ..--.  .-. | , ' , ' :  
  '  : |__ '  :  | | |.    ' / |        .    ' / |  \__\/: . .  \  \    `./___/ \: |         /___/ \:     ' \__\/: . ./___/ \: |  
  |  | '.'||  |  ' | :'   ;   /|        '   ;   /|  ," .--.; |   `----.   \.  \  ' |         .   \  ' .\    ," .--.; | .  \  ' |  
  ;  :    ;|  :  :_:,''   |  / |        '   |  / | /  /  ,.  |  /  /`--'  / \  ;   :          \   \   ' \ |/  /  ,.  |  \  ;   :  
  |  ,   / |  | ,'    |   :    |        |   :    |;  :   .'   \'--'.     /   \  \  ;           \   \  |--";  :   .'   \  \  \  ;  
   ---`-'  `--''       \   \  /          \   \  / |  ,     .-./  `--'---'     :  \  \           \   \ |   |  ,     .-./   :  \  \ 
                        `----'            `----'   `--`---'                    \  ' ;            '---"     `--`---'        \  ' ; 
                                                                                `--`                                        `--`  
EOF
}

# Define Kubernetes installation variables
function define_k8s_variables() {
    local master_ip=$1
    
    # Commands for master node setup
    KUBEADMIN_INIT="sudo kubeadm init --apiserver-advertise-address ${master_ip} --pod-network-cidr=${POD_NETWORK_CIDR}"
    K8S_CONFIG="mkdir -p /root/.kube && cp -i /etc/kubernetes/admin.conf /root/.kube/config"
    CILIUM_INSTALL="cilium install --version ${CILIUM_VERSION}"
    CMD_METALLB="kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
    CMD_INSTALL_HELM="curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    CMD_INSTALL_NGINX="kubectl apply -f scripts/manifest/ingress/manifest.yaml"
    CMD_INSTALL_ARGOCD="kubectl create namespace argocd && kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
    CMD_METRIC_SERVER="kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
    CMD_KPS="helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && helm repo update && helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack --version 70.4.2"
    
    # TLS certificate creation
    TLS_CREATE="openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj '/CN=*.demo.com/O=HigorSilva' -addext 'subjectAltName = DNS:*.${MYDOMAIN}'"
}

# Configure MetalLB
function config_metal_lb() {
    local master_ip=$1
    log_info "Configurando MetalLB"
    EXEC_METALLB="kubectl apply -f scripts/manifest/metallb/manifest.yaml"
    ssh -o StrictHostKeyChecking=no -n root@${master_ip} "$EXEC_METALLB"
    log_success "MetalLB configurado com sucesso"
}

# Configure ArgoCD Ingress
function config_argocd_ingress() {
    local master_ip=$1
    log_info "Configurando TLS para o ArgoCD"
    EXEC_TLS="kubectl create secret tls high-domain-secret --key /root/tls.key --cert /root/tls.crt -n argocd"
    ssh -o StrictHostKeyChecking=no -n root@${master_ip} "$EXEC_TLS"
    
    log_info "Configurando ArgoCD Ingress"
    EXEC_ARGOCD="kubectl apply -f /root/scripts/manifest/argocd/argocd-ingress.yaml -n argocd"
    ssh -o StrictHostKeyChecking=no -n root@${master_ip} "$EXEC_ARGOCD"
    log_success "ArgoCD Ingress configurado com sucesso"
}

# Wait for pods with specific label to be running
function wait_for_pods() {
    local master_ip=$1
    local namespace=$2
    local label=$3
    local timeout=$4
    local interval=5
    
    log_info "Aguardando pods ${label} no namespace ${namespace}..."
    
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if ssh -o StrictHostKeyChecking=no -n root@${master_ip} "kubectl get pods -n ${namespace} -l ${label} | grep Running"; then
            log_success "Pods estão em execução"
            return 0
        fi
        sleep $interval
        elapsed=$((elapsed + interval))
        log_info "Aguardando pods... ($elapsed/$timeout segundos)"
    done
    
    log_error "Timeout aguardando pods"
    return 1
}

#########################################################################
# Main Script Execution
#########################################################################

# Backup and initialize SSH known_hosts
log_info "Inicializando ambiente SSH"
mv ~/.ssh/known_hosts ~/.ssh/known_hosts-bkp 2>/dev/null || true
touch ~/.ssh/known_hosts

# Start Vagrant VMs
log_info "Iniciando máquinas virtuais com Vagrant"
vagrant up

# Discover all VMs dynamically
log_info "Descobrindo todas as VMs do ambiente"

# Get list of all VMs from vagrant status
vm_list=$(vagrant status | grep -E 'master-|worker-' | awk '{print $1}')

# Initialize machines.txt file
echo "" > "$MACHINES_FILE"

# Discover master nodes
master_count=0
for vm in $vm_list; do
    if [[ $vm == master-* ]]; then
        master_count=$((master_count + 1))
        log_info "Descobrindo IP do nó master: $vm"
        ip=$(vagrant ssh $vm -c "ip addr" | grep ${PREFIX_IP} | awk '{$1=$1}1' | cut -d " " -f 2 | cut -d "/" -f 1)
        if [ -n "$ip" ]; then
            echo "$ip $vm.kubernetes.local server 10.200.0.0/24" > "$MACHINES_FILE"
            log_success "Nó master $vm encontrado com IP: $ip"
            master_ip=$ip  # Store the master IP for later use
        else
            log_error "Não foi possível obter o IP do nó master $vm"
            exit 1
        fi
    fi
done

# Discover worker nodes
worker_count=0
for vm in $vm_list; do
    if [[ $vm == worker-* ]]; then
        worker_count=$((worker_count + 1))
        worker_num=${vm#worker-}  # Extract worker number
        log_info "Descobrindo IP do nó worker: $vm"
        ip=$(vagrant ssh $vm -c "ip addr" | grep ${PREFIX_IP} | awk '{$1=$1}1' | cut -d " " -f 2 | cut -d "/" -f 1)
        if [ -n "$ip" ]; then
            echo "$ip $vm.kubernetes.local $vm ${WORKER_SUBNET_PREFIX}.$((worker_count)).0/24" >> "$MACHINES_FILE"
            log_success "Nó worker $vm encontrado com IP: $ip"
        else
            log_error "Não foi possível obter o IP do nó worker $vm"
            exit 1
        fi
    fi
done

log_info "Total de nós descobertos: $((master_count + worker_count)) ($master_count master, $worker_count workers)"
log_info "Informações dos nós salvas em $MACHINES_FILE"

# Test SSH connectivity to all nodes
log_info "Testando conectividade SSH com todos os nós"
while read IP FQDN HOST SUBNET; do 
    log_info "Testando SSH no nó: ${HOST} (${IP})"
    if ssh -o StrictHostKeyChecking=no -n root@${IP} sudo uname -o -m; then
        log_success "Conectividade SSH com ${HOST} estabelecida"
    else
        log_error "Falha ao conectar via SSH com ${HOST}"
        exit 1
    fi
done < "$MACHINES_FILE"

# Configure hostnames on all nodes
log_info "Configurando hostnames em todos os nós"
while read IP FQDN HOST SUBNET; do
    log_info "Configurando hostname no nó ${HOST}"
    CMD="sudo sed -i 's/^127.0.1.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
    ssh -o StrictHostKeyChecking=no -n root@${IP} "$CMD"
    ssh -o StrictHostKeyChecking=no -n root@${IP} sudo hostnamectl hostname ${HOST}
    log_success "Hostname configurado para ${HOST}"
done < "$MACHINES_FILE"

# Create hosts file for all nodes
log_info "Criando arquivo hosts para todos os nós"
echo "" > "$HOSTS_FILE"
echo "# Kubernetes Cluster Hosts" >> "$HOSTS_FILE"
while read IP FQDN HOST SUBNET; do 
    ENTRY="${IP} ${FQDN} ${HOST}"
    echo "$ENTRY" | sudo tee -a "$HOSTS_FILE"
done < "$MACHINES_FILE"

# Distribute hosts file to all nodes
log_info "Distribuindo arquivo hosts para todos os nós"
while read IP FQDN HOST SUBNET; do
    scp "$HOSTS_FILE" root@${IP}:~/
    ssh -o StrictHostKeyChecking=no -n root@${IP} "sudo cat hosts >> /etc/hosts"
    log_success "Arquivo hosts atualizado no nó ${HOST}"
done < "$MACHINES_FILE"

# Copy scripts to all nodes
log_info "Copiando scripts para todos os nós"
while read IP FQDN HOST SUBNET; do 
    ssh -o StrictHostKeyChecking=no -n root@${IP} "mkdir -p ~/scripts"
    scp -r scripts/* root@${IP}:~/scripts
    log_success "Scripts copiados para o nó ${HOST}"
done < "$MACHINES_FILE"

# Install Kubernetes on all nodes in parallel
log_info "Instalando Kubernetes em todos os nós (em paralelo)"
while read IP FQDN HOST SUBNET; do
    log_info "Iniciando instalação do Kubernetes no nó ${HOST}"
    chmod +x scripts/k8s-install.sh
    ssh -o StrictHostKeyChecking=no -n root@${IP} "sudo scripts/k8s-install.sh" &
done < "$MACHINES_FILE"

# Wait for all installations to complete
wait
log_success "Instalação do Kubernetes concluída em todos os nós"

# Display banner
banner
log_info "---------------------------"
log_info "   CONFIGURANDO CLUSTER K8S"
log_info "---------------------------"

# Initialize Kubernetes cluster on master node
log_info "Inicializando cluster Kubernetes no nó master"
while read -r IP FQDN HOST SUBNET || [ -n "$IP" ]; do
    case "$HOST" in
        "server")
            # Define variables for master node
            define_k8s_variables "$IP"
            
            # Create TLS certificates
            log_info "Criando certificados TLS"
            ssh -o StrictHostKeyChecking=no -n root@${IP} "$TLS_CREATE"
            
            # Initialize Kubernetes cluster
            log_info "Inicializando cluster Kubernetes"
            ssh -o StrictHostKeyChecking=no -n root@${IP} "
                ${KUBEADMIN_INIT} &&
                ${K8S_CONFIG} &&
                ${CILIUM_INSTALL} &&
                ${CMD_METALLB} &&
                ${CMD_INSTALL_HELM} &&
                ${CMD_INSTALL_NGINX} &&
                ${CMD_INSTALL_ARGOCD} &&
                ${CMD_METRIC_SERVER}
            "
            
            # Get join command for worker nodes
            log_info "Obtendo comando para adicionar workers ao cluster"
            join_command=$(ssh -o StrictHostKeyChecking=no -n root@${IP} "sudo kubeadm token create --print-join-command")
            if [ -z "$join_command" ]; then
                log_error "Não foi possível obter o comando para adicionar workers"
                exit 1
            fi
            log_success "Cluster Kubernetes inicializado com sucesso"
            ;;
    esac
done < "$MACHINES_FILE"

# Join worker nodes to the cluster
log_info "Adicionando nós workers ao cluster"
worker_jobs=()
while read IP FQDN HOST SUBNET; do
    case "$HOST" in
        worker-*)
            log_info "Adicionando worker ${HOST} ao cluster"
            # Run worker joins in background for parallel execution
            ssh -o StrictHostKeyChecking=no -n root@${IP} "sudo ${join_command}" &
            worker_jobs+=($!)
            ;;
        *)
            log_info "Host ${HOST} não é um worker. Nenhuma ação necessária."
            ;;
    esac
done < "$MACHINES_FILE"

# Wait for all worker joins to complete
for job in "${worker_jobs[@]}"; do
    wait $job
done
log_success "Todos os workers foram adicionados ao cluster"

# Configure additional components
log_info "Configurando componentes adicionais"
while read -r IP FQDN HOST SUBNET || [ -n "$IP" ]; do
    case "$HOST" in
        "server")
            # Wait for MetalLB pods to be running
            log_info "Aguardando pods do MetalLB"
            TIMEOUT=300 # 5 minutes
            if ! wait_for_pods "$IP" "metallb-system" "app=metallb" "$TIMEOUT"; then
                log_warning "Timeout aguardando pods do MetalLB, continuando mesmo assim"
            fi
            sleep 15
            # Configure MetalLB
            config_metal_lb "$IP"
            
            sleep 30
            # Configure ArgoCD Ingress
            config_argocd_ingress "$IP"
            
            log_success "Componentes adicionais configurados com sucesso"
            ;;
    esac
done < "$MACHINES_FILE"
log_info "install Kube Prometheus Stack"
while read -r IP FQDN HOST SUBNET || [ -n "$IP" ]; do
    case "$HOST" in
        "server")
            # Define variables for master node
            define_k8s_variables "$IP"

            # Initialize Kubernetes cluster
            log_info "execute Helm install"
            ssh -o StrictHostKeyChecking=no -n root@${IP} "${CMD_KPS}"
            ;;
    esac
done < "$MACHINES_FILE"
# Clean up
log_info "Limpando ambiente"
rm -f ~/.ssh/known_hosts

# Calculate execution time
end_time=$(date +%s)
duration=$((end_time - start_time))
minutes=$((duration / 60))
seconds=$((duration % 60))
log_success "Tempo de execução: ${minutes} minuto(s) e ${seconds} segundo(s)."

# Display access information
log_info "---------------------------"
log_info "INFORMAÇÕES DE ACESSO"
log_info "---------------------------"
log_info "Para acessar o Grafana:"
log_info "kubectl --namespace default get secrets kube-prometheus-stack-grafana -o jsonpath=\"{.data.admin-password}\" | base64 -d ; echo"
log_info ""
log_info "Para acessar o ArgoCD:"
log_info "kubectl --namespace argocd get secrets argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d ; echo"
log_info "---------------------------"
log_success "CLUSTER KUBERNETES CONFIGURADO COM SUCESSO!"