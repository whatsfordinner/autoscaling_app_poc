#!/bin/bash -e

# Find the region we're running in
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

# Get the name of the content bucket from parameter store
BUCKET=$(aws ssm get-parameter --name app-bucket-name --region $REGION --query 'Parameter.Value' --output text)

# Sync the contents of the bucket with our nginx config
aws s3 sync s3://$BUCKET/config/ /etc/nginx

# Sync the contents of the bucket with our static docs
aws s3 sync s3://$BUCKET/content/ /usr/local

# Test to make sure nginx can start
nginx -t

# Start nginx
systemctl start nginx