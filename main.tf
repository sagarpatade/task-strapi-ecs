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

# ==========================================
# 2. ECS CLUSTER
# ==========================================
resource "aws_ecs_cluster" "strapi_cluster" {
  name = "strapi-fargate-cluster" # Keeping name same as created
}

# ==========================================
# 3. TASK DEFINITION (EC2 Type)
# ==========================================
resource "aws_ecs_task_definition" "strapi_task" {
  family                   = "strapi-v4-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"] # CHANGED: FARGATE -> EC2
  cpu                      = "256"
  memory                   = "512"
  
  # Using standard role (Ensure manager granted PassRole permission)
  execution_role_arn       = "arn:aws:iam::811738710312:role/ecsTaskExecutionRole"

  container_definitions = jsonencode([
    {
      name      = "strapi-container"
      image     = "811738710312.dkr.ecr.us-east-1.amazonaws.com/sagar-patade-strapi-app:${var.image_tag}"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 1337
          hostPort      = 1337
        }
      ]
    }
  ])
}

# ==========================================
# 4. SECURITY GROUP
# ==========================================
resource "aws_security_group" "strapi_ecs_sg" {
  name        = "strapi-ecs-sg-ec2-final" 
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
# 5. ECS SERVICE (EC2 Type)
# ==========================================
resource "aws_ecs_service" "strapi_service" {
  name            = "strapi-service-ec2" # New unique name
  cluster         = aws_ecs_cluster.strapi_cluster.id
  task_definition = aws_ecs_task_definition.strapi_task.arn
  launch_type     = "EC2"                # CHANGED: FARGATE -> EC2
  desired_count   = 1

  network_configuration {
    subnets          = data.aws_subnets.public.ids 
    security_groups  = [aws_security_group.strapi_ecs_sg.id]
    assign_public_ip = true
  }
}