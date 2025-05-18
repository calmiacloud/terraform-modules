#!/usr/bin/env bash

set -euo pipefail

if [ $# -ne 1 ]; then
  echo -e "\e[31m ==> ❌ Halted Script, Pipeline ARN not found.\e[0m"
  exit 1
fi

PIPELINE_ARN="$1"

# Get Pipeline versions

echo -e "\e[33m ==> Scanning Imagebuilder Pipeline Version...\e[0m"

IMAGEBUILDER_VERSION_ARN=$(
  aws imagebuilder list-image-pipeline-images \
    --image-pipeline-arn "$PIPELINE_ARN" \
    --no-paginate \
    --query 'imageSummaryList[0].arn' \
    --output text)

# Pipeline version found

if [ -n "$IMAGEBUILDER_VERSION_ARN" ] || [ "$IMAGEBUILDER_VERSION_ARN" != "None" ]; then

  echo -e "\e[33m ==> Pipeline Version found, ARN: $IMAGEBUILDER_VERSION_ARN\e[0m"

 echo -e "\e[33m ==> Scanning Ami Snapshot...\e[0m"

  SNAPSHOT_ID=$(aws ec2 describe-images \
    --image-ids "$AMI_ID" \
    --query 'Images[].BlockDeviceMappings[].Ebs.SnapshotId' \
    --output text)

  if [ -z "$SNAPSHOT_ID" ] || [ "$SNAPSHOT_ID" = "None" ]; then
    echo -e "\e[31m==> ❌ Halted Script, no snapshot found related to AMI $AMI_ID.\e[0m"
    exit 1
  fi

  echo -e "\e[33m ==> Removing Ami Snapshot $SNAPSHOT_ID...\e[0m"
  aws ec2 delete-snapshot --snapshot-id "$SNAPSHOT_ID"
  echo -e "\e[33m ==> Removed Ami Snapshot $SNAPSHOT_ID...\e[0m"

  AMI_ID=$(
  aws imagebuilder list-image-pipeline-images \
    --image-pipeline-arn "$PIPELINE_ARN" \
    --no-paginate \
    --query 'imageSummaryList[0].outputResources.amis[0].image' \
    --output text)

  echo -e "\e[33m ==> Deregistering AMI: $AMI_ID\e[0m"
  aws ec2 deregister-image --image-id "$AMI_ID"
  echo -e "\e[33m ==> Deregistered AMI: $AMI_ID\e[0m"

  echo -e "\e[33m ==> Removing image Builder Version  $IMAGEBUILDER_VERSION_ARN...\e[0m"
  aws imagebuilder delete-image --image-build-version-arn "$IMAGEBUILDER_VERSION_ARN"
  echo -e "\e[33m ==> Removed image Builder Version  $IMAGEBUILDER_VERSION_ARN...\e[0m"

else
  echo -e "\e[33m ==> No Image Builder Version...\e[0m"
fi

echo ""
echo -e "\e[33m ==> Starting Image Builder Pipeline...\e[0m"
PIPELINE=$(aws imagebuilder start-image-pipeline-execution \
  --image-pipeline-arn "$PIPELINE_ARN" \
  --query 'imageBuildVersionArn' \
  --output text) || exit 1

echo -e "\e[33m ==> Pipeline started: $PIPELINE\e[0m"

while true; do
  STATUS=$(aws imagebuilder get-image \
    --image-build-version-arn "$PIPELINE" \
    --query 'image.state.status' \
    --output text)

  echo -e "\e[33m ==> Pipeline status: $STATUS\e[0m"

  case "$STATUS" in
    "AVAILABLE")
      echo -e "\e[32m ==> ✔️ Build completed.\e[0m"
      break
      ;;
    "FAILED")
      echo -e "\e[31m ==> ❌ Build failed.\e[0m"
      exit 1
      ;;
    *)
      echo -e "\e[33m ==> Waiting 30s...\e[0m"
      sleep 30
      ;;
  esac
done

echo -e "\e[32m ==> Build complete.\e[0m"