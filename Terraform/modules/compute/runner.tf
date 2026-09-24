resource "aws_iam_role" "github_runner" {
  name = "${var.environment}-github-runner-role"

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
    Name        = "${var.environment}-github-runner-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "github_runner" {
  name = "${var.environment}-github-runner-policy"
  role = aws_iam_role.github_runner.id

  policy = jsonencode({
  Version = "2012-10-17"

  Statement = [
    {
      Effect = "Allow"

      Action = [
        "ecr:GetAuthorizationToken"
      ]

      Resource = "*"
    },

    {
      Effect = "Allow"

      Action = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:CompleteLayerUpload",
        "ecr:InitiateLayerUpload",
        "ecr:PutImage",
        "ecr:UploadLayerPart"
      ]

      Resource = "*"
    },

    {
      Effect = "Allow"

      Action = [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeTasks",
        "ecs:ListTasks",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService"
      ]

      Resource = "*"
    },

    {
      Effect = "Allow"

      Action = [
        "iam:PassRole"
      ]

      Resource = aws_iam_role.ecs_task_execution.arn
    }
  ]
})
  
  
}

resource "aws_iam_role_policy_attachment" "github_runner_ssm" {
  role       = aws_iam_role.github_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "github_runner" {
  name = "${var.environment}-github-runner-profile"
  role = aws_iam_role.github_runner.name
}

resource "aws_security_group" "github_runner" {
  name        = "${var.environment}-github-runner-sg"
  description = "Security group for GitHub Actions self-hosted runner"
  vpc_id      = var.vpc_id

  # No inbound rules are required.
  # The runner connects outbound to GitHub.

  egress {
    description = "Allow outbound HTTPS and other required traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-github-runner-sg"
    Environment = var.environment
  }
}

data "aws_ami" "github_runner" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "github_runner" {
  ami           = data.aws_ami.github_runner.id
  instance_type = "t3.small"

  subnet_id = var.public_subnet_ids[0]

  associate_public_ip_address = true

  vpc_security_group_ids = [
    aws_security_group.github_runner.id
  ]

  iam_instance_profile = aws_iam_instance_profile.github_runner.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash

    dnf update -y

    dnf install -y \
      amazon-ssm-agent \
      docker \
      git \
      jq \
      unzip

    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    systemctl enable docker
    systemctl start docker

    usermod -aG docker ec2-user

    echo "GitHub Actions runner prerequisites installed."
  EOF

  tags = {
    Name        = "${var.environment}-github-runner"
    Environment = var.environment
    Purpose     = "GitHub Actions self-hosted runner"
  }
}