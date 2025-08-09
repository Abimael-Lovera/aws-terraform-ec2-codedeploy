output "public_ips" { value = [for i in aws_instance.this : i.public_ip] }
output "public_dns" { value = [for i in aws_instance.this : i.public_dns] }
output "instance_ids" { value = [for i in aws_instance.this : i.id] }
output "instance_names" { value = [for i in aws_instance.this : i.tags["Name"]] }
output "security_group_id" { value = aws_security_group.instance.id }
output "iam_instance_role" { value = aws_iam_role.codedeploy_instance_role.name }
