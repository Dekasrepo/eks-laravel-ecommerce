# Laravel E-Commerce Application on AWS EKS

## Overview
This repository documents the end-to-end deployment process of a production-ready Laravel e-commerce application on AWS using Docker, Amazon EKS (Kubernetes), and Amazon RDS.

Rather than presenting a high-level deployment summary, this project focuses on the actual implementation process, reflecting how production systems are built, migrated, and evolved in real environments.

This deployment is a continuation of a prior ECS-based Laravel application, intentionally reusing existing AWS networking and security resources to simulate a realistic migration from ECS to Kubernetes.

-----

## Architecture
### High-level flow:

<img width="1024" height="1536" alt="ChatGPT Image Jan 16, 2026, 11_03_06 PM" src="https://github.com/user-attachments/assets/9862fffb-6156-47a5-89cf-df09e641af0c" />


The application runs entirely within private subnets and is exposed securely via HTTPS using ACM and Route 53.

-----

## AWS Services Used

- Amazon VPC
- Public & Private Subnets
- Internet Gateway & NAT Gateway
- EC2 Instance Connect Endpoint (EICE)
- Amazon EKS
- EKS Managed Node Groups
- Amazon ECR
- Amazon RDS (MySQL)
- AWS Secrets Manager
- AWS Secrets Store CSI Driver
- Elastic Load Balancer (NLB)
- Amazon Route 53
- AWS Certificate Manager (ACM)

-----

## Repository Structure

```
eks-laravel-ecommerce/
├── architecture/
│   └── eks-architecture.png
├── docker/
│   ├── Dockerfile
│   ├── AppServiceProvider 
|   ├── db-migrate-script
|   ├── build.sh
│   └── push.sh
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── secret-provider-class.yaml
│   └── aws-auth-patch.yaml
├── docs/
│   ├── Project-Agenda.md
│   └── Resource-Naming-Convention.md
└── README.md
```
-----

## Deployment Process

### 1. Networking Foundation
This deployment builds on an existing AWS networking foundation created in a prior ECS project, including:
- One vpc
- Two public subnet
- Four private subnet
- Public and Private route tables
- Internet gateway 
- Nat Gateway for outbound accesss 
- Elastic IP
- EC2 Instance Connect Endpoint (EICE)
This setup enables secure access to private resources without a bastion host.

<img width="1153" height="416" alt="Screenshot 2025-12-23 at 15 00 14" src="https://github.com/user-attachments/assets/f91dc874-f185-45f3-b909-d196d71ec387" />

<img width="1157" height="397" alt="Screenshot 2025-12-23 at 15 00 22" src="https://github.com/user-attachments/assets/bcd14b29-7b49-4ca8-9115-a7f262fe57dd" />

------

### 2. Database Setup and Migration (Outside Kubernetes)

An Amazon RDS MySQL instance is deployed within private data subnets using an existing DB subnet group.

**Database Migration Strategy**

Database migration is handled outside of Kubernetes using a dedicated EC2 data migration server.
- The migration server is launched in a private subnet
- A user data script executes automatically on first boot
- The script:
  - Retrieves credentials from AWS Secrets Manager
  - Downloads SQL files from Amazon S3
  - Uses Flyway to migrate data into Amazon RDS

This approach ensures:
- Clear separation between infrastructure bootstrapping and application runtime
- No hardcoded credentials
- No accidental re-execution from Kubernetes
- A clean handoff to the EKS deployment once the database is fully prepared

**Migration Design Principles**
- Database migration is not performed by the application containers
- Migration logic is not executed during application startup
- Migration runs once during EC2 instance initialization
- SQL data is securely stored in Amazon S3
- Database credentials are retrieved at runtime from AWS Secrets Manager

**Migration Workflow**
1. A temporary EC2 instance is launched in a private subnet
2. A user data script runs automatically on first boot
3. The script:
   - Retrieves database credentials from AWS Secrets Manager
   - Downloads migration SQL files from Amazon S3
   - Uses Flyway to migrate data into the Amazon RDS MySQL instance
4. After successful migration, the EC2 instance is no longer required
This approach ensures:
   - Clear separation between infrastructure bootstrapping and application runtime
   - No hardcoded credentials or secrets
   - No risk of accidental re-execution from Kubernetes or application containers
   - A clean handoff to Kubernetes once the database is fully prepared
     
**Production Considerations**

This migration strategy reflects real-world production practices where:
- Initial data loading or legacy migrations are performed before application rollout
- One-off migration tasks are isolated from long-running services
- Execution is intentionally limited to a controlled environment

