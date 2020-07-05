#!/bin/bash -e

# Check the script is running from the app directory
if [ ! -d config ]
then
    echo "Unable to find config directory. This script must be run from app directory."
    exit 1
fi

if [ ! -d content ]
then
    echo "Unable to find content directory. This script must be run from app directory."
    exit 1
fi

# Get environment details from Parameter Store
BUCKET=$(aws ssm get-parameter --name app-bucket-name --query 'Parameter.Value' --output text)
ASG_NAME=$(aws ssm get-parameter --name app-autoscaling-group-id --query 'Parameter.Value' --output text)

# Sync config and content directories with the S3 bucket
aws s3 sync . s3://${BUCKET} --exclude 'deploy.sh'

# Refresh the autoscaling group so that the new content and config is pulled down
REFRESH_ID=$(aws autoscaling start-instance-refresh \
--auto-scaling-group-name ${ASG_NAME} \
--preferences '{"InstanceWarmup": 30}' \
--query 'InstanceRefreshId' --output text)

# Get the initial status of the autoscaling group refresh
REFRESH_STATUS=$(aws autoscaling describe-instance-refreshes \
--auto-scaling-group-name ${ASG_NAME} \
--instance-refresh-ids ${REFRESH_ID} \
--query 'InstanceRefreshes[].Status' --output text)

# When the refresh is created it'll be in pending state
# Pending state doesn't have additional attributes that we care about
while [ ${REFRESH_STATUS} == "Pending" ]
do
    echo "Autoscaling Group refresh is pending..."
    REFRESH_STATUS=$(aws autoscaling describe-instance-refreshes \
    --auto-scaling-group-name ${ASG_NAME} \
    --instance-refresh-ids ${REFRESH_ID} \
    --query 'InstanceRefreshes[].Status' --output text)
    sleep 5
done

# Provided everything's correct, the refresh will move into the InProgress state
# Here we want to keep up-to-date on the progress of the deployment
while [ ${REFRESH_STATUS} == "InProgress" ]
do
    REFRESH_INFO=$(aws autoscaling describe-instance-refreshes \
    --auto-scaling-group-name ${ASG_NAME} \
    --instance-refresh-ids ${REFRESH_ID})
    COMPLETION=$(echo ${REFRESH_INFO} | jq -r '.InstanceRefreshes[] | .PercentageComplete')
    REFRESH_STATUS=$(echo ${REFRESH_INFO} | jq -r '.InstanceRefreshes[] | .Status')
    echo "Refresh in progress: ${COMPLETION}% complete..."
    sleep 10
done

# Output the final state - success or failure
echo ${REFRESH_INFO} | jq