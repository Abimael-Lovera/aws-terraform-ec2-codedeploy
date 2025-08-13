resource "aws_iam_role" "codedeploy_service_role" {
  name = "${var.project_name}-${var.environment}-codedeploy-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "codedeploy.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
  tags = {
    Name = "${var.project_name}-${var.environment}-codedeploy-service-role"
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_service" {
  role       = aws_iam_role.codedeploy_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
}

resource "aws_codedeploy_app" "this" {
  name             = "${var.project_name}-${var.environment}-app"
  compute_platform = "Server"
  tags = {
    Name = "${var.project_name}-${var.environment}-app"
  }
}

resource "aws_codedeploy_deployment_group" "groups" {
  for_each              = length(var.deployment_groups) > 0 ? var.deployment_groups : { default = [] }
  app_name              = aws_codedeploy_app.this.name
  deployment_group_name = length(var.deployment_groups) > 0 ? "${var.project_name}-${var.environment}-${each.key}" : "${var.project_name}-${var.environment}-dg"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn

  # Se houver lista de nomes, cria um único tag set com múltiplos filtros (OR)
  dynamic "ec2_tag_set" {
    for_each = length(each.value) > 0 ? [1] : []
    content {
      dynamic "ec2_tag_filter" {
        for_each = each.value
        content {
          key   = "Name"
          type  = "KEY_AND_VALUE"
          value = ec2_tag_filter.value
        }
      }
    }
  }

  dynamic "ec2_tag_set" {
    for_each = length(each.value) == 0 ? [1] : []
    content {
      ec2_tag_filter {
        key   = "Environment"
        type  = "KEY_AND_VALUE"
        value = var.environment
      }
    }
  }

  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type   = "IN_PLACE"
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  tags = {
    Name = length(var.deployment_groups) > 0 ? "${var.project_name}-${var.environment}-${each.key}" : "${var.project_name}-${var.environment}-dg"
  }
}

# Bucket S3 para armazenar revisões do CodeDeploy
resource "aws_s3_bucket" "codedeploy_revisions" {
  bucket = "${var.project_name}-codedeploy-revisions-${random_string.bucket_suffix.result}"

  tags = {
    Name = "${var.project_name}-codedeploy-revisions"
  }
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "codedeploy_revisions" {
  bucket = aws_s3_bucket.codedeploy_revisions.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codedeploy_revisions" {
  bucket = aws_s3_bucket.codedeploy_revisions.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "codedeploy_revisions" {
  bucket = aws_s3_bucket.codedeploy_revisions.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
