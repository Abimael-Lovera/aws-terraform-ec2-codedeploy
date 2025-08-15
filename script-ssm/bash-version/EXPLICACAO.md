# 🔍 Explicação dos Scripts Bash Version

## 🤔 **Por que existem DOIS scripts diferentes?**

Na pasta `bash-version` temos:

1. **`extract_appsettings_windows.sh`** (Bash) - Roda no seu Mac/Linux
2. **`extract_appsettings.ps1`** (PowerShell) - Roda nos servidores Windows

## 📋 **ROTEIRO DE FUNCIONAMENTO:**

### **PASSO 1: Você executa o script Bash**

```bash
./extract_appsettings_windows.sh meu-profile
```

### **PASSO 2: O script Bash faz isso:**

1. Conecta na AWS usando seu profile
2. Busca servidores Windows com "SI2" no nome
3. Para cada servidor encontrado:
   - Verifica se SSM está ativo
   - **ENVIA COMANDOS PowerShell** via SSM para o servidor Windows
   - Recebe o resultado de volta
   - Salva os arquivos no seu computador

### **PASSO 3: Os comandos PowerShell (que são enviados):**

- `$env:COMPUTERNAME` (pegar hostname)
- `Test-Path 'D:\Sites\Api'` (verificar se pasta existe)
- `Get-Content 'D:\Sites\Api\appsettings.json' -Raw` (ler arquivo)

---

## 🔄 **FLUXO DETALHADO:**

```
SEU COMPUTADOR (Mac/Linux)          SERVIDOR WINDOWS (via SSM)
┌─────────────────────────┐         ┌─────────────────────────┐
│                         │         │                         │
│ 1. extract_windows.sh   │ ───────→│ 2. Executa PowerShell  │
│    (script Bash)        │   SSM   │    $env:COMPUTERNAME    │
│                         │         │                         │
│ 3. Recebe: "SI2-WEB-01" │ ←─────── │                         │
│                         │         │                         │
│ 4. extract_windows.sh   │ ───────→│ 5. Executa PowerShell  │
│    envia outro comando  │   SSM   │    Get-Content arquivo  │
│                         │         │                         │
│ 6. Recebe: conteúdo do  │ ←─────── │                         │
│    arquivo appsettings  │         │                         │
│                         │         │                         │
│ 7. Salva arquivo local  │         │                         │
│                         │         │                         │
└─────────────────────────┘         └─────────────────────────┘
```

---

## 🎯 **ENTÃO, QUAL É A DIFERENÇA?**

### **`extract_appsettings_windows.sh` (Bash)**

- **Onde roda:** No seu computador (Mac/Linux)
- **O que faz:**
  - Orquestra todo o processo
  - Conecta na AWS
  - Busca servidores
  - Envia comandos PowerShell via SSM
  - Organiza arquivos baixados
- **Linguagem:** Bash (shell do Mac/Linux)

### **`extract_appsettings.ps1` (PowerShell)**

- **Onde roda:** Nos servidores Windows (via SSM)
- **O que faz:**
  - Script "modelo" que pode ser executado diretamente no Windows
  - Mostra exemplo de como buscar arquivos localmente
  - **NÃO é usado diretamente** pelo script Bash
- **Linguagem:** PowerShell (nativo do Windows)

---

## 🔧 **QUAL VOCÊ USA?**

### **Para extrair arquivos dos servidores:**

```bash
# ESTE é o que você executa
./extract_appsettings_windows.sh meu-profile
```

### **O PowerShell (.ps1) serve para:**

- ✅ **Referência** - ver como buscar arquivos no Windows
- ✅ **Execução manual** - se quiser rodar direto no servidor Windows
- ✅ **Estudo** - entender os comandos PowerShell usados

---

## 💡 **ANALOGIA SIMPLES:**

Imagine que você quer pegar um arquivo de dentro de uma casa:

- **Script Bash** = Você (do lado de fora) usando um controle remoto
- **Comandos PowerShell** = Os comandos que o controle remoto envia
- **Script .ps1** = Manual de instruções de como fazer manualmente dentro da casa

**Você usa o controle remoto (Bash), que envia comandos (PowerShell) para dentro da casa (servidor Windows)!**

---

## 📊 **RESUMO:**

| Script                           | Onde Executa     | Para que Serve                          |
| -------------------------------- | ---------------- | --------------------------------------- |
| `extract_appsettings_windows.sh` | Seu computador   | **PRINCIPAL** - Extrai arquivos via SSM |
| `extract_appsettings.ps1`        | Servidor Windows | **REFERÊNCIA** - Exemplo/manual         |

**Use apenas o `.sh` - ele faz tudo automaticamente!** 🚀
