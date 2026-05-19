# ============================================================
# Data source: look up the latest Ubuntu 22.04 AMI automatically.
# We use a data source so we never have to hardcode an AMI ID,
# which changes per-region and goes stale over time.
# ============================================================
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]   # Canonical's official AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ============================================================
# SSH Key Pair
# You generate the key locally, give Terraform the public half.
# The private key never leaves your machine.
# ============================================================
resource "aws_key_pair" "deployer" {
  key_name   = "${var.project_name}-deployer-key"
  public_key = var.ssh_public_key

  tags = { ManagedBy = "terraform" }
}

# ============================================================
# IAM Role: App Server
# Allows the app server EC2 instance to pull images from ECR.
# The assume_role_policy says: "EC2 can use this role."
# ============================================================
resource "aws_iam_role" "app_server" {
  name = "${var.project_name}-app-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { ManagedBy = "terraform" }
}

resource "aws_iam_role_policy" "app_ecr_pull" {
  name = "${var.project_name}-app-ecr-pull"
  role = aws_iam_role.app_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "app_server" {
  name = "${var.project_name}-app-server-profile"
  role = aws_iam_role.app_server.name
}

# ============================================================
# IAM Role: Jenkins Server
# Jenkins needs to push images to ECR and run Terraform.
# More permissions than the app server — carefully scoped.
# ============================================================
resource "aws_iam_role" "jenkins" {
  name = "${var.project_name}-jenkins-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { ManagedBy = "terraform" }
}

resource "aws_iam_role_policy" "jenkins_ecr_push" {
  name = "${var.project_name}-jenkins-ecr-push"
  role = aws_iam_role.jenkins.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        # Allow Jenkins to read SSM Parameter Store for secrets
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jenkins" {
  name = "${var.project_name}-jenkins-profile"
  role = aws_iam_role.jenkins.name
}

# ============================================================
# Bastion Host
# Tiny instance — it only forwards SSH connections.
# Lives in the public subnet with a public IP.
# ============================================================
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [var.bastion_sg_id]
  key_name               = aws_key_pair.deployer.key_name

  # Bastion needs a public IP so you can SSH into it from your laptop
  associate_public_ip_address = true

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail
    apt-get update -y
    apt-get install -y \
      fail2ban \       # auto-bans IPs with repeated failed SSH attempts
      awscli           # useful for debugging from the bastion
    systemctl enable fail2ban
    systemctl start fail2ban
    echo "Bastion ready" >> /var/log/user-data.log
  EOF
  )

  tags = {
    Name        = "${var.project_name}-bastion"
    Role        = "bastion"
    ManagedBy   = "terraform"
  }
}

# ============================================================
# App Server
# Runs in the PRIVATE subnet — no public IP.
# Bootstraps Docker and pulls the latest image from ECR.
# ============================================================
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.app_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.app_sg_id]
  key_name               = aws_key_pair.deployer.key_name
  iam_instance_profile   = aws_iam_instance_profile.app_server.name

  # Private subnet — no public IP, all outbound via NAT
  associate_public_ip_address = false

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail

    # Log everything for debugging
    exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

    apt-get update -y
    apt-get install -y docker.io awscli

    # Start Docker and enable on boot
    systemctl enable docker
    systemctl start docker

    # Add ubuntu user to docker group so it can run docker without sudo
    usermod -aG docker ubuntu

    # Authenticate Docker to ECR
    # The instance role provides credentials — no keys stored on disk
    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin \
      ${var.ecr_repository_url}

    # Pull and run the latest app image
    docker pull ${var.ecr_repository_url}:latest
    docker run -d \
      --name app \
      --restart unless-stopped \
      -p 3000:3000 \
      -e NODE_ENV=production \
      ${var.ecr_repository_url}:latest

    echo "App server ready" >> /var/log/user-data.log
  EOF
  )

  tags = {
    Name      = "${var.project_name}-app-server"
    Role      = "app"
    ManagedBy = "terraform"
  }
}

# ============================================================
# Jenkins Server
# Larger instance — builds need CPU and memory.
# Installs Jenkins, Docker, and configures ECR access.
# ============================================================
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.jenkins_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.jenkins_sg_id]
  key_name               = aws_key_pair.deployer.key_name
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  associate_public_ip_address = false

  # 30GB root volume for storing Docker images during builds
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"    # gp3 is cheaper and faster than gp2
    delete_on_termination = true
    encrypted             = true     # always encrypt volumes — security best practice
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail
    exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

    apt-get update -y
    apt-get install -y \
      openjdk-17-jre \
      docker.io \
      awscli \
      git

    # Install Jenkins from official repo
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | \
      tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
      https://pkg.jenkins.io/debian-stable binary/" | \
      tee /etc/apt/sources.list.d/jenkins.list
    apt-get update -y
    apt-get install -y jenkins

    # Jenkins needs Docker access for building images
    usermod -aG docker jenkins
    usermod -aG docker ubuntu

    systemctl enable jenkins docker
    systemctl start docker
    systemctl start jenkins

    # Give Jenkins a moment to start, then print the unlock key to the log
    sleep 30
    echo "=== Jenkins initial admin password ===" >> /var/log/user-data.log
    cat /var/lib/jenkins/secrets/initialAdminPassword >> /var/log/user-data.log

    echo "Jenkins ready" >> /var/log/user-data.log
  EOF
  )

  tags = {
    Name      = "${var.project_name}-jenkins"
    Role      = "jenkins"
    ManagedBy = "terraform"
  }
}