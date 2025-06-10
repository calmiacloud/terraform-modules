#!/usr/bin/env bash
# comprueba_record_route53.sh
# Uso: ./comprueba_record_route53.sh <HOSTED_ZONE_ID> <RECORD_NAME> <RECORD_TYPE>
# Ejemplo: ./comprueba_record_route53.sh Z123ABCDEF example.com. A

set -euo pipefail

# Validar parámetros
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Uso: $0 <HOSTED_ZONE_ID> <RECORD_NAME> [RECORD_TYPE]"
  exit 1
fi

HOSTED_ZONE_ID="$1"
RECORD_NAME="$2"
RECORD_TYPE="${3:-A}"

# Comprobar si la zona DNS es privada
PRIVATE_ZONE=$(aws route53 get-hosted-zone \
  --id "$HOSTED_ZONE_ID" \
  --query 'HostedZone.Config.PrivateZone' \
  --output text)

if [[ "$ACTION" == "destroy" ]]; then
  echo "Acción 'destroy' detectada. Saliendo sin comprobar."
  exit 0
fi

if [[ "$PRIVATE_ZONE" == "true" ]]; then
  echo "La zona DNS '$HOSTED_ZONE_ID' es privada. Abortando comprobación."
  exit 1
fi

echo "Zona DNS pública. Continúo con la comprobación..."

# Configuración de reintentos
MAX_RETRIES=5
SLEEP_SECONDS=10

echo "Comprobando registro Route 53:"
echo "  Zona alojada: $HOSTED_ZONE_ID"
echo "  Nombre:       $RECORD_NAME"
echo "  Tipo:         $RECORD_TYPE"
echo

for ((i=1; i<=MAX_RETRIES; i++)); do
  echo "Intento $i de $MAX_RETRIES..."

  # Llamada a AWS CLI para test-dns-answer
  OUTPUT_JSON=$(aws route53 test-dns-answer \
    --hosted-zone-id "$HOSTED_ZONE_ID" \
    --record-name "$RECORD_NAME" \
    --record-type "$RECORD_TYPE")

  # Extraer valores con jq
  RESPONSE_CODE=$(echo "$OUTPUT_JSON" | jq -r '.ResponseCode')
  RECORD_DATA=$(echo "$OUTPUT_JSON" | jq -r '.RecordData | join(", ")')

  echo "  ResponseCode: $RESPONSE_CODE"
  echo "  RecordData:   $RECORD_DATA"

  # Verificar resolución correcta
  if [[ "$RESPONSE_CODE" == "NOERROR" && -n "$RECORD_DATA" ]]; then
    echo
    echo "Registro comprobado correctamente."
    exit 0
  fi

  # Esperar antes de reintentar si no es el último intento
  if (( i < MAX_RETRIES )); then
    echo "  Aún no resuelto, esperando $SLEEP_SECONDS segundos antes de reintentar..."
    sleep "$SLEEP_SECONDS"
  fi

done

echo
 echo "No se pudo comprobar el registro tras $MAX_RETRIES intentos." >&2
exit 1
