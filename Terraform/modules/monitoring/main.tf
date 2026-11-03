# ============================================================
# DATA SOURCE: AMAZON LINUX 2023
# ============================================================

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
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

data "aws_caller_identity" "current" {}

# ============================================================
# SECURITY GROUP: ELASTICSEARCH
# ============================================================

resource "aws_security_group" "elasticsearch" {
  name        = "${var.environment}-elasticsearch-sg"
  description = "Security group for Elasticsearch"
  vpc_id      = var.vpc_id

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-elasticsearch-sg"
    Environment = var.environment
    Service     = "Elasticsearch"
  }
}


# ============================================================
# SECURITY GROUP: LOGSTASH
# ============================================================

resource "aws_security_group" "logstash" {
  name        = "${var.environment}-logstash-sg"
  description = "Security group for Logstash"
  vpc_id      = var.vpc_id

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-logstash-sg"
    Environment = var.environment
    Service     = "Logstash"
  }
}



# ============================================================
# SECURITY GROUP: KIBANA
# ============================================================

resource "aws_security_group" "kibana" {
  name        = "${var.environment}-kibana-sg"
  description = "Security group for Kibana"
  vpc_id      = var.vpc_id

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-kibana-sg"
    Environment = var.environment
    Service     = "Kibana"
  }
}

# ============================================================
# SECURITY GROUP RULES: ELASTICSEARCH
# ============================================================

resource "aws_vpc_security_group_ingress_rule" "elasticsearch_from_logstash" {
  security_group_id            = aws_security_group.elasticsearch.id
  referenced_security_group_id = aws_security_group.logstash.id
  description                  = "Allow Logstash to send logs to Elasticsearch"
  ip_protocol                  = "tcp"
  from_port                    = 9200
  to_port                      = 9200
}

resource "aws_vpc_security_group_ingress_rule" "elasticsearch_from_kibana" {
  security_group_id            = aws_security_group.elasticsearch.id
  referenced_security_group_id = aws_security_group.kibana.id
  description                  = "Allow Kibana to query Elasticsearch"
  ip_protocol                  = "tcp"
  from_port                    = 9200
  to_port                      = 9200
}

# logstash

resource "aws_vpc_security_group_ingress_rule" "logstash_from_compute" {
  security_group_id = aws_security_group.logstash.id
  cidr_ipv4         = "10.1.0.0/16"

  description = "Allow Beats traffic from Compute VPC"
  ip_protocol = "tcp"
  from_port   = 5044
  to_port     = 5044
}

resource "aws_vpc_security_group_ingress_rule" "logstash_from_onprem" {
  security_group_id = aws_security_group.logstash.id
  cidr_ipv4         = "10.50.0.0/16"

  description = "Allow Beats traffic from simulated on-premises VPC"
  ip_protocol = "tcp"
  from_port   = 5044
  to_port     = 5044
}

# ============================================================
# SECURITY GROUP RULES: KIBANA
# ============================================================

resource "aws_vpc_security_group_ingress_rule" "kibana_from_compute" {
  security_group_id = aws_security_group.kibana.id
  cidr_ipv4         = "10.1.0.0/16"
  description       = "Allow Kibana access from the Compute VPC"
  ip_protocol       = "tcp"
  from_port         = 5601
  to_port           = 5601
}

# ============================================================
# IAM ROLE: ELASTIC STACK
# ============================================================

resource "aws_iam_role" "elastic" {
  name = "${var.environment}-elastic-ec2-role"

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
    Name        = "${var.environment}-elastic-ec2-role"
    Environment = var.environment
  }
}

# ============================================================
# IAM POLICY: SYSTEMS MANAGER
# ============================================================

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.elastic.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ============================================================
# IAM INSTANCE PROFILE
# ============================================================

resource "aws_iam_instance_profile" "elastic" {
  name = "${var.environment}-elastic-instance-profile"
  role = aws_iam_role.elastic.name
}

# ============================================================
# EC2 INSTANCE: ELASTICSEARCH
# ============================================================

