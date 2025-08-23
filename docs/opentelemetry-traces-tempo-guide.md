# 📊 OpenTelemetry + Grafana Tempo: Guia Completo para Traces

## 🎯 Visão Geral

Este guia explica como configurar **distributed tracing** usando **OpenTelemetry** e **Grafana Tempo** na sua stack Kubernetes. O objetivo é capturar, processar e visualizar traces de aplicações de forma automática.

### 🔄 Fluxo de Dados (Data Flow)

```
[Aplicação Java] 
    ↓ (auto-instrumentação)
[OpenTelemetry Agent] 
    ↓ (OTLP gRPC - porta 4317)
[OpenTelemetry Collector] 
    ↓ (OTLP gRPC - porta 4317)
[Grafana Tempo] 
    ↓ (consulta)
[Grafana Dashboard]
```

---

## 🏗️ Arquitetura dos Componentes

### 1. **OpenTelemetry Operator**
- **Função**: Gerencia auto-instrumentação de aplicações
- **Namespace**: `opentelemetry-operator-system`
- **Responsabilidades**:
  - Injeta agents de instrumentação automaticamente
  - Gerencia configurações de instrumentação por linguagem
  - Cria e gerencia OpenTelemetry Collectors

### 2. **OpenTelemetry Collector**
- **Função**: Recebe, processa e exporta telemetria
- **Modo**: DaemonSet (roda em cada nó)
- **Namespace**: `monitoring`
- **Responsabilidades**:
  - Recebe traces via OTLP (portas 4317/4318)
  - Adiciona metadados Kubernetes
  - Envia traces para Grafana Tempo

### 3. **Grafana Tempo**
- **Função**: Armazena e consulta traces distribuídos
- **Arquitetura**: Distribuída (distributor, ingester, querier, etc.)
- **Namespace**: `monitoring`
- **Responsabilidades**:
  - Armazena traces de forma eficiente
  - Fornece API de consulta para Grafana
  - Gerencia retenção e compactação

---

## 📁 Estrutura de Arquivos e Configurações

### 🔧 1. OpenTelemetry Operator (`/scripts/helm/otel-operator/`)

#### `values.yaml` - Configuração do Operator
```yaml
# Configuração mínima do OpenTelemetry Operator
replicaCount: 1

manager:
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi
  env:
    ENABLE_WEBHOOKS: "true"  # Habilita auto-instrumentação
    OTEL_RESOURCE_ATTRIBUTES: "service.name=opentelemetry-operator"
```

**📝 Explicação**:
- `ENABLE_WEBHOOKS`: Permite que o operator injete instrumentação automaticamente
- Recursos limitados para ambiente de desenvolvimento
- O operator monitora annotations nos pods para decidir quando instrumentar

#### `instrumentation.yaml` - Configuração de Auto-instrumentação
```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: default-instrumentation
  namespace: opentelemetry-operator-system
spec:
  # 🎯 CRÍTICO: Endpoint onde traces serão enviados
  exporter:
    endpoint: http://otel-collector-collector.monitoring.svc.cluster.local:4317
  
  # Formatos de propagação de contexto
  propagators:
    - tracecontext  # W3C Trace Context (padrão)
    - baggage       # W3C Baggage
    - b3            # Zipkin B3 (compatibilidade)
  
  # Configuração de sampling (25% dos traces)
  sampler:
    type: parentbased_traceidratio
    argument: "0.25"
  
  # Configurações por linguagem
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
    env:
      - name: OTEL_JAVAAGENT_DEBUG
        value: "false"
      - name: OTEL_INSTRUMENTATION_JDBC_ENABLED
        value: "true"  # Instrumenta queries SQL
      - name: OTEL_INSTRUMENTATION_KAFKA_ENABLED
        value: "true"  # Instrumenta Kafka
```

**📝 Explicação**:
- **Endpoint**: Deve apontar para o Collector (porta 4317 = gRPC)
- **Sampling**: 25% reduz overhead, mas mantém visibilidade
- **Propagators**: Garantem que contexto de trace seja mantido entre serviços
- **Por linguagem**: Cada linguagem tem configurações específicas

