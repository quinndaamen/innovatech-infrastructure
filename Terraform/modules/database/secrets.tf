resource "aws_secretsmanager_secret" "database" {
  name = "${var.environment}/database"

  tags = {
    Name        = "${var.environment}-database-secret"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id

  secret_string = jsonencode({
    username = var.master_username
    password = var.master_password
  })
}