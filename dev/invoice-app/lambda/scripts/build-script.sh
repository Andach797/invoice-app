#!/bin/bash

set -e

FUNCTION_NAME="$1"
BUCKET="$2"
S3_KEY="$3"

# Check for the presence of go.mod and initialize if not present
test -f go.mod || go mod init main 2>&1
go mod tidy

# Check for the presence of the compiled binary and build if not present
test -f main || GOARCH=amd64 GOOS=linux go build -o main main.go
chmod +x main

# Check for the presence of the zipped function and zip if not present
test -f ${FUNCTION_NAME}.zip || zip -r ${FUNCTION_NAME}.zip main

# Calculate the MD5 checksum of the local zip file in hexadecimal format
LOCAL_MD5_HEX=$(openssl dgst -md5 ${FUNCTION_NAME}.zip | awk '{print $2}')

# Get the ETag of the object on S3
S3_ETAG=$(aws s3api head-object --bucket $BUCKET --key $S3_KEY --query "ETag" --output text 2>/dev/null | sed 's/\"//g')

# Print out the checksums for debugging
echo "Local MD5 (Hex): $LOCAL_MD5_HEX"
echo "S3 ETag: $S3_ETAG"

# Only upload if the MD5 checksums don't match
if [ "$LOCAL_MD5_HEX" != "$S3_ETAG" ]; then
    aws s3 cp ${FUNCTION_NAME}.zip s3://${BUCKET}/${S3_KEY}
else
    echo "Local zip file is the same as the one on S3. Skipping upload."
fi
