locals {
  vpc_cidr           = "192.168.0.0/16"
  availability_zones = data.aws_availability_zones.az.names
}

# Availability Zones
data "aws_availability_zones" "az" {}

# VPC
resource "aws_vpc" "default" {
  cidr_block           = local.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Default Security Group
resource "aws_default_security_group" "default_sg" {
  vpc_id = aws_vpc.default.id
}

# Subnets - Limit to 3 AZs
resource "aws_subnet" "public_subnets" {
  count = min(3, length(local.availability_zones))

  vpc_id                  = aws_vpc.default.id
  cidr_block              = cidrsubnet(local.vpc_cidr, 4, count.index)
  availability_zone       = local.availability_zones[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-${local.availability_zones[count.index]}",
    Type = "Public"
  }
}

resource "aws_subnet" "webui_private_subnets" {
  count = min(3, length(local.availability_zones))

  vpc_id            = aws_vpc.default.id
  cidr_block        = cidrsubnet(local.vpc_cidr, 4, count.index + 3)
  availability_zone = local.availability_zones[count.index]
  tags = {
    Name = "webui-private-subnet-${local.availability_zones[count.index]}",
    Type = "Private"
  }
}

resource "aws_subnet" "module_private_subnets" {
  count = min(3, length(local.availability_zones))

  vpc_id            = aws_vpc.default.id
  cidr_block        = cidrsubnet(local.vpc_cidr, 4, count.index + 6)
  availability_zone = local.availability_zones[count.index]
  tags = {
    Name = "module-private-subnet-${local.availability_zones[count.index]}",
    Type = "Private"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.default.id
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.default.id
  tags = {
    Name = "rt-public"
  }
}

resource "aws_route" "igw_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_rt_association" {
  count = min(3, length(local.availability_zones))

  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnets[count.index].id
}

# Private route tables (NO NAT Gateway - using VPC endpoints only)
resource "aws_route_table" "private_route_table" {
  count = min(3, length(local.availability_zones))

  vpc_id = aws_vpc.default.id
  tags = {
    Name = "rt-private-${count.index}"
  }
}

resource "aws_route_table_association" "private_rt_association_webui" {
  count = min(3, length(local.availability_zones))

  route_table_id = aws_route_table.private_route_table[count.index].id
  subnet_id      = aws_subnet.webui_private_subnets[count.index].id
}

resource "aws_route_table_association" "private_rt_association_module" {
  count = min(3, length(local.availability_zones))

  route_table_id = aws_route_table.private_route_table[count.index].id
  subnet_id      = aws_subnet.module_private_subnets[count.index].id
}

# VPC Endpoints - IAM Policies
data "aws_iam_policy_document" "logs_endpoint_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:CreateExportTask",
      "logs:DescribeExportTasks",
      "logs:ListTagsLogGroup"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "kms_endpoint_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:Sign"
    ]
    resources = [
      "arn:aws:kms:*:${var.account_id}:key/*"
    ]
  }
}

# S3 Gateway Endpoint (for S3 access without NAT Gateway charges)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.default.id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = concat(
    [aws_route_table.public_route_table.id],
    aws_route_table.private_route_table[*].id
  )

  tags = {
    Name = "s3-gateway-endpoint"
  }
}

# Interface VPC Endpoints - Using 2 AZs for cost optimization
module "vpc_interface_endpoints" {
  source = "./modules/vpc_endpoints_interface"

  region = var.region

  vpc = {
    id         = aws_vpc.default.id
    cidr       = local.vpc_cidr
    subnet_ids = slice(aws_subnet.module_private_subnets[*].id, 0, 2)  # Use only first 2 AZs
  }

  vpc_interface_endpoints = [
    {
      name = "ecr.api"
    },
    {
      name = "ecr.dkr"
    },
    {
      name   = "logs"
      policy = data.aws_iam_policy_document.logs_endpoint_policy.json
    },
    {
      name   = "kms"
      policy = data.aws_iam_policy_document.kms_endpoint_policy.json
    },
    {
      name = "execute-api"  # Added for API Gateway access
    },
    {
      name = "secretsmanager"
    }
  ]
}
