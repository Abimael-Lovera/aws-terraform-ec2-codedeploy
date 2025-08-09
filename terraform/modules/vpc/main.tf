resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name             = "${var.project_name}-${var.environment}-vpc"
    Environment      = var.environment
    ManagedBy        = "Terraform"
    application-name = var.project_name
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name             = "${var.project_name}-${var.environment}-igw"
    Environment      = var.environment
    ManagedBy        = "Terraform"
    application-name = var.project_name
  }
}

resource "aws_subnet" "public" {
  count                   = var.public_subnet_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr_block, var.public_subnet_newbits, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name             = "${var.project_name}-${var.environment}-public-${count.index}"
    Environment      = var.environment
    ManagedBy        = "Terraform"
    application-name = var.project_name
  }
}

data "aws_availability_zones" "available" {}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name             = "${var.project_name}-${var.environment}-public-rt"
    Environment      = var.environment
    ManagedBy        = "Terraform"
    application-name = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  count          = var.public_subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
