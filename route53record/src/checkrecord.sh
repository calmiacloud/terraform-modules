#!/bin/bash

#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

RECORD_NAME=${1:?Uso: $0 <nombre_registro> <tipo_registro> <valor_esperado_csv> <zona_id>}
RECORD_TYPE=$2
EXPECTED_CSV=$3
ZONE_ID=$4

# 🚫 Omitir si estamos en terraform destroy
if [[ "${TF_ACTION:-}" == "destroy" ]]; then
  echo -e "\e[33m[SKIP] Terraform destroy detectado. Omitiendo comprobación DNS.\e[0m"
  exit 0
fi

# 🚫 Omitir si la zona es privada
PRIVATE_ZONE=$(aws route53 get-hosted-zone --id "$ZONE_ID" \
  --query 'HostedZone.Config.PrivateZone' --output text)
if [[ "$PRIVATE_ZONE" == "true" ]]; then
  echo -e "\e[33m[SKIP] Zona $ZONE_ID es privada. Omitiendo comprobación DNS.\e[0m"
  exit 0
fi

# Para A, CNAME, etc.
IFS=',' read -ra EXPECTED_VALUES <<< "$EXPECTED_CSV"

echo -e "\e[34m==> Comprobando con AWS CLI (sin dig):\e[0m"
echo -e "    • Nombre: $RECORD_NAME"
echo -e "    • Tipo  : $RECORD_TYPE"
echo -e "    • Zona  : $ZONE_ID"
echo -e "    • Esperado completo:\e[0m"
echo "      $EXPECTED_CSV"

START_TIME=$(date +%s)
TIMEOUT=900   # 15 minutos
INTERVAL=10   # segundos entre intentos

while :; do
  # Llamada a Route 53
  RAW=$(aws route53 test-dns-answer \
    --hosted-zone-id "$ZONE_ID" \
    --record-name "$RECORD_NAME" \
    --record-type "$RECORD_TYPE" \
    --query 'ResourceRecords[].Value' \
    --output text)

  # Cada valor tabulado => salto de línea; quitamos comillas si las hubiera
  RECORDS=$(echo "$RAW" | tr '\t' '\n' | sed 's/^"//;s/"$//')

  echo -e "\e[36m--> AWS Route 53 devuelve:\e[0m"
  if [[ -z "$RECORDS" ]]; then
    echo "      (no existe todavía)"
  else
    echo "$RECORDS" | sed 's/^/      - /'
  fi

  if [[ "$RECORD_TYPE" == "TXT" ]]; then
    # Para TXT (DKIM): unimos fragmentos con espacios
    COMBINED=$(echo "$RECORDS" | paste -sd ' ')
    echo -e "\e[36m--> TXT combinado:\e[0m"
    echo "      - $COMBINED"

    if [[ "$COMBINED" == "$EXPECTED_CSV" ]]; then
      echo -e "\e[32m ✅ Registro TXT propagado en AWS correctamente!\e[0m"
      exit 0
    fi

  else
    # Para A, CNAME, etc.: comprobación de cada valor
    mapfile -t ACTUAL <<< "$RECORDS"
    ALL_OK=true
    for want in "${EXPECTED_VALUES[@]}"; do
      if ! printf '%s\n' "${ACTUAL[@]}" | grep -Fxq "$want"; then
        ALL_OK=false
        break
      fi
    done

    if $ALL_OK; then
      echo -e "\e[32m ✅ Registro $RECORD_TYPE detectado en AWS correctamente!\e[0m"
      exit 0
    fi
  fi

  # Timeout y espera
  NOW=$(date +%s)
  ELAPSED=$((NOW - START_TIME))
  if (( ELAPSED > TIMEOUT )); then
    echo -e "\e[31m ❌ Timeout: AWS no devuelve el registro tras $((TIMEOUT/60)) minutos.\e[0m"
    exit 1
  fi

  printf -v H "%02d" $((ELAPSED/3600))
  printf -v M "%02d" $(((ELAPSED%3600)/60))
  printf -v S "%02d" $((ELAPSED%60))
  echo -e "\e[33m ==> Esperando $INTERVAL s… (transcurrido: $H:$M:$S)\e[0m"
  sleep "$INTERVAL"
done
