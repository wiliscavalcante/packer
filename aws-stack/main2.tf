# Definindo o provedor e a região
provider "aws" {
  region = "sa-east-1"
}

locals {
  user_data = <<-EOF
    #!/bin/bash

    # Atualizar o sistema
    yum update -y

    # Instalar o Docker
    yum install -y docker
    service docker start

    # Adicionar o usuário ec2-user ao grupo Docker
    usermod -a -G docker ec2-user

    # Outras configurações e comandos de inicialização da instância
    yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm

    # Fim do script de inicialização
  EOF
}

# Criando uma instância EC2
resource "aws_instance" "example_instance" {
  ami                    = "ami-0a9704d6387465eed"  # ID da AMI que você deseja usar
  instance_type          = "t3.small"
  subnet_id              = "subnet-08d47e590ecc0f621"  # Subnet onde a instância será criada
  associate_public_ip_address = true

  # Definindo o user data para configuração da instância (opcional)
  user_data = base64encode(local.user_data)

  # Adicionar uma função IAM existente à instância
  iam_instance_profile {
    name = "EC2AccessECS"
  }

  # Adicionar um par de chaves existente à instância
  key_name = "key_linux_becompliance"

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 30
    delete_on_termination = true
  }

  tags = {
    Name = "example-instance"
  }
}

# Criando um Application Load Balancer (ALB) interno
resource "aws_lb" "example_lb" {
  name               = "example-lb"
  internal           = true  # Definindo o ALB como interno
  load_balancer_type = "application"
  subnets            = ["subnet-08d47e590ecc0f621"]  # Subnet onde o ALB será criado

  # Configurando a terminação TLS
  listener {
    port              = 443
    protocol          = "HTTPS"
    ssl_policy        = "ELBSecurityPolicy-2016-08"
    certificate_arn   = "arn:aws:acm:sa-east-1:615519303364:certificate/a0d0a701-7065-40ae-aafc-76845b3407e0"

    default_action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.example_target_group.arn
    }
  }
}

# Criando um target group para associar com o ALB
resource "aws_lb_target_group" "example_target_group" {
  name        = "example-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-b4efa2d3"  # ID da VPC onde o ALB será criado

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    port                = "traffic-port"
  }
}

# Associando a instância ao Target Group
resource "aws_lb_target_group_attachment" "example_attachment" {
  target_group_arn = aws_lb_target_group.example_target_group.arn
  target_id        = aws_instance.example_instance.id
  port             = 80
}