#### `opentelemetry-collector.yaml` - Configuração do Collector
```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: otel-collector
  namespace: monitoring
spec:
  mode: daemonset  # Roda em cada nó do cluster
  
  config:
    # 📥 RECEIVERS: Como receber telemetria
    receivers:
      otlp:  # Protocolo nativo OpenTelemetry
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317  # Para aplicações modernas
          http:
            endpoint: 0.0.0.0:4318  # Para compatibilidade
      
      jaeger:  # Para aplicações legacy
        protocols:
          grpc:
            endpoint: 0.0.0.0:14250
          thrift_http:
            endpoint: 0.0.0.0:14268

    # 🔄 PROCESSORS: Como processar telemetria
    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024  # Agrupa traces para eficiência
      
      resource:
        attributes:
          - key: cluster.name
            value: "local-k8s"
            action: insert
          - key: deployment.environment
            value: "development"
            action: insert
      
      k8sattributes:  # Adiciona metadados Kubernetes
        auth_type: "serviceAccount"
        extract:
          metadata:
            - k8s.pod.name
            - k8s.deployment.name
            - k8s.namespace.name
            - k8s.node.name

    # 📤 EXPORTERS: Para onde enviar telemetria
    exporters:
      otlp/tempo:
        endpoint: http://tempo-distributor.monitoring.svc.cluster.local:4317
        tls:
          insecure: true
      
      debug:  # Para troubleshooting
        verbosity: detailed

    # 🔀 PIPELINES: Fluxo de processamento
    service:
      pipelines:
        traces:
          receivers: [otlp, jaeger]
          processors: [k8sattributes, resource, batch]
          exporters: [otlp/tempo, debug]
```

**📝 Explicação**:
- **DaemonSet**: Garante que cada nó tenha um collector
- **Receivers**: Múltiplos protocolos para compatibilidade
- **k8sattributes**: Enriquece traces com informações do Kubernetes
- **Batch processor**: Melhora performance agrupando dados
- **Pipeline**: Define o fluxo completo de processamento

---

### 🎯 2. Grafana Tempo (`/scripts/helm/tempo/`)

#### `values.yaml` - Configuração do Tempo
```yaml
fullnameOverride: tempo

# 🔌 PROTOCOLOS: Quais formatos aceitar
traces:
  jaeger:
    grpc:
      enabled: true
    thriftHttp:
      enabled: true
  zipkin:
    enabled: true
  otlp:  # 🎯 PRINCIPAL: OpenTelemetry nativo
    http:
      enabled: true
    grpc:
      enabled: true

# 🏗️ COMPONENTES DISTRIBUÍDOS
distributor:
  replicas: 1  # Recebe traces
  resources:
    limits:
      cpu: 500m
      memory: 512Mi

ingester:
  replicas: 2  # 🚨 IMPORTANTE: Mínimo 2 para replicação
  resources:
    limits:
      cpu: 500m
      memory: 1Gi
  persistence:
    enabled: true
    size: 10Gi

querier:
  replicas: 1  # Processa consultas
  
queryFrontend:
  replicas: 1  # Interface de consulta

compactor:
  replicas: 1  # Compacta dados antigos

# 📊 CONFIGURAÇÕES GLOBAIS
global_overrides:
  ingestion_rate_limit_bytes: 20000000
  ingestion_burst_size_bytes: 30000000
  max_traces_per_user: 10000
  ingestion_rate_strategy: local      # Para single-tenant
  max_global_traces_per_user: 0       # Sem limite global

# 💾 ARMAZENAMENTO
storage:
  trace:
    backend: local  # Para desenvolvimento
    local:
      path: /var/tempo/traces
    wal:
      path: /var/tempo/wal
```

**📝 Explicação**:
- **Ingester replicas: 2**: Tempo exige mínimo 2 réplicas para replicação
- **Protocolos múltiplos**: Aceita OTLP, Jaeger e Zipkin
- **Storage local**: Para desenvolvimento; produção usaria S3/GCS
- **Rate limiting**: Protege contra sobrecarga

---

## 🚀 Como Usar Auto-instrumentação

