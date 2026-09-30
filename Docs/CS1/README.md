# Innovatech Solutions – Case Study 1

This document provides an overview of the infrastructure I designed and implemented for Case Study 1 of the Innovatech Solutions project.

![Business Context](.../Images/businesscontext.png)   

The main goal of this case study was to create infrastructure that is scalable, secure, monitored, and automated using Infrastructure as Code (IaC) and DevOps practices.

## Architecture

The final infrastructure was built in AWS Frankfurt (`eu-central-1`).


![Network Diagram](.../Images/networkdiagram.png)   


The infrastructure is separated into three VPCs:

- **Compute VPC** – `10.1.0.0/16`
- **Database VPC** – `10.2.0.0/16`
- **Monitoring VPC** – `10.3.0.0/16`

The VPCs are connected through an **AWS Transit Gateway**.

### Compute VPC

The Compute VPC contains the public and private components of the application infrastructure.

The public subnets contain:

- Application Load Balancer (ALB)
- Self-hosted GitHub Actions runner

The private subnets contain:

- ECS Fargate tasks

The ECS tasks do not have public IP addresses. Internet traffic first reaches the Application Load Balancer, which then forwards requests to the ECS tasks.

### Database VPC

The database is hosted in a separate private VPC.

I used:

- Aurora PostgreSQL
- Private database subnets
- Security Groups
- AWS Secrets Manager

The database is not publicly accessible. The web application connects to it through the private network.

### Monitoring VPC

Monitoring is separated from the application infrastructure.

The Monitoring VPC contains a private EC2 instance running:

- Prometheus
- Grafana

The monitoring instance does not have a public IP address. I used AWS Systems Manager (SSM) and port forwarding to access Grafana.

## Infrastructure as Code

I used **Terraform** to create and manage the AWS infrastructure.

Terraform manages components such as:

- VPCs
- Subnets
- Route tables
- Security Groups
- Transit Gateway
- VPC endpoints
- ECS
- Application Load Balancer
- ECR
- Aurora PostgreSQL
- Secrets Manager
- Monitoring EC2 instance
- GitHub Actions runner

The infrastructure can be created and managed using the standard Terraform workflow:

```text
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

## Web Application

The web application consists of a Flask application behind Nginx.

The application includes:

- Homepage
- Form
- Submissions page
- `/health`
- `/health/db`

The Flask application connects to Aurora PostgreSQL.

The application and Nginx are containerised using Docker. The images are stored in Amazon ECR:

- `innovatech-web`
- `innovatech-nginx`

## ECS and Scaling

The application runs on ECS Fargate across two private subnets.

The service is configured with:

- Minimum tasks: 2
- Maximum tasks: 4
- CPU target: 60%
- Scale cooldown: 60 seconds

The ECS service also replaces failed tasks automatically.

I tested this by stopping one of the running tasks. The number of running tasks automatically returned from 1 to 2.

I also tested autoscaling behaviour. The configuration was in place, but during the load test my laptop reached approximately 98% RAM usage before I could sustain enough traffic to trigger a scale-out.

Because of this, the autoscaling test was marked as **partial**.

## Rolling Updates

I used ECS rolling updates for application deployments.

The deployment configuration keeps the existing tasks available while the new version starts.

I tested this by changing the web application and deploying a new version. The ECS task definition changed from revision 10 to revision 11, and the new version became available through the Application Load Balancer without taking the service completely offline.

## CI/CD

I used:

- GitHub
- GitHub Actions
- Self-hosted GitHub Actions runner
- Docker
- Amazon ECR
- Amazon ECS

The self-hosted runner is an EC2 instance in the public Compute subnet. It does not accept inbound access and is managed using AWS Systems Manager.

The deployment process is:

```text
Git push
    ↓
GitHub Actions
    ↓
Build Docker image
    ↓
Push image to ECR
    ↓
Create new ECS task definition revision
    ↓
Update ECS service
    ↓
Rolling deployment
```

I use the Git commit SHA as the Docker image tag so that every deployment uses a specific image version rather than relying on the `latest` tag.

## Monitoring

I implemented monitoring using:

- Prometheus
- Grafana
- Amazon CloudWatch

The Grafana dashboard displays infrastructure information including:

- ECS CPU usage
- ECS memory usage
- ALB healthy hosts

I also configured a Grafana CPU alert for the ECS service.


![Monitoring Dashboard](.../Images/monitoringdashboard.png)   

During testing, I generated traffic and successfully received the configured email alert.

## Network Security

The infrastructure uses separate VPCs and private subnets to reduce direct exposure.

The main security measures include:

- ECS tasks in private subnets
- Private Aurora database
- Security Groups controlling traffic between components
- Application Load Balancer as the public entry point
- VPC endpoints for required AWS services
- Secrets Manager for database credentials
- Systems Manager instead of SSH for private instances

I used VPC endpoints for services such as ECR, S3, Secrets Manager, and SSM so that private resources could communicate with the required AWS services without needing direct internet access.

## Testing

I tested the main parts of the infrastructure, including:

- Web application availability
- ALB health checks
- Database connectivity
- Database read/write operations
- Database private access
- ECS private networking
- Security Groups
- ECS task failure recovery
- Autoscaling
- Monitoring
- Grafana alerts
- Rolling updates
- CI/CD
- Secrets Manager

Most tests passed successfully.

The main partial result was the ECS autoscaling test because I could not generate enough sustained traffic from my laptop to trigger the configured scale-out.

More detailed testing is documented in my school portfolio.

![test plan](.../Images/testplanoutcomes.png)  

## Problems Encountered

During implementation, I encountered several problems that required changes to the infrastructure.

One example was that private ECS tasks could not initially retrieve required resources from AWS services. I resolved this by adding the required VPC endpoints.

I also initially used the `latest` Docker image tag. This caused problems when deploying new versions because ECS could continue using the previous image. I changed the CI/CD pipeline to use Git commit SHA tags instead.

Another issue occurred with Secrets Manager after rebuilding the infrastructure with Terraform. The secret could be scheduled for deletion, so I had to restore it and import it into the Terraform state when necessary.

I also initially planned to use Ansible, but I did not use it in the final implementation because Terraform and AWS services covered the infrastructure-management requirements.

## Final Result

The final Case Study 1 infrastructure consists of three connected AWS VPCs with:

- AWS Transit Gateway
- Application Load Balancer
- ECS Fargate
- Nginx
- Flask
- Aurora PostgreSQL
- Amazon ECR
- Secrets Manager
- Prometheus
- Grafana
- CloudWatch
- GitHub Actions
- Self-hosted GitHub Actions runner
- Terraform

The infrastructure is managed through Infrastructure as Code, and the application can be deployed through the CI/CD pipeline using rolling updates.