In a fully automated production environment, this migration step could be further evolved into:
- A dedicated Kubernetes Job, or
- A CI/CD pipeline stage managed via Infrastructure as Code (Terraform)
This evolution is planned for a future phase of this project.

------

### 3. Build and push Docker image to Amazon ECR

After database migration:
- The Laravel application is containerized using Docker
- The Dockerfile defines the application runtime and dependencies
- AppServiceProvider remains part of the application runtime
- The migration script is included for controlled infrastructure workflows, not runtime execution
- The image is built locally using a build script
- The image is tagged and pushed to Amazon ECR

<img width="485" height="152" alt="Screenshot 2025-12-23 at 17 34 31" src="https://github.com/user-attachments/assets/2514fc62-3869-4d59-ad2c-a7e8d104cef5" />

- Navigate to console then, to ECR (Elastic container Repository) verify if reopsitory exist or create it.
- Authenticate docker to ECR, Set permissions first (chmod x + push-image.sh), tag and push image to ECR.

<img width="814" height="420" alt="Screenshot 2026-01-06 at 10 43 47" src="https://github.com/user-attachments/assets/522a8b7e-eba6-4df6-9ef8-0c35f5f1c517" />

------

### 4.EKS Cluster and Node Group Creation

The EKS cluster is created using existing VPC resources.

Steps include:
- Creating IAM roles and policies for:
  - EKS Cluster
  - Worker Nodes

<img width="1166" height="535" alt="Screenshot 2025-12-23 at 16 02 05" src="https://github.com/user-attachments/assets/5716e4db-7868-464a-b3da-99df375a3265" />

<img width="1178" height="612" alt="Screenshot 2025-12-23 at 16 06 47" src="https://github.com/user-attachments/assets/9aa5d126-1dc1-4826-bff0-4ce653308104" />


- Creating the EKS cluster
- Creating a managed node group
- Updating the RDS security group to allow traffic from EKS worker nodes
  

<img width="1155" height="268" alt="Screenshot 2025-12-23 at 16 28 23" src="https://github.com/user-attachments/assets/c24e2df9-a2a2-4a0d-a466-065847c418c9" />

<img width="1158" height="647" alt="Screenshot 2025-12-23 at 16 28 33" src="https://github.com/user-attachments/assets/9626be6b-050f-4162-bf8a-cf948bc23d25" />

<img width="1167" height="689" alt="Screenshot 2025-12-23 at 16 42 49" src="https://github.com/user-attachments/assets/06c62671-2dc4-4975-b8b8-5d9cd02d7cd6" />


------

### 5. Kubernetes Authentication and Access

- IAM users are granted cluster access via the aws-auth ConfigMap
- kubectl is configured locally to interact with the cluster

------


### 6. Application Deployment Using Kubernetes Manifests

The application is deployed using Kubernetes manifests:
- deployment.yaml — defines pods and container specs
- secret-provider-class.yaml — integrates AWS Secrets Manager
- service.yaml — exposes the application using a LoadBalancer service
- aws-auth-patch.yaml — manages cluster authentication

<img width="1173" height="690" alt="Screenshot 2025-12-23 at 17 44 30" src="https://github.com/user-attachments/assets/c86d9150-ce8c-41fc-983f-65ac7a7e55eb" />

<img width="1143" height="644" alt="Screenshot 2025-12-23 at 17 45 37" src="https://github.com/user-attachments/assets/c1d08e6e-9dfc-4c56-bdc0-167fad5234b4" />

<img width="542" height="136" alt="Screenshot 2025-12-23 at 17 42 52" src="https://github.com/user-attachments/assets/6b9e8e2f-0913-4101-a94c-73bb9e81353c" />

Manifests are applied using kubectl, and pod health is verified.

---------


### 7. Load Balancer, DNS, and HTTPS Configuration

- Kubernetes provisions an AWS Load Balancer automatically
- The Load Balancer DNS name is mapped in Route 53
- An ACM certificate is attached for SSL termination
- The application becomes accessible securely via HTTPS

------

## Security Highlights

- Application workloads run in private subnets
- Database access restricted via security groups
- Secrets managed using AWS Secrets Manager
- No credentials stored in source code or Kubernetes manifests

------

## Next Phase

This deployment was executed using the AWS Console and CLI to maintain clarity and visibility into each component.

The next phase of this project will:
- Rebuild the architecture using Terraform
- Introduce CI/CD automation
- Improve repeatability and scalability














