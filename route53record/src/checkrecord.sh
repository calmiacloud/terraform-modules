#!/bin/bash

RECORD_NAME=$1
RECORD_TYPE=$2
EXPECTED_CSV=$3
ZONE_ID=$4

if [[ -z "$RECORD_NAME" || -z "$RECORD_TYPE" || -z "$EXPECTED_CSV" || -z "$ZONE_ID" ]]; then
  echo -e "\e[31mERROR: Faltan argumentos.\e[0m"
  echo "Uso: $0 <record_name> <record_type> <expected_value_csv> <zone_id>"
  exit 1
fi

# 🚫 Omitir si estamos en terraform destroy
if [[ "$TF_ACTION" == "destroy" ]]; then
  echo -e "\e[33m[SKIP] Terraform destroy detectado. Se omite comprobación DNS.\e[0m"
  exit 0
fi

# 🚫 Omitir si la zona es privada
IS_PRIVATE=$(aws route53 get-hosted-zone --id "$ZONE_ID" | jq -r '.HostedZone.Config.PrivateZone')
if [[ "$IS_PRIVATE" == "true" ]]; then
  echo -e "\e[33m[SKIP] Zona $ZONE_ID es privada. Se omite comprobación DNS.\e[0m"
  exit 0
fi

# Para REGISTROS NO-TXT, preparamos array de valores esperados
IFS=',' read -ra EXPECTED_VALUES <<< "$EXPECTED_CSV"

echo -e "\e[34m==> Comprobando propagación DNS:\e[0m"
echo -e "\e[34m    Name : $RECORD_NAME"
echo -e "\e[34m    Type : $RECORD_TYPE"
echo -e "\e[34m    Zone : $ZONE_ID"
echo -e "\e[34m    Expected values:\e[0m"
for val in "${EXPECTED_VALUES[@]}"; do echo " - $val"; done

START_TIME=$(date +%s)

while :; do
  # Consulta a Google DNS
  DIG_RAW=$(dig +short "$RECORD_NAME" "$RECORD_TYPE" @8.8.8.8)

  echo -e "\e[36m--> Valores devueltos por Google DNS:\e[0m"
  if [[ -z "$DIG_RAW" ]]; then
    echo " (ninguno)"
  else
    echo "$DIG_RAW" | sed 's/^"//;s/"$//' | while read -r line; do
      echo " - $line"
    done
  fi

  if [[ "$RECORD_TYPE" == "TXT" ]]; then
    # Lógica especial para TXT (DKIM): unimos fragmentos con espacios
    RECORD_COMBINED=$(echo "$DIG_RAW" | sed 's/^"//;s/"$//' | paste -sd ' ' -)
    echo -e "\e[36m--> Valor TXT combinado:\e[0m"
    echo " - $RECORD_COMBINED"

    if [[ "$RECORD_COMBINED" == "$EXPECTED_CSV" ]]; then
      echo -e "\e[32m ✅ Registro TXT (DKIM) propagado correctamente!\e[0m"
      break
    fi
  else
    # Lógica general para A, CNAME, etc.
    RECORDS=($(echo "$DIG_RAW" | sed 's/^"//;s/"$//' | sort))
    ALL_FOUND=true
    for expected in "${EXPECTED_VALUES[@]}"; do
      if ! printf '%s\n' "${RECORDS[@]}" | grep -Fxq "$expected"; then
        ALL_FOUND=false
        break
      fi
    done

    if [[ "$ALL_FOUND" == true ]]; then
      echo -e "\e[32m ✅ Registro propagado correctamente!\e[0m"
      break
    fi
  fi

  # Esperamos y comprobamos timeout
  NOW=$(date +%s)
  ELAPSED=$((NOW - START_TIME))
  printf -v ET "%02d:%02d:%02d" $((ELAPSED/3600)) $(((ELAPSED%3600)/60)) $((ELAPSED%60))
  echo -e "\e[33m ==> Esperando 30s... (tiempo transcurrido: $ET)\e[0m"
  sleep 30

  if (( ELAPSED > 900 )); then
    echo -e "\e[31m ❌ Timeout: no se detectó propagación tras 15 minutos.\e[0m"
    exit 1
  fi
done

echo -e "\e[32m ==> ¡Todo listo!\e[0m"
