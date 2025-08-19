# Kubernetes Easy Mode - Helm Integration

## Estrutura Reorganizada

O projeto foi reorganizado para usar Helm charts com templates padrão, proporcionando maior flexibilidade e facilidade de manutenção. Esta abordagem substitui os manifestos YAML estáticos por charts oficiais da comunidade.

### Nova Estrutura de Diretórios

```
scripts/helm/
├── metallb/
│   ├── values.yaml          # Configurações do MetalLB
│   └── manifest.yaml        # Configuração adicional de IP pools
├── ingress-nginx/
│   └── values.yaml          # Configurações do NGINX Ingress
├── argocd/
│   ├── values.yaml          # Configurações do ArgoCD
│   └── argocd-ingress.yaml  # Ingress customizado para ArgoCD
├── prometheus/
│   ├── values.yaml          # Configurações do Prometheus Stack
│   └── grafana-ingress.yaml # Ingress para Grafana
├── metrics-server/
│   └── values.yaml          # Configurações do Metrics Server
└── local-path-provisioner/
    └── values.yaml          # Configurações do storage provisioner
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
  - Configurado via Helm chart oficial
  - Pool de IPs definido em values.yaml
  - Protocolo Layer 2 para ambiente local

- **NGINX Ingress**: Controller de ingress com LoadBalancer
  - Service type LoadBalancer para integração com MetalLB
  - Métricas habilitadas
  - Recursos otimizados para ambiente de desenvolvimento

- **ArgoCD**: GitOps com ingress configurado para argocd.high.sh
  - Instalado via Helm chart oficial da Argo
  - Ingress customizado com TLS
  - Certificado autoassinado para desenvolvimento

- **Prometheus Stack**: Monitoramento completo com Grafana
  - Inclui Prometheus, Grafana, AlertManager
  - Persistência configurada com Local Path Provisioner
  - Grafana com senha padrão: admin123
  - Retenção de dados: 30 dias

- **Local Path Provisioner**: Storage class padrão
  - Configurado como storage class padrão
  - Ideal para ambientes de desenvolvimento
  - Armazenamento local nos nós worker

- **Metrics Server**: Métricas de recursos dos pods/nodes
  - Necessário para HPA e comandos kubectl top
  - Configurado para funcionar com certificados inseguros (desenvolvimento)

### Uso

O script principal `up-k8s.sh` foi atualizado para usar automaticamente os Helm charts durante a inicialização do cluster. Os templates e values são copiados para o master node e executados via Helm.

#### Fluxo de Instalação

1. **Preparação**: Scripts e values são copiados para o master node
2. **Helm Setup**: Helm é instalado e repositórios são adicionados
3. **Instalação Sequencial**: Componentes são instalados na ordem correta
4. **Configuração**: Recursos adicionais como ingress e certificados são aplicados

#### Personalização

Para personalizar qualquer componente, edite o arquivo `values.yaml` correspondente:

```bash
# Exemplo: Alterar configurações do Prometheus
vim scripts/helm/prometheus/values.yaml

# Reinstalar apenas o Prometheus
./scripts/helm-install.sh prometheus
```

#### Monitoramento

Após a instalação, você pode monitorar os deployments:

```bash
# Ver status de todos os releases Helm
helm list --all-namespaces

# Ver pods de monitoramento
kubectl get pods -n monitoring

# Acessar Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```