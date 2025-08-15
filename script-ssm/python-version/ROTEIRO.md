# 📋 Roteiro do Script extract_simple.py

## 🎯 **O que o script faz:**

Acessa servidores Windows na AWS e copia arquivos de configuração `appsettings.json` para o seu computador.

---

## 🔄 **Fluxo de Execução (Passo a Passo):**

### **1. 🚀 INÍCIO**

- Recebe o nome do profile AWS como parâmetro
- Define configurações:
  - Filtro de servidores: "SI2" (busca servidores com SI2 no nome)
  - Caminho no Windows: `D:\Sites\Api`

### **2. 🔌 CONECTAR NA AWS**

- Conecta na AWS usando o profile informado
- Cria clientes para EC2 (gerenciar servidores) e SSM (executar comandos remotos)

### **3. 🔍 BUSCAR SERVIDORES WINDOWS**

- Faz uma consulta no EC2 procurando por:
  - ✅ Servidores Windows
  - ✅ Que estejam rodando (running)
  - ✅ Que tenham "SI2" no nome
- Lista todos os servidores encontrados

### **4. 📁 CRIAR PASTA DE BACKUP**

- Cria uma pasta local com timestamp: `backup_appsettings_20250815_143022`
- Aqui ficarão todos os arquivos baixados

### **5. 🔄 PARA CADA SERVIDOR ENCONTRADO:**

#### **5.1 ✅ Verificar SSM**

- Verifica se o servidor tem o SSM Agent funcionando
- SSM = Systems Manager (permite executar comandos remotos)
- Se não tiver SSM ativo, pula para o próximo servidor

#### **5.2 🖥️ Obter Hostname**

- Executa comando PowerShell: `$env:COMPUTERNAME`
- Pega o nome real do servidor no Windows

#### **5.3 📥 Extrair Arquivos**

- Busca 2 arquivos específicos:
  - `appsettings.json` (arquivo geral)
  - `appsettings.HOSTNAME.json` (arquivo específico do servidor)

#### **5.4 💾 Salvar Localmente**

- Para cada arquivo encontrado:
  - Executa comando PowerShell para ler o conteúdo
  - Se o arquivo existir, salva na pasta local
  - Cria uma subpasta para cada servidor

#### **5.5 📊 Salvar Metadados**

- Cria arquivo `metadata.json` com informações:
  - ID da instância
  - Nome do servidor
  - Hostname
  - IP
  - Data/hora da extração
  - Quantos arquivos foram extraídos

### **6. 📈 RELATÓRIO FINAL**

- Mostra resumo:
  - Quantos servidores foram encontrados
  - Quantos tiveram arquivos extraídos com sucesso
  - Onde os arquivos foram salvos
- Lista todos os arquivos baixados

---

## 🎬 **Exemplo de Execução:**

```
🚀 Extrator AppSettings - Profile: alm-yahoo-account
--------------------------------------------------
✅ Conectado à AWS
🔍 Buscando servidores Windows com 'SI2'...
📋 Encontradas 2 instâncias:
  - SI2-WEB-01 (i-1234567890abcdef0)
  - SI2-API-02 (i-0987654321fedcba0)
📁 Salvando em: backup_appsettings_20250815_143022

🔄 Processando: SI2-WEB-01
  ✅ SSM online
  🖥️  Hostname: SI2-WEB-01
  ✅ Extraído: appsettings.json
  ✅ Extraído: appsettings.SI2-WEB-01.json
  ✅ Concluído: 2 arquivos

🔄 Processando: SI2-API-02
  ✅ SSM online
  🖥️  Hostname: SI2-API-02
  ✅ Extraído: appsettings.json
  ❌ Não encontrado: appsettings.SI2-API-02.json
  ✅ Concluído: 1 arquivos

==================================================
📊 RESUMO:
  Instâncias encontradas: 2
  Instâncias com sucesso: 2
  Diretório de backup: backup_appsettings_20250815_143022
==================================================
🎉 Extração concluída com sucesso!

📁 Arquivos extraídos:
  SI2-WEB-01/appsettings.json
  SI2-WEB-01/appsettings.SI2-WEB-01.json
  SI2-API-02/appsettings.json
```

---

## 📂 **Resultado Final:**

```
backup_appsettings_20250815_143022/
├── SI2-WEB-01/
│   ├── appsettings.json
│   ├── appsettings.SI2-WEB-01.json
│   └── metadata.json
└── SI2-API-02/
    ├── appsettings.json
    └── metadata.json
```

---

## 🔑 **Pontos Importantes:**

1. **SSM é obrigatório** - sem ele, não consegue acessar o servidor
2. **Busca automática** - você não precisa saber os IPs dos servidores
3. **Seguro** - usa as credenciais AWS configuradas, não precisa de senhas
4. **Organizado** - cada servidor fica em sua própria pasta
5. **Robusto** - se um servidor falhar, continua com os outros

## 🎯 **Em resumo:**

O script é como um "aspirador de arquivos de configuração" que vai em todos os servidores Windows com "SI2" no nome e traz os arquivos `appsettings.json` para o seu computador de forma automática e organizada!
