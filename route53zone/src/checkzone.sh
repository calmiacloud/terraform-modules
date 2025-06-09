#!/bin/bash

ZONE_ID=$1

if [[ -z "$ZONE_ID" ]]; then
  echo -e "\e[31mERROR: Route 53 Zone ID was not provided.\e[0m"
  echo "Usage: ./wait_ns_google.sh <zone_id>"
  exit 1
fi

# Check if zone exists — if not, assume we're in destroy
if ! aws route53 get-hosted-zone --id "$ZONE_ID" > /dev/null 2>&1; then
  echo -e "\e[33m[SKIP] Zone $ZONE_ID not found. Skipping check (likely destroy).\e[0m"
  exit 0
fi

ZONE_INFO=$(aws route53 get-hosted-zone --id "$ZONE_ID")
IS_PRIVATE=$(echo "$ZONE_INFO" | jq -r '.HostedZone.Config.PrivateZone')

if [[ "$IS_PRIVATE" == "true" ]]; then
  echo -e "\e[34m==> Zone is private. NS propagation check is not applicable.\e[0m"
  exit 0
fi

DOMAIN=$(echo "$ZONE_INFO" | jq -r '.HostedZone.Name' | sed 's/\.$//')
NS_ROUTE53=($(echo "$ZONE_INFO" | jq -r '.DelegationSet.NameServers[]' | sort))

echo -e "\e[34m==> Domain: $DOMAIN\e[0m"
echo -e "\e[34m==> Expected NS (from Route 53):\e[0m"
for ns in "${NS_ROUTE53[@]}"; do echo " - $ns"; done
echo ""

echo -e "\e[34m==> Checking propagation in Google DNS (8.8.8.8)...\e[0m"
START_TIME=$(date +%s)

while :; do
  NS_GOOGLE=($(dig +short @8.8.8.8 NS "$DOMAIN" | sort))

  if [[ ${#NS_GOOGLE[@]} -eq 0 ]]; then
    STATUS="NO_RESPONSE"
  elif diff <(printf "%s\n" "${NS_ROUTE53[@]}") <(printf "%s\n" "${NS_GOOGLE[@]}") > /dev/null; then
    STATUS="PROPAGATED"
  else
    STATUS="MISMATCH"
  fi

  echo -e "\e[33m ==> Status: $STATUS\e[0m"

  case "$STATUS" in
    PROPAGATED)
      echo -e "\e[32m ==> ✅ NS propagated successfully on Google DNS.\e[0m"
      break
      ;;
    MISMATCH | NO_RESPONSE)
      NOW=$(date +%s)
      ELAPSED=$((NOW - START_TIME))
      printf -v ET "%02d:%02d:%02d" $((ELAPSED/3600)) $(((ELAPSED%3600)/60)) $((ELAPSED%60))
      echo -e "\e[33m ==> Waiting 30s... (elapsed: $ET)\e[0m"
      sleep 30
      ;;
  esac

  if (( ELAPSED > 900 )); then
    echo -e "\e[31m ❌ Timeout: NS records did not propagate after 15 minutes.\e[0m"
    exit 1
  fi
done

echo -e "\e[32m ==> All done!\e[0m"
