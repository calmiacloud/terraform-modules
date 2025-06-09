#!/bin/bash

RECORD_NAME=$1
RECORD_TYPE=$2
EXPECTED_VALUE=$3

if [[ -z "$RECORD_NAME" || -z "$RECORD_TYPE" || -z "$EXPECTED_VALUE" ]]; then
  echo -e "\e[31mERROR: Missing arguments.\e[0m"
  echo "Usage: ./wait_dns_record_google.sh <record_name> <record_type> <expected_value>"
  exit 1
fi

echo -e "\e[34m==> Checking DNS propagation for:\e[0m"
echo -e "\e[34m    Name: $RECORD_NAME\e[0m"
echo -e "\e[34m    Type: $RECORD_TYPE\e[0m"
echo -e "\e[34m    Expected value: \"$EXPECTED_VALUE\"\e[0m"

START_TIME=$(date +%s)

while :; do
  DIG_RAW=$(dig +short "$RECORD_NAME" "$RECORD_TYPE" @8.8.8.8)
  RECORDS=($(echo "$DIG_RAW" | sed 's/^"//;s/"$//' | tr -d '"' | sort))

  echo -e "\e[36m--> Values returned by Google DNS:\e[0m"
  if [[ ${#RECORDS[@]} -eq 0 ]]; then
    echo " (none)"
  else
    for val in "${RECORDS[@]}"; do echo " - $val"; done
  fi

  if printf '%s\n' "${RECORDS[@]}" | grep -Fxq "$EXPECTED_VALUE"; then
    echo -e "\e[32m ✅ Record propagated successfully!\e[0m"
    break
  else
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    printf -v ET "%02d:%02d:%02d" $((ELAPSED/3600)) $(((ELAPSED%3600)/60)) $((ELAPSED%60))
    echo -e "\e[33m ==> Waiting 30s... (elapsed: $ET)\e[0m"
    sleep 30
  fi

  if (( ELAPSED > 900 )); then
    echo -e "\e[31m ❌ Timeout: Record did not propagate after 15 minutes.\e[0m"
    exit 1
  fi
done

echo -e "\e[32m ==> All done!\e[0m"
