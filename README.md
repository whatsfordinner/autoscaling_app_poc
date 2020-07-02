# Autoscaling Proof of Concept  

This repo is a proof of concept for an application that runs in EC2 in an autoscaling group. Packer is used to build an AMI containing the application, but final configuration is done when the instance starts, prior to joining the autoscaling group. The use case for something like this is when an application runs in many different environments (E.g. dev, staging, multiple production environments). In such cases, configuration and the application binary might differ per environment, but we deliberately want to maintain the same runtime environment.

In this case, the application is being represented by nginx:  
* nginx config files represent application configuration  
* static docs represent application code  