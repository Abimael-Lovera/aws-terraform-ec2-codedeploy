output "instance_public_ips" { value = module.ec2.public_ips }
output "instance_public_dns" { value = module.ec2.public_dns }
output "public_subnet_ids" { value = module.vpc.public_subnet_ids }
output "security_group_id" { value = module.ec2.security_group_id }
output "iam_instance_role" { value = module.ec2.iam_instance_role }
