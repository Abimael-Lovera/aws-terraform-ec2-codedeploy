variable "project_name" {
	type    = string
	default = "contador-app"
}

variable "environment" {
	type    = string
	default = "dev"
}

variable "region" {
	type    = string
	default = "us-east-1"
}

variable "aws_profile" {
	description = "AWS profile a ser usado para autenticação"
	type        = string
	default     = "alm-yahoo-account"
}

variable "instance_type" {
	type    = string
	default = "t2.micro"
}

variable "key_name" {
	type = string
}

variable "allowed_cidr" {
	type    = string
	default = "0.0.0.0/0"
}

variable "subnet_index" {
	type    = number
	default = 0
	validation {
		condition     = var.subnet_index >= 0 && var.subnet_index < var.public_subnet_count
		error_message = "subnet_index deve ser >= 0 e menor que public_subnet_count."
	}
}

variable "http_port" {
	type    = number
	default = 8080
}

variable "ssh_port" {
	type    = number
	default = 22
}

# CIDRs específicos (se vazios, usa allowed_cidr)
variable "allowed_cidr_ssh" {
	type    = string
	default = ""
}

variable "allowed_cidr_http" {
	type    = string
	default = ""
}

variable "instance_count" {
	type    = number
	default = 1
}

variable "public_subnet_count" {
	description = "Número de subnets públicas a serem criadas"
	type        = number
	default     = 2
	validation {
		condition     = var.public_subnet_count >= 1 && var.public_subnet_count <= 6
		error_message = "public_subnet_count deve estar entre 1 e 6."
	}
}

variable "public_subnet_newbits" {
	description = "Quantidade de newbits para calcular o CIDR das subnets públicas"
	type        = number
	default     = 4
}

############################
# Validations auxiliares   #
############################

locals {
	# Se campos específicos vazios, reutiliza allowed_cidr
	effective_allowed_cidr_ssh  = length(trimspace(var.allowed_cidr_ssh)) > 0 ? var.allowed_cidr_ssh : var.allowed_cidr
	effective_allowed_cidr_http = length(trimspace(var.allowed_cidr_http)) > 0 ? var.allowed_cidr_http : var.allowed_cidr
}

