# Terraform Enterprise Module

This module deploys Terraform Enterprise into an existing VPC infrastructure created by the base environment.

## Prerequisites

1. **Base Infrastructure**: The base environment must be deployed first
2. **TFE License**: Obtain a TFE license file from HashiCorp
3. **SSH Key**: The same SSH key pair used in the base infrastructure

## Dependencies

This module references the following resources from the base infrastructure:
- VPC and private subnet
- Bastion host security group
- Vault instance and security group
- SSH key pair

## Quick Start

1. **Copy the example variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars with your values:**
   ```hcl
   aws_region        = "us-west-2"
   base_project_name = "base-env"  # Must match base infrastructure
   key_pair_name     = "your-key-pair-name"
   tfe_instance_type = "t3.large"
   ```

3. **Initialize and deploy:**
   ```bash
   terraform init  # Downloads required providers (aws, local)
   terraform plan
   terraform apply
   ```

## Installation Process

After deployment:

1. **Get connection commands:**
   ```bash
   terraform output setup_instructions
   ```

2. **Connect to TFE instance:**
   ```bash
   terraform output tfe_ssh_command
   ```

3. **Upload TFE license file:**
   ```bash
   scp license.rli ec2-user@<bastion-ip>:/tmp/
   # Then copy to TFE instance
   ```

4. **Install TFE:**
   ```bash
   sudo ./install-tfe.sh
   ```

5. **Access TFE UI:**
   ```bash
   terraform output tfe_ui_tunnel_command
   # Open https://localhost:8800
   ```

## Vault Integration

The TFE instance includes automated Vault integration:

1. **Test connectivity:**
   ```bash
   ./test-vault-connectivity.sh
   ```

2. **Setup integration:**
   ```bash
   ./setup-tfe-vault-integration.sh
   ```

3. **Configure TFE workspace variables:**
   ```bash
   VAULT_ADDR = http://<vault-ip>:8200
   VAULT_TOKEN = <vault-token>
   ```

## Secondary User Access

The TFE module automatically inherits and manages the secondary user configuration from the base infrastructure:

1. **Inherits secondary user settings** from base infrastructure
2. **Creates local copy of secondary SSH key** in `generated-keys/` directory  
3. **Sets up AWS key pair** for the secondary user in TFE account
4. **Provides local SSH commands** using the generated keys

### Key Management:

- **Primary key**: Uses same key pair as base infrastructure (already exists in AWS)
- **Secondary key**: Uses existing key pair from base infrastructure (does not create duplicate)
- **Local key copy**: Copies secondary private key to `./generated-keys/` for convenience
- **SSH commands**: Reference local key files for easier access from TFE directory

### Setup Process:

1. **Configure in base infrastructure** (`../terraform/terraform.tfvars`):
   ```hcl
   create_secondary_user   = true
   secondary_user_name     = "vault-admin"  # Will be used for TFE too
   generate_secondary_key  = true
   secondary_key_pair_name = "vault-admin-key"
   ```

2. **Deploy base infrastructure first:**
   ```bash
   cd ../terraform
   terraform apply
   ```

3. **Deploy TFE module** (secondary user and keys automatically configured):
   ```bash
   cd ../terraform-enterprise
   terraform init  # Required for local provider
   terraform apply
   ```

4. **Access secondary user:**
   ```bash
   # Uses local generated key file
   terraform output secondary_user_ssh_command
   
   # Key file location
   terraform output secondary_private_key_path
   ```

The secondary user has full sudo privileges and access to all TFE management scripts.

## Management

Use the included management script for common operations:

```bash
./tfe-manager.sh status     # Check service status
./tfe-manager.sh logs       # View application logs
./tfe-manager.sh restart    # Restart services
./tfe-manager.sh backup     # Create backup
```

## Architecture

```
Base Infrastructure VPC
├── Public Subnet
│   └── Bastion Host
└── Private Subnet
    ├── Vault Instance (existing)
    └── TFE Instance (this module)
```

## Security

- **Network Isolation**: TFE runs in private subnet
- **Bastion Access**: SSH access only through bastion host
- **Vault Communication**: Direct communication with Vault instance
- **Encrypted Storage**: 50GB encrypted EBS volume
- **Security Groups**: Restrictive security group rules

## Customization

### Instance Size
```hcl
tfe_instance_type = "t3.xlarge"  # For larger workloads
```

### Additional Access
```hcl
allowed_cidr_blocks = ["10.0.0.0/8"]  # Additional networks
```

### Hostname
```hcl
tfe_hostname = "tfe.company.com"  # Custom hostname
```

## Cost Considerations

- **t3.large instance**: ~$65/month (24/7)
- **50GB GP3 storage**: ~$4/month
- **Combined with base infrastructure**: Additional cost on top of base

## Troubleshooting

1. **Cannot find base infrastructure**:
   - Verify `base_project_name` matches exactly
   - Ensure base infrastructure is deployed in same region

2. **SSH connection issues**:
   - Verify SSH key exists in AWS
   - Check bastion host is running
   - Confirm security group rules

3. **TFE installation fails**:
   - Check license file is uploaded to `/tmp/license.rli`
   - Verify sufficient disk space
   - Check PostgreSQL and Redis are running

4. **Vault connectivity issues**:
   - Run `./test-vault-connectivity.sh`
   - Verify Vault is unsealed and running
   - Check security group rules

## Files Structure

- `main.tf` - Provider and data source configuration
- `variables.tf` - Input variables
- `security_group.tf` - TFE security group
- `ec2.tf` - TFE EC2 instance
- `user_data.sh` - Instance initialization script
- `outputs.tf` - Output values
- `terraform.tfvars.example` - Example configuration

## Cleanup

To destroy only the TFE instance while keeping base infrastructure:

```bash
terraform destroy
```

This will remove only the TFE instance and its security group, leaving the base infrastructure intact.
