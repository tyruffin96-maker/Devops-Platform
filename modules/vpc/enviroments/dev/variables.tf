variable "project_name" {
  type    = string
  default = "devops-platform"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "allowed_ssh_cidr" {
  type = string
}

variable "ssh_public_key" {
  type      = string
  sensitive = true
}

variable "ecr_repository_url" {
  type    = string
  default = ""
}

variable "alert_email" {
  description = "Email for CloudWatch alarm notifications"
  type        = string
}