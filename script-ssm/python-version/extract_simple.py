#!/usr/bin/env python3
"""
Script simples para extrair appsettings.json de servidores Windows via SSM
"""

import boto3
import json
import time
import sys
from datetime import datetime
from pathlib import Path

def main():
    # Configurações básicas
    if len(sys.argv) < 2:
        print("Uso: python extract_simple.py <aws_profile>")
        print("Exemplo: python extract_simple.py meu-profile")
        sys.exit(1)
    
    aws_profile = sys.argv[1]
    server_filter = "SI2"
    target_path = r"D:\Sites\Api"
    
    print(f"🚀 Extrator AppSettings - Profile: {aws_profile}")
    print("-" * 50)
    
    # Inicializar clientes AWS
    try:
        session = boto3.Session(profile_name=aws_profile)
        ec2 = session.client('ec2')
        ssm = session.client('ssm')
        print("✅ Conectado à AWS")
    except Exception as e:
        print(f"❌ Erro ao conectar AWS: {e}")
        sys.exit(1)
    
    # Buscar instâncias Windows
    print(f"🔍 Buscando servidores Windows com '{server_filter}'...")
    try:
        response = ec2.describe_instances(
            Filters=[
                {'Name': 'platform', 'Values': ['windows']},
                {'Name': 'instance-state-name', 'Values': ['running']},
                {'Name': 'tag:Name', 'Values': [f'*{server_filter}*']}
            ]
        )
        
        instances = []
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                name = 'Unknown'
                for tag in instance.get('Tags', []):
                    if tag['Key'] == 'Name':
                        name = tag['Value']
                        break
                
                instances.append({
                    'id': instance['InstanceId'],
                    'name': name,
                    'ip': instance.get('PrivateIpAddress', 'N/A')
                })
        
        print(f"📋 Encontradas {len(instances)} instâncias:")
        for inst in instances:
            print(f"  - {inst['name']} ({inst['id']})")
        
    except Exception as e:
        print(f"❌ Erro ao buscar instâncias: {e}")
        sys.exit(1)
    
    if not instances:
        print("❌ Nenhuma instância encontrada")
        sys.exit(1)
    
    # Criar diretório de backup
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_dir = Path(f'backup_appsettings_{timestamp}')
    backup_dir.mkdir(exist_ok=True)
    print(f"📁 Salvando em: {backup_dir}")
    
    # Processar cada instância
    success_count = 0
    for inst in instances:
        print(f"\n🔄 Processando: {inst['name']}")
        
        # Verificar SSM
        try:
            ssm_response = ssm.describe_instance_information(
                InstanceInformationFilterList=[
                    {'key': 'InstanceIds', 'valueSet': [inst['id']]}
                ]
            )
            
            if not ssm_response['InstanceInformationList']:
                print(f"  ❌ SSM não disponível")
                continue
                
            ssm_status = ssm_response['InstanceInformationList'][0]['PingStatus']
            if ssm_status != 'Online':
                print(f"  ❌ SSM offline: {ssm_status}")
                continue
                
            print(f"  ✅ SSM online")
            
        except Exception as e:
            print(f"  ❌ Erro SSM: {e}")
            continue
        
        # Obter hostname
        try:
            cmd_response = ssm.send_command(
                InstanceIds=[inst['id']],
                DocumentName='AWS-RunPowerShellScript',
                Parameters={'commands': ['$env:COMPUTERNAME']}
            )
            
            time.sleep(3)
            
            result = ssm.get_command_invocation(
                CommandId=cmd_response['Command']['CommandId'],
                InstanceId=inst['id']
            )
            
            hostname = result['StandardOutputContent'].strip()
            print(f"  🖥️  Hostname: {hostname}")
            
        except Exception as e:
            print(f"  ⚠️  Erro ao obter hostname: {e}")
            hostname = inst['name']
        
        # Extrair arquivos
        files_extracted = 0
        inst_dir = backup_dir / inst['name']
        inst_dir.mkdir(exist_ok=True)
        
        # Lista de arquivos para extrair
        files_to_extract = [
            'appsettings.json',
            f'appsettings.{hostname}.json'
        ]
        
        for filename in files_to_extract:
            try:
                file_path = f"{target_path}\\{filename}"
                
                # Comando para ler arquivo
                cmd_response = ssm.send_command(
                    InstanceIds=[inst['id']],
                    DocumentName='AWS-RunPowerShellScript',
                    Parameters={
                        'commands': [f"if (Test-Path '{file_path}') {{ Get-Content '{file_path}' -Raw }} else {{ 'FILE_NOT_FOUND' }}"]
                    }
                )
                
                time.sleep(5)
                
                result = ssm.get_command_invocation(
                    CommandId=cmd_response['Command']['CommandId'],
                    InstanceId=inst['id']
                )
                
                content = result['StandardOutputContent']
                
                if content.strip() != 'FILE_NOT_FOUND' and content.strip():
                    # Salvar arquivo
                    local_file = inst_dir / filename
                    local_file.write_text(content, encoding='utf-8')
                    print(f"  ✅ Extraído: {filename}")
                    files_extracted += 1
                else:
                    print(f"  ❌ Não encontrado: {filename}")
                    
            except Exception as e:
                print(f"  ❌ Erro ao extrair {filename}: {e}")
        
        # Salvar metadados
        metadata = {
            'instance_id': inst['id'],
            'instance_name': inst['name'],
            'hostname': hostname,
            'ip': inst['ip'],
            'extraction_date': datetime.now().isoformat(),
            'files_extracted': files_extracted
        }
        
        metadata_file = inst_dir / 'metadata.json'
        metadata_file.write_text(json.dumps(metadata, indent=2), encoding='utf-8')
        
        if files_extracted > 0:
            success_count += 1
            print(f"  ✅ Concluído: {files_extracted} arquivos")
        else:
            print(f"  ❌ Nenhum arquivo extraído")
    
    # Resumo final
    print(f"\n{'='*50}")
    print(f"📊 RESUMO:")
    print(f"  Instâncias encontradas: {len(instances)}")
    print(f"  Instâncias com sucesso: {success_count}")
    print(f"  Diretório de backup: {backup_dir}")
    print(f"{'='*50}")
    
    if success_count > 0:
        print("🎉 Extração concluída com sucesso!")
        
        # Listar arquivos extraídos
        json_files = list(backup_dir.rglob("*.json"))
        json_files = [f for f in json_files if f.name != 'metadata.json']
        
        if json_files:
            print("\n📁 Arquivos extraídos:")
            for file_path in sorted(json_files):
                relative_path = file_path.relative_to(backup_dir)
                print(f"  {relative_path}")
    else:
        print("❌ Nenhum arquivo foi extraído")

if __name__ == '__main__':
    main()
