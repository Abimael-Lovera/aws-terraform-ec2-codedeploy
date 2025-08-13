# Scripts de Deploy

Este projeto possui três scripts de deploy diferentes para atender diferentes necessidades:

## 📋 Scripts Disponíveis

### 1. `./deploy.sh` - Deploy Completo com Opções

**Uso recomendado**: Deploy em produção ou quando você quer controle total

**Características**:

- ✅ Validações completas (dependências, testes, infraestrutura)
- 🎯 Permite escolher deployment groups específicos ou todos
- 📊 Monitoramento detalhado com progresso
- 🛠️ Compilação completa com testes
- 🔍 Relatórios detalhados de erro

**Exemplo de uso**:

```bash
./deploy.sh
```

O script perguntará qual deployment group usar:

```
Deployment Groups disponíveis:
  1. contador-app-dev-g1
  2. contador-app-dev-g2
  3. Todos os deployment groups

Escolha uma opção (1-3): 3
```

### 2. `./quick-deploy.sh` - Deploy Rápido com Opções

**Uso recomendado**: Deploy rápido durante desenvolvimento

**Características**:

- ⚡ Deploy rápido (pula testes unitários)
- 🎯 Permite escolher deployment groups específicos ou todos
- 📊 Monitoramento básico
- 🔧 Validações mínimas

**Exemplo de uso**:

```bash
./quick-deploy.sh
```

### 3. `./deploy-all.sh` - Deploy Automático em Todos os Grupos

**Uso recomendado**: CI/CD ou deploy automático completo

**Características**:

- 🤖 Totalmente automático (sem interação)
- 🌐 Deploy em TODOS os deployment groups automaticamente
- ⚡ Deploy rápido (pula testes unitários)
- 📊 Monitoramento detalhado de múltiplos deployments

**Exemplo de uso**:

```bash
./deploy-all.sh
```

## 🎯 Deployment Groups

O projeto possui **2 deployment groups**:

- **contador-app-dev-g1**: Instâncias `contador-app-dev-ec2-0` e `contador-app-dev-ec2-1`
- **contador-app-dev-g2**: Instâncias `contador-app-dev-ec2-2` e `contador-app-dev-ec2-3`

## 📊 Monitoramento

Todos os scripts fornecem:

- ✅ Status em tempo real do deployment
- 📋 IDs dos deployments para referência
- ❌ Detalhes de erro em caso de falha
- 🔗 Comandos para verificação manual

## 🔍 Validação Pós-Deploy

Após qualquer deploy, use:

```bash
./validate_instances.sh
```

Ou teste manualmente os endpoints:

```bash
# Healthcheck
curl http://<IP_INSTANCIA>:8080/healthcheck

# Contador
curl http://<IP_INSTANCIA>:8080/contador
```

## 💡 Dicas de Uso

### Para Desenvolvimento Diário

```bash
# Deploy rápido em um grupo específico
./quick-deploy.sh
# Escolha: 1 (primeiro grupo)
```

### Para Deploy de Produção

```bash
# Deploy completo com validações
./deploy.sh
# Escolha: 3 (todos os grupos)
```

### Para CI/CD Pipeline

```bash
# Deploy automático sem interação
./deploy-all.sh
```

### Para Rollback de Emergência

```bash
# Use o AWS CLI diretamente
aws deploy stop-deployment --deployment-id <DEPLOYMENT_ID> --auto-rollback-enabled
```

## ⚠️ Tratamento de Erros

### Deploy Falhou em Um Grupo

- O script continuará com os outros grupos
- Será mostrado um relatório final com sucessos/falhas
- IDs dos deployments falhados serão listados para investigação

### Timeout de Deploy

- Deployments podem continuar executando no background
- Use os IDs fornecidos para monitoramento manual:

```bash
aws deploy get-deployment --deployment-id <DEPLOYMENT_ID>
```

### Verificação de Status Manual

```bash
# Listar deployments recentes
aws deploy list-deployments --application-name contador-app-dev-app --deployment-group-name contador-app-dev-g1

# Ver detalhes de um deployment específico
aws deploy get-deployment --deployment-id <DEPLOYMENT_ID>
```

## 🔧 Configuração

Os scripts usam as seguintes configurações:

- **AWS Profile**: `alm-yahoo-account`
- **AWS Region**: `us-east-1`
- **Application**: `contador-app-dev-app`
- **S3 Bucket**: Obtido automaticamente do Terraform

Para alterar essas configurações, edite as variáveis no início de cada script.
