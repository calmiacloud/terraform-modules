#!/usr/bin/env bash
set -euo pipefail

# Comprueba que se proporciona exactamente un argumento (ARN del pipeline)
if [ $# -ne 1 ]; then
  echo -e "\e[31m ==> ❌ Halted Script: Pipeline ARN not provided.\e[0m"
  exit 1
fi

PIPELINE_ARN="$1"

#!/bin/bash

DOMAIN=$1

echo "Zona creada: ${DOMAIN}"
echo "Servidores DNS asignados por Route53:"
dig +short NS "${DOMAIN}" || {
  echo "No se pudieron obtener los NS todavía."
}

echo "Esperando a que los servidores NS estén disponibles públicamente..."

for i in {1..30}; do
  dig +short NS "${DOMAIN}" | grep amazonaws.com && exit 0
  sleep 10
done

echo "Tiempo de espera agotado para la propagación de NS"
exit 1
