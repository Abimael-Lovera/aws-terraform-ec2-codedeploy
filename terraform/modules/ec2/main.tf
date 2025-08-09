data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_region" "current" {}

locals {
  effective_cidr_ssh  = var.allowed_cidr_ssh != "" ? var.allowed_cidr_ssh : var.allowed_cidr
  effective_cidr_http = var.allowed_cidr_http != "" ? var.allowed_cidr_http : var.allowed_cidr
}

resource "aws_security_group" "instance" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Allow app and SSH"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = [local.effective_cidr_ssh]
  }

  ingress {
    description = "APP"
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    cidr_blocks = [local.effective_cidr_http]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name             = "${var.project_name}-${var.environment}-sg"
    Environment      = var.environment
    ManagedBy        = "Terraform"
    application-name = var.project_name
  }
}

resource "aws_instance" "this" {
  count                  = var.instance_count
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = length(var.subnet_ids) > 0 ? element(var.subnet_ids, count.index % length(var.subnet_ids)) : var.subnet_id
  vpc_security_group_ids = [aws_security_group.instance.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.codedeploy_instance_profile.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20 # 20GB para ter espaço suficiente
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name             = "${var.project_name}-${var.environment}-ec2-${count.index}"
    Environment      = var.environment
    ManagedBy        = "Terraform"
    application-name = var.project_name
  }
  user_data = <<-EOT
              #!/bin/bash
              set -euo pipefail
              echo "[USER_DATA] Iniciando bootstrap" | logger -t user_data
              dnf install -y ruby wget amazon-cloudwatch-agent
              dnf install -y java-17-amazon-corretto-headless
              # Instala agente CodeDeploy
              REGION="${data.aws_region.current.name}"
              echo "[USER_DATA] Instalando CodeDeploy agent na região $REGION" | logger -t user_data
              cd /tmp
              wget https://aws-codedeploy-$REGION.s3.$REGION.amazonaws.com/latest/install
              chmod +x ./install
              ./install auto
              systemctl enable codedeploy-agent
              systemctl start codedeploy-agent || systemctl restart codedeploy-agent
              # Diretórios da aplicação
              id -u appuser 2>/dev/null || useradd -r -s /sbin/nologin appuser
              mkdir -p /opt/app /var/run/app
              chown -R appuser:appuser /opt/app /var/run/app
              touch /var/log/app.log
              chown appuser:appuser /var/log/app.log
              echo "[USER_DATA] Bootstrap finalizado" | logger -t user_data
              EOT
}

resource "aws_iam_role" "codedeploy_instance_role" {
  name = "${var.project_name}-${var.environment}-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = {
    Name             = "${var.project_name}-${var.environment}-instance-role"
    Environment      = var.environment
    ManagedBy        = "Terraform"
    application-name = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "codedeploy_instance" {
  role = aws_iam_role.codedeploy_instance_role.name
  # Permissões mínimas para o agente CodeDeploy na instância
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.codedeploy_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.codedeploy_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "codedeploy_instance_profile" {
  name = "${var.project_name}-${var.environment}-instance-profile"
  role = aws_iam_role.codedeploy_instance_role.name
  tags = {
    Name             = "${var.project_name}-${var.environment}-instance-profile"
    Environment      = var.environment
    ManagedBy        = "Terraform"
    application-name = var.project_name
  }
}
