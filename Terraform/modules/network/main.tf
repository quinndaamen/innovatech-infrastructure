# VPC creations

resource "aws_vpc" "compute" {
  cidr_block           = var.compute_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-compute-vpc"
    Environment = var.environment
  }
}

resource "aws_vpc" "database" {
  cidr_block           = var.database_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-database-vpc"
    Environment = var.environment
  }
}

resource "aws_vpc" "monitoring" {
  cidr_block           = var.monitoring_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.environment}-monitoring-vpc"
    Environment = var.environment
  }
}


# Subnet Creations

resource "aws_subnet" "compute_public_1" {
  vpc_id            = aws_vpc.compute.id
  cidr_block        = "10.1.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.environment}-compute-public-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "compute_public_2" {
  vpc_id            = aws_vpc.compute.id
  cidr_block        = "10.1.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.environment}-compute-public-2"
    Environment = var.environment
  }
}

resource "aws_subnet" "compute_private_1" {
  vpc_id            = aws_vpc.compute.id
  cidr_block        = "10.1.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.environment}-compute-private-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "compute_private_2" {
  vpc_id            = aws_vpc.compute.id
  cidr_block        = "10.1.12.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.environment}-compute-private-2"
    Environment = var.environment
  }
}

resource "aws_subnet" "database_private_1" {
  vpc_id            = aws_vpc.database.id
  cidr_block        = "10.2.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.environment}-database-private-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "database_private_2" {
  vpc_id            = aws_vpc.database.id
  cidr_block        = "10.2.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.environment}-database-private-2"
    Environment = var.environment
  }
}

resource "aws_subnet" "monitoring_private_1" {
  vpc_id            = aws_vpc.monitoring.id
  cidr_block        = "10.3.1.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = "${var.environment}-monitoring-private-1"
    Environment = var.environment
  }
}

resource "aws_subnet" "monitoring_private_2" {
  vpc_id            = aws_vpc.monitoring.id
  cidr_block        = "10.3.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name        = "${var.environment}-monitoring-private-2"
    Environment = var.environment
  }
}


# Internet gateway creation

resource "aws_internet_gateway" "compute" {
  vpc_id = aws_vpc.compute.id

  tags = {
    Name        = "${var.environment}-compute-igw"
    Environment = var.environment
  }
}


# Route table and route for compute public

resource "aws_route_table" "compute_public" {
  vpc_id = aws_vpc.compute.id

  tags = {
    Name        = "${var.environment}-compute-public-rt"
    Environment = var.environment
  }
}

resource "aws_route" "compute_public_internet" {
  route_table_id         = aws_route_table.compute_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.compute.id
}

resource "aws_route_table_association" "compute_public_1" {
  subnet_id      = aws_subnet.compute_public_1.id
  route_table_id = aws_route_table.compute_public.id
}

resource "aws_route_table_association" "compute_public_2" {
  subnet_id      = aws_subnet.compute_public_2.id
  route_table_id = aws_route_table.compute_public.id
}


resource "aws_route_table" "compute_private" {
  vpc_id = aws_vpc.compute.id

  tags = {
    Name        = "${var.environment}-compute-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "compute_private_1" {
  subnet_id      = aws_subnet.compute_private_1.id
  route_table_id = aws_route_table.compute_private.id
}

resource "aws_route_table_association" "compute_private_2" {
  subnet_id      = aws_subnet.compute_private_2.id
  route_table_id = aws_route_table.compute_private.id
}


resource "aws_route_table" "database_private" {
  vpc_id = aws_vpc.database.id

  tags = {
    Name        = "${var.environment}-database-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "database_private_1" {
  subnet_id      = aws_subnet.database_private_1.id
  route_table_id = aws_route_table.database_private.id
}

resource "aws_route_table_association" "database_private_2" {
  subnet_id      = aws_subnet.database_private_2.id
  route_table_id = aws_route_table.database_private.id
}


resource "aws_route_table" "monitoring_private" {
  vpc_id = aws_vpc.monitoring.id

  tags = {
    Name        = "${var.environment}-monitoring-private-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "monitoring_private_1" {
  subnet_id      = aws_subnet.monitoring_private_1.id
  route_table_id = aws_route_table.monitoring_private.id
}

resource "aws_route_table_association" "monitoring_private_2" {
  subnet_id      = aws_subnet.monitoring_private_2.id
  route_table_id = aws_route_table.monitoring_private.id
}


# Transit Gateway

resource "aws_ec2_transit_gateway" "main" {
  description = "${var.environment}-transit-gateway"

  tags = {
    Name        = "${var.environment}-transit-gateway"
    Environment = var.environment
  }
}


resource "aws_ec2_transit_gateway_vpc_attachment" "compute" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.compute.id

  subnet_ids = [
    aws_subnet.compute_private_1.id,
    aws_subnet.compute_private_2.id
  ]

  tags = {
    Name        = "${var.environment}-compute-tgw-attachment"
    Environment = var.environment
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "database" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.database.id

  subnet_ids = [
    aws_subnet.database_private_1.id,
    aws_subnet.database_private_2.id
  ]

  tags = {
    Name        = "${var.environment}-database-tgw-attachment"
    Environment = var.environment
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "monitoring" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.monitoring.id

  subnet_ids = [
    aws_subnet.monitoring_private_1.id,
    aws_subnet.monitoring_private_2.id
  ]

  tags = {
    Name        = "${var.environment}-monitoring-tgw-attachment"
    Environment = var.environment
  }
}


# Routes through TGW

# Compute

resource "aws_route" "compute_to_database" {
  route_table_id         = aws_route_table.compute_private.id
  destination_cidr_block = var.database_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

resource "aws_route" "compute_to_monitoring" {
  route_table_id         = aws_route_table.compute_private.id
  destination_cidr_block = var.monitoring_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}


# Database

resource "aws_route" "database_to_compute" {
  route_table_id         = aws_route_table.database_private.id
  destination_cidr_block = var.compute_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

resource "aws_route" "database_to_monitoring" {
  route_table_id         = aws_route_table.database_private.id
  destination_cidr_block = var.monitoring_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}


# Monitoring

resource "aws_route" "monitoring_to_compute" {
  route_table_id         = aws_route_table.monitoring_private.id
  destination_cidr_block = var.compute_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}

resource "aws_route" "monitoring_to_database" {
  route_table_id         = aws_route_table.monitoring_private.id
  destination_cidr_block = var.database_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main.id
}


# Security group for Compute VPC interface endpoints

resource "aws_security_group" "compute_vpc_endpoints" {
  name        = "${var.environment}-compute-vpc-endpoints-sg"
  description = "Security group for VPC interface endpoints"
  vpc_id      = aws_vpc.compute.id

  ingress {
    description = "Allow HTTPS from Compute VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.compute_vpc_cidr]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-compute-vpc-endpoints-sg"
    Environment = var.environment
  }
}


# ECR API interface endpoint

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.compute.id
  service_name        = "com.amazonaws.eu-central-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.compute_private_1.id,
    aws_subnet.compute_private_2.id
  ]

  security_group_ids = [
    aws_security_group.compute_vpc_endpoints.id
  ]

  tags = {
    Name        = "${var.environment}-ecr-api-endpoint"
    Environment = var.environment
  }
}


# ECR Docker registry interface endpoint

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.compute.id
  service_name        = "com.amazonaws.eu-central-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.compute_private_1.id,
    aws_subnet.compute_private_2.id
  ]

  security_group_ids = [
    aws_security_group.compute_vpc_endpoints.id
  ]

  tags = {
    Name        = "${var.environment}-ecr-dkr-endpoint"
    Environment = var.environment
  }
}


# S3 gateway endpoint for ECR image layers

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.compute.id
  service_name      = "com.amazonaws.eu-central-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.compute_private.id
  ]

  tags = {
    Name        = "${var.environment}-s3-endpoint"
    Environment = var.environment
  }
}


