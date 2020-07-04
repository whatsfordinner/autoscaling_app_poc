# Autoscaling a Legacy App - Proof of Concept  

This repo is a proof of concept for an application that runs in EC2 in an autoscaling group. Packer is used to build an AMI containing the application, but final configuration is done when the instance starts, prior to joining the autoscaling group. The use case for something like this is when an application runs in many different environments (E.g. dev, staging, multiple production environments). In such cases, configuration and the application binary might differ per environment, but we deliberately want to maintain the same runtime environment.

In this case, the application is being represented by nginx:  
* nginx config files represent application configuration  
* static docs represent application code  

## Running Packer to build the AMI

```
docker run \
-v $(pwd):/mnt -w /mnt/packer \
-e AWS_ACCESS_KEY_ID \
-e AWS_SECRET_ACCESS_KEY \
-e AWS_SESSION_TOKEN \
-e AWS_DEFAULT_REGION \
hashicorp/packer:light build app.json
```

## Running Terraform to deploy the app

```
docker run \
-v $(pwd):/mnt -w /mnt/terraform \
-e AWS_ACCESS_KEY_ID \
-e AWS_SECRET_ACCESS_KEY \
-e AWS_SESSION_TOKEN \
-e AWS_DEFAULT_REGION \
hashicorp/terraform:light init

docker run \
-v $(pwd):/mnt -w /mnt/terraform \
-e AWS_ACCESS_KEY_ID \
-e AWS_SECRET_ACCESS_KEY \
-e AWS_SESSION_TOKEN \
-e AWS_DEFAULT_REGION \
hashicorp/terraform:light plan -input=false -out=tfplan

docker run \
-v $(pwd):/mnt -w /mnt/terraform \
-e AWS_ACCESS_KEY_ID \
-e AWS_SECRET_ACCESS_KEY \
-e AWS_SESSION_TOKEN \
-e AWS_DEFAULT_REGION \
hashicorp/terraform:light apply -input=false tfplan
```

## Removing resources when you're done

```
docker run \
-v $(pwd):/mnt -w /mnt/terraform \
-e AWS_ACCESS_KEY_ID \
-e AWS_SECRET_ACCESS_KEY \
-e AWS_SESSION_TOKEN \
-e AWS_DEFAULT_REGION \
hashicorp/terraform:light plan -input=false -destroy -out=tfplan

docker run \
-v $(pwd):/mnt -w /mnt/terraform \
-e AWS_ACCESS_KEY_ID \
-e AWS_SECRET_ACCESS_KEY \
-e AWS_SESSION_TOKEN \
-e AWS_DEFAULT_REGION \
hashicorp/terraform:light apply -input=false tfplan

for IMAGE_ID in $(aws ec2 describe-images --owners "self" --query 'Images[?name == "autoscaling-poc-*"].ImageId' --output text)
do
  aws ec2 deregister-image --image-id $IMAGE_ID
done
```

## Caveats

None of this is what I would consider production-ready