#!/bin/bash

ZONE_ID="$1"
RECORD_NAME="$2"
RECORD_TYPE="$3"

echo -e "\e[34m🔍 Retrieving information for hosted zone ${ZONE_ID}...\e[0m"
ZONE_INFO=$(aws route53 get-hosted-zone --id "${ZONE_ID}")
IS_PRIVATE=$(echo "$ZONE_INFO" | jq -r '.HostedZone.Config.PrivateZone')
ZONE_NAME=$(echo "$ZONE_INFO" | jq -r '.HostedZone.Name')
FQDN="${RECORD_NAME}.${ZONE_NAME%.}"

if [ "$IS_PRIVATE" = "true" ]; then
  echo -e "\e[36mℹ️  Private zone detected (${ZONE_NAME}). DNS check will be skipped.\e[0m"
  exit 0
fi

echo -e "\e[34m⏱️  Waiting for DNS record ${FQDN} (${RECORD_TYPE}) to become available...\e[0m"

START_TIME=$(date +%s)
while :; do
  RESP_CODE=$(aws route53 test-dns-answer \
    --hosted-zone-id "${ZONE_ID}" \
    --record-name "${FQDN}" \
    --record-type "${RECORD_TYPE}" \
    | jq -r '.ResponseCode')

  echo -e "\e[33m ==> DNS status: $RESP_CODE\e[0m"

  case "$RESP_CODE" in
    NOERROR)
      echo -e "\e[32m ==> ✔️ DNS is available.\e[0m"
      break
      ;;
    NXDOMAIN|SERVFAIL|FORMERR|REFUSED)
      echo -e "\e[31m ==> ❌ DNS failed with code: $RESP_CODE\e[0m"
      exit 1
      ;;
    *)
      NOW=$(date +%s)
      ELAPSED=$((NOW - START_TIME))
      printf -v ET "%02d:%02d:%02d" \
        $((ELAPSED/3600)) \
        $(((ELAPSED%3600)/60)) \
        $((ELAPSED%60))
      echo -e "\e[33m ==> Waiting another 30s... (elapsed: $ET)\e[0m"
      sleep 30
      ;;
  esac
done

echo -e "\e[32m ==> 🎉 DNS check completed successfully.\e[0m"