resource "aws_instance" "elasticsearch" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.elasticsearch_instance_type
  subnet_id     = var.private_subnet_ids[0]

  vpc_security_group_ids = [
    aws_security_group.elasticsearch.id
  ]

  iam_instance_profile        = aws_iam_instance_profile.elastic.name
  associate_public_ip_address = false

  root_block_device {
    volume_size           = var.elasticsearch_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${var.environment}-elasticsearch"
    Environment = var.environment
    Service     = "Elasticsearch"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ============================================================
# EC2 INSTANCE: LOGSTASH
# ============================================================

resource "aws_instance" "logstash" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.logstash_instance_type
  subnet_id     = var.private_subnet_ids[0]

  vpc_security_group_ids = [
    aws_security_group.logstash.id
  ]

  iam_instance_profile        = aws_iam_instance_profile.elastic.name
  associate_public_ip_address = false

  root_block_device {
    volume_size           = var.logstash_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${var.environment}-logstash"
    Environment = var.environment
    Service     = "Logstash"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ============================================================
# EC2 INSTANCE: KIBANA
# ============================================================

resource "aws_instance" "kibana" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.kibana_instance_type
  subnet_id     = var.private_subnet_ids[1]

  vpc_security_group_ids = [
    aws_security_group.kibana.id
  ]

  iam_instance_profile        = aws_iam_instance_profile.elastic.name
  associate_public_ip_address = false

  root_block_device {
    volume_size           = var.kibana_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${var.environment}-kibana"
    Environment = var.environment
    Service     = "Kibana"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# ============================================================
# S3 BUCKET: ELASTIC INSTALLATION PACKAGES
# ============================================================

resource "aws_s3_bucket" "elastic_packages" {
  bucket = "innovatech-${var.environment}-elastic-packages-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "innovatech-${var.environment}-elastic-packages"
    Environment = var.environment
    Purpose     = "Elastic Stack installation packages"
  }
  lifecycle {
    prevent_destroy = true
  }


}

resource "aws_s3_bucket_public_access_block" "elastic_packages" {
  bucket = aws_s3_bucket.elastic_packages.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "elastic_packages" {
  bucket = aws_s3_bucket.elastic_packages.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ============================================================
# IAM POLICY: DOWNLOAD ELASTIC PACKAGES
# ============================================================

resource "aws_iam_role_policy" "elastic_s3_read" {
  name = "${var.environment}-elastic-s3-read"
  role = aws_iam_role.elastic.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = [
          "${aws_s3_bucket.elastic_packages.arn}/*"
        ]
      },
      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = [
          aws_s3_bucket.elastic_packages.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.elastic_packages.arn}/certs/http_ca.crt"
        ]
      }
    ]
  })
}

# ============================================================
# IAM POLICY: KIBANA SERVICE ACCOUNT TOKEN
# ============================================================

resource "aws_iam_role_policy" "elastic_ssm_parameter_read" {
  name = "${var.environment}-elastic-ssm-parameter-access"
  role = aws_iam_role.elastic.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter"
        ]

        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/innovatech/${var.environment}/kibana/service-account-token",

          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/innovatech/${var.environment}/logstash/api-key"
        ]
      }
    ]
  })
}

# ============================================================
# S3 OBJECT: ELASTICSEARCH PACKAGE
# ============================================================

resource "aws_s3_object" "elasticsearch_package" {
  bucket = aws_s3_bucket.elastic_packages.id
  key    = "elasticsearch/elasticsearch-${var.elastic_version}-linux-x86_64.tar.gz"

  source = "${path.module}/files/elastic/elasticsearch-${var.elastic_version}-linux-x86_64.tar.gz"

  source_hash = filemd5(
    "${path.module}/files/elastic/elasticsearch-${var.elastic_version}-linux-x86_64.tar.gz"
  )

  server_side_encryption = "AES256"
}

# ============================================================
# S3 OBJECT: ELASTICSEARCH INSTALLATION SCRIPT
# ============================================================

resource "aws_s3_object" "elasticsearch_install_script" {
  bucket = aws_s3_bucket.elastic_packages.id
  key    = "scripts/install-elasticsearch.sh"

  source = "${path.module}/files/elastic/scripts/install-elasticsearch.sh"

  source_hash = filemd5(
    "${path.module}/files/elastic/scripts/install-elasticsearch.sh"
  )

  server_side_encryption = "AES256"
}

