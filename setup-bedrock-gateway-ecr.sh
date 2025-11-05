#!/bin/bash

# Script to build and push Bedrock Access Gateway to ECR
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Step 1b: Setting up Bedrock Access Gateway in ECR${NC}"
echo ""

# Get AWS details
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
REPO_NAME="bedrock-access-gateway"
IMAGE_TAG="latest"

# Clone the repository
echo -e "${YELLOW}Cloning Bedrock Access Gateway repository...${NC}"
if [ -d "bedrock-access-gateway" ]; then
    echo -e "${YELLOW}Directory exists, removing...${NC}"
    rm -rf bedrock-access-gateway
fi

git clone https://github.com/aws-samples/bedrock-access-gateway.git
cd bedrock-access-gateway/src

echo -e "${GREEN}✓ Repository cloned${NC}"
echo ""

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

# Build the image
ECR_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO_NAME:$IMAGE_TAG"
echo -e "${YELLOW}Building Bedrock Access Gateway image...${NC}"
echo "This may take a few minutes..."

docker build . -f Dockerfile_ecs -t $ECR_IMAGE --platform linux/arm64

echo -e "${GREEN}✓ Image built successfully${NC}"
echo ""

# Push to ECR
echo -e "${YELLOW}Pushing image to ECR...${NC}"
echo "This may take a few minutes..."
docker push $ECR_IMAGE

echo -e "${GREEN}✓ Image pushed to ECR successfully!${NC}"
echo ""

# Cleanup
cd ../..
rm -rf bedrock-access-gateway

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}Bedrock Access Gateway ECR Setup Complete!${NC}"
echo -e "${GREEN}==================================================${NC}"
echo ""
echo "Your ECR image URI is:"
echo -e "${YELLOW}$ECR_IMAGE${NC}"
echo ""
echo "Save this URI - you'll need it for the Terraform configuration."
echo ""
