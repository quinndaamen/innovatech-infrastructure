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



resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "prometheus_s3" {
  name = "${var.environment}-prometheus-s3"
  role = aws_iam_role.monitoring.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = "${aws_s3_bucket.prometheus.arn}/*"
      }
    ]
  })
}


resource "aws_iam_instance_profile" "monitoring" {
  name = "${var.environment}-monitoring-profile"

  role = aws_iam_role.monitoring.name
}

resource "aws_s3_bucket" "prometheus" {
  bucket = "${var.environment}-prometheus-artifact"

  tags = {
    Name        = "${var.environment}-prometheus-artifact"
    Environment = var.environment
  }
}

resource "aws_s3_object" "prometheus" {
  bucket = aws_s3_bucket.prometheus.id
  key    = "prometheus-3.5.0.linux-amd64.tar.gz"
  source = "${path.module}/files/prometheus-3.5.0.linux-amd64.tar.gz"

  etag = filemd5("${path.module}/files/prometheus-3.5.0.linux-amd64.tar.gz")
}


resource "aws_instance" "monitoring" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  subnet_id     = var.private_subnet_id

  vpc_security_group_ids = [
    aws_security_group.monitoring.id
  ]

  associate_public_ip_address = false

  iam_instance_profile = aws_iam_instance_profile.monitoring.name

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash

    set -e

    # Update system
    dnf update -y

    # Install required packages
    dnf install -y wget tar awscli

    # Ensure SSM Agent is running
    dnf install -y amazon-ssm-agent
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    # Create Prometheus user
    useradd --no-create-home --shell /sbin/nologin prometheus || true

    # Create Prometheus directories
    mkdir -p /etc/prometheus
    mkdir -p /var/lib/prometheus

    # Download Prometheus from the private S3 endpoint
    cd /tmp

    aws s3 cp \
    s3://${aws_s3_bucket.prometheus.id}/prometheus-${var.prometheus_version}.linux-amd64.tar.gz \
    prometheus-${var.prometheus_version}.linux-amd64.tar.gz

    tar -xzf prometheus-${var.prometheus_version}.linux-amd64.tar.gz

    cd prometheus-${var.prometheus_version}.linux-amd64

    # Install Prometheus binaries
    cp prometheus /usr/local/bin/prometheus
    cp promtool /usr/local/bin/promtool

    # Install Prometheus configuration
    cat > /etc/prometheus/prometheus.yml <<'PROMETHEUS_CONFIG'
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: "prometheus"
        static_configs:
          - targets:
              - "localhost:9090"
    PROMETHEUS_CONFIG

    # Set permissions
    chown prometheus:prometheus /usr/local/bin/prometheus
    chown prometheus:prometheus /usr/local/bin/promtool
    chown -R prometheus:prometheus /etc/prometheus
    chown -R prometheus:prometheus /var/lib/prometheus

    # Create systemd service
    cat > /etc/systemd/system/prometheus.service <<'SERVICE'
    [Unit]
    Description=Prometheus Monitoring
    Wants=network-online.target
    After=network-online.target

    [Service]
    User=prometheus
    Group=prometheus
    Type=simple

    ExecStart=/usr/local/bin/prometheus \
      --config.file=/etc/prometheus/prometheus.yml \
      --storage.tsdb.path=/var/lib/prometheus

    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
    SERVICE

    # Start Prometheus
    systemctl daemon-reload
    systemctl enable prometheus
    systemctl start prometheus
  EOF

  tags = {
    Name        = "${var.environment}-monitoring"
    Environment = var.environment
  }
}