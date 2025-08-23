#!/bin/bash

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Install Helm if not present
install_helm() {
    if ! command -v helm &> /dev/null; then
        log_info "Instalando Helm..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        log_success "Helm instalado com sucesso"
    else
        log_info "Helm já está instalado"
    fi
}

# Add Helm repositories
add_helm_repos() {
    log_info "Adicionando repositórios Helm..."
    
    helm repo add metallb https://metallb.github.io/metallb
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo add argo https://argoproj.github.io/argo-helm
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add containeroo https://charts.containeroo.ch
    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add minio https://charts.min.io/
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo add jetstack https://charts.jetstack.io
    
    helm repo update
    log_success "Repositórios Helm adicionados e atualizados"
}

# Install MetalLB
install_metallb() {
    log_info "Instalando MetalLB via Helm..."
    
    helm upgrade --install metallb metallb/metallb \
        --namespace metallb-system \
        --create-namespace \
        --values /root/scripts/helm/metallb/values.yaml \
        --debug \
        --wait
        
    log_success "MetalLB instalado com sucesso"
}

# Install NGINX Ingress
install_nginx_ingress() {
    log_info "Instalando NGINX Ingress via Helm..."
    
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --values /root/scripts/helm/ingress-nginx/values.yaml \
        --debug \
        --wait
        
    log_success "NGINX Ingress instalado com sucesso"
}

# Install ArgoCD
install_argocd() {
    log_info "Instalando ArgoCD via Helm..."
    
    helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        --values /root/scripts/helm/argocd/values.yaml \
        --debug \
        --wait
        
    log_success "ArgoCD instalado com sucesso"
}

# Install Prometheus Stack
install_prometheus() {
    log_info "Instalando Prometheus Stack via Helm..."
    
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --values /root/scripts/helm/prometheus/values.yaml \
        --debug \
        --version 72.6.2 \
        --wait
        
    log_success "Prometheus Stack instalado com sucesso"
}

# Install Local Path Provisioner
install_local_path() {
    log_info "Instalando Local Path Provisioner via Helm..."
    
    helm upgrade --install local-path-provisioner containeroo/local-path-provisioner \
        --namespace local-path-storage \
        --create-namespace \
        --values /root/scripts/helm/local-path-provisioner/values.yaml \
        --debug \
        --wait
        
    log_success "Local Path Provisioner instalado com sucesso"
}

# Install Metrics Server
install_metrics_server() {
    log_info "Instalando Metrics Server via Helm..."
    
    helm upgrade --install metrics-server metrics-server/metrics-server \
        --namespace kube-system \
        --values /root/scripts/helm/metrics-server/values.yaml \
        --debug \
        --wait
        
    log_success "Metrics Server instalado com sucesso"
}

# Install Grafana Loki (Logs)
install_loki() {
    log_info "Instalando Grafana Loki via Helm..."
    
    helm upgrade --install loki grafana/loki --version 6.36.1 \
        --namespace monitoring \
        --create-namespace \
        --values /root/scripts/helm/loki/values.yaml \
        --debug \
        --wait
        
    log_success "Grafana Loki instalado com sucesso"
    
    # Install Promtail after Loki
    install_promtail
}

# Install Promtail (Log collector)
install_promtail() {
    log_info "Instalando Promtail via Helm..."
    
    helm upgrade --install promtail grafana/promtail \
        --namespace monitoring \
        --create-namespace \
        --values /root/scripts/helm/promtail/values.yaml \
        --debug \
        --wait
        
    log_success "Promtail instalado com sucesso"
}

# Install Grafana Tempo (Traces)
install_tempo() {
    log_info "Instalando Grafana Tempo via Helm..."
    
    helm upgrade --install tempo grafana/tempo-distributed --version 1.46.4 \
        --namespace monitoring \
        --create-namespace \
        --values /root/scripts/helm/tempo/values.yaml \
        --debug \
        --wait
        
    log_success "Grafana Tempo instalado com sucesso"
}

# Install Grafana Mimir (Metrics)
install_mimir() {
    log_info "Instalando Grafana Mimir via Helm..."
    
    helm upgrade --install mimir grafana/mimir-distributed --version 5.8.0-weekly.356\
        --namespace monitoring \
        --create-namespace \
        --values /root/scripts/helm/mimir/values.yaml \
        --debug \
        --wait
        
    log_success "Grafana Mimir instalado com sucesso"
}

