# 1. ECS Cluster
resource "aws_ecs_cluster" "strapi_cluster" {
  name = "strapi-fargate-cluster"
}

# 2. ECS Task Definition
resource "aws_ecs_task_definition" "strapi_task" {
  family                   = "strapi-v4-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  
  # USE THE COMPANY PROVIDED ARN DIRECTLY
  # This bypasses the need for your user to have 'iam:CreateRole' permissions
  execution_role_arn       = "arn:aws:iam::811738710312:role/ec2-ecr-role"

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

# 3. Unique Security Group
resource "aws_security_group" "strapi_ecs_sg" {
  name        = "strapi-ecs-sg-sagar-unique" # Changed name to avoid 'InvalidGroup.Duplicate'
  description = "Allow Strapi traffic for Task 7"

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

# 4. ECS Service
resource "aws_ecs_service" "strapi_service" {
  name            = "strapi-fargate-service"
  cluster         = aws_ecs_cluster.strapi_cluster.id
  task_definition = aws_ecs_task_definition.strapi_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    # Ensure this subnet ID is correct for your environment
    subnets          = ["subnet-0a612502807e38e6e"] 
    security_groups  = [aws_security_group.strapi_ecs_sg.id]
    assign_public_ip = true
  }
}