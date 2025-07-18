output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  description = "Private IP address of the bastion host"
  value       = aws_instance.bastion.private_ip
}

output "vault_instance_private_ip" {
  description = "Private IP address of the Vault instance"
  value       = aws_instance.vault.private_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion host"
  value       = var.generate_new_key ? "ssh -i ${path.module}/generated-keys/${var.key_pair_name}-private-key.pem ec2-user@${aws_instance.bastion.public_ip}" : "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${aws_instance.bastion.public_ip}"
}

output "vault_ssh_command" {
  description = "SSH command to connect to Vault instance via bastion"
  value       = var.generate_new_key ? "ssh -i ${path.module}/generated-keys/${var.key_pair_name}-private-key.pem -o ProxyCommand='ssh -i ${path.module}/generated-keys/${var.key_pair_name}-private-key.pem -W %h:%p ec2-user@${aws_instance.bastion.public_ip}' ec2-user@${aws_instance.vault.private_ip}" : "ssh -i ~/.ssh/${var.key_pair_name}.pem -o ProxyCommand='ssh -i ~/.ssh/${var.key_pair_name}.pem -W %h:%p ec2-user@${aws_instance.bastion.public_ip}' ec2-user@${aws_instance.vault.private_ip}"
}

output "vault_ui_tunnel_command" {
  description = "SSH tunnel command to access Vault UI through bastion"
  value       = var.generate_new_key ? "ssh -i ${path.module}/generated-keys/${var.key_pair_name}-private-key.pem -L 8200:${aws_instance.vault.private_ip}:8200 ec2-user@${aws_instance.bastion.public_ip}" : "ssh -i ~/.ssh/${var.key_pair_name}.pem -L 8200:${aws_instance.vault.private_ip}:8200 ec2-user@${aws_instance.bastion.public_ip}"
}

output "vault_ui_url" {
  description = "Vault UI URL (after establishing SSH tunnel)"
  value       = "http://localhost:8200"
}

output "tfe_ui_url" {
  description = "Terraform Enterprise UI URL (after establishing SSH tunnel)"
  value       = "https://localhost:8800"
}

output "vault_setup_instructions" {
  description = "Instructions for setting up Vault with cloud secret engines"
  value       = <<-EOT
    After connecting to the Vault instance:
    
    1. Initialize and unseal Vault:
       ./vault-manager.sh init
       ./vault-manager.sh unseal
    
    2. Authenticate with root token:
       vault login <root-token-from-init>
    
    3. Setup cloud secret engines:
       ./vault-manager.sh setup-clouds
    
    4. Configure cloud providers:
       - Edit /tmp/aws-config.json with your AWS credentials
       - Edit /tmp/azure-config.json with your Azure credentials  
       - Edit /tmp/gcp-config.json with your GCP service account JSON
    
    5. Apply configurations:
       vault write aws/config/root @/tmp/aws-config.json
       vault write azure/config @/tmp/azure-config.json
       vault write gcp/config @/tmp/gcp-config.json
    
    6. Create roles using example scripts:
       ./aws-role-example.sh
       ./azure-role-example.sh
       ./gcp-role-example.sh
  EOT
}

output "key_pair_name" {
  description = "Name of the key pair used"
  value       = aws_key_pair.main.key_name
}

output "create_secondary_user" {
  description = "Whether secondary user is enabled"
  value       = var.create_secondary_user
}

output "secondary_user_name" {
  description = "Name of the secondary user"
  value       = var.secondary_user_name
}

output "generate_secondary_key" {
  description = "Whether secondary key was generated"
  value       = var.generate_secondary_key
}

output "secondary_key_pair_name" {
  description = "Name of the secondary key pair"
  value       = var.secondary_key_pair_name
}

output "secondary_user_ssh_command" {
  description = "SSH command to connect to Vault instance as secondary user (if enabled)"
  value       = var.create_secondary_user ? (var.generate_secondary_key ? "ssh -i ${path.module}/generated-keys/${var.secondary_key_pair_name}-private-key.pem -o ProxyCommand='ssh -i ${path.module}/generated-keys/${var.key_pair_name}-private-key.pem -W %h:%p ec2-user@${aws_instance.bastion.public_ip}' ${var.secondary_user_name}@${aws_instance.vault.private_ip}" : "ssh -i ~/.ssh/${var.secondary_key_pair_name}.pem -o ProxyCommand='ssh -i ~/.ssh/${var.key_pair_name}.pem -W %h:%p ec2-user@${aws_instance.bastion.public_ip}' ${var.secondary_user_name}@${aws_instance.vault.private_ip}") : "Secondary user not enabled"
}

output "bastion_secondary_user_ssh_command" {
  description = "SSH command to connect to bastion host as secondary user (if enabled)"
  value       = var.create_secondary_user ? (var.generate_secondary_key ? "ssh -i ${path.module}/generated-keys/${var.secondary_key_pair_name}-private-key.pem ${var.secondary_user_name}@${aws_instance.bastion.public_ip}" : "ssh -i ~/.ssh/${var.secondary_key_pair_name}.pem ${var.secondary_user_name}@${aws_instance.bastion.public_ip}") : "Secondary user not enabled"
}

output "secondary_private_key_path" {
  description = "Path to the generated secondary private key file (only if generate_secondary_key is true)"
  value       = var.create_secondary_user && var.generate_secondary_key ? "${path.module}/generated-keys/${var.secondary_key_pair_name}-private-key.pem" : "N/A"
}

output "private_key_path" {
  description = "Path to the generated private key file (only if generate_new_key is true)"
  value       = var.generate_new_key ? "${path.module}/generated-keys/${var.key_pair_name}-private-key.pem" : "N/A - using existing key"
}

output "secondary_public_key" {
  description = "Public key content for the secondary user"
  value       = var.create_secondary_user ? (var.generate_secondary_key ? tls_private_key.secondary[0].public_key_openssh : var.secondary_user_public_key) : null
  sensitive   = false
}

output "secondary_private_key" {
  description = "Private key content for the secondary user (if generated)"
  value       = var.create_secondary_user && var.generate_secondary_key ? tls_private_key.secondary[0].private_key_pem : null
  sensitive   = true
}
