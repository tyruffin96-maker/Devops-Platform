variable "project_name"     { type = string }
variable "vpc_id"           { type = string }
variable "allowed_ssh_cidr" {
  type        = string
  description = "Your IP in CIDR notation, e.g. 203.0.113.5/32. Never use 0.0.0.0/0."
}