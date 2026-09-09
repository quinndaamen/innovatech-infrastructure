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


resource "aws_subnet" "compute_public_1" {
    vpc_id          = aws_vpc.compute.id
    cidr_block      = "10.1.1.0/24"
    availability_zone = data.aws_availability_zones.available.names[0]

    tags = {
        Name        = "${var.environment}-compute-public-1"
        Environment = var.environment
    }
}

resource "aws_subnet" "compute_public_2" {
    vpc_id          = aws_vpc.compute.id
    cidr_block      = "10.1.2.0/24"
    availability_zone = data.aws_availability_zones.available.names[1]

    tags = {
        Name        = "${var.environment}-compute-public-2"
        Environment = var.environment
    }
}


resource "aws_subnet" "compute_private_1" {
    vpc_id          = aws_vpc.compute.id
    cidr_block      = "10.1.11.0/24"
    availability_zone = data.aws_availability_zones.available.names[0]

    tags = {
        Name        = "${var.environment}-compute-private-1"
        Environment = var.environment
    }
}


resource "aws_subnet" "compute_private_2" {
    vpc_id          = aws_vpc.compute.id
    cidr_block      = "10.1.12.0/24"
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