#!/usr/bin/env python3
"""
Script super simples para extração rápida de appsettings.json
"""

import sys
import subprocess

def main():
    profile = sys.argv[1] if len(sys.argv) > 1 else 'default'
    
    print("🚀 Extrator Rápido AppSettings")
    print(f"Profile: {profile}")
    print()
    
    # Executar script simplificado
    try:
        subprocess.run([sys.executable, 'extract_simple.py', profile], check=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ Erro na execução: {e}")
        return 1
    except FileNotFoundError:
        print("❌ Arquivo extract_simple.py não encontrado")
        return 1
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
