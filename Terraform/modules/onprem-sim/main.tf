# Security Group for the simulated on-premises server
resource "aws_security_group" "onprem_server" {
  name        = "${var.environment}-onprem-server-sg"
  description = "Security group for simulated on-premises Ubuntu server"
  vpc_id      = var.vpc_id

  # No inbound rules: administration through AWS SSM

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-onprem-server-sg"
    Environment = var.environment
  }
}

# IAM Role for Systems Manager
resource "aws_iam_role" "onprem_ssm_role" {
  name = "${var.environment}-onprem-ssm-role"

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
}

# Attach the AWS-managed SSM permissions
resource "aws_iam_role_policy_attachment" "onprem_ssm" {
  role       = aws_iam_role.onprem_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile for EC2
resource "aws_iam_instance_profile" "onprem" {
  name = "${var.environment}-onprem-instance-profile"
  role = aws_iam_role.onprem_ssm_role.name
}

# Retrieve the latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
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


# Simulated on-premises Ubuntu server
resource "aws_instance" "onprem_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  subnet_id = var.public_subnet_id

  vpc_security_group_ids = [
    aws_security_group.onprem_server.id
  ]

  iam_instance_profile = aws_iam_instance_profile.onprem.name

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name        = "${var.environment}-onprem-ubuntu"
    Environment = var.environment
    Role        = "OnPremSimulation"
  }
}