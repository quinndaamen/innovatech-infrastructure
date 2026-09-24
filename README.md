# Innovatech Infrastructure

An individual project where I build an infrastructure for a fictional company named Innovatech Solutions. The main focus is IaC and automation. I started the project as an on-cloud network but later throughout the project made it Hybrid.

The project is being developed across multiple case studies, with each case study building further on the infrastructure and knowledge from the previous one.

## Overview

I build this project as part of my Cloud & Automation semester at Fontys ICT.

In my last project I created another Hybrid environment [Knowledge Hub Hybrid Infrastructure](https://github.com/quinndaamen/knowledge-hub-hybrid-infrastructure), but that one was much more minimal because it was my first time touching anything related to cloud and networks. Because of the experience I had since gained, I could learn new things faster and implement things I already knew.

The main focus of this project for me personally was to gain more knowledge about different tools. This is also why I chose AWS this time instead of Azure, which I had previously used already. The goal was to use tools that would be useful in my future career.

The assignment of the first case study/phase was to create an environment that was automated using IaC, well monitored, scalable and secure. At the same time, I had to think about which technologies to choose, be able to explain why I chose them and take costs into account.

## Why I Made This

First of all, this was the assignment given by the education program/teachers, but there was more freedom than last time. This time we were free to use whatever technologies we wanted, from on-premise to AWS/Google/Azure and whichever web application or monitoring solution we wanted to use, as long as we could explain why we chose that route.

I saw this project as a way to gain knowledge about technologies that could be used in companies I would be working for later.

I am also planning to study Cyber Security in the next semester, so gaining more knowledge about networks could give me a head start.

The project was created across different Case Studies:

## Case Studies

### Case Study 1

**Status: Finished**

Case Study 1 focused on building a resilient and scalable AWS infrastructure using Infrastructure as Code and DevOps practices.

I started the implementation by making a network using Terraform and building on top of that using a structured file system for all the components in the network. A big part of this phase was to implement an autoscalable web server, which I completed by using ECS Fargate as the compute and CloudWatch as the autoscaling metric.

More things I implemented were:

- A private network with only the Load Balancer and the GitHub runner on public subnets.
- Rolling updates of the web server code using a GitHub runner, GitHub Actions and ECR.
- A monitoring solution on a separate isolated EC2 instance running Prometheus and Grafana.
- A private Aurora PostgreSQL database.
- VPC separation between Compute, Database and Monitoring.
- Transit Gateway connectivity between the VPCs.
- VPC endpoints to allow private services to communicate with AWS services without direct internet access.

## Technologies Used

### Infrastructure

- Terraform
- AWS CLI
- AWS:
  - EC2
  - ECS
  - ECR
  - S3
  - VPC
  - Aurora PostgreSQL
  - Secrets Manager
  - Transit Gateway
  - Application Load Balancer
  - Systems Manager
  - IAM
  - VPC Endpoints

### Monitoring

- Prometheus
- Grafana
- Amazon CloudWatch

### CI/CD

- GitHub
- GitHub Actions
- Self-hosted GitHub Runner
- Docker