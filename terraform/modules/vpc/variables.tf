variable "project_name" { type = string }
variable "environment" { type = string }
variable "cidr_block" { type = string }

# Número de subnets públicas a criar (cada uma em AZ distinta)
variable "public_subnet_count" {
	type    = number
	default = 2
}

# Quantos bits novos para subdividir CIDR principal (mantendo /24 para 2 subnets em /16 default -> newbits=8)
variable "public_subnet_newbits" {
	type    = number
	default = 8
}
