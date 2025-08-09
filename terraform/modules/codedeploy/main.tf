resource "aws_iam_role" "codedeploy_service_role" {
  name = "${var.project_name}-${var.environment}-codedeploy-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "codedeploy.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
  tags = {
    Name             = "${var.project_name}-${var.environment}-codedeploy-service-role"
    Environment      = var.environment
    ManagedBy        = "Terraform"
    application-name = var.project_name
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
    Name             = "${var.project_name}-${var.environment}-app"
    Environment      = var.environment
    ManagedBy        = "Terraform"
    application-name = var.project_name
  }
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name              = aws_codedeploy_app.this.name
  deployment_group_name = "${var.project_name}-${var.environment}-dg"
  service_role_arn      = aws_iam_role.codedeploy_service_role.arn

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Environment"
      type  = "KEY_AND_VALUE"
      value = var.environment
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
    Name             = "${var.project_name}-${var.environment}-dg"
    Environment      = var.environment
    ManagedBy        = "Terraform"
    application-name = var.project_name
  }
}
