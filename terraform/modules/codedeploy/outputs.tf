output "application_name" {
  description = "Nome da aplicação CodeDeploy"
  value       = aws_codedeploy_app.this.name
}

output "deployment_group_name" {
  description = "Nome do deployment group"
  value       = aws_codedeploy_deployment_group.this.deployment_group_name
}

output "service_role_arn" {
  description = "ARN do role de serviço do CodeDeploy"
  value       = aws_iam_role.codedeploy_service_role.arn
}

output "s3_bucket_name" {
  description = "Nome do bucket S3 para revisões"
  value       = aws_s3_bucket.codedeploy_revisions.bucket
}

output "s3_bucket_arn" {
  description = "ARN do bucket S3 para revisões"
  value       = aws_s3_bucket.codedeploy_revisions.arn
}
