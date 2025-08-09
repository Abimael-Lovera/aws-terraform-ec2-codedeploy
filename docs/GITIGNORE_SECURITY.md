# .gitignore - Guia de Segurança

## ⚠️ Arquivos Sensíveis Protegidos

Este `.gitignore` foi configurado para proteger informações sensíveis e manter o repositório limpo.

### 🔑 Arquivos Críticos Excluídos

#### **Chaves SSH e Certificados**

```
*.pem
*.key
*.ppk
EC2 Key Pair SSH.pem
```

**⚠️ NUNCA commite chaves privadas!**

#### **Terraform State Files**

```
terraform.tfstate
terraform.tfstate.*
.terraform/
terraform.tfvars
```

**Contêm IDs de recursos, IPs e dados sensíveis da infraestrutura**

#### **Credenciais AWS**

```
.aws/credentials
.aws/config
```

### 📋 Configuração Inicial

1. **Copie o arquivo de exemplo:**

   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   ```

2. **Edite com seus valores:**

   ```bash
   # terraform/terraform.tfvars
   aws_profile = "seu-profile"
   key_name = "sua-key-pair"
   allowed_cidr_ssh = "SEU.IP.AQUI/32"
   ```

3. **Configure sua chave SSH:**
   ```bash
   # Coloque sua chave na raiz do projeto
   cp ~/Downloads/sua-chave.pem ./
   chmod 400 sua-chave.pem
   ```

### 🛡️ Verificação de Segurança

Para verificar se não há arquivos sensíveis commitados:

```bash
# Verificar arquivos sensíveis no histórico
git log --name-only | grep -E "(\.pem|\.key|\.tfstate|credentials)"

# Verificar status atual
git status --ignored

# Listar arquivos ignorados
git ls-files --others --ignored --exclude-standard
```

### 🔄 Estado do Terraform

**⚠️ IMPORTANTE**: Os arquivos de state do Terraform foram removidos do Git mas permanecem localmente para desenvolvimento.

- ✅ `terraform.tfstate` - Mantido localmente
- ✅ `.terraform/` - Mantido localmente
- ✅ `terraform.tfvars` - Mantido localmente
- ❌ Não são commitados (contêm dados sensíveis)

### 📦 Arquivos de Build Ignorados

- `target/` - Artefatos Maven
- `*.jar` - JARs compilados (exceto em releases)
- `.terraform/` - Cache do Terraform
- `node_modules/` - Dependências npm/yarn

### 💡 Boas Práticas

1. **Sempre revisar** antes de commit:

   ```bash
   git diff --cached
   ```

2. **Nunca força** arquivos ignorados:

   ```bash
   # ❌ NÃO FAÇA
   git add -f arquivo-sensivel.pem
   ```

3. **Use terraform.tfvars.example** como template

4. **Mantenha chaves SSH fora do projeto** quando possível

### 🚨 Em Caso de Commit Acidental

Se commitou arquivo sensível:

```bash
# Remover do último commit
git rm --cached arquivo-sensivel
git commit --amend

# Remover do histórico (CUIDADO!)
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch arquivo-sensivel' \
  --prune-empty --tag-name-filter cat -- --all
```

### 🔍 Arquivos Incluídos no Repositório

```
✅ Código fonte (.java, .tf, .sh)
✅ Configurações (.properties, .yml)
✅ Documentação (.md)
✅ Templates (.example)
❌ States, keys, credentials
❌ Artefatos de build
❌ Arquivos IDE/OS
```
