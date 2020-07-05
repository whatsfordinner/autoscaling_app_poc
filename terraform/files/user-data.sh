#!/bin/bash -e

# Find the region we're running in
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)

# Get the name of the content bucket from parameter store
BUCKET=$(aws ssm get-parameter --name app-bucket-name --region $REGION --query 'Parameter.Value' --output text)

# Sync the contents of the bucket with our nginx config
aws s3 sync s3://$BUCKET/config/ /etc/nginx

# aws s3 sync doesn't like some of the symlinking going on in the default nginx directory
rm -rf /usr/share/nginx/html/*

# Sync the contents of the bucket with our static docs
aws s3 sync s3://$BUCKET/content/ /usr/share/nginx/html

# Test to make sure nginx can start
nginx -t

# Start nginx
systemctl start nginx