# ============================================================
# S3 OBJECT: LOGSTASH PACKAGE
# ============================================================

resource "aws_s3_object" "logstash_package" {
  bucket = aws_s3_bucket.elastic_packages.id
  key    = "logstash/logstash-${var.elastic_version}-linux-x86_64.tar.gz"

  source = "${path.module}/files/elastic/logstash-${var.elastic_version}-linux-x86_64.tar.gz"

  source_hash = filemd5(
    "${path.module}/files/elastic/logstash-${var.elastic_version}-linux-x86_64.tar.gz"
  )

  server_side_encryption = "AES256"
}

# ============================================================
# S3 OBJECT: KIBANA PACKAGE
# ============================================================

resource "aws_s3_object" "kibana_package" {
  bucket = aws_s3_bucket.elastic_packages.id
  key    = "kibana/kibana-${var.elastic_version}-linux-x86_64.tar.gz"

  source = "${path.module}/files/elastic/kibana-${var.elastic_version}-linux-x86_64.tar.gz"

  source_hash = filemd5(
    "${path.module}/files/elastic/kibana-${var.elastic_version}-linux-x86_64.tar.gz"
  )

  server_side_encryption = "AES256"
}

# ============================================================
# LOCALS: RENDER ELASTICSEARCH INSTALLATION SCRIPT
# ============================================================

locals {
elasticsearch_install_script = replace(
  replace(
    replace(
      replace(
        replace(
          file("${path.module}/files/elastic/scripts/install-elasticsearch.sh"),
          "__ENVIRONMENT__",
          var.environment
        ),
        "__ELASTIC_VERSION__",
        var.elastic_version
      ),
      "__ELASTIC_BUCKET__",
      aws_s3_bucket.elastic_packages.id
    ),
    "__AWS_REGION__", 
    var.aws_region
  ),
  "__ELASTICSEARCH_PRIVATE_IP__",
  aws_instance.elasticsearch.private_ip
)


    kibana_install_script = replace(
    replace(
      replace(
        replace(
          replace(
            replace(
              file("${path.module}/files/elastic/scripts/install-kibana.sh"),
              "__ENVIRONMENT__",
              var.environment
            ),
            "__ELASTIC_VERSION__",
            var.elastic_version
          ),
          "__ELASTIC_BUCKET__",
          aws_s3_bucket.elastic_packages.id
        ),
        "__AWS_REGION__",
        var.aws_region
      ),
      "__KIBANA_PRIVATE_IP__",
      aws_instance.kibana.private_ip
    ),
    "__ELASTICSEARCH_PRIVATE_IP__",
    aws_instance.elasticsearch.private_ip
  )

  logstash_install_script = replace(
  replace(
    replace(
      replace(
        replace(
          file("${path.module}/files/elastic/scripts/install-logstash.sh"),
          "__ELASTIC_VERSION__",
          var.elastic_version
        ),
        "__ELASTIC_BUCKET__",
        aws_s3_bucket.elastic_packages.id
      ),
      "__AWS_REGION__",
      var.aws_region
    ),
    "__ELASTICSEARCH_PRIVATE_IP__",
    aws_instance.elasticsearch.private_ip
  ),
  "__ENVIRONMENT__",
  var.environment
)
}

# ============================================================
# SSM DOCUMENT: INSTALL ELASTICSEARCH
# ============================================================

resource "aws_ssm_document" "install_elasticsearch" {
  name            = "${var.environment}-install-elasticsearch"
  document_type   = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Install and configure Elasticsearch"

    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "installElasticsearch"

        inputs = {
          runCommand = [
            "set -e",
            "cat > /tmp/install-elasticsearch.sh <<'INSTALL_SCRIPT'",
            local.elasticsearch_install_script,
            "INSTALL_SCRIPT",
            "chmod 700 /tmp/install-elasticsearch.sh",
            "bash /tmp/install-elasticsearch.sh"
          ]
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Service     = "Elasticsearch"
  }
}

# ============================================================
# SSM ASSOCIATION: INSTALL ELASTICSEARCH
# ============================================================

