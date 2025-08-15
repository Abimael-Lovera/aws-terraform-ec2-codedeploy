#!/usr/bin/env python3
"""
Script Python para extrair arquivos appsettings.json de servidores Windows via SSM
Autor: AWS Terraform EC2 CodeDeploy Project
Data: 2025-08-15
"""

import boto3
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import argparse
import logging
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor, as_completed


@dataclass
class WindowsInstance:
    """Representa uma instância Windows"""
    instance_id: str
    name: str
    private_ip: str
    public_ip: str
    hostname: Optional[str] = None
    ssm_status: Optional[str] = None


class ColoredFormatter(logging.Formatter):
    """Formatter com cores para logging"""
    
    COLORS = {
        'DEBUG': '\033[36m',    # Cyan
        'INFO': '\033[34m',     # Blue
        'WARNING': '\033[33m',  # Yellow
        'ERROR': '\033[31m',    # Red
        'CRITICAL': '\033[35m', # Magenta
    }
    
    RESET = '\033[0m'
    
    def format(self, record):
        color = self.COLORS.get(record.levelname, self.RESET)
        record.levelname = f"{color}{record.levelname}{self.RESET}"
        return super().format(record)


class AppSettingsExtractor:
    """Extrator de arquivos appsettings.json via SSM"""
    
    def __init__(self, aws_profile: str = 'default', 
                 server_filter: str = 'SI2',
                 target_path: str = r'D:\Sites\Api',
                 concurrent_operations: int = 3):
        """
        Inicializa o extrator
        
        Args:
            aws_profile: Profile AWS a usar
            server_filter: Filtro para nome dos servidores
            target_path: Caminho no servidor Windows
            concurrent_operations: Número de operações simultâneas
        """
        self.aws_profile = aws_profile
        self.server_filter = server_filter
        self.target_path = target_path
        self.concurrent_operations = concurrent_operations
        
        # Configurar diretórios
        self.timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        self.backup_dir = Path(f'./config_backups_{self.timestamp}')
        self.log_dir = Path('./logs')
        
        # Criar diretórios
        self.backup_dir.mkdir(parents=True, exist_ok=True)
        self.log_dir.mkdir(exist_ok=True)
        
        # Configurar logging
        self._setup_logging()
        
        # Inicializar clientes AWS
        self._init_aws_clients()
        
        # Estatísticas
        self.stats = {
            'instances_found': 0,
            'instances_processed': 0,
            'instances_successful': 0,
            'files_extracted': 0,
            'errors': []
        }
    
    def _setup_logging(self):
        """Configura logging com cores e arquivo"""
        log_file = self.log_dir / f'extract_appsettings_{self.timestamp}.log'
        
        # Logger principal
        self.logger = logging.getLogger('AppSettingsExtractor')
        self.logger.setLevel(logging.INFO)
        
        # Handler para console com cores
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        console_formatter = ColoredFormatter(
            '[%(asctime)s] [%(levelname)s] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        console_handler.setFormatter(console_formatter)
        
        # Handler para arquivo
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(logging.DEBUG)
        file_formatter = logging.Formatter(
            '[%(asctime)s] [%(levelname)s] [%(funcName)s:%(lineno)d] %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        file_handler.setFormatter(file_formatter)
        
        # Adicionar handlers
        self.logger.addHandler(console_handler)
        self.logger.addHandler(file_handler)
        
        self.logger.info(f"Log salvo em: {log_file}")
    
    def _init_aws_clients(self):
        """Inicializa clientes AWS"""
        try:
            session = boto3.Session(profile_name=self.aws_profile)
            self.ec2_client = session.client('ec2')
            self.ssm_client = session.client('ssm')
            
            # Verificar credenciais
            sts_client = session.client('sts')
            identity = sts_client.get_caller_identity()
            self.logger.info(f"Usando AWS Account: {identity.get('Account')}")
            self.logger.info(f"Profile: {self.aws_profile}")
            
        except Exception as e:
            self.logger.error(f"Erro ao inicializar clientes AWS: {e}")
            sys.exit(1)
    
    def find_windows_instances(self) -> List[WindowsInstance]:
        """Busca instâncias Windows com filtro no nome"""
        self.logger.info(f"Buscando instâncias Windows com '{self.server_filter}' no nome...")
        
        try:
            response = self.ec2_client.describe_instances(
                Filters=[
                    {'Name': 'platform', 'Values': ['windows']},
                    {'Name': 'instance-state-name', 'Values': ['running']},
                    {'Name': f'tag:Name', 'Values': [f'*{self.server_filter}*']}
                ]
            )
            
            instances = []
            for reservation in response['Reservations']:
                for instance in reservation['Instances']:
                    # Extrair nome da tag
                    name = 'Unknown'
                    for tag in instance.get('Tags', []):
                        if tag['Key'] == 'Name':
                            name = tag['Value']
                            break
                    
                    instances.append(WindowsInstance(
                        instance_id=instance['InstanceId'],
                        name=name,
                        private_ip=instance.get('PrivateIpAddress', 'N/A'),
                        public_ip=instance.get('PublicIpAddress', 'N/A')
                    ))
            
            self.stats['instances_found'] = len(instances)
            self.logger.info(f"Encontradas {len(instances)} instâncias")
            
            for instance in instances:
                self.logger.info(f"  {instance.name} ({instance.instance_id}) - "
                               f"IP Privado: {instance.private_ip}")
            
            return instances
            
        except Exception as e:
            self.logger.error(f"Erro ao buscar instâncias: {e}")
            return []
    
    def check_ssm_status(self, instance: WindowsInstance) -> bool:
        """Verifica se SSM está ativo na instância"""
        try:
            response = self.ssm_client.describe_instance_information(
                InstanceInformationFilterList=[
                    {
                        'key': 'InstanceIds',
                        'valueSet': [instance.instance_id]
                    }
                ]
            )
            
            if response['InstanceInformationList']:
                status = response['InstanceInformationList'][0]['PingStatus']
                instance.ssm_status = status
                
                if status == 'Online':
                    self.logger.info(f"✅ SSM ativo para {instance.name}")
                    return True
                else:
                    self.logger.warning(f"⚠️ SSM não ativo para {instance.name} - Status: {status}")
                    return False
            else:
                self.logger.warning(f"⚠️ Instância {instance.name} não encontrada no SSM")
                instance.ssm_status = 'NotFound'
                return False
                
        except Exception as e:
            self.logger.error(f"Erro ao verificar SSM para {instance.name}: {e}")
            instance.ssm_status = 'Error'
            return False
    
    def execute_ssm_command(self, instance_id: str, commands: List[str], 
                           timeout: int = 30) -> Optional[str]:
        """Executa comando via SSM e retorna o resultado"""
        try:
            response = self.ssm_client.send_command(
                InstanceIds=[instance_id],
                DocumentName='AWS-RunPowerShellScript',
                Parameters={'commands': commands}
            )
            
            command_id = response['Command']['CommandId']
            
            # Aguardar execução
            time.sleep(3)
            
            # Tentar obter resultado com timeout
            start_time = time.time()
            while time.time() - start_time < timeout:
                try:
                    result = self.ssm_client.get_command_invocation(
                        CommandId=command_id,
                        InstanceId=instance_id
                    )
                    
                    status = result['Status']
                    if status == 'Success':
                        return result['StandardOutputContent']
                    elif status in ['Failed', 'Cancelled', 'TimedOut']:
                        self.logger.error(f"Comando falhou com status: {status}")
                        if result.get('StandardErrorContent'):
                            self.logger.error(f"Erro: {result['StandardErrorContent']}")
                        return None
                    else:
                        # Ainda executando, aguardar mais
                        time.sleep(2)
                        
                except self.ssm_client.exceptions.InvocationDoesNotExist:
                    time.sleep(2)
                    continue
            
            self.logger.warning(f"Timeout ao executar comando (>{timeout}s)")
            return None
            
        except Exception as e:
            self.logger.error(f"Erro ao executar comando SSM: {e}")
            return None
    
    def get_hostname(self, instance: WindowsInstance) -> str:
        """Obtém o hostname da instância"""
        self.logger.debug(f"Obtendo hostname de {instance.name}...")
        
        result = self.execute_ssm_command(
            instance.instance_id,
            ['$env:COMPUTERNAME']
        )
        
        if result:
            hostname = result.strip()
            instance.hostname = hostname
            self.logger.debug(f"Hostname: {hostname}")
            return hostname
        else:
            self.logger.warning(f"Não foi possível obter hostname de {instance.name}")
            instance.hostname = 'unknown'
            return 'unknown'
    
    def check_directory_exists(self, instance: WindowsInstance) -> bool:
        """Verifica se o diretório target existe"""
        self.logger.debug(f"Verificando diretório {self.target_path} em {instance.name}...")
        
        result = self.execute_ssm_command(
            instance.instance_id,
            [f"Test-Path '{self.target_path}'"]
        )
        
        if result and result.strip() == 'True':
            self.logger.debug(f"✅ Diretório encontrado em {instance.name}")
            return True
        else:
            self.logger.warning(f"❌ Diretório {self.target_path} não encontrado em {instance.name}")
            return False
    
    def extract_appsettings_files(self, instance: WindowsInstance) -> Dict[str, str]:
        """Extrai arquivos appsettings.json da instância"""
        self.logger.info(f"📁 Extraindo arquivos de {instance.name}...")
        
        files_content = {}
        
        # Lista de arquivos para extrair
        files_to_extract = [
            'appsettings.json',
            f'appsettings.{instance.hostname}.json'
        ]
        
        for filename in files_to_extract:
            file_path = f"{self.target_path}\\{filename}"
            
            self.logger.debug(f"Tentando extrair: {filename}")
            
            result = self.execute_ssm_command(
                instance.instance_id,
                [f"if (Test-Path '{file_path}') {{ Get-Content '{file_path}' -Raw }} else {{ 'FILE_NOT_FOUND' }}"],
                timeout=60
            )
            
            if result and result.strip() != 'FILE_NOT_FOUND':
                files_content[filename] = result
                self.logger.info(f"✅ Extraído: {filename}")
                self.stats['files_extracted'] += 1
            else:
                self.logger.warning(f"❌ Arquivo não encontrado: {filename}")
        
        return files_content
    
    def save_files(self, instance: WindowsInstance, files_content: Dict[str, str]) -> int:
        """Salva arquivos extraídos no sistema local"""
        if not files_content:
            return 0
        
        # Criar diretório para a instância
        instance_dir = self.backup_dir / instance.name
        instance_dir.mkdir(exist_ok=True)
        
        files_saved = 0
        
        for filename, content in files_content.items():
            try:
                file_path = instance_dir / filename
                file_path.write_text(content, encoding='utf-8')
                files_saved += 1
                self.logger.debug(f"💾 Salvo: {file_path}")
                
            except Exception as e:
                self.logger.error(f"Erro ao salvar {filename}: {e}")
                self.stats['errors'].append(f"Erro ao salvar {filename} de {instance.name}: {e}")
        
        # Criar arquivo de metadados
        metadata = {
            'instance_id': instance.instance_id,
            'instance_name': instance.name,
            'hostname': instance.hostname,
            'private_ip': instance.private_ip,
            'public_ip': instance.public_ip,
            'target_path': self.target_path,
            'extraction_date': datetime.now().isoformat(),
            'files_extracted': list(files_content.keys()),
            'files_count': len(files_content),
            'ssm_status': instance.ssm_status
        }
        
        metadata_path = instance_dir / 'metadata.json'
        metadata_path.write_text(json.dumps(metadata, indent=2), encoding='utf-8')
        
        self.logger.info(f"💾 Metadados salvos: {metadata_path}")
        
        return files_saved
    
    def process_instance(self, instance: WindowsInstance) -> bool:
        """Processa uma instância completa"""
        self.logger.info(f"🔄 Processando: {instance.name} ({instance.instance_id})")
        
        try:
            self.stats['instances_processed'] += 1
            
            # 1. Verificar SSM
            if not self.check_ssm_status(instance):
                return False
            
            # 2. Obter hostname
            self.get_hostname(instance)
            
            # 3. Verificar diretório
            if not self.check_directory_exists(instance):
                return False
            
            # 4. Extrair arquivos
            files_content = self.extract_appsettings_files(instance)
            
            if not files_content:
                self.logger.warning(f"Nenhum arquivo extraído de {instance.name}")
                return False
            
            # 5. Salvar arquivos
            files_saved = self.save_files(instance, files_content)
            
            if files_saved > 0:
                self.stats['instances_successful'] += 1
                self.logger.info(f"✅ Concluído: {instance.name} - {files_saved} arquivos salvos")
                return True
            else:
                self.logger.error(f"❌ Falha ao salvar arquivos de {instance.name}")
                return False
                
        except Exception as e:
            error_msg = f"Erro ao processar {instance.name}: {e}"
            self.logger.error(error_msg)
            self.stats['errors'].append(error_msg)
            return False
    
    def run(self) -> bool:
        """Executa o processo completo de extração"""
        self.logger.info("🚀 Iniciando extração de arquivos appsettings.json")
        self.logger.info(f"Profile AWS: {self.aws_profile}")
        self.logger.info(f"Filtro de servidor: {self.server_filter}")
        self.logger.info(f"Diretório de backup: {self.backup_dir}")
        self.logger.info(f"Operações simultâneas: {self.concurrent_operations}")
        
        # 1. Buscar instâncias
        instances = self.find_windows_instances()
        
        if not instances:
            self.logger.error("❌ Nenhuma instância encontrada")
            return False
        
        # 2. Processar instâncias (pode ser concorrente)
        if self.concurrent_operations > 1:
            self._process_instances_concurrent(instances)
        else:
            self._process_instances_sequential(instances)
        
        # 3. Relatório final
        self._generate_final_report()
        
        return self.stats['instances_successful'] > 0
    
    def _process_instances_sequential(self, instances: List[WindowsInstance]):
        """Processa instâncias sequencialmente"""
        self.logger.info("Processamento sequencial...")
        
        for i, instance in enumerate(instances, 1):
            self.logger.info(f"--- Instância {i}/{len(instances)} ---")
            self.process_instance(instance)
            print()  # Linha em branco para separar
    
    def _process_instances_concurrent(self, instances: List[WindowsInstance]):
        """Processa instâncias concorrentemente"""
        self.logger.info(f"Processamento concorrente ({self.concurrent_operations} threads)...")
        
        with ThreadPoolExecutor(max_workers=self.concurrent_operations) as executor:
            # Submeter tarefas
            future_to_instance = {
                executor.submit(self.process_instance, instance): instance 
                for instance in instances
            }
            
            # Aguardar conclusão
            for future in as_completed(future_to_instance):
                instance = future_to_instance[future]
                try:
                    success = future.result()
                    status = "✅ Sucesso" if success else "❌ Falha"
                    self.logger.info(f"{status}: {instance.name}")
                except Exception as e:
                    self.logger.error(f"❌ Exceção ao processar {instance.name}: {e}")
    
    def _generate_final_report(self):
        """Gera relatório final"""
        self.logger.info("=" * 50)
        self.logger.info("📊 RELATÓRIO FINAL")
        self.logger.info("=" * 50)
        self.logger.info(f"Instâncias encontradas: {self.stats['instances_found']}")
        self.logger.info(f"Instâncias processadas: {self.stats['instances_processed']}")
        self.logger.info(f"Instâncias com sucesso: {self.stats['instances_successful']}")
        self.logger.info(f"Total de arquivos extraídos: {self.stats['files_extracted']}")
        self.logger.info(f"Diretório de backup: {self.backup_dir}")
        
        if self.stats['errors']:
            self.logger.warning(f"Erros encontrados: {len(self.stats['errors'])}")
            for error in self.stats['errors']:
                self.logger.warning(f"  - {error}")
        
        # Listar arquivos extraídos
        if self.stats['instances_successful'] > 0:
            self.logger.info("\n📁 Arquivos extraídos:")
            json_files = list(self.backup_dir.rglob("*.json"))
            json_files = [f for f in json_files if f.name != 'metadata.json']
            
            for file_path in sorted(json_files):
                relative_path = file_path.relative_to(self.backup_dir)
                self.logger.info(f"  {relative_path}")
        
        # Taxa de sucesso
        success_rate = (self.stats['instances_successful'] / max(self.stats['instances_found'], 1)) * 100
        self.logger.info(f"\n🎯 Taxa de sucesso: {success_rate:.1f}%")
        
        if success_rate == 100:
            self.logger.info("🎉 Extração concluída com sucesso!")
        elif success_rate > 0:
            self.logger.warning("⚠️ Extração concluída com algumas falhas")
        else:
            self.logger.error("❌ Extração falhou completamente")


def main():
    """Função principal"""
    parser = argparse.ArgumentParser(
        description='Extrai arquivos appsettings.json de servidores Windows via SSM',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemplos de uso:
  %(prog)s --profile meu-profile
  %(prog)s --filter SI2 --target "D:\\Sites\\Api"
  %(prog)s --concurrent 5
  %(prog)s --profile meu-profile --filter WEB --target "C:\\Apps\\Config"
        """
    )
    
    parser.add_argument(
        '--profile', '-p',
        default='default',
        help='Profile AWS a usar (padrão: default)'
    )
    
    parser.add_argument(
        '--filter', '-f',
        default='SI2',
        help='Filtro para nome dos servidores (padrão: SI2)'
    )
    
    parser.add_argument(
        '--target', '-t',
        default=r'D:\Sites\Api',
        help=r'Caminho no servidor Windows (padrão: D:\Sites\Api)'
    )
    
    parser.add_argument(
        '--concurrent', '-c',
        type=int,
        default=3,
        help='Número de operações simultâneas (padrão: 3)'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='Logging detalhado (DEBUG)'
    )
    
    args = parser.parse_args()
    
    try:
        # Criar extrator
        extractor = AppSettingsExtractor(
            aws_profile=args.profile,
            server_filter=args.filter,
            target_path=args.target,
            concurrent_operations=args.concurrent
        )
        
        # Ajustar nível de log se verbose
        if args.verbose:
            extractor.logger.setLevel(logging.DEBUG)
            for handler in extractor.logger.handlers:
                handler.setLevel(logging.DEBUG)
        
        # Executar extração
        success = extractor.run()
        
        # Exit code
        sys.exit(0 if success else 1)
        
    except KeyboardInterrupt:
        print("\n❌ Operação cancelada pelo usuário")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Erro fatal: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
