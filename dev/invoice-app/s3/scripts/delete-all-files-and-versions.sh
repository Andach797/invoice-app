#!/bin/bash
AWS_REGION=$1
BUCKET_NAME=$2
bucket_status=$(aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" 2>&1)
if [ $? -eq 0 ]; then
echo "Starts empty bucket"
# Empty the bucket
aws s3 rm s3://$BUCKET_NAME --recursive --region $AWS_REGION
echo "Starts delete all versions"
# Delete all versions
aws s3api list-object-versions --bucket $BUCKET_NAME --region $AWS_REGION \
  --query 'Versions[]|[?IsLatest==`false`].[Key, VersionId]' \
  --output text | \
  while read -r key versionId; do
    aws s3api delete-object --bucket $BUCKET_NAME --key "$key" --version-id "$versionId" --region $AWS_REGION
  done
  echo "All files and versions deleted."
else
  echo "Bucket does not exist, skipping..."
  exit 0
fi

