# ==========================================
# 1. NETWORK DATA SOURCES
# ==========================================
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
  }
}

# Get latest ECS-optimized AMI for the region
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# ==========================================
# 2. ECS CLUSTER
# ==========================================
resource "aws_ecs_cluster" "strapi_cluster" {
  name = "strapi-fargate-cluster"
}

# ==========================================
# 3. EC2 INFRASTRUCTURE (Updated for Policy)
# ==========================================

resource "aws_instance" "ecs_node" {
  ami                    = data.aws_ssm_parameter.ecs_ami.value
  
  # CHANGED: t3.micro -> t2.micro to satisfy your 'only-t2.micro' policy
  instance_type          = "t2.micro" 
  
  subnet_id              = data.aws_subnets.public.ids[0]
  vpc_security_group_ids = [aws_security_group.strapi_ecs_sg.id]
  iam_instance_profile   = "ec2-ecr-role" 

  user_data = <<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.strapi_cluster.name} >> /etc/ecs/ecs.config
              EOF

  tags = { Name = "Sagar-ECS-Host" }
}

# ==========================================
# 4. TASK DEFINITION (EC2 Type)
# ==========================================
resource "aws_ecs_task_definition" "strapi_task" {
  family                   = "strapi-v4-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  
  execution_role_arn       = "arn:aws:iam::811738710312:role/ecsTaskExecutionRole"

  container_definitions = jsonencode([
    {
      name      = "strapi-container"
      image     = "811738710312.dkr.ecr.us-east-1.amazonaws.com/sagar-patade-strapi-app:${var.image_tag}"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [{ containerPort = 1337, hostPort = 1337 }]
    }
  ])
}

# ==========================================
# 5. SECURITY GROUP
# ==========================================
resource "aws_security_group" "strapi_ecs_sg" {
  name        = "strapi-ecs-sg-ec2-final-v2" 
  vpc_id      = data.aws_vpc.default.id
  description = "Allow Strapi traffic"

  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 6. ECS SERVICE
# ==========================================
resource "aws_ecs_service" "strapi_service" {
  name            = "strapi-service-ec2-v3" # Incrementing to avoid locks
  cluster         = aws_ecs_cluster.strapi_cluster.id
  task_definition = aws_ecs_task_definition.strapi_task.arn
  launch_type     = "EC2"
  desired_count   = 1

  network_configuration {
    subnets          = data.aws_subnets.public.ids 
    security_groups  = [aws_security_group.strapi_ecs_sg.id]
    assign_public_ip = false # Required for EC2 launch type
  }
}