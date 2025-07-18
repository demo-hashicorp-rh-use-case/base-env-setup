# Base Environment Setup

A comprehensive AWS infrastructure setup using Terraform with modular architecture for secure, enterprise-grade deployments.

## Project Overview

This project provides a complete foundation for secure AWS infrastructure with HashiCorp Vault and optional Terraform Enterprise. The architecture follows best practices with proper network isolation, security groups, and enterprise-ready automation.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Internet Gateway                     │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────────────────────────────────────────┐
│               Public Subnet (10.0.1.0/24)              │
│  ┌─────────────────┐      ┌──────────────────────────┐  │
│  │   Bastion Host  │      │      NAT Gateway         │  │
│  │   (t3.micro)    │      │   (Outbound Internet)    │  │
│  └─────────────────┘      └──────────────────────────┘  │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────────────────────────────────────────┐
│              Private Subnet (10.0.2.0/24)              │
│  ┌─────────────────┐      ┌──────────────────────────┐  │
│  │  Vault Instance │      │ TFE Instance (Optional) │  │
│  │   (t3.small)    │      │     (t3.large)          │  │
│  │                 │      │                          │  │
│  │ • AWS Secrets   │      │ • PostgreSQL + Redis    │  │
│  │ • Azure Secrets │      │ • Docker + TFE          │  │
│  │ • GCP Secrets   │      │ • Vault Integration     │  │
│  └─────────────────┘      └──────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 📁 Folder Structure

### `/terraform/` - Base Infrastructure

The foundational AWS infrastructure that provides:

- **VPC & Networking**: Complete VPC setup with public/private subnets, NAT Gateway, Internet Gateway
- **Bastion Host**: Secure jump server for accessing private resources
- **HashiCorp Vault**: Enterprise secrets management with cloud provider integrations
- **Security Groups**: Least-privilege network access controls
- **SSH Key Management**: Flexible key pair handling (generate new or use existing)

**Key Features:**
- ✅ Production-ready VPC architecture
- ✅ Automated Vault setup with cloud secret engines (AWS/Azure/GCP)
- ✅ Comprehensive management scripts
- ✅ Security hardening and encryption
- ✅ Cost-optimized instance sizing

**When to use:** Deploy this first as the foundation for any additional services.

### `/terraform-enterprise/` - TFE Module

Optional Terraform Enterprise deployment that leverages the base infrastructure:

- **Modular Design**: References base infrastructure via Terraform data sources
- **Complete TFE Setup**: Automated installation with PostgreSQL and Redis
- **Vault Integration**: Pre-configured scripts for TFE-Vault communication
- **Enterprise Features**: Full TFE capabilities including teams, workspaces, and policy management
- **Independent Deployment**: Can be deployed separately after base infrastructure

**Key Features:**
- ✅ Self-contained TFE module
- ✅ Automated database setup (PostgreSQL + Redis)
- ✅ TFE-Vault integration scripts
- ✅ Management and monitoring tools
- ✅ Secure configuration with self-signed certificates

**When to use:** Deploy after base infrastructure when you need enterprise Terraform workflows.

## 🚀 Quick Start

### 1. Deploy Base Infrastructure

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
terraform init
terraform plan
terraform apply
```

### 2. Access and Configure Vault

```bash
# Get SSH commands from outputs
terraform output vault_ssh_command
terraform output vault_ui_tunnel_command

# Connect to Vault instance
ssh -i ~/.ssh/your-key.pem -o ProxyCommand='...' ec2-user@<vault-ip>

# Initialize Vault
./vault-manager.sh init
./vault-manager.sh unseal
./vault-manager.sh setup-clouds
```

### 3. (Optional) Deploy Terraform Enterprise

```bash
cd ../terraform-enterprise/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings
terraform init
terraform plan
terraform apply

# After deployment, connect and install TFE
terraform output tfe_ssh_command
# Upload TFE license and run installation
```

## 📋 Prerequisites

- **AWS Account** with appropriate permissions
- **Terraform** >= 1.0 installed
- **AWS CLI** configured with credentials
- **SSH Key Pair** (existing or let Terraform generate one)
- **TFE License** (if deploying Terraform Enterprise)

## 🔧 Configuration

### Base Infrastructure Variables

Key variables in `terraform/terraform.tfvars`:

```hcl
project_name          = "my-project"
aws_region           = "us-west-2"
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"
allowed_ssh_cidr    = "0.0.0.0/0"  # Restrict to your IP for security

# SSH Key Management
generate_new_key     = true        # Let Terraform generate a key pair
key_pair_name       = "my-key"
# public_key_content = "ssh-rsa ..." # If uploading existing key

# Instance Sizing
bastion_instance_type = "t3.micro"
vault_instance_type   = "t3.small"
```

### TFE Module Variables

Key variables in `terraform-enterprise/terraform.tfvars`:

```hcl
base_project_name    = "my-project"    # Must match base infrastructure
tfe_project_name     = "tfe"
aws_region          = "us-west-2"
key_pair_name       = "my-key"
generate_new_key    = true            # Must match base setting
tfe_instance_type   = "t3.large"      # TFE requires significant resources
tfe_hostname        = "terraform-enterprise.local"
```

## 🔒 Security Features

- **Network Isolation**: Private subnets with no direct internet access
- **Bastion Security**: SSH access only from specified CIDR blocks
- **Vault Encryption**: All secrets encrypted at rest and in transit
- **Security Groups**: Least-privilege access controls
- **Key Management**: Secure SSH key generation and management
- **TFE Security**: Application and database encryption

## 💰 Cost Considerations

**Base Infrastructure:**
- Bastion: t3.micro (~$9/month, free tier eligible)
- Vault: t3.small (~$17/month)
- NAT Gateway: ~$45/month (largest cost component)
- EBS Storage: ~$1-2/month

**TFE Addition:**
- TFE Instance: t3.large (~$67/month)
- Additional EBS: ~$5/month

**Cost Optimization Tips:**
- Use smaller instances for development
- Consider NAT instances instead of NAT Gateway for dev environments
- Leverage AWS free tier where applicable

## 🛠️ Management

### Base Infrastructure
- `./vault-manager.sh` - Comprehensive Vault management
- Automated cloud secret engine setup
- Health monitoring and backup scripts

### Terraform Enterprise
- `./tfe-manager.sh` - TFE service management
- `./install-tfe.sh` - Automated TFE installation
- `./test-vault-connectivity.sh` - TFE-Vault integration testing

## 📖 Detailed Documentation

- [`terraform/README.md`](terraform/README.md) - Base infrastructure details
- [`terraform-enterprise/README.md`](terraform-enterprise/README.md) - TFE module documentation

## 🧹 Cleanup

```bash
# Remove TFE (if deployed)
cd terraform-enterprise/
terraform destroy

# Remove base infrastructure
cd ../terraform/
terraform destroy
```

## 🤝 Contributing

1. Ensure all Terraform configurations are validated
2. Test both modules independently
3. Update documentation for any changes
4. Follow security best practices

## 📄 License

This project is provided as-is for educational and development purposes. Ensure you have appropriate licenses for HashiCorp Vault and Terraform Enterprise in production environments.
