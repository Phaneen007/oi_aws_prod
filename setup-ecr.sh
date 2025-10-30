#!/bin/bash

# Script to create ECR repository and push Open WebUI image
# This eliminates the need for NAT Gateway to pull public images

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Setting up ECR for Open WebUI${NC}"
echo ""

# Check if required tools are installed
command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI is required but not installed. Aborting.${NC}" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo -e "${RED}Docker is required but not installed. Aborting.${NC}" >&2; exit 1; }

# Get AWS account ID and region from terraform variables or prompt
read -p "Enter your AWS Account ID: " AWS_ACCOUNT_ID
read -p "Enter your AWS Region [us-east-1]: " AWS_REGION
AWS_REGION=${AWS_REGION:-us-east-1}
read -p "Enter your AWS Profile [default]: " AWS_PROFILE
AWS_PROFILE=${AWS_PROFILE:-default}

echo ""
echo -e "${GREEN}Using AWS Account: $AWS_ACCOUNT_ID${NC}"
echo -e "${GREEN}Using AWS Region: $AWS_REGION${NC}"
echo -e "${GREEN}Using AWS Profile: $AWS_PROFILE${NC}"
echo ""

# Repository name
REPO_NAME="openwebui"
IMAGE_TAG="latest"
PUBLIC_IMAGE="ghcr.io/open-webui/open-webui:main"

# Create ECR repository
echo -e "${YELLOW}Creating ECR repository...${NC}"
aws ecr create-repository \
    --repository-name $REPO_NAME \
    --region $AWS_REGION \
    --profile $AWS_PROFILE \
    --image-scanning-configuration scanOnPush=true \
    --encryption-configuration encryptionType=AES256 \
    2>/dev/null || echo -e "${YELLOW}Repository may already exist, continuing...${NC}"

echo -e "${GREEN}✓ ECR repository created/verified${NC}"
echo ""

# Get ECR login
echo -e "${YELLOW}Logging into ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION --profile $AWS_PROFILE | \
    docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

echo -e "${GREEN}✓ Logged into ECR${NC}"
echo ""

# Pull the public image
echo -e "${YELLOW}Pulling Open WebUI image from GitHub Container Registry...${NC}"
echo "This may take a few minutes..."
docker pull $PUBLIC_IMAGE

echo -e "${GREEN}✓ Image pulled successfully${NC}"
echo ""

# Tag for ECR
ECR_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG"
echo -e "${YELLOW}Tagging image for ECR...${NC}"
docker tag $PUBLIC_IMAGE $ECR_IMAGE

echo -e "${GREEN}✓ Image tagged${NC}"
echo ""

# Push to ECR
echo -e "${YELLOW}Pushing image to ECR...${NC}"
echo "This may take a few minutes..."
docker push $ECR_IMAGE

echo -e "${GREEN}✓ Image pushed to ECR successfully!${NC}"
echo ""

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}ECR Setup Complete!${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo "Your ECR image URI is:"
echo -e "${YELLOW}$ECR_IMAGE${NC}"
echo ""
echo "Save this URI - you'll need it for the Terraform configuration."
echo ""
