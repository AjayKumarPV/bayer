#  Django Application Deployment on AWS using Terraform

##  Overview

This project provisions AWS infrastructure using **Terraform** to deploy the default Django application in a secure, scalable, and highly available architecture.

The objective of this assessment is to:

- Deploy the default Django application on AWS
- Use Infrastructure as Code (Terraform)
- Separate public and private network layers
- Apply security best practices
- Ensure reproducibility
- Implement basic high availability

---

#  Design Rationale

This solution focuses on:

- Simplicity and clarity within the 3-hour constraint
- Secure separation between public and private layers
- High availability using Multi-AZ architecture
- Reproducible Infrastructure as Code
- Minimal cost footprint

The architecture is intentionally simple but extensible for production-scale enhancements.


---

#  Architecture

## Components Used

- VPC with public & private subnets (Multi-AZ)
- Internet Gateway
- NAT Gateway
- Application Load Balancer (ALB)
- Target Group
- Auto Scaling Group (ASG)
- Launch Template
- Bastion Host
- Security Groups
- IAM Role & Instance Profile
- Amazon Linux 2023 AMI
- Django + Gunicorn (bootstrapped via user_data)

---

#  Network Design

## Public Layer
- Application Load Balancer
- Bastion Host

## Private Layer
- Django application instances (Auto Scaling Group)

## Routing
- Internet Gateway → Public Subnets
- NAT Gateway → Outbound access for Private Subnets

---

#  Security Design

- ALB exposed on port 80 (HTTP)
- App instances accessible only from ALB (port 8000)
- No public IPs for application servers
- SSH allowed only from my public IP to Bastion
- App servers allow SSH only from Bastion
- IAM Role attached to EC2 instances
- Security Groups used instead of broad CIDR rules where possible

---

#  High Availability

- Multi-AZ public subnets
- Multi-AZ private subnets
- ALB deployed across 2 Availability Zones
- Auto Scaling Group (min=1, max=2)
- ELB health checks enabled

---

#  Assumptions

- An existing EC2 key pair is available
- Terraform >= 1.5.0 is installed
- AWS credentials are configured locally
- The deployment is done in a single AWS region

  
#  Deployment Instructions

Clone the repo

Copy `terraform.tfvars.example` to `terraform.tfvars` and update required values such as your public IP address and EC2 key pair name.

```bash

##  Initialize Terraform

terraform init

##  Validate Configuration
terraform validate

##  Create Execution Plan
terraform plan -out=tfplan

##  Apply Infrastructure
terraform apply tfplan

```
After deployment:
terraform output alb_dns_name

Access the application using a browser in your laptop - http://<alb_dns_name>

Expected output:
Hello, world. You're at the polls index.


