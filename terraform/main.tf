module "vpc" {
  source                = "./modules/vpc"
  project_name          = var.project_name
  environment           = var.environment
  cidr_block            = "10.0.0.0/16"
  public_subnet_count   = var.public_subnet_count
  public_subnet_newbits = var.public_subnet_newbits
}

module "ec2" {
  source       = "./modules/ec2"
  project_name = var.project_name
  environment  = var.environment
  # Escolhe subnet pela variável subnet_index
  subnet_id         = module.vpc.public_subnet_ids[var.subnet_index]
  subnet_ids        = module.vpc.public_subnet_ids
  vpc_id            = module.vpc.vpc_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  allowed_cidr      = var.allowed_cidr
  http_port         = var.http_port
  ssh_port          = var.ssh_port
  allowed_cidr_http = var.allowed_cidr_http
  allowed_cidr_ssh  = var.allowed_cidr_ssh
  instance_count    = var.instance_count
}

module "codedeploy" {
  source            = "./modules/codedeploy"
  project_name      = var.project_name
  environment       = var.environment
  service_role_name = "${var.project_name}-codedeploy-role"
  deployment_groups = var.deployment_groups
}
