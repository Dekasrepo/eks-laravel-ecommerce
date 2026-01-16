#!/bin/bash

# ============================================
# CONFIGURATION SECTION
# ============================================

# Docker Image Configuration
export IMAGE_NAME="shopwise"
export IMAGE_TAG="latest"

# GitHub Configuration
export GITHUB_USERNAME="Dekasrepo"
export REPOSITORY_NAME="multi-tier-app-code"
export APPLICATION_CODE_FILE_NAME="shopwise"

# RDS Database Configuration
export RDS_ENDPOINT="dev-nest-db.cz8imamwshze.eu-west-3.rds.amazonaws.com"
export RDS_DB_NAME="applicationdb"
export RDS_DB_USERNAME="admin"

# Application Configuration
export DOMAIN_NAME="www.jideka.com.ng"

# AWS Secrets Manager Configuration
export SECRET_NAME="dev-nest-secrets"
export AWS_REGION="eu-west-3"

# Color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ============================================
# RETRIEVE SECRETS FROM AWS SECRETS MANAGER
# ============================================

echo -e "${CYAN}Starting Docker build process for $IMAGE_NAME application...${NC}"
echo -e "${CYAN}Retrieving secrets from AWS Secrets Manager...${NC}"

# Retrieve secret from Secrets Manager
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id ${SECRET_NAME} \
  --region ${AWS_REGION} \
  --query SecretString \
  --output text 2>&1)

# Check if secret retrieval was successful
if [ $? -ne 0 ]; then
  echo -e "${RED}Error: Failed to retrieve secrets from AWS Secrets Manager${NC}"
  exit 1
fi

# Parse individual secrets using jq
PERSONAL_ACCESS_TOKEN=$(echo $SECRET_JSON | jq -r '.personal_access_token')
RDS_DB_PASSWORD=$(echo $SECRET_JSON | jq -r '.password')

# Validate secrets were parsed correctly
if [ -z "$PERSONAL_ACCESS_TOKEN" ] || [ -z "$RDS_DB_PASSWORD" ]; then
  echo -e "${RED}Error: Failed to parse secrets from JSON${NC}"
  exit 1
fi

echo -e "${GREEN}Secrets retrieved successfully!${NC}"

# ============================================
# BUILD DOCKER IMAGE WITH BUILDKIT SECRETS
# ============================================

echo -e "${CYAN}Building Docker image with BuildKit secrets...${NC}"

# Enable BuildKit
export DOCKER_BUILDKIT=1

# Set secrets as environment variables for BuildKit (will be mounted as secrets in the container)
export PERSONAL_ACCESS_TOKEN_SECRET="$PERSONAL_ACCESS_TOKEN"
export RDS_DB_PASSWORD_SECRET="$RDS_DB_PASSWORD"

# Run the docker build command with BuildKit secrets
docker build \
  --secret id=personal_access_token,env=PERSONAL_ACCESS_TOKEN_SECRET \
  --secret id=rds_db_password,env=RDS_DB_PASSWORD_SECRET \
  --build-arg GITHUB_USERNAME="$GITHUB_USERNAME" \
  --build-arg REPOSITORY_NAME="$REPOSITORY_NAME" \
  --build-arg APPLICATION_CODE_FILE_NAME="$APPLICATION_CODE_FILE_NAME" \
  --build-arg RDS_ENDPOINT="$RDS_ENDPOINT" \
  --build-arg RDS_DB_NAME="$RDS_DB_NAME" \
  --build-arg RDS_DB_USERNAME="$RDS_DB_USERNAME" \
  --build-arg DOMAIN_NAME="$DOMAIN_NAME" \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  .

# Clean up temporary environment variables
unset PERSONAL_ACCESS_TOKEN_SECRET
unset RDS_DB_PASSWORD_SECRET

# Check if build was successful
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Docker image $IMAGE_NAME built successfully!${NC}"
else
  echo -e "${RED}Docker build failed. Please check the error messages above.${NC}"
  exit 1
fi