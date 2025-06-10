#!/bin/bash
set -euo pipefail

# Parámetros
HOSTED_ZONE_ID="$1"
RECORD_NAME="$2"
RECORD_TYPE="${3:-A}"

# Número máximo de intentos y retardo entre ellos (segundos)
MAX_RETRIES=5
SLEEP_SECONDS=10

echo "Comprobando registro Route 53:"
echo "  Zona alojada: $HOSTED_ZONE_ID"
echo "  Nombre:       $RECORD_NAME"
echo "  Tipo:         $RECORD_TYPE"
echo

for ((i=1; i<=MAX_RETRIES; i++)); do
  echo "Intento $i de $MAX_RETRIES..."

  # Llamada a AWS CLI
  OUTPUT_JSON=$(aws route53 test-dns-answer \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --record-name "$RECORD_NAME" \
    --record-type "$RECORD_TYPE")

  # Extraer valores con jq
  RESPONSE_CODE=$(echo "$OUTPUT_JSON" | jq -r '.ResponseCode')
  RECORD_DATA=$(echo "$OUTPUT_JSON" | jq -r '.RecordData | join(", ")')

  echo "  ResponseCode: $RESPONSE_CODE"
  echo "  RecordData:   $RECORD_DATA"

  # Comprobamos si está resuelto correctamente
  if [[ "$RESPONSE_CODE" == "NOERROR" && -n "$RECORD_DATA" ]]; then
    echo -e "\nRegistro comprobado correctamente."
    exit 0
  fi

  # Si no hemos llegado al máximo, esperamos y repetimos
  if (( i < MAX_RETRIES )); then
    echo "  Aún no resuelto, esperando $SLEEP_SECONDS s antes de reintentar..."
    sleep "$SLEEP_SECONDS"
  fi
done

echo -e "\nNo se pudo comprobar el registro tras $MAX_RETRIES intentos." >&2
exit 1
