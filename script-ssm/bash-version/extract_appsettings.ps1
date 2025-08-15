# Script PowerShell para ser executado via SSM nos servidores Windows
# Busca e extrai arquivos appsettings.json específicos

param(
    [string]$TargetPath = "D:\Sites\Api",
    [string]$OutputBucket = "",
    [string]$LocalTempPath = "C:\temp\appsettings_backup"
)

# Função para logging
function Write-LogMessage {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] [$Level] $Message"
}

try {
    $hostname = $env:COMPUTERNAME
    Write-LogMessage "Iniciando extração em servidor: $hostname"
    
    # Verificar se o diretório existe
    if (-not (Test-Path $TargetPath)) {
        Write-LogMessage "Diretório não encontrado: $TargetPath" "ERROR"
        exit 1
    }
    
    Write-LogMessage "Diretório encontrado: $TargetPath"
    
    # Criar diretório temporário
    if (-not (Test-Path $LocalTempPath)) {
        New-Item -Path $LocalTempPath -ItemType Directory -Force | Out-Null
    }
    
    # Buscar arquivos appsettings
    $appsettingsFiles = @()
    
    # appsettings.json principal
    $mainSettings = Join-Path $TargetPath "appsettings.json"
    if (Test-Path $mainSettings) {
        $appsettingsFiles += $mainSettings
        Write-LogMessage "Encontrado: appsettings.json"
    }
    
    # appsettings.<hostname>.json
    $hostnameSettings = Join-Path $TargetPath "appsettings.$hostname.json"
    if (Test-Path $hostnameSettings) {
        $appsettingsFiles += $hostnameSettings
        Write-LogMessage "Encontrado: appsettings.$hostname.json"
    }
    
    # Buscar outros arquivos appsettings (appsettings.*.json)
    $otherSettings = Get-ChildItem -Path $TargetPath -Filter "appsettings.*.json" | Where-Object { 
        $_.Name -ne "appsettings.$hostname.json" 
    }
    
    foreach ($file in $otherSettings) {
        $appsettingsFiles += $file.FullName
        Write-LogMessage "Encontrado: $($file.Name)"
    }
    
    if ($appsettingsFiles.Count -eq 0) {
        Write-LogMessage "Nenhum arquivo appsettings.json encontrado" "WARNING"
        exit 0
    }
    
    # Copiar arquivos para diretório temporário
    $backupDir = Join-Path $LocalTempPath $hostname
    if (-not (Test-Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }
    
    $copiedFiles = @()
    foreach ($file in $appsettingsFiles) {
        $fileName = Split-Path $file -Leaf
        $destPath = Join-Path $backupDir $fileName
        
        try {
            Copy-Item -Path $file -Destination $destPath -Force
            $copiedFiles += $destPath
            Write-LogMessage "Copiado: $fileName para $destPath"
            
            # Mostrar conteúdo do arquivo (primeiras linhas para verificação)
            Write-LogMessage "Conteúdo de $fileName (primeiras 5 linhas):"
            Get-Content $file -TotalCount 5 | ForEach-Object { Write-LogMessage "  $_" }
            
        } catch {
            Write-LogMessage "Erro ao copiar $fileName`: $($_.Exception.Message)" "ERROR"
        }
    }
    
    # Criar arquivo de metadados
    $metadataFile = Join-Path $backupDir "metadata.json"
    $metadata = @{
        hostname = $hostname
        extractionDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        targetPath = $TargetPath
        filesFound = $appsettingsFiles.Count
        filesCopied = $copiedFiles.Count
        files = @()
    }
    
    foreach ($file in $appsettingsFiles) {
        $fileInfo = Get-Item $file
        $metadata.files += @{
            name = $fileInfo.Name
            fullPath = $fileInfo.FullName
            size = $fileInfo.Length
            lastModified = $fileInfo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    $metadata | ConvertTo-Json -Depth 3 | Out-File -FilePath $metadataFile -Encoding UTF8
    
    Write-LogMessage "Metadados salvos em: $metadataFile"
    Write-LogMessage "Total de arquivos processados: $($copiedFiles.Count)"
    
    # Listar todos os arquivos criados
    Write-LogMessage "Arquivos no diretório de backup:"
    Get-ChildItem $backupDir | ForEach-Object {
        Write-LogMessage "  $($_.Name) - $($_.Length) bytes"
    }
    
    Write-LogMessage "Extração concluída com sucesso para servidor: $hostname"
    
} catch {
    Write-LogMessage "Erro durante a extração: $($_.Exception.Message)" "ERROR"
    Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" "ERROR"
    exit 1
}
