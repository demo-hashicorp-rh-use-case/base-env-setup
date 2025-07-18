# Terraform Enterprise Module
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data sources to reference existing infrastructure
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["${var.base_project_name}-vpc"]
  }
}

data "aws_subnet" "private" {
  filter {
    name   = "tag:Name"
    values = ["${var.base_project_name}-private-subnet"]
  }
}

data "aws_security_group" "bastion" {
  filter {
    name   = "tag:Name"
    values = ["${var.base_project_name}-bastion-sg"]
  }
}

data "aws_security_group" "vault" {
  filter {
    name   = "tag:Name"
    values = ["${var.base_project_name}-vault-sg"]
  }
}

data "aws_instance" "vault" {
  filter {
    name   = "tag:Service"
    values = ["HashiCorp Vault"]
  }
  
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

data "aws_key_pair" "main" {
  key_name = var.key_pair_name
}

# Data source for bastion instance from base infrastructure
data "aws_instance" "bastion" {
  filter {
    name   = "tag:Name"
    values = ["${var.base_project_name}-bastion"]
  }
  
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# Data source for secondary key pair from base infrastructure
data "terraform_remote_state" "base" {
  backend = "local"
  
  config = {
    path = "${path.module}/../terraform/terraform.tfstate"
  }
}
