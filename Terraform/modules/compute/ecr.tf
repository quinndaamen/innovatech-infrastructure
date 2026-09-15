resource "aws_ecr_repository" "app" {
  name = "${var.environment}-web"

  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.environment}-web"
    Environment = var.environment
  }
}