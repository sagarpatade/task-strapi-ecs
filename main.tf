# 1. ECS Cluster
resource "aws_ecs_cluster" "strapi_cluster" {
  name = "strapi-fargate-cluster"
}



# 1. Create the Execution Role instead of looking it up
resource "aws_iam_role" "ecs_execution_role" {
  name = "sagar-ecs-execution-role-task7"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# 2. Attach the standard AWS policy for ECR and Logging
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 3. ECS Task Definition
resource "aws_ecs_task_definition" "strapi_task" {
  family                   = "strapi-v4-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  
 
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "strapi-container"
      image     = "811738710312.dkr.ecr.us-east-1.amazonaws.com/sagar-patade-strapi-app:${var.image_tag}"
        portMappings = [
            {
            containerPort = 1337
            protocol      = "tcp"
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