resource "aws_ssm_association" "install_elasticsearch" {
  name             = aws_ssm_document.install_elasticsearch.name
  association_name = "${var.environment}-install-elasticsearch"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.elasticsearch.id]
  }

  wait_for_success_timeout_seconds = 900

  depends_on = [
    aws_s3_object.elasticsearch_package,
    aws_s3_object.elasticsearch_install_script,
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy.elastic_s3_read,
  ]
}

# ============================================================
# S3 OBJECT: KIBANA INSTALLATION SCRIPT
# ============================================================

resource "aws_s3_object" "kibana_install_script" {
  bucket = aws_s3_bucket.elastic_packages.id
  key    = "scripts/install-kibana.sh"

  source = "${path.module}/files/elastic/scripts/install-kibana.sh"

  source_hash = filemd5(
    "${path.module}/files/elastic/scripts/install-kibana.sh"
  )

  server_side_encryption = "AES256"
}

# ============================================================
# SSM DOCUMENT: INSTALL KIBANA
# ============================================================

resource "aws_ssm_document" "install_kibana" {
  name            = "${var.environment}-install-kibana"
  document_type   = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Install and configure Kibana"

    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "installKibana"

        inputs = {
          runCommand = [
            "set -e",
            "cat > /tmp/install-kibana.sh <<'INSTALL_SCRIPT'",
            local.kibana_install_script,
            "INSTALL_SCRIPT",
            "chmod 700 /tmp/install-kibana.sh",
            "bash /tmp/install-kibana.sh"
          ]
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Service     = "Kibana"
  }
}

# ============================================================
# SSM ASSOCIATION: INSTALL KIBANA
# ============================================================

resource "aws_ssm_association" "install_kibana" {
  name             = aws_ssm_document.install_kibana.name
  association_name = "${var.environment}-install-kibana"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.kibana.id]
  }

  wait_for_success_timeout_seconds = 900

  depends_on = [
    aws_s3_object.kibana_package,
    aws_s3_object.kibana_install_script,
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy.elastic_s3_read,
    aws_iam_role_policy.elastic_ssm_parameter_read,
    aws_ssm_association.install_elasticsearch,
    aws_iam_role_policy_attachment.ssm
  ]
}

# ============================================================
# S3 OBJECT: LOGSTASH INSTALLATION SCRIPT
# ============================================================

resource "aws_s3_object" "logstash_install_script" {
  bucket = aws_s3_bucket.elastic_packages.id
  key    = "scripts/install-logstash.sh"

  source = "${path.module}/files/elastic/scripts/install-logstash.sh"

  source_hash = filemd5(
    "${path.module}/files/elastic/scripts/install-logstash.sh"
  )

  server_side_encryption = "AES256"
}

# ============================================================
# SSM DOCUMENT: INSTALL LOGSTASH
# ============================================================

resource "aws_ssm_document" "install_logstash" {
  name            = "${var.environment}-install-logstash"
  document_type   = "Command"
  document_format = "YAML"

  content = yamlencode({
    schemaVersion = "2.2"
    description   = "Install and configure Logstash"

    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "installLogstash"

        inputs = {
          runCommand = [
            "set -e",
            "cat > /tmp/install-logstash.sh <<'INSTALL_SCRIPT'",
            local.logstash_install_script,
            "INSTALL_SCRIPT",
            "chmod 700 /tmp/install-logstash.sh",
            "bash /tmp/install-logstash.sh"
          ]
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Service     = "Logstash"
  }
}

# ============================================================
# SSM ASSOCIATION: INSTALL LOGSTASH
# ============================================================

resource "aws_ssm_association" "install_logstash" {
  name             = aws_ssm_document.install_logstash.name
  association_name = "${var.environment}-install-logstash"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.logstash.id]
  }

  wait_for_success_timeout_seconds = 900

  depends_on = [
    aws_s3_object.logstash_package,
    aws_s3_object.logstash_install_script,
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy.elastic_s3_read,
    aws_iam_role_policy.elastic_ssm_parameter_read,
    aws_ssm_association.install_elasticsearch,
  ]
}