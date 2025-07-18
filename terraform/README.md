# Base Environment Setup - Terraform

This Terraform configuration creates a secure AWS infrastructure foundation with:

- **VPC** with DNS support and hostnames enabled
- **Public subnet** with Internet Gateway for internet access
- **Private subnet** with NAT Gateway for outbound internet access
- **Bastion host** in the public subnet for secure access
- **HashiCorp Vault instance** in the private subnet for secrets management
- **Security groups** with least privilege access

## Architecture

```
Internet Gateway
       |
   Public Subnet (10.0.1.0/24)
       |
   Bastion Host (t3.micro)
       |
   NAT Gateway
       |
   Private Subnet (10.0.2.0/24)
       |
   └── Vault Instance (t3.small)
```

## Modular Design

This base configuration provides the foundational infrastructure. Additional services can be deployed separately:

- **Terraform Enterprise**: Available in `../terraform-enterprise/` folder for separate deployment
- **Other Services**: Can reference this base infrastructure via data sources

## Prerequisites

1. **AWS CLI configured** with appropriate credentials
2. **Terraform installed** (version >= 1.0)
3. **SSH Key Pair** - You can either:
   - Use an existing AWS Key Pair, OR
   - Let Terraform generate a new one for you

## SSH Key Management

This configuration supports two methods for SSH key management:

### Option 1: Use Existing Key Pair
If you already have an AWS key pair:
```hcl
generate_new_key = false
key_pair_name    = "my-existing-key"
# public_key_content not needed if key already exists in AWS
```

### Option 2: Upload Your Public Key
If you have a local SSH key pair:
```hcl
generate_new_key     = false
key_pair_name        = "my-uploaded-key"
public_key_content   = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7..."
```

### Option 3: Generate New Key Pair
If you want Terraform to create a new key pair for you:
```hcl
generate_new_key = true
key_pair_name    = "terraform-generated-key"
# public_key_content not needed when generate_new_key = true
```

## Secondary User Configuration

You can optionally create a secondary user on the Vault instance with a separate SSH key pair. This is useful for:
- Providing Vault admin access to different team members
- Separating administrative access from regular EC2 access
- Testing different authentication methods

### Enable Secondary User
```hcl
create_secondary_user      = true
secondary_user_name        = "vault-admin"
generate_secondary_key     = true
secondary_key_pair_name    = "vault-admin-key"
```

### Use Existing Key for Secondary User
```hcl
create_secondary_user      = true
secondary_user_name        = "vault-admin"
generate_secondary_key     = false
secondary_user_public_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7... admin@example.com"
secondary_key_pair_name    = "existing-admin-key"
```

## Prerequisites

⚠️ **Important**: If you choose Option 3, the private key will be saved to `generated-keys/` directory. Keep this file secure!

## Quick Start

1. **Copy the example variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars** with your values:
   ```hcl
   aws_region     = "us-west-2"
   project_name   = "my-project"
   
   # Choose your SSH key option:
   # Option 1: Use existing AWS key pair
   generate_new_key = false
   key_pair_name    = "your-existing-key-name"
   
   # Option 2: Upload your public key
   # generate_new_key     = false
   # key_pair_name        = "my-uploaded-key"
   # public_key_content   = "ssh-rsa AAAAB3NzaC1yc2E..."
   
   # Option 3: Generate new key pair
   # generate_new_key = true
   # key_pair_name    = "terraform-generated-key"
   
   allowed_ssh_cidr = "YOUR_IP/32"  # Replace with your IP
   ```

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Plan the deployment:**
   ```bash
   terraform plan
   ```

5. **Apply the configuration:**
   ```bash
   terraform apply
   ```

## Accessing Your Instances

After deployment, use the output commands to connect:

### Connect to Bastion Host
```bash
ssh -i ~/.ssh/your-key.pem ec2-user@<bastion-public-ip>
```

### Connect to Vault Instance (via Bastion)
```bash
ssh -i ~/.ssh/your-key.pem -o ProxyCommand='ssh -i ~/.ssh/your-key.pem -W %h:%p ec2-user@<bastion-public-ip>' ec2-user@<vault-instance-ip>
```

### Connect as Secondary User (if enabled)
```bash
ssh -i ~/.ssh/secondary-key.pem -o ProxyCommand='ssh -i ~/.ssh/main-key.pem -W %h:%p ec2-user@<bastion-public-ip>' vault-admin@<vault-instance-ip>
```

### Initialize Vault
After connecting to the Vault instance:
```bash
# Initialize Vault (first time only)
./vault-manager.sh init

# Unseal Vault
./vault-manager.sh unseal

# Authenticate with root token
vault login <root-token-from-init-output>

# Setup cloud secret engines
./vault-manager.sh setup-clouds
```

