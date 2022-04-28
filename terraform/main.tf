terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "my_vpc_module" {
  source = "./vpc"
}

resource "aws_ecs_cluster" "dash-ecs-cluster" {
  name = "dash-ecs-cluster"
}

resource "aws_iam_role" "ecs_task_execution_iam_role" {
  name = "ecs_task_execution_iam_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
  })

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

resource "aws_ecs_task_definition" "dash-app-1" {
  family                   = "dash-app-1"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  task_role_arn            = aws_iam_role.ecs_task_execution_iam_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_iam_role.arn
  container_definitions    = <<TASK_DEFINITION
[
        {
            "portMappings": [
                {
                    "protocol": "tcp",
                    "containerPort": 8050
                }
            ],
            "environment": [
                {
                    "name": "PORT",
                    "value": "8050"
                }
            ],
            "image": "montumodi/test-dash",
            "name": "dash-app-1"
        }
    ]
TASK_DEFINITION
}

resource "aws_ecs_task_definition" "dash-app-2" {
  family                   = "dash-app-2"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  task_role_arn            = aws_iam_role.ecs_task_execution_iam_role.arn
  execution_role_arn       = aws_iam_role.ecs_task_execution_iam_role.arn
  container_definitions    = <<TASK_DEFINITION
[
        {
            "portMappings": [
                {
                    "protocol": "tcp",
                    "containerPort": 8050
                }
            ],
            "environment": [
                {
                    "name": "PORT",
                    "value": "8050"
                }
            ],
            "image": "montumodi/test-dash-v2",
            "name": "dash-app-2"
        }
    ]
TASK_DEFINITION
}

resource "aws_security_group" "Load-Balancer-SG" {
  name        = "Load-Balancer-SG"
  description = "SG to allow access from everywhere on port 80"
  vpc_id      = module.my_vpc_module.vpc_id

  ingress {
    description = "Allow access from everywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow access from everywhere"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  tags = {
    Name = "Load-Balancer-SG"
  }
}

resource "aws_security_group" "Dash-SG" {
  name        = "Dash-SG"
  description = "SG to allow access from load balancer security group on port 8050"
  vpc_id      = module.my_vpc_module.vpc_id

  ingress {
    description     = "Allow access from load balancer security group"
    from_port       = 8050
    to_port         = 8050
    protocol        = "tcp"
    security_groups = [aws_security_group.Load-Balancer-SG.id]
  }

  egress {
    description = "Allow access from everywhere"
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  tags = {
    Name = "Dash-SG"
  }
}

resource "aws_lb_target_group" "dash-app-1-tg" {
  name        = "dash-app-1-tg"
  port        = 8050
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.my_vpc_module.vpc_id
  health_check {
    path = "/apps/dash-app-1/"
  }
}

resource "aws_lb_target_group" "dash-app-2-tg" {
  name        = "dash-app-2-tg"
  port        = 8050
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.my_vpc_module.vpc_id
  health_check {
    path = "/apps/dash-app-2/"
  }
}

resource "aws_lb" "dash-load-balancer" {
  name               = "dash-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.Load-Balancer-SG.id]
  subnets            = [module.my_vpc_module.public_subnet_a_id, module.my_vpc_module.public_subnet_b_id]
}

resource "aws_lb_listener" "default_listener" {
  load_balancer_arn = aws_lb.dash-load-balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "This path doesnt exists"
      status_code  = "503"
    }
  }
}

resource "aws_lb_listener_rule" "path_based_routing_for_dash_app_1" {
  listener_arn = aws_lb_listener.default_listener.arn
  priority     = 99

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dash-app-1-tg.arn
  }

  condition {
    path_pattern {
      values = ["/apps/dash-app-1*"]
    }
  }
}

resource "aws_lb_listener_rule" "path_based_routing_for_dash_app_2" {
  listener_arn = aws_lb_listener.default_listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dash-app-2-tg.arn
  }

  condition {
    path_pattern {
      values = ["/apps/dash-app-2*"]
    }
  }
}

resource "aws_ecs_service" "dash-app-1-service" {
  name            = "dash-app-1-service"
  cluster         = aws_ecs_cluster.dash-ecs-cluster.id
  task_definition = aws_ecs_task_definition.dash-app-1.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.dash-app-1-tg.arn
    container_name   = "dash-app-1"
    container_port   = 8050
  }

  network_configuration {
    security_groups = [aws_security_group.Dash-SG.id]
    subnets         = [module.my_vpc_module.private_subnet_a_id, module.my_vpc_module.private_subnet_b_id]
  }
}

resource "aws_ecs_service" "dash-app-2-service" {
  name            = "dash-app-2-service"
  cluster         = aws_ecs_cluster.dash-ecs-cluster.id
  task_definition = aws_ecs_task_definition.dash-app-2.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.dash-app-2-tg.arn
    container_name   = "dash-app-2"
    container_port   = 8050
  }

  network_configuration {
    security_groups = [aws_security_group.Dash-SG.id]
    subnets         = [module.my_vpc_module.private_subnet_a_id, module.my_vpc_module.private_subnet_b_id]
  }
}