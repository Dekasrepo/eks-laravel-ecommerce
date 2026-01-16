#!/bin/bash

# ============================================
# CONFIGURATION SECTION
# ============================================

# Define repository name, region, and account ID
ECR_REPO_NAME="shopwise"
LOCAL_IMAGE_NAME="shopwise"  
IMAGE_TAG="latest"
AWS_REGION="eu-west-3"
AWS_ACCOUNT_ID="648682442381"

# Color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================
# CHECK IF ECR REPOSITORY EXISTS
# ============================================

# Attempt to describe the repository
aws ecr describe-repositories \
  --repository-names "$ECR_REPO_NAME" \
  --region "$AWS_REGION" 2>/dev/null

# Check if the repository exists
# $? contains exit code: 0 if previous command succeeded, non-zero otherwise
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Repository already exists. Skipping creation.${NC}"
else
    echo -e "${CYAN}Repository does not exist. Creating repository...${NC}"
    aws ecr create-repository \
      --repository-name "$ECR_REPO_NAME" \
      --region "$AWS_REGION"
    
    # Check if repository creation was successful
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Repository created successfully!${NC}"
    else
        echo -e "${RED}Failed to create ECR repository.${NC}"
        exit 1
    fi
fi

# ============================================
# TAG AND PUSH DOCKER IMAGE
# ============================================

# Tag the Docker image with the ECR repository URI
docker tag "$LOCAL_IMAGE_NAME:$IMAGE_TAG" "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG"

# Check if tagging was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Docker image tagged successfully.${NC}"
else
    echo -e "${RED}Failed to tag Docker image. Make sure the image '$LOCAL_IMAGE_NAME:$IMAGE_TAG' exists locally.${NC}"
    echo -e "${YELLOW}Run 'docker images' to see available images.${NC}"
    exit 1
fi

# Retrieve an authentication token and log in to the ECR registry
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Check if authentication was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Successfully authenticated with ECR.${NC}"
else
    echo -e "${RED}Failed to authenticate with ECR.${NC}"
    exit 1
fi

# Push the Docker image to the ECR repository
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG"

# Check if push was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Docker image pushed successfully to ECR!${NC}"
    echo -e "${CYAN}Image URI: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME:$IMAGE_TAG${NC}"
else
    echo -e "${RED}Docker push failed. Please check the error messages above.${NC}"
    exit 1
fi