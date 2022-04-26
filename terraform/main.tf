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

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "dash-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "dash-internet-gateway"
  }
}

resource "aws_subnet" "public-subet-zone-a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.0.0/20"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "dash-public-subnet-1"
  }
}

resource "aws_subnet" "public-subet-zone-b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.16.0/20"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "dash-public-subnet-2"
  }
}

resource "aws_subnet" "private-subet-zone-a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.128.0/20"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "dash-private-subnet-1"
  }
}

resource "aws_subnet" "private-subet-zone-b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.144.0/20"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "dash-private-subnet-2"
  }
}

resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "dash-public-route-table"
  }
}

resource "aws_route_table_association" "public-subnet-public-route-table-a" {
  subnet_id      = aws_subnet.public-subet-zone-a.id
  route_table_id = aws_route_table.public-route-table.id
}

resource "aws_route_table_association" "public-subnet-public-route-table-b" {
  subnet_id      = aws_subnet.public-subet-zone-b.id
  route_table_id = aws_route_table.public-route-table.id
}

resource "aws_eip" "elastic-ip" {
  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_nat_gateway" "dash-public-nat-gateway" {
  allocation_id = aws_eip.elastic-ip.allocation_id
  subnet_id     = aws_subnet.public-subet-zone-a.id

  tags = {
    Name = "dash-public-nat-gateway"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}


resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.dash-public-nat-gateway.id
  }

  tags = {
    Name = "dash-private-route-table"
  }
}

resource "aws_route_table_association" "private-subnet-public-route-table-a" {
  subnet_id      = aws_subnet.private-subet-zone-a.id
  route_table_id = aws_route_table.private-route-table.id
}

resource "aws_route_table_association" "private-subnet-public-route-table-b" {
  subnet_id      = aws_subnet.private-subet-zone-b.id
  route_table_id = aws_route_table.private-route-table.id
}

resource "aws_ecs_cluster" "dash-ecs-cluster" {
  name = "dash-ecs-cluster"
}

resource "aws_ecs_task_definition" "dash-app-1" {
  family                   = "dash-app-1"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  task_role_arn = "arn:aws:iam::640935740154:role/ecsTaskExecutionRole"
  execution_role_arn = "arn:aws:iam::640935740154:role/ecsTaskExecutionRole"
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
  task_role_arn = "arn:aws:iam::640935740154:role/ecsTaskExecutionRole"
  execution_role_arn = "arn:aws:iam::640935740154:role/ecsTaskExecutionRole"
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
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "Allow access from everywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow access from everywhere"
    cidr_blocks      = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }

  tags = {
    Name = "Load-Balancer-SG"
  }
}

resource "aws_security_group" "Dash-SG" {
  name        = "Dash-SG"
  description = "SG to allow access from load balancer security group on port 8050"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "Allow access from load balancer security group"
    from_port        = 8050
    to_port          = 8050
    protocol         = "tcp"
    security_groups = [aws_security_group.Load-Balancer-SG.id]
  }

  egress {
    description      = "Allow access from everywhere"
    cidr_blocks      = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
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
  vpc_id      = aws_vpc.main.id
  health_check {
    path = "/apps/dash-app-1/"
  }
}

resource "aws_lb" "dash-load-balancer" {
  name               = "dash-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.Load-Balancer-SG.id]
  subnets            = [aws_subnet.public-subet-zone-a.id, aws_subnet.public-subet-zone-b.id]
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

resource "aws_lb_listener_rule" "host_based_weighted_routing" {
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
    security_groups = [ aws_security_group.Dash-SG.id ]
    subnets = [ aws_subnet.private-subet-zone-a.id, aws_subnet.private-subet-zone-b.id ]
  }
}