data "aws_ssm_parameter" "windows_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

resource "aws_security_group" "onprem_windows" {
  name        = "${var.environment}-onprem-windows-sg"
  description = "Security group for simulated on-premises Windows server"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-onprem-windows-sg"
    Environment = var.environment
  }
}

resource "aws_instance" "onprem_windows" {
  ami           = data.aws_ssm_parameter.windows_ami.value
  instance_type = "t3.medium"

  subnet_id = var.public_subnet_id

  vpc_security_group_ids = [
    aws_security_group.onprem_windows.id
  ]

  iam_instance_profile = aws_iam_instance_profile.onprem.name

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 50
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = {
    Name        = "${var.environment}-onprem-windows"
    Environment = var.environment
    Role        = "OnPremSimulation"
    OS          = "Windows"
  }
}