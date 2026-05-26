output "bastion_public_ip"  { value = aws_instance.bastion.public_ip }
output "app_private_ip"     { value = aws_instance.app.private_ip }
output "jenkins_private_ip" { value = aws_instance.jenkins.private_ip }
output "deployer_key_name"  { value = aws_key_pair.deployer.key_name }
output "instance_id" {
  value = aws_instance.app.id
}