# Install MinIO
install_minio() {
    log_info "Instalando MinIO via Helm..."
    
    helm upgrade --install minio minio/minio \
        --namespace minio \
        --create-namespace \
        --values /root/scripts/helm/minio/values.yaml \
        --debug \
        --wait
        
    log_success "MinIO instalado com sucesso"
}

# Install cert-manager (dependency for OpenTelemetry Operator)
install_cert_manager() {
    log_info "Instalando cert-manager via Helm..."
    
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true \
        --debug \
        --wait
        
    log_success "cert-manager instalado com sucesso"
}

# Install OpenTelemetry Operator
install_otel_operator() {
    log_info "Instalando OpenTelemetry Operator via Helm..."
    
    # Install cert-manager first (dependency)
    install_cert_manager
    
    helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
        --namespace opentelemetry-operator-system \
        --create-namespace \
        --values /root/scripts/helm/otel-operator/values.yaml \
        --debug \
        --wait
        
    log_success "OpenTelemetry Operator instalado com sucesso"
    
    # Wait for operator to be ready
    log_info "Aguardando Operator ficar pronto..."
    kubectl wait --for=condition=available deployment/opentelemetry-operator \
        -n opentelemetry-operator-system --timeout=300s
    
    # Apply RBAC and CRDs
    log_info "Aplicando RBAC e CRDs do OpenTelemetry..."
    kubectl apply -f /root/scripts/helm/otel-operator/rbac.yaml
    kubectl apply -f /root/scripts/helm/otel-operator/opentelemetry-collector.yaml
    kubectl apply -f /root/scripts/helm/otel-operator/instrumentation.yaml
    
    log_success "RBAC e CRDs do OpenTelemetry aplicados com sucesso"
}


# Install complete LGTM Stack
install_lgtm_stack() {
    log_info "Instalando Stack LGTM completa..."
    install_minio
    install_loki
    install_tempo
    install_mimir
    log_success "Stack LGTM instalada com sucesso"
}

# Create TLS secret for ArgoCD
create_tls_secret() {
    log_info "Criando certificado TLS para ArgoCD..."
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /tmp/tls.key -out /tmp/tls.crt \
        -subj '/CN=*.high.sh/O=HigorSilva' \
        -addext 'subjectAltName = DNS:*.high.sh'
    kubectl create namespace argocd
    kubectl create secret tls high-domain-secret \
        --key /tmp/tls.key --cert /tmp/tls.crt \
        -n argocd --dry-run=client -o yaml | kubectl apply -f -
        
    rm -f /tmp/tls.key /tmp/tls.crt
    log_success "Certificado TLS criado com sucesso"
}

# Main function
main() {
    case "$1" in
        "helm")
            install_helm
            ;;
        "repos")
            add_helm_repos
            ;;
        "metallb")
            install_metallb
            ;;
        "ingress")
            install_nginx_ingress
            ;;
        "argocd")
            create_tls_secret
            install_argocd
            ;;
        "prometheus")
            install_prometheus
            ;;
        "local-path")
            install_local_path
            ;;
        "metrics-server")
            install_metrics_server
            ;;
        "loki")
            install_loki
            ;;
        "promtail")
            install_promtail
            ;;
        "tempo")
            install_tempo
            ;;
        "mimir")
            install_mimir
            ;;
        "minio")
            install_minio
            ;;
        "cert-manager")
            install_cert_manager
            ;;
        "otel-operator")
            install_otel_operator
            ;;
        "otel")
            install_otel_operator
            ;;
        "lgtm")
            install_lgtm_stack
            ;;
        "all")
            install_helm
            add_helm_repos
            install_local_path
            install_metrics_server
            install_metallb
            install_nginx_ingress
            create_tls_secret
            install_argocd
            install_prometheus
            install_lgtm_stack
            ;;
        *)
            echo "Uso: $0 {helm|repos|metallb|ingress|argocd|prometheus|local-path|metrics-server|minio|loki|promtail|tempo|mimir|cert-manager|otel-operator|otel|lgtm|all}"
            exit 1
            ;;
    esac
}

main "$@"