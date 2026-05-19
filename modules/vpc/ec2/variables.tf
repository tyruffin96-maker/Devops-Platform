variable "project_name"        { type = string }
variable "aws_region"          { type = string }
variable "ssh_public_key" {
  type      = string
  sensitive = true
}
variable "public_subnet_ids"   { type = list(string) }
variable "private_subnet_ids"  { type = list(string) }
variable "bastion_sg_id"       { type = string }
variable "app_sg_id"           { type = string }
variable "jenkins_sg_id"       { type = string }
variable "ecr_repository_url"  { type = string }
variable "app_instance_type" {
  type    = string
  default = "t3.micro"
}
variable "jenkins_instance_type" {
  type    = string
  default = "t3.small"
}