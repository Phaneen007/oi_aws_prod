locals {
  ecs = {
    cluster_name       = "openwebui-prod-cluster"
    service_name_webui = "openwebui"
  }
}

# ECS Cluster
resource "aws_iam_service_linked_role" "AWSServiceRoleForECS" {
  aws_service_name = "ecs.amazonaws.com"
}

resource "aws_ecs_cluster" "ecs_cluster" {
  name       = local.ecs.cluster_name
  depends_on = [aws_iam_service_linked_role.AWSServiceRoleForECS]
}

resource "aws_ecs_cluster_capacity_providers" "ecs_cluster_capacity_provider" {
  cluster_name       = aws_ecs_cluster.ecs_cluster.name
  capacity_providers = ["FARGATE"]
}

# Application Load Balancer
module "alb_sg" {
  source = "./modules/security_group"

  name   = "alb-sg"
  vpc_id = aws_vpc.default.id

  cidr_egresses = [{
    cidr_blocks = [local.vpc_cidr]
    port        = 0
    protocol    = "-1"
  }]

  cidr_ingresses = [
    {
      cidr_blocks = ["0.0.0.0/0"]
      port        = 80
      protocol    = "tcp"
    },
    {
      cidr_blocks = ["0.0.0.0/0"]
      port        = 443
      protocol    = "tcp"
    }
  ]
}

resource "aws_lb" "alb" {
  name               = "openwebui-prod-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.alb_sg.id]
  subnets            = aws_subnet.public_subnets[*].id
}

resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_target_group" "alb_target_group" {
  name        = "openwebui-prod-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.default.id
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 45
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener_rule" "alb_listener_rule" {
  listener_arn = aws_lb_listener.alb_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_target_group.arn
  }

  condition {
    path_pattern {
      values = ["*"]
    }
  }
}

# IAM Roles
data "aws_iam_policy_document" "task_execution_policy" {
  statement {
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:${var.region}:${var.account_id}:*"]
  }

  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.openrouter_api_key.arn
    ]
  }

  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "task_execution_policy" {
  name_prefix = "task-execution-policy-"
  policy      = data.aws_iam_policy_document.task_execution_policy.json
}

module "task_execution_role" {
  source  = "./modules/iam_role"
  name    = "${local.ecs.cluster_name}-task-execution-role"
  service = ["ecs-tasks.amazonaws.com"]
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    aws_iam_policy.task_execution_policy.arn
  ]
}

# Task Role for OpenWebUI (S3 access)
data "aws_iam_policy_document" "openwebui_task_policy" {
  # S3 Permissions for file storage
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.openwebui_storage.arn,
      "${aws_s3_bucket.openwebui_storage.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "openwebui_task_policy" {
  name_prefix = "openwebui-task-policy-"
  policy      = data.aws_iam_policy_document.openwebui_task_policy.json
}

module "openwebui_task_role" {
  source              = "./modules/iam_role"
  name                = "${local.ecs.cluster_name}-openwebui-task-role"
  service             = ["ecs-tasks.amazonaws.com"]
  managed_policy_arns = [aws_iam_policy.openwebui_task_policy.arn]
}

# OPENWEBUI
## OpenWebUI ECS Service
module "ecs_service_openwebui_sg" {
  source = "./modules/security_group"

  name   = "${local.ecs.service_name_webui}-sg"
  vpc_id = aws_vpc.default.id

  cidr_egresses = [{
    cidr_blocks = ["0.0.0.0/0"]
    port        = 0
    protocol    = "-1"
  }]

  security_group_ingresses = [
    {
      security_groups = [module.alb_sg.id]
      port            = 8080
      protocol        = "tcp"
    }
  ]
}

resource "aws_ecs_task_definition" "task_definition_openwebui" {
  family                   = local.ecs.service_name_webui
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = 4096
  cpu                      = 2048
  execution_role_arn       = module.task_execution_role.arn
  task_role_arn            = module.openwebui_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "openwebui"
      image     = "ghcr.io/open-webui/open-webui:main"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        # S3 Storage Configuration
        {
          name  = "STORAGE_PROVIDER"
          value = "s3"
        },
        {
          name  = "S3_BUCKET_NAME"
          value = aws_s3_bucket.openwebui_storage.id
        },
        {
          name  = "S3_REGION_NAME"
          value = var.region
        },
        {
          name  = "S3_ENDPOINT_URL"
          value = "https://s3.${var.region}.amazonaws.com"
        },
        # OpenRouter API Configuration
        {
          name  = "OPENAI_API_BASE_URL"
          value = "https://openrouter.ai/api/v1"
        },
        # General Configuration
        {
          name  = "WEBUI_SECRET_KEY"
          value = random_password.webui_secret_key.result
        },
        # Enable basic authentication
        {
          name  = "WEBUI_AUTH"
          value = "true"
        }
      ]
      secrets = [
        {
          name      = "OPENAI_API_KEY"
          valueFrom = aws_secretsmanager_secret.openrouter_api_key.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/${local.ecs.cluster_name}/openwebui"
          awslogs-region        = var.region
          awslogs-create-group  = "true"
          awslogs-stream-prefix = "ecs"
        }
      }
      mountPoints = [
        {
          sourceVolume  = "openwebui-efs-volume"
          containerPath = "/app/backend/data"
          readOnly      = false
        }
      ]
    }
  ])

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  volume {
    name = "openwebui-efs-volume"

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.efs_filesystem.id
      root_directory     = "/"
      transit_encryption = "ENABLED"
    }
  }
}

resource "aws_ecs_service" "ecs_service_openwebui" {
  name                   = local.ecs.service_name_webui
  cluster                = aws_ecs_cluster.ecs_cluster.id
  task_definition        = aws_ecs_task_definition.task_definition_openwebui.arn
  desired_count          = 1
  launch_type            = "FARGATE"
  force_new_deployment   = true
  enable_execute_command = true

  network_configuration {
    subnets          = aws_subnet.webui_private_subnets[*].id
    security_groups  = [module.ecs_service_openwebui_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.alb_target_group.arn
    container_name   = "openwebui"
    container_port   = 8080
  }
}

## OpenWebUI EFS
module "efs_sg" {
  source = "./modules/security_group"
  name   = "efs-sg"
  vpc_id = aws_vpc.default.id

  cidr_egresses = [{
    cidr_blocks = ["0.0.0.0/0"]
    port        = 0
    protocol    = "-1"
  }]

  security_group_ingresses = [
    {
      security_groups = [module.ecs_service_openwebui_sg.id]
      port            = 2049
      protocol        = "tcp"
    }
  ]
}

resource "aws_efs_file_system" "efs_filesystem" {
  creation_token  = "openwebui-efs"
  encrypted       = true
  throughput_mode = "elastic"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_archive = "AFTER_90_DAYS"
  }
}

resource "aws_efs_mount_target" "efs_mount" {
  count = length(aws_subnet.webui_private_subnets)

  file_system_id  = aws_efs_file_system.efs_filesystem.id
  subnet_id       = aws_subnet.webui_private_subnets[count.index].id
  security_groups = [module.efs_sg.id]
}

# Generate random secret key for WebUI
resource "random_password" "webui_secret_key" {
  length  = 32
  special = true
}