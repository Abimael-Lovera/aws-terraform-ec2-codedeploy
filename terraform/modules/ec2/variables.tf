variable "project_name" { type = string }
variable "environment" { type = string }
variable "subnet_id" { type = string }
variable "subnet_ids" {
	type    = list(string)
	default = []
}
variable "instance_count" {
	type    = number
	default = 1
}
variable "vpc_id" { type = string }
variable "instance_type" { type = string }
variable "key_name" { type = string }
variable "allowed_cidr" { type = string }
variable "http_port" { type = number }
variable "ssh_port" { type = number }
variable "allowed_cidr_ssh" { type = string }
variable "allowed_cidr_http" { type = string }
