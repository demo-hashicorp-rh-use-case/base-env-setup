variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "base-env"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "bastion_instance_type" {
  description = "EC2 instance type for bastion host"
  type        = string
  default     = "t3.micro"
}

variable "private_instance_type" {
  description = "EC2 instance type for private instance"
  type        = string
  default     = "t3.micro"
}

variable "vault_instance_type" {
  description = "EC2 instance type for Vault instance"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "Name of the AWS key pair to use for EC2 instances"
  type        = string
  default     = "my-key-pair"
}

variable "public_key_content" {
  description = "Public key content for the AWS key pair (only needed if generate_new_key is false and key doesn't exist in AWS)"
  type        = string
  default     = null
}

variable "generate_new_key" {
  description = "Whether to generate a new SSH key pair or use an existing public key"
  type        = bool
  default     = false
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH to bastion host"
  type        = string
  default     = "0.0.0.0/0"
}

variable "create_secondary_user" {
  description = "Whether to create a secondary EC2 user for Vault access"
  type        = bool
  default     = false
}

variable "secondary_user_name" {
  description = "Name of the secondary EC2 user"
  type        = string
  default     = "vault-admin"
}

variable "secondary_user_public_key" {
  description = "Public SSH key content for the secondary user"
  type        = string
  default     = ""
}

variable "secondary_key_pair_name" {
  description = "Name for the secondary key pair (if generating new key)"
  type        = string
  default     = "vault-admin-key"
}

variable "generate_secondary_key" {
  description = "Whether to generate a new SSH key pair for the secondary user"
  type        = bool
  default     = false
}
