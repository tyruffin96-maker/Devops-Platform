# This module creates the complete network foundation.
# Think of this as designing the floor plan before building anything.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr          # 10.0.0.0/16 = 65,536 IP addresses
  enable_dns_hostnames = true                  # lets EC2 instances get DNS names
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"                  # tells humans this isn't hand-built
  }
}

# The Internet Gateway is the "front door" of your VPC
# Without this, nothing in the VPC can reach the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-igw"
    ManagedBy = "terraform"
  }
}

# Public subnet — internet-facing resources live here
resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = var.availability_zones[count.index]

  # This is what makes it "public" — instances get a public IP automatically
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Tier = "public"
  }
}

# Private subnet — app servers and Jenkins live here
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  # No public IPs — private subnet instances are invisible to the internet
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-private-${var.availability_zones[count.index]}"
    Tier = "private"
  }
}

# NAT Gateway lets private subnet instances make OUTBOUND calls only
# e.g., apt-get install, docker pull — but nothing can initiate an INBOUND connection
resource "aws_eip" "nat" {
  domain = "vpc"  # required for NAT gateway EIPs
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # NAT gateway must be in public subnet

  tags = {
    Name      = "${var.project_name}-nat"
    ManagedBy = "terraform"
  }
}

# Route table: public subnet sends internet traffic through the IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                    # all traffic
    gateway_id = aws_internet_gateway.main.id   # goes out the front door
  }

  tags = { Name = "${var.project_name}-rt-public" }
}

# Route table: private subnet sends internet traffic through NAT (outbound only)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id  # goes through NAT, not IGW
  }

  tags = { Name = "${var.project_name}-rt-private" }
}

# Associate each subnet with its route table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

module "monitoring" {
  source       = "./monitoring"
  project_name = var.project_name
  instance_id  = module.ec2.instance_id   # adjust to match your ec2 output name
  alert_email  = var.alert_email
}