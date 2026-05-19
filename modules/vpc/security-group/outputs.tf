output "alb_sg_id"     { value = aws_security_group.alb.id }
output "bastion_sg_id" { value = aws_security_group.bastion.id }
output "app_sg_id"     { value = aws_security_group.app.id }
output "jenkins_sg_id" { value = aws_security_group.jenkins.id }