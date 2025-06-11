#!/bin/bash

ZONE_ID="$1"
RECORD_NAME="$2"
RECORD_TYPE="$3"

echo "Obteniendo información de la zona ${ZONE_ID}..."
ZONE_INFO=$(aws route53 get-hosted-zone --id "${ZONE_ID}")
IS_PRIVATE=$(echo "$ZONE_INFO" | jq -r '.HostedZone.Config.PrivateZone')
ZONE_NAME=$(echo "$ZONE_INFO" | jq -r '.HostedZone.Name')

if [ "$IS_PRIVATE" = "true" ]; then
  echo "Zona privada detectada (${ZONE_NAME}). No se realiza comprobación DNS."
  exit 0
fi

# Quitar punto final si existe
ZONE_NAME="${ZONE_NAME%.}"

# Asegura que RECORD_NAME no sea ya FQDN
if [[ "$RECORD_NAME" == *"." ]]; then
  FQDN="$RECORD_NAME"
else
  FQDN="${RECORD_NAME}.${ZONE_NAME}"
fi

echo "Zona pública detectada. Probando el registro DNS ${FQDN} (${RECORD_TYPE})..."
aws route53 test-dns-answer \
  --hosted-zone-id "${ZONE_ID}" \
  --record-name "${FQDN}" \
  --record-type "${RECORD_TYPE}"
