#!/bin/bash

set -euo pipefail

PIPELINE_ARN="$1"
NAME="$2"

echo ""
echo -e "\e[33m ==> Searching AMIs with name: Ami${NAME}*\e[0m"
echo ""

DESCRIBE_AMIS=$(aws ec2 describe-images \
  --filters \
    "Name=name,Values=${NAME}-*" \
    "Name=state,Values=available" \
  --query 'Images[*].ImageId' \
  --output text)

echo $DESCRIBE_AMIS;
exit

if [ -n "$DESCRIBE_AMIS" ]; then
  for ami in $DESCRIBE_AMIS; do
    echo ""
    echo -e "\e[33m ==> AMI found: $ami, deleting...\e[0m"
    echo ""

    IMAGE_RESOURCE_ARN=$(aws ec2 describe-images \
      --image-ids "$ami" \
      --query "Images[0].Tags[?Key=='Ec2ImageBuilderArn'].Value[]" \
      --output text)

    aws imagebuilder delete-image \
      --image-build-version-arn "$IMAGE_RESOURCE_ARN" || exit 1

    aws ec2 deregister-image --image-id "$ami"

    SNAPSHOTS=$(aws ec2 describe-images \
      --image-ids "$ami" \
      --query 'Images[0].BlockDeviceMappings[*].Ebs.SnapshotId' \
      --output text)

    for snap in $SNAPSHOTS; do
      if [ "$snap" != "None" ]; then
        echo ""
        echo -e "\e[33m ==> Deleting snapshot: $snap\e[0m"
        aws ec2 delete-snapshot --snapshot-id "$snap"
      fi
    done
  done
else
  echo ""
  echo -e "\e[32m ==> No AMIs found. Proceeding to build.\e[0m"
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
