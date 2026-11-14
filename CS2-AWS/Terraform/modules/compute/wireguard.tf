# --------------------------------------------------
# Security Group for WireGuard VPN
# --------------------------------------------------

resource "aws_security_group" "ipsec" {
  name        = "${var.environment}-ipsec-sg"
  description = "Security group for the IPsec VPN server"
  vpc_id      = var.vpc_id

  ingress {
    description = "IKE"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "IPsec NAT Traversal"
    from_port   = 4500
    to_port     = 4500
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
    Name        = "${var.environment}-ipsec-sg"
    Environment = var.environment
  }
}

# --------------------------------------------------
# Ubuntu 24.04 AMI
# --------------------------------------------------

data "aws_ami" "ipsec_ubuntu" {
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

resource "aws_iam_role" "ipsec_ssm" {
  name = "${var.environment}-ipsec-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "${var.environment}-ipsec-ssm-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ipsec_ssm" {
  role       = aws_iam_role.ipsec_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ipsec_ssm" {
  name = "${var.environment}-ipsec-ssm-profile"
  role = aws_iam_role.ipsec_ssm.name
}
# --------------------------------------------------
# WireGuard VPN Server
# --------------------------------------------------

# --------------------------------------------------
# WireGuard VPN Server
# --------------------------------------------------

resource "aws_instance" "ipsec" {
  ami                         = data.aws_ami.ipsec_ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.ipsec.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.ipsec_ssm.name

  # IPsec gateway must be able to forward traffic
  source_dest_check = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    exec > >(tee -a /var/log/ipsec-bootstrap.log) 2>&1

    export DEBIAN_FRONTEND=noninteractive

    apt-get update

    apt-get install -y strongswan strongswan-pki libcharon-extra-plugins curl snapd

    # Install SSM Agent
    if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
      snap install amazon-ssm-agent --classic
    fi

    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent.service

    # Enable IPv4 forwarding
    cat >/etc/sysctl.d/99-ipsec.conf <<'SYSCTL'
    net.ipv4.ip_forward=1
    SYSCTL

    sysctl --system

    echo "strongSwan installation completed."
  EOF

  tags = {
    Name        = "${var.environment}-ipsec"
    Environment = var.environment
    Purpose     = "Site-to-site IPsec VPN"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ipsec_ssm
  ]
}