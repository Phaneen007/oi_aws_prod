locals {
  ecs = {
    cluster_name       = "openwebui-prod-cluster"
    service_name_webui = "openwebui"
    service_name_mcpo  = "mcpo"
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
      aws_secretsmanager_secret.openrouter_api_key.arn,
      aws_secretsmanager_secret.aurora_credentials.arn,
      # MCPO secrets if using modules
      aws_secretsmanager_secret.mcpo_api_key_secret.arn,
      aws_secretsmanager_secret.gitlab_token_secret.arn,
      aws_secretsmanager_secret.linear_token_secret.arn
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

# Task Role for OpenWebUI (S3 and Aurora access)
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
      "${aws_s3_bucket.openwebui_storage.arn}",
      "${aws_s3_bucket.openwebui_storage.arn}/*"
    ]
  }

  # Cognito permissions (if needed for user management)
  statement {
    actions = [
      "cognito-idp:AdminGetUser",
      "cognito-idp:ListUsers"
    ]
    resources = [
      module.cognito.user_pool_arn
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
      image     = "${aws_ecr_repository.openwebui_repository.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        # Database Configuration (Aurora PostgreSQL with pgvector)
        {
          name  = "DATABASE_URL"
          value = "postgresql://${var.db_username}:${var.db_password}@${module.aurora.cluster_endpoint}:5432/${var.db_name}"
        },
        {
          name  = "VECTOR_DB"
          value = "pgvector"
        },
        {
          name  = "ENABLE_POSTGRESQL_VECTOR_EXTENSION"
          value = "false"
        },
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
        # Cognito OAuth Configuration
        {
          name  = "ENABLE_OAUTH_SIGNUP"
          value = "true"
        },
        {
          name  = "OAUTH_MERGE_ACCOUNTS_BY_EMAIL"
          value = "true"
        },
        {
          name  = "OAUTH_CLIENT_ID"
          value = module.cognito.client_id
        },
        {
          name  = "OPENID_PROVIDER_URL"
          value = "https://cognito-idp.${var.region}.amazonaws.com/${module.cognito.user_pool_id}/.well-known/openid-configuration"
        },
        {
          name  = "OPENID_REDIRECT_URI"
          value = "http://${aws_lb.alb.dns_name}/oauth/oidc/callback"
        },
        {
          name  = "OAUTH_PROVIDER_NAME"
          value = "AWS Cognito"
        },
        {
          name  = "OAUTH_SCOPES"
          value = "openid email profile"
        },
        {
          name  = "WEBUI_URL"
          value = "http://${aws_lb.alb.dns_name}"
        },
        # OpenRouter API Configuration (to be updated after deployment)
        {
          name  = "OPENAI_API_BASE_URL"
          value = "https://openrouter.ai/api/v1"
        },
        # General Configuration
        {
          name  = "WEBUI_SECRET_KEY"
          value = random_password.webui_secret_key.result
        },
        {
          name  = "ENABLE_OAUTH_PERSISTENT_CONFIG"
          value = "true"
        }
      ]
      secrets = [
        {
          name      = "OPENAI_API_KEY"
          valueFrom = aws_secretsmanager_secret.openrouter_api_key.arn
        },
        {
          name      = "OAUTH_CLIENT_SECRET"
          valueFrom = module.cognito.client_secret_arn
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
    }
  ])

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
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

# MCPO Module (Optional - Keep if you're using this)
module "ecs_service_module_sg" {
  source = "./modules/security_group"

  name   = "module-sg"
  vpc_id = aws_vpc.default.id

  cidr_egresses = [{
    cidr_blocks = ["0.0.0.0/0"]
    port        = 0
    protocol    = "-1"
  }]

  security_group_ingresses = [
    {
      security_groups = [module.ecs_service_openwebui_sg.id]
      port            = 80
      protocol        = "tcp"
    }
  ]
}

resource "aws_ecs_task_definition" "task_definition_mcpo" {
  family                   = local.ecs.service_name_mcpo
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  memory                   = 1024
  cpu                      = 512
  execution_role_arn       = module.task_execution_role.arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "mcpo"
      image     = "${aws_ecr_repository.mcpo_repository.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      secrets = [
        {
          name      = "API_KEY"
          valueFrom = aws_secretsmanager_secret.mcpo_api_key_secret.arn
        },
        {
          name      = "GITLAB_PERSONAL_ACCESS_TOKEN"
          valueFrom = aws_secretsmanager_secret.gitlab_token_secret.arn
        },
        {
          name      = "LINEAR_API_KEY"
          valueFrom = aws_secretsmanager_secret.linear_token_secret.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/${local.ecs.cluster_name}"
          awslogs-region        = var.region
          awslogs-create-group  = "true"
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "ecs_service_mcpo" {
  name            = local.ecs.service_name_mcpo
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.task_definition_mcpo.arn

  desired_count        = 1
  launch_type          = "FARGATE"
  force_new_deployment = true

  network_configuration {
    subnets          = aws_subnet.module_private_subnets[*].id
    security_groups  = [module.ecs_service_module_sg.id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.sd_discovery_service_mcpo.arn
  }
}

# Service Discovery for MCPO
resource "aws_service_discovery_private_dns_namespace" "sd_dns_namespace" {
  name = "openwebui.local"
  vpc  = aws_vpc.default.id
}

resource "aws_service_discovery_service" "sd_discovery_service_mcpo" {
  name = "mcpo"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.sd_dns_namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# Generate random secret key for WebUI
resource "random_password" "webui_secret_key" {
  length  = 32
  special = true
}