terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "devops-platform-tfstate-904934037838"
    key    = "devops-platform/dev/terraform.tfstate"
    region = "us-east-1"
  }
}

module "vpc" {
  source       = "../../../vpc"
  project_name = var.project_name
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"
}

module "security_groups" {
  source           = "../../security-group"
  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

module "ec2" {
  source             = "../../ec2"
  project_name       = var.project_name
  aws_region         = var.aws_region
  ssh_public_key     = var.ssh_public_key
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  bastion_sg_id      = module.security_groups.bastion_sg_id
  app_sg_id          = module.security_groups.app_sg_id
  jenkins_sg_id      = module.security_groups.jenkins_sg_id
  ecr_repository_url = var.ecr_repository_url
}


output "bastion_ip" { value = module.ec2.bastion_public_ip }
output "app_ip"     { value = module.ec2.app_private_ip }
output "jenkins_ip" { value = module.ec2.jenkins_private_ip }

module "monitoring" {
  source       = "../../monitoring"
  project_name = var.project_name
  instance_id  = module.ec2.instance_id
  alert_email  = var.alert_email
  aws_region   = var.aws_region
}