# Secrets Manager interface endpoint for ECS tasks
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.compute.id
  service_name        = "com.amazonaws.eu-central-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.compute_private_1.id,
    aws_subnet.compute_private_2.id
  ]

  security_group_ids = [
    aws_security_group.compute_vpc_endpoints.id
  ]

  tags = {
    Name        = "${var.environment}-secretsmanager-endpoint"
    Environment = var.environment
  }
}


# S3 gateway endpoint for Monitoring VPC
resource "aws_vpc_endpoint" "monitoring_s3" {
  vpc_id            = aws_vpc.monitoring.id
  service_name      = "com.amazonaws.eu-central-1.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.monitoring_private.id
  ]

  tags = {
    Name        = "${var.environment}-monitoring-s3-endpoint"
    Environment = var.environment
  }
}


# Security group for Monitoring VPC interface endpoints

resource "aws_security_group" "monitoring_vpc_endpoints" {
  name        = "${var.environment}-monitoring-vpc-endpoints-sg"
  description = "Security group for SSM VPC interface endpoints"
  vpc_id      = aws_vpc.monitoring.id

  ingress {
    description = "Allow HTTPS from Monitoring VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.monitoring_vpc_cidr]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-monitoring-vpc-endpoints-sg"
    Environment = var.environment
  }
}


# AWS Systems Manager endpoint

resource "aws_vpc_endpoint" "monitoring_ssm" {
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.eu-central-1.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.monitoring_private_1.id,
    aws_subnet.monitoring_private_2.id
  ]

  security_group_ids = [
    aws_security_group.monitoring_vpc_endpoints.id
  ]

  tags = {
    Name        = "${var.environment}-monitoring-ssm-endpoint"
    Environment = var.environment
  }
}


# AWS Systems Manager Messages endpoint

resource "aws_vpc_endpoint" "monitoring_ssmmessages" {
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.eu-central-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.monitoring_private_1.id,
    aws_subnet.monitoring_private_2.id
  ]

  security_group_ids = [
    aws_security_group.monitoring_vpc_endpoints.id
  ]

  tags = {
    Name        = "${var.environment}-monitoring-ssmmessages-endpoint"
    Environment = var.environment
  }
}


# EC2 Messages endpoint

resource "aws_vpc_endpoint" "monitoring_ec2messages" {
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.eu-central-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.monitoring_private_1.id,
    aws_subnet.monitoring_private_2.id
  ]

  security_group_ids = [
    aws_security_group.monitoring_vpc_endpoints.id
  ]

  tags = {
    Name        = "${var.environment}-monitoring-ec2messages-endpoint"
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint" "monitoring_cloudwatch" {
  vpc_id              = aws_vpc.monitoring.id
  service_name        = "com.amazonaws.eu-central-1.monitoring"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.monitoring_private_1.id,
    aws_subnet.monitoring_private_2.id
  ]

  security_group_ids = [
    aws_security_group.monitoring_vpc_endpoints.id
  ]

  tags = {
    Name        = "${var.environment}-monitoring-cloudwatch"
    Environment = var.environment
  }
}