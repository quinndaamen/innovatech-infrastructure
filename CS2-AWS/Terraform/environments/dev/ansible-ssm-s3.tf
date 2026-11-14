resource "aws_s3_bucket" "ansible_ssm_transfer" {
  bucket = "innovatech-ansible-ssm-transfer-639962671417"

  tags = {
    Name        = "innovatech-ansible-ssm-transfer"
    Environment = "dev"
    Purpose     = "Ansible SSM temporary file transfer"
    ManagedBy   = "Terraform"
  }


}

resource "aws_s3_bucket_public_access_block" "ansible_ssm_transfer" {
  bucket = aws_s3_bucket.ansible_ssm_transfer.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "ansible_ssm_transfer" {
  bucket = aws_s3_bucket.ansible_ssm_transfer.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "ansible_ssm_transfer" {
  bucket = aws_s3_bucket.ansible_ssm_transfer.id

  rule {
    id     = "expire-temporary-ansible-files"
    status = "Enabled"

    filter {}

    expiration {
      days = 1
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}
