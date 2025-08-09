#!/bin/bash -e
# Empacota a aplicação e scripts em um zip pronto para CodeDeploy

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
APP_DIR="$ROOT_DIR/app"
OUTPUT_ZIP=${1:-deployment.zip}

cd "$APP_DIR"
mvn -q -DskipTests package
cp -r ../scripts ./scripts
cp appspec.yml target/
cd target
zip -qr "$OUTPUT_ZIP" app-0.0.1-SNAPSHOT.jar ../scripts ../appspec.yml
mv "$OUTPUT_ZIP" "$ROOT_DIR/$OUTPUT_ZIP"

echo "[INFO] Arquivo criado em $ROOT_DIR/$OUTPUT_ZIP"
