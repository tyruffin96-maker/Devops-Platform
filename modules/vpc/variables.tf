variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "dev, staging, or prod"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs to deploy into — use at least 2 for high availability"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}