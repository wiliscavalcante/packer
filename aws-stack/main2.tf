# Definindo o provedor e a região
provider "aws" {
  region = "sa-east-1"
}

# Configuração do Launch Template
resource "aws_launch_template" "example_launch_template" {
  name               = "example-launch-template"
  image_id           = "ami-0a9704d6387465eed"  # ID da AMI que você deseja usar
  instance_type      = "t3.small"
  vpc_security_group_ids = [aws_security_group.example_security_group.id]
  user_data = base64encode(local.user_data)

  # Adicionar uma função IAM existente ao launch template
  iam_instance_profile {
    name = "EC2AccessECS"
  }

  # Adicionar um par de chaves existente ao launch template
  key_name = "key_linux_becompliance"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type = "gp2"
      volume_size = 30
      delete_on_termination = true
    }
  }
}

# Criando um Application Load Balancer (ALB) interno
resource "aws_lb" "example_lb" {
  name               = "example-lb"
  internal           = true  # Definindo o ALB como interno
  load_balancer_type = "application"
  security_groups    = [aws_security_group.example_security_group.id]
  subnets            = ["subnet-08d47e590ecc0f621", "subnet-0bc945ea6d09519bc"]  # Subnets onde o ALB será criado
}

# Configurando a terminação TLS
resource "aws_lb_listener" "example_listener" {
  load_balancer_arn = aws_lb.example_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:sa-east-1:615519303364:certificate/a0d0a701-7065-40ae-aafc-76845b3407e0"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example_target_group.arn
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

# Criando uma instância EC2 a partir do Launch Template
resource "aws_instance" "example_instance" {
  ami           = aws_launch_template.example_launch_template.latest_version[0].image_id
  instance_type = aws_launch_template.example_launch_template.instance_type
  key_name      = aws_launch_template.example_launch_template.key_name
  user_data     = aws_launch_template.example_launch_template.user_data
  vpc_security_group_ids = aws_launch_template.example_launch_template.vpc_security_group_ids
  iam_instance_profile   = aws_launch_template.example_launch_template.iam_instance_profile
  block_device_mappings  = aws_launch_template.example_launch_template.block_device_mappings

  # Associando a instância ao target group do ALB
  vpc_security_group_ids = [aws_security_group.example_security_group.id]
  user_data              = base64encode(local.user_data)

  tags = {
    Name = "example-instance"
  }
}

# Criando um grupo de segurança
resource "aws_security_group" "example_security_group" {
  name        = "example-security-group"
  description = "Example security group"

  # Regras de entrada (exemplo: SSH e HTTP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
