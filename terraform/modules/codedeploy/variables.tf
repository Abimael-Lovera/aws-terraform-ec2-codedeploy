variable "project_name" { type = string }
variable "environment" { type = string }
variable "service_role_name" { type = string }

# Mapa opcional de deployment groups -> lista de nomes (tag Name) das instâncias EC2.
# Ex: { g1 = ["contador-app-dev-ec2-0","contador-app-dev-ec2-1"], g2 = ["contador-app-dev-ec2-2","contador-app-dev-ec2-3"] }
variable "deployment_groups" {
  type    = map(list(string))
  default = {}
}
