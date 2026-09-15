# ============================================================
# Monitoring EC2
# ============================================================

# ------------------------------------------------------------
# Amazon Linux 2023 AMI
# ------------------------------------------------------------

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}


# ============================================================
# Security Group
# ============================================================

resource "aws_security_group" "monitoring" {
  name        = "${var.environment}-monitoring-sg"
  description = "Security group for Prometheus and Grafana"
  vpc_id      = var.vpc_id

  ingress {
    description = "Grafana from Compute VPC"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  ingress {
    description = "Prometheus from Compute VPC"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-monitoring-sg"
    Environment = var.environment
  }
}


# ============================================================
# IAM Role
# ============================================================

resource "aws_iam_role" "monitoring" {
  name = "${var.environment}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-monitoring-role"
    Environment = var.environment
  }
}


# ============================================================
# SSM Policy
# ============================================================

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# ============================================================
# Instance Profile
# ============================================================

resource "aws_iam_instance_profile" "monitoring" {
  name = "${var.environment}-monitoring-profile"

  role = aws_iam_role.monitoring.name
}


# ============================================================
# Monitoring EC2
# ============================================================

resource "aws_instance" "monitoring" {
  ami = data.aws_ami.amazon_linux.id

  instance_type = var.instance_type

  subnet_id = var.private_subnet_id

  vpc_security_group_ids = [
    aws_security_group.monitoring.id
  ]

  # ----------------------------------------------------------
  # No public IP
  # ----------------------------------------------------------

  associate_public_ip_address = false

  # ----------------------------------------------------------
  # IAM permissions for SSM
  # ----------------------------------------------------------

  iam_instance_profile = aws_iam_instance_profile.monitoring.name

  # ----------------------------------------------------------
  # User data
  #
  # AL2023 normally includes the SSM Agent.
  # We simply enable and start it.
  # ----------------------------------------------------------

  user_data = <<-EOF
    #!/bin/bash

    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
  EOF

  tags = {
    Name        = "${var.environment}-monitoring"
    Environment = var.environment
  }
}