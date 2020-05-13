# terraform-awsvpc-dynamic-subnets

This repository contains a minimalist but working prototype for terraforming a VPC in AWS using dynamic private &amp; public subnets with an extra feature to turnoff private subnet. The details are explained over this post.
This project is just a DIY to give an example which can the be basis of for other related projects.

## Usage

### Init

`` terraform init ``

### Plan

`` terraform plan -out /tmp/vpc.plan -detailed-exitcode ``

### Apply

`` terraform apply /tmp/vpc.plan ``

### Show

`` terraform show ``

### Destroy

`` terraform destroy -force ``
