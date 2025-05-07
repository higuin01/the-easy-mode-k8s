Inspirado pelos estudos sobre Kubernetes e pela falta de um homeLab, decidi compartilhar o esqueleto do meu "Playground".

# Modo Fácil do Kubernetes: Implantação Automatizada de Clusters Kubernetes com o Vagrant

Uma ferramenta de automação baseada em Go que simplifica a implantação e o gerenciamento de clusters Kubernetes com vários nós usando o Vagrant. Ela fornece uma maneira simplificada de criar, gerenciar e monitorar ambientes de desenvolvimento Kubernetes com monitoramento integrado e recursos de GitOps.

Este projeto automatiza a configuração de um ambiente Kubernetes completo, incluindo um nó mestre e vários nós de trabalho, com componentes essenciais pré-configurados, como Cilium para rede, MetalLB para balanceamento de carga, Controlador de Entrada NGINX, ArgoCD para GitOps e Prometheus para monitoramento. A automação cuida de todos os aspectos, desde o provisionamento de VMs até a instalação e configuração de componentes do Kubernetes, tornando-a ideal para ambientes de desenvolvimento e teste.

## Estrutura do Repositório
```
.
├── devfile.yaml              # Development environment configuration
├── main.go                   # Application entry point
├── pkg/                      # Core application packages
│   ├── cluster/             # Cluster management implementation
│   ├── config/              # Configuration handling
│   └── ui/                  # User interface components
├── scripts/                  # Automation scripts
│   ├── k8s-install.sh       # Kubernetes installation script
│   ├── up-k8s.sh           # Cluster initialization script
│   ├── manifest/            # Kubernetes manifests
│   │   ├── argocd/         # ArgoCD configuration
│   │   ├── ingress/        # NGINX Ingress configuration
│   │   └── metallb/        # MetalLB configuration
│   └── sys-moni.sh         # System monitoring script
└── Vagrantfile              # Vagrant VM configuration
```

## Instruções de Uso
### Pré-requisitos
- VirtualBox 6.1 or later
- Vagrant 2.2.x or later
- Go 1.19 or later
- At least 8GB of RAM available
- 20GB of free disk space
- Linux/Unix-based operating system (MacOS or Linux recommended)

### Instalação

1. Clone o repository:
```bash
git clone <repository-url>
cd kubernetes-easy-mode
```

2. Install dependencies:
```bash
go mod download
```

3. Faça o build da aplicação:
```bash
go build -o k8s-easy
```

### Quick Start

1. Inicie a aplicação:
```bash
./k8s-easy
```

2. No menu, selecione a opção 1 para iniciar o cluster:
```
1. Iniciar Cluster
2. Mostrar Status
3. Destruir Cluster
4. Sair
```

3. Aguarde a conclusão da inicialização do cluster (aproximadamente 10 a 15 minutos)

### Exemplos mais detalhados

1. Monitor cluster nodes:
```bash
./scripts/monitor-node.sh
```

2. Check cluster status:
```bash
./scripts/status-k8s.sh
```

3. Accesso ao ArgoCD UI:
```bash
# Get the ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# Access via https://argocd.high.sh
```

### Troubleshooting

1. Problemas na Criação de VM
- Erro: "VT-x não está disponível"
* Habilite a virtualização nas configurações do BIOS
* Certifique-se de que nenhum outro software de virtualização esteja em execução

2. Falhas na Instalação do Kubernetes
- Verifique os logs:
```bash
vagrant ssh master-1
sudo journalctl -u kubelet
```
- Verificar conectividade de rede:
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

3. MetalLB Configuration
- Verificar configuração do pool de IP:
```bash
kubectl get ipaddresspool -n metallb-system
```
- Check MetalLB pods:
```bash
kubectl get pods -n metallb-system
```

## Fluxo de Dados
O sistema automatiza a criação e a configuração de um cluster Kubernetes por meio de uma série de etapas coordenadas, desde o provisionamento da VM até a implantação do serviço.

```ascii
[User Input] -> [Cluster Manager] -> [Vagrant VMs] -> [Kubernetes Setup]
                      |                                      |
                      v                                      v
              [System Monitoring] <- [MetalLB/Ingress] <- [Services]
```

Interações de componentes:
1. O Gerenciador de Cluster inicia a criação da VM por meio do Vagrant
2. As VMs são provisionadas com os componentes necessários do Kubernetes
3. O nó mestre é inicializado com o kubeadm
4. Os nós de trabalho ingressam no cluster usando tokens gerados
5. Plug-ins de rede (Cilium) estabelecem a rede de pods
6. O MetalLB fornece recursos de balanceamento de carga
7. O controlador Ingress permite acesso externo
8. Os sistemas de monitoramento rastreiam a integridade do cluster

## Infrastructure

![Infrastructure diagram](./docs/infra.svg)
- VMs do VirtualBox:
* master-1: plano de controle do Kubernetes (2 CPUs, 3 GB de RAM)
* worker-0/1/2: ​​nós de trabalho (1 CPU, 1,5 GB de RAM cada)

- Componentes do Kubernetes:
* Cilium: plugin CNI para rede
* MetalLB: balanceador de carga (intervalo de IP: 192.168.56.240-250)
* NGINX Ingress: controlador Ingress
* ArgoCD: plataforma GitOps
* Prometheus: pilha de monitoramento
 
