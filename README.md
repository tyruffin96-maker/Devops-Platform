# DevOps Platform

AWS infrastructure built with Terraform featuring:
- VPC with public/private subnets
- EC2 instances (Bastion, App, Jenkins)
- Security Groups with least-privilege access
- Remote state management with S3
- CI/CD with GitHub Actions

## Architecture
- Bastion host for secure SSH access
- App servers in private subnets
- Jenkins CI/CD server
- NAT Gateway for outbound private subnet traffic

## Tools Used
- Terraform
- AWS (VPC, EC2, S3, NAT Gateway)
- GitHub Actions
