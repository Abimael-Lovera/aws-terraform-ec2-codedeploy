#!/bin/bash -e
# Executa comandos Terraform usando profile AWS fixo (alm-yahoo-account)
# Uso: ./terraform_apply_with_profile.sh [plan|apply|destroy] [args adicionais]

PROFILE=alm-yahoo-account
ACTION=${1:-plan}
shift || true
TF_DIR="$(cd "$(dirname "$0")/../terraform" && pwd)"

if ! command -v terraform >/dev/null 2>&1; then
  echo "[ERROR] Terraform não encontrado no PATH" >&2
  exit 1
fi

export AWS_PROFILE=$PROFILE
export AWS_DEFAULT_REGION=us-east-1
cd "$TF_DIR"

case "$ACTION" in
  init)
    terraform init "$@" ;;
  plan)
    terraform plan "$@" ;;
  apply)
    terraform apply "$@" ;;
  destroy)
    terraform destroy "$@" ;;
  output)
    terraform output "$@" ;;
  *)
    echo "Uso: $0 {init|plan|apply|destroy|output} [args]" >&2
    exit 1 ;;
 esac
