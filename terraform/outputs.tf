output "instance_public_ips" { value = module.ec2.public_ips }
output "instance_public_dns" { value = module.ec2.public_dns }
output "public_subnet_ids" { value = module.vpc.public_subnet_ids }
output "security_group_id" { value = module.ec2.security_group_id }
output "iam_instance_role" { value = module.ec2.iam_instance_role }

# Outputs do CodeDeploy
output "codedeploy_application_name" {
  description = "Nome da aplicação CodeDeploy"
  value       = module.codedeploy.application_name
}
output "codedeploy_deployment_group_name" {
  description = "Nome do deployment group"
  value       = module.codedeploy.deployment_group_name
}
output "s3_bucket_name" {
  description = "Nome do bucket S3 para revisões"
  value       = module.codedeploy.s3_bucket_name
}
output "codedeploy_service_role_arn" {
  description = "ARN do role de serviço do CodeDeploy"
  value       = module.codedeploy.service_role_arn
}
