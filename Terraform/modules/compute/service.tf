resource "aws_ecs_service" "app" {
  name            = "${var.environment}-web-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn

  desired_count = 2

  launch_type = "FARGATE"

  network_configuration {
    subnets = var.private_subnet_ids

    security_groups = [
      aws_security_group.ecs_tasks.id
    ]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "web"
    container_port   = 80
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  tags = {
    Name        = "${var.environment}-web-service"
    Environment = var.environment
  }
}