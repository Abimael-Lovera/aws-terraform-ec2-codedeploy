#!/bin/bash -e
# Executa comandos Terraform usando profile alm-yahoo-account
# Uso: ./terraform_apply_with_profile.sh [ACTION] [args adicionais]
# Exemplos:
#   ./terraform_apply_with_profile.sh plan
#   ./terraform_apply_with_profile.sh apply
#   ./terraform_apply_with_profile.sh destroy

PROFILE="alm-yahoo-account"
ACTION=${1:-plan}
shift || true

if ! command -v terraform >/dev/null 2>&1; then
  echo "[ERROR] Terraform não encontrado no PATH" >&2
  exit 1
fi

echo "[INFO] Usando AWS profile: $PROFILE"

case "$ACTION" in
  init)
    terraform init "$@" ;;
  plan)
    terraform plan -var="aws_profile=$PROFILE" "$@" ;;
  apply)
    terraform apply -var="aws_profile=$PROFILE" "$@" ;;
  destroy)
    terraform destroy -var="aws_profile=$PROFILE" "$@" ;;
  output)
    terraform output "$@" ;;
  *)
    echo "Uso: $0 {init|plan|apply|destroy|output} [args]" >&2
    echo "Exemplos:" >&2
    echo "  $0 plan" >&2
    echo "  $0 apply" >&2
    echo "  $0 destroy" >&2
    exit 1 ;;
 esac
