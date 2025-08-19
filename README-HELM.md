# Kubernetes Easy Mode - Helm Integration

## Estrutura Reorganizada

O projeto foi reorganizado para usar Helm charts com templates padrão, proporcionando maior flexibilidade e facilidade de manutenção.

### Nova Estrutura de Diretórios

```
helm/
├── metallb/
│   └── values.yaml          # Configurações do MetalLB
├── ingress-nginx/
│   └── values.yaml          # Configurações do NGINX Ingress
├── argocd/
│   └── values.yaml          # Configurações do ArgoCD
├── prometheus/
│   └── values.yaml          # Configurações do Prometheus Stack
├── local-path-provisioner/
│   └── values.yaml          # Configurações do Local Path Provisioner
└── metrics-server/
    └── values.yaml          # Configurações do Metrics Server
```

### Scripts Atualizados

- `scripts/helm-install.sh` - Script principal para instalação via Helm
- `scripts/up-k8s.sh` - Script atualizado para usar Helm

### Comandos Disponíveis

```bash
# Instalar componentes individuais
./scripts/helm-install.sh helm           # Instala Helm
./scripts/helm-install.sh repos          # Adiciona repositórios
./scripts/helm-install.sh metallb        # Instala MetalLB
./scripts/helm-install.sh ingress        # Instala NGINX Ingress
./scripts/helm-install.sh argocd         # Instala ArgoCD
./scripts/helm-install.sh prometheus     # Instala Prometheus Stack
./scripts/helm-install.sh local-path     # Instala Local Path Provisioner
./scripts/helm-install.sh metrics-server # Instala Metrics Server
./scripts/helm-install.sh all            # Instala todos os componentes
```

### Vantagens da Nova Abordagem

1. **Templates Padrão**: Usa charts oficiais mantidos pela comunidade
2. **Configuração Centralizada**: Todos os values em arquivos YAML dedicados
3. **Facilidade de Atualização**: Simples upgrade via Helm
4. **Rollback**: Possibilidade de rollback automático
5. **Customização**: Fácil personalização via values.yaml

### Componentes Configurados

- **MetalLB**: Load balancer com pool de IPs 192.168.56.240-250
- **NGINX Ingress**: Controller de ingress com LoadBalancer
- **ArgoCD**: GitOps com ingress configurado para argocd.high.sh
- **Prometheus Stack**: Monitoramento completo com Grafana
- **Local Path Provisioner**: Storage class padrão
- **Metrics Server**: Métricas de recursos dos pods/nodes

### Uso

O script principal `up-k8s.sh` foi atualizado para usar automaticamente os Helm charts durante a inicialização do cluster. Os templates e values são copiados para o master node e executados via Helm.