### 1. **Instrumentar Aplicação Java**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minha-app-java
spec:
  template:
    metadata:
      annotations:
        # 🎯 CHAVE: Esta annotation ativa auto-instrumentação
        instrumentation.opentelemetry.io/inject-java: "opentelemetry-operator-system/default-instrumentation"
    spec:
      containers:
      - name: app
        image: minha-app:latest
        env:
        # 📝 IDENTIFICAÇÃO: Nome do serviço nos traces
        - name: OTEL_SERVICE_NAME
          value: "minha-app-producao"
        # 🏷️ METADADOS: Informações adicionais
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "service.name=minha-app,service.version=1.2.3,environment=production"
```

### 2. **O que Acontece Automaticamente**

1. **Operator detecta** a annotation
2. **Injeta init container** com Java agent
3. **Configura variáveis** de ambiente OTEL_*
4. **Agent instrumenta** automaticamente:
   - HTTP requests/responses
   - Database queries (JDBC)
   - Kafka producers/consumers
   - Spring Boot endpoints
   - E muito mais...

### 3. **Outras Linguagens**

```yaml
# Node.js
instrumentation.opentelemetry.io/inject-nodejs: "opentelemetry-operator-system/default-instrumentation"

# Python
instrumentation.opentelemetry.io/inject-python: "opentelemetry-operator-system/default-instrumentation"

# .NET
instrumentation.opentelemetry.io/inject-dotnet: "opentelemetry-operator-system/default-instrumentation"
```

---

## 🔍 Visualização no Grafana

### 1. **Configurar Data Source**
- **URL**: `http://tempo-query-frontend.monitoring.svc.cluster.local:3200`
- **Access**: Server (default)

### 2. **Consultar Traces**
```
# Por serviço
{service.name="minha-app-producao"}

# Por operação
{service.name="minha-app-producao" && name="GET /api/users"}

# Por erro
{service.name="minha-app-producao" && status=error}
```

### 3. **Informações Disponíveis**
- **Duração** de cada operação
- **Dependências** entre serviços
- **Erros** e stack traces
- **Metadados** Kubernetes
- **Correlação** com logs e métricas

---

## 🛠️ Comandos de Instalação

```bash
# 1. Instalar Tempo
./scripts/helm-install.sh tempo

# 2. Instalar OpenTelemetry Operator
./scripts/helm-install.sh otel-operator

# 3. Verificar se está funcionando
kubectl get pods -n monitoring | grep -E "(tempo|otel)"
kubectl get pods -n opentelemetry-operator-system
```

---

## 🔧 Troubleshooting

### ❌ **Problema**: Traces não aparecem no Grafana
```bash
# Verificar se collector está recebendo
kubectl logs -l app.kubernetes.io/name=otel-collector-collector -n monitoring | grep -i trace

# Verificar se Tempo está recebendo
kubectl logs -l app.kubernetes.io/name=tempo,app.kubernetes.io/component=distributor -n monitoring
```

### ❌ **Problema**: Auto-instrumentação não funciona
```bash
# Verificar se annotation foi aplicada
kubectl describe pod <nome-do-pod> | grep -i instrumentation

# Verificar se init container foi injetado
kubectl get pod <nome-do-pod> -o jsonpath='{.spec.initContainers[*].name}'
```

### ❌ **Problema**: Erro "at least 2 live replicas required"
- **Solução**: Aumentar `ingester.replicas` para 2 no Tempo

---

## 📈 Benefícios para Produção

1. **Observabilidade Completa**: Vê exatamente onde tempo é gasto
2. **Debug Distribuído**: Rastreia requests através de múltiplos serviços
3. **Performance Insights**: Identifica gargalos automaticamente
4. **Zero Code Changes**: Auto-instrumentação não requer mudanças no código
5. **Correlação**: Liga traces com logs e métricas no Grafana

---

## 🎯 Próximos Passos

Agora que traces estão funcionando, podemos configurar:
1. **Loki** para logs correlacionados
2. **Mimir** para métricas de longa duração
3. **Alerting** baseado em traces
4. **Service Map** no Grafana

---

**✅ Stack de Traces Completa e Funcionando!** 🚀