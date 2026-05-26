variable "project_name" {
  description = "Used to prefix all resource names"
  type        = string
}

variable "instance_id" {
  description = "EC2 instance ID to monitor"
  type        = string
}

variable "alert_email" {
  description = "Email address for alarm notifications"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}