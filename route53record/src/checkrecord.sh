#!/bin/bash

RECORD_NAME=$1
RECORD_TYPE=$2
EXPECTED_CSV=$3
ZONE_ID=$4

if [[ -z "$RECORD_NAME" || -z "$RECORD_TYPE" || -z "$EXPECTED_CSV" || -z "$ZONE_ID" ]]; then
  echo -e "\e[31mERROR: Missing arguments.\e[0m"
  echo "Usage: ./wait_dns_record_google.sh <record_name> <record_type> <expected_value_csv> <zone_id>"
  exit 1
fi

# 🚫 Omitir si estamos en terraform destroy
if [[ "$TF_ACTION" == "destroy" ]]; then
  echo -e "\e[33m[SKIP] Terraform destroy detected. Skipping DNS check.\e[0m"
  exit 0
fi

# 🚫 Omitir si la zona es privada
IS_PRIVATE=$(aws route53 get-hosted-zone --id "$ZONE_ID" | jq -r '.HostedZone.Config.PrivateZone')

if [[ "$IS_PRIVATE" == "true" ]]; then
  echo -e "\e[33m[SKIP] Zone $ZONE_ID is private. Skipping DNS check.\e[0m"
  exit 0
fi

IFS=',' read -ra EXPECTED_VALUES <<< "$EXPECTED_CSV"

echo -e "\e[34m==> Checking DNS propagation for:\e[0m"
echo -e "\e[34m    Name : $RECORD_NAME"
echo -e "\e[34m    Type : $RECORD_TYPE"
echo -e "\e[34m    Zone : $ZONE_ID"
echo -e "\e[34m    Expected values:\e[0m"
for val in "${EXPECTED_VALUES[@]}"; do echo " - $val"; done

START_TIME=$(date +%s)

while :; do
  DIG_RAW=$(dig +short "$RECORD_NAME" "$RECORD_TYPE" @8.8.8.8)
  RECORDS=($(echo "$DIG_RAW" | sed 's/^"//;s/"$//' | tr -d '"' | sort))

  echo -e "\e[36m--> Values returned by Google DNS:\e[0m"
  if [[ ${#RECORDS[@]} -eq 0 ]]; then
    echo " (none)"
  else
    for rec in "${RECORDS[@]}"; do echo " - $rec"; done
  fi

  ALL_FOUND=true
  for expected in "${EXPECTED_VALUES[@]}"; do
    if ! printf '%s\n' "${RECORDS[@]}" | grep -Fxq "$expected"; then
      ALL_FOUND=false
      break
    fi
  done

  if [[ "$ALL_FOUND" == true ]]; then
    echo -e "\e[32m ✅ All expected values found. Propagation complete!\e[0m"
    break
  fi

  NOW=$(date +%s)
  ELAPSED=$((NOW - START_TIME))
  printf -v ET "%02d:%02d:%02d" $((ELAPSED/3600)) $(((ELAPSED%3600)/60)) $((ELAPSED%60))
  echo -e "\e[33m ==> Waiting 30s... (elapsed: $ET)\e[0m"
  sleep 30

  if (( ELAPSED > 900 )); then
    echo -e "\e[31m ❌ Timeout: Record did not propagate after 15 minutes.\e[0m"
    exit 1
  fi
done

echo -e "\e[32m ==> All done!\e[0m"
