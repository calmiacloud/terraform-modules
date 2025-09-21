#!/usr/bin/env bash
set -euo pipefail

# Comprueba que se proporciona exactamente un argumento (ARN del pipeline)
if [ $# -ne 1 ]; then
  echo -e "\e[31m ==> ❌ Halted Script: Pipeline ARN not provided.\e[0m"
  exit 1
fi

PIPELINE_ARN="$1"

# 1️⃣ Obtener la versión actual del Image Builder
echo -e "\e[33m ==> Scanning Imagebuilder Pipeline Versions…\e[0m"
IMAGEBUILDER_VERSION_ARN=$(
  aws imagebuilder list-image-pipeline-images \
    --image-pipeline-arn "$PIPELINE_ARN" \
    --no-paginate \
    --query 'imageSummaryList[0].arn' \
    --output text
)

if [[ -n "$IMAGEBUILDER_VERSION_ARN" && "$IMAGEBUILDER_VERSION_ARN" != "None" ]]; then
  echo -e "\e[33m ==> Found Image Builder Version ARN: $IMAGEBUILDER_VERSION_ARN\e[0m"

  # 2️⃣ Obtener el AMI ID de esa versión
  AMI_ID=$(
    aws imagebuilder list-image-pipeline-images \
      --image-pipeline-arn "$PIPELINE_ARN" \
      --no-paginate \
      --query 'imageSummaryList[0].outputResources.amis[0].image' \
      --output text
  )
  if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
    echo -e "\e[31m ==> ❌ Halted Script: No AMI_ID found for version $IMAGEBUILDER_VERSION_ARN.\e[0m"
    exit 1
  fi
  echo -e "\e[33m ==> Discovered AMI_ID: $AMI_ID\e[0m"

  # 3️⃣ Escanear snapshot asociado al AMI
  echo -e "\e[33m ==> Scanning AMI Snapshot for $AMI_ID…\e[0m"
  SNAPSHOT_ID=$(
    aws ec2 describe-images \
      --image-ids "$AMI_ID" \
      --query 'Images[0].BlockDeviceMappings[].Ebs.SnapshotId' \
      --output text
  )
  if [[ -z "$SNAPSHOT_ID" || "$SNAPSHOT_ID" == "None" ]]; then
    echo -e "\e[31m ==> ❌ Halted Script: no snapshot found for AMI $AMI_ID.\e[0m"
    exit 1
  fi

  # 4️⃣ Deregistrar la AMI
  echo -e "\e[33m ==> Deregistering AMI $AMI_ID…\e[0m"
  aws ec2 deregister-image --image-id "$AMI_ID"
  echo -e "\e[32m ==> Deregistered AMI $AMI_ID.\e[0m"

  # 5️⃣ Eliminar el snapshot asociado
  echo -e "\e[33m ==> Removing AMI Snapshot $SNAPSHOT_ID…\e[0m"
  aws ec2 delete-snapshot --snapshot-id "$SNAPSHOT_ID"
  echo -e "\e[32m ==> Removed AMI Snapshot $SNAPSHOT_ID.\e[0m"

  # 6️⃣ Borrar la versión de Image Builder
  echo -e "\e[33m ==> Deleting Image Builder Version $IMAGEBUILDER_VERSION_ARN…\e[0m"
  aws imagebuilder delete-image --image-build-version-arn "$IMAGEBUILDER_VERSION_ARN"
  echo -e "\e[32m ==> Deleted Image Builder Version $IMAGEBUILDER_VERSION_ARN.\e[0m"

else
  echo -e "\e[33m ==> No existing Image Builder version found. Skipping cleanup.\e[0m"
fi