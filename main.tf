# 1. ECS Cluster
resource "aws_ecs_cluster" "strapi_cluster" {
  name = "strapi-fargate-cluster"
}


# We use the existing role provided by the team
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ec2-ecr-role" 
}

# 3. ECS Task Definition
resource "aws_ecs_task_definition" "strapi_task" {
  family                   = "strapi-v4-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 0.5 GB
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn

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

# 4. ECS Service
resource "aws_ecs_service" "strapi_service" {
  name            = "strapi-fargate-service"
  cluster         = aws_ecs_cluster.strapi_cluster.id
  task_definition = aws_ecs_task_definition.strapi_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1



  network_configuration {
    subnets          = ["subnet-xxxxxx"] # Replace with your public subnet ID
    security_groups  = [aws_security_group.strapi_ecs_sg.id]
    assign_public_ip = true
  }
}

# 5. Security Group for ECS Fargate
resource "aws_security_group" "strapi_ecs_sg" {
  name        = "strapi-ecs-fargate-sg"
  description = "Allow Strapi traffic on port 1337"
  

  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allows access from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allows all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}