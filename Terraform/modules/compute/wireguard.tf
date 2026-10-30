# --------------------------------------------------
# Security Group for WireGuard VPN
# --------------------------------------------------

resource "aws_security_group" "wireguard" {
  name        = "${var.environment}-wireguard-sg"
  description = "Security group for the WireGuard VPN server"
  vpc_id      = var.vpc_id

  ingress {
    description = "WireGuard VPN traffic"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-wireguard-sg"
    Environment = var.environment
  }
}

# --------------------------------------------------
# Ubuntu 24.04 AMI
# --------------------------------------------------

data "aws_ami" "wireguard_ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --------------------------------------------------
# IAM Role for WireGuard SSM Access
# --------------------------------------------------

resource "aws_iam_role" "wireguard_ssm" {
  name = "${var.environment}-wireguard-ssm-role"

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
    Name        = "${var.environment}-wireguard-ssm-role"
    Environment = var.environment
  }
}

# --------------------------------------------------
# Attach AWS-Managed SSM Policy
# --------------------------------------------------

resource "aws_iam_role_policy_attachment" "wireguard_ssm" {
  role       = aws_iam_role.wireguard_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# --------------------------------------------------
# IAM Instance Profile
# --------------------------------------------------

resource "aws_iam_instance_profile" "wireguard_ssm" {
  name = "${var.environment}-wireguard-ssm-profile"
  role = aws_iam_role.wireguard_ssm.name
}

# --------------------------------------------------
# WireGuard VPN Server
# --------------------------------------------------

# --------------------------------------------------
# WireGuard VPN Server
# --------------------------------------------------

resource "aws_instance" "wireguard" {
  ami                         = data.aws_ami.wireguard_ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.wireguard.id]
  associate_public_ip_address = true

  # Enable AWS Systems Manager access
  iam_instance_profile = aws_iam_instance_profile.wireguard_ssm.name

  # Require IMDSv2
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  # Encrypted root volume
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  # Bootstrap SSM and WireGuard on first boot
  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    exec > >(tee -a /var/log/wireguard-bootstrap.log) 2>&1

    export DEBIAN_FRONTEND=noninteractive

    # Update package metadata
    apt-get update

    # Install WireGuard and tools required for VPN routing
    apt-get install -y wireguard iptables curl snapd

    # Install SSM Agent if it is not already installed
    if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
      snap install amazon-ssm-agent --classic
    fi

    # Enable and start SSM Agent
    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent.service

    # Enable IPv4 forwarding for VPN traffic
    cat >/etc/sysctl.d/99-wireguard.conf <<'SYSCTL'
    net.ipv4.ip_forward=1
    SYSCTL

    sysctl --system

    # Ensure WireGuard configuration directory exists
    install -d -m 700 /etc/wireguard

    echo "WireGuard bootstrap completed."
  EOF

  tags = {
    Name        = "${var.environment}-wireguard"
    Environment = var.environment
    Purpose     = "Site-to-site VPN"
  }
}