### Configure Cloud Secret Engines

1. **AWS Secret Engine:**
   ```bash
   # Edit AWS configuration
   nano /tmp/aws-config.json
   # Apply configuration
   vault write aws/config/root @/tmp/aws-config.json
   ```

2. **Azure Secret Engine:**
   ```bash
   # Edit Azure configuration
   nano /tmp/azure-config.json
   # Apply configuration
   vault write azure/config @/tmp/azure-config.json
   ```

3. **GCP Secret Engine:**
   ```bash
   # Edit GCP configuration
   nano /tmp/gcp-config.json
   # Apply configuration
   vault write gcp/config @/tmp/gcp-config.json
   ```

### Create Roles and Generate Credentials

```bash
# Create example roles
./aws-role-example.sh
./azure-role-example.sh
./gcp-role-example.sh

# Generate dynamic credentials
vault read aws/creds/ec2-role
vault read azure/creds/reader-role
vault read gcp/key/storage-reader
```

### Vault Management Commands

```bash
# Use the comprehensive management script
./vault-manager.sh help
./vault-manager.sh status
./vault-manager.sh list-engines
./vault-manager.sh list-policies
```

Or use the exact commands from Terraform outputs:
```bash
terraform output vault_ssh_command
terraform output vault_ui_tunnel_command
terraform output secondary_user_ssh_command  # If secondary user enabled
```

## Security Features

- **Bastion Security Group**: Only allows SSH (port 22) from specified CIDR
- **Private Security Group**: Only allows SSH from bastion and HTTP/HTTPS from VPC
- **Vault Security Group**: Only allows SSH from bastion, Vault API (8200) and cluster (8201) from VPC
- **Network Isolation**: Private instances have no direct internet access
- **NAT Gateway**: Enables outbound internet for private instances (for updates, etc.)
- **Vault Encryption**: All secrets stored encrypted at rest
- **Vault Access Control**: UI and API access only through SSH tunnel

## Customization

### Instance Types
Modify in `terraform.tfvars`:
```hcl
bastion_instance_type = "t3.small"
vault_instance_type   = "t3.medium"  # Vault benefits from more resources
```

### Network Configuration
Adjust CIDR blocks in `terraform.tfvars`:
```hcl
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"
```

### Security
For better security, restrict SSH access to your IP:
```hcl
allowed_ssh_cidr = "YOUR_PUBLIC_IP/32"
```

## Cost Optimization

- Uses `t3.micro` instance for bastion (eligible for free tier)
- Uses `t3.small` for Vault (minimal viable size for Vault)
- NAT Gateway incurs charges (~$45/month)
- Consider NAT Instance for lower cost in development environments

## Terraform Enterprise Module

For Terraform Enterprise deployment, see the separate `../terraform-enterprise/` module which:

- References this base infrastructure via data sources
- Deploys TFE instance with complete automation
- Includes TFE-Vault integration scripts
- Can be deployed independently after this base infrastructure

## HashiCorp Vault Features

- **Version**: Vault 1.15.4 (latest stable)
- **Storage**: File storage backend (suitable for single-node development)
- **UI**: Web UI enabled and accessible via SSH tunnel
- **Configuration**: Pre-configured with secure defaults
- **Initialization**: Automated initialization script provided
- **Service**: Runs as systemd service with auto-restart
- **Security**: Runs as dedicated vault user with minimal privileges

### Cloud Secret Engines

- **AWS Secret Engine**: Dynamic AWS IAM user/role credentials
- **Azure Secret Engine**: Dynamic Azure service principal credentials  
- **GCP Secret Engine**: Dynamic GCP service account credentials
- **Automated Setup**: Scripts provided for easy configuration
- **Example Roles**: Pre-configured example roles for each cloud provider
- **Template Configs**: Configuration templates for quick setup

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Files Structure

- `main.tf` - Provider configuration and data sources
- `variables.tf` - Input variables
- `vpc.tf` - VPC, subnets, and networking resources
- `security_groups.tf` - Security group configurations
- `ec2.tf` - EC2 instances
- `key_pair.tf` - SSH key pair management
- `outputs.tf` - Output values
- `terraform.tfvars.example` - Example variables file

## Troubleshooting

1. **Key pair not found**: 
   - If using existing key: Ensure the key pair exists in your AWS region
   - If uploading: Set `public_key_content` with your public key
   - If generating: Set `generate_new_key = true`
2. **Permission denied**: Check AWS credentials and IAM permissions
3. **CIDR conflicts**: Ensure your VPC CIDR doesn't conflict with existing VPCs
4. **Region availability**: Some instance types may not be available in all AZs
5. **Generated key permissions**: If using generated keys, ensure the private key file has correct permissions (600)
