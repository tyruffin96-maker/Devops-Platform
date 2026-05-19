# ============================================================
# ALB Security Group
# The load balancer is the only thing internet users touch.
# We allow 80 so we can redirect to 443. We allow 443 for HTTPS.
# ============================================================
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-sg-alb"
  description = "Controls traffic to the Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet - redirect to HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound - the ALB needs to reach the app servers
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"           # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.project_name}-sg-alb"
    ManagedBy = "terraform"
  }
}

# ============================================================
# Bastion Host Security Group
# The ONLY entry point for SSH into the entire VPC.
# IMPORTANT: Replace var.allowed_ssh_cidr with your actual IP.
# Never use 0.0.0.0/0 for SSH in production - that's how
# servers get brute-forced within hours of creation.
# ============================================================
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-sg-bastion"
  description = "SSH access to the bastion jump box"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from trusted IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]   # e.g. "203.0.113.5/32" - your IP
  }

  egress {
    description = "All outbound - bastion needs to reach private subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.project_name}-sg-bastion"
    ManagedBy = "terraform"
  }
}

# ============================================================
# App Server Security Group
# Key insight: sources are security group IDs, not CIDRs.
# This means ONLY traffic from the ALB and bastion is allowed -
# not any random host that happens to be in the VPC.
# ============================================================
resource "aws_security_group" "app" {
  name        = "${var.project_name}-sg-app"
  description = "App server - only ALB and bastion can connect"
  vpc_id      = var.vpc_id

  ingress {
    description     = "App traffic from ALB only"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]   # SG reference, not CIDR
  }

  ingress {
    description     = "SSH from bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Outbound via NAT (pull images, packages, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.project_name}-sg-app"
    ManagedBy = "terraform"
  }
}

# ============================================================
# Jenkins Security Group
# Jenkins UI on 8080 is only reachable from the app server.
# This prevents anyone from accessing Jenkins directly -
# it should only be reachable via the bastion or app server.
# ============================================================
resource "aws_security_group" "jenkins" {
  name        = "${var.project_name}-sg-jenkins"
  description = "Jenkins - only app server and bastion can connect"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Jenkins UI from app server only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "Jenkins agent port from app server"
    from_port       = 50000
    to_port         = 50000
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description     = "SSH from bastion for maintenance"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Outbound - pull code from GitHub, push images to ECR"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name      = "${var.project_name}-sg-jenkins"
    ManagedBy = "terraform"
  }
}