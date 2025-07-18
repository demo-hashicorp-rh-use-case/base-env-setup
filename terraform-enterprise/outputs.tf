output "tfe_instance_id" {
  description = "ID of the Terraform Enterprise instance"
  value       = aws_instance.terraform_enterprise.id
}

output "tfe_private_ip" {
  description = "Private IP address of the Terraform Enterprise instance"
  value       = aws_instance.terraform_enterprise.private_ip
}

output "tfe_security_group_id" {
  description = "ID of the TFE security group"
  value       = aws_security_group.terraform_enterprise.id
}

output "vault_private_ip" {
  description = "Private IP address of the Vault instance (from base infrastructure)"
  value       = data.aws_instance.vault.private_ip
}

output "bastion_public_ip" {
  description = "Public IP address of the bastion host (from base infrastructure)"
  value       = data.aws_instance.bastion.public_ip
}

output "tfe_ssh_command" {
  description = "SSH command to connect to TFE instance via bastion"
  value       = var.generate_new_key ? "ssh -i ${path.module}/../terraform/generated-keys/${var.key_pair_name}-private-key.pem -o ProxyCommand='ssh -i ${path.module}/../terraform/generated-keys/${var.key_pair_name}-private-key.pem -W %h:%p ec2-user@${data.aws_instance.bastion.public_ip}' ec2-user@${aws_instance.terraform_enterprise.private_ip}" : "ssh -i ~/.ssh/${var.key_pair_name}.pem -o ProxyCommand='ssh -i ~/.ssh/${var.key_pair_name}.pem -W %h:%p ec2-user@${data.aws_instance.bastion.public_ip}' ec2-user@${aws_instance.terraform_enterprise.private_ip}"
}

output "tfe_ui_tunnel_command" {
  description = "SSH tunnel command to access TFE UI through bastion"
  value       = var.generate_new_key ? "ssh -i ${path.module}/../terraform/generated-keys/${var.key_pair_name}-private-key.pem -L 8800:${aws_instance.terraform_enterprise.private_ip}:8800 ec2-user@${data.aws_instance.bastion.public_ip}" : "ssh -i ~/.ssh/${var.key_pair_name}.pem -L 8800:${aws_instance.terraform_enterprise.private_ip}:8800 ec2-user@${data.aws_instance.bastion.public_ip}"
}

output "tfe_ui_url" {
  description = "Terraform Enterprise UI URL (after establishing SSH tunnel)"
  value       = "https://localhost:8800"
}

output "setup_instructions" {
  description = "Setup instructions for TFE"
  value = <<-EOT
    Terraform Enterprise Setup:
    
    1. Connect to TFE instance:
       ${var.generate_new_key ? "ssh -i ${path.module}/../terraform/generated-keys/${var.key_pair_name}-private-key.pem -o ProxyCommand='ssh -i ${path.module}/../terraform/generated-keys/${var.key_pair_name}-private-key.pem -W %h:%p ec2-user@${data.aws_instance.bastion.public_ip}' ec2-user@${aws_instance.terraform_enterprise.private_ip}" : "ssh -i ~/.ssh/${var.key_pair_name}.pem -o ProxyCommand='ssh -i ~/.ssh/${var.key_pair_name}.pem -W %h:%p ec2-user@${data.aws_instance.bastion.public_ip}' ec2-user@${aws_instance.terraform_enterprise.private_ip}"}
    
    2. Test Vault connectivity:
       ./test-vault-connectivity.sh
    
    3. Upload TFE license:
       # First, upload license to bastion:
       ${var.generate_new_key ? "scp -i ${path.module}/../terraform/generated-keys/${var.key_pair_name}-private-key.pem license.rli ec2-user@${data.aws_instance.bastion.public_ip}:/tmp/" : "scp -i ~/.ssh/${var.key_pair_name}.pem license.rli ec2-user@${data.aws_instance.bastion.public_ip}:/tmp/"}
       
       # Then, from within TFE instance (after connecting in step 1):
       scp ec2-user@${data.aws_instance.bastion.private_ip}:/tmp/license.rli /tmp/
    
    4. Install TFE:
       sudo ./install-tfe.sh
    
    5. Access TFE UI:
       ${var.generate_new_key ? "ssh -i ${path.module}/../terraform/generated-keys/${var.key_pair_name}-private-key.pem -L 8800:${aws_instance.terraform_enterprise.private_ip}:8800 ec2-user@${data.aws_instance.bastion.public_ip}" : "ssh -i ~/.ssh/${var.key_pair_name}.pem -L 8800:${aws_instance.terraform_enterprise.private_ip}:8800 ec2-user@${data.aws_instance.bastion.public_ip}"}
       Open: https://localhost:8800
    
    6. Setup Vault integration:
       ./setup-tfe-vault-integration.sh
    
    TFE Instance: ${aws_instance.terraform_enterprise.private_ip}
    Vault Instance: ${data.aws_instance.vault.private_ip}
    VPC: ${data.aws_vpc.main.id}
    
    ${data.terraform_remote_state.base.outputs.create_secondary_user ? "Secondary User Commands:" : ""}
    ${data.terraform_remote_state.base.outputs.create_secondary_user ? "Connect as secondary user: terraform output secondary_user_ssh_command" : ""}
    ${data.terraform_remote_state.base.outputs.create_secondary_user ? "Secondary user: ${data.terraform_remote_state.base.outputs.secondary_user_name}" : ""}
  EOT
}

output "bastion_ssh_command" {
  description = "SSH command to connect to bastion host"
  value       = var.generate_new_key ? "ssh -i ${path.module}/../terraform/generated-keys/${var.key_pair_name}-private-key.pem ec2-user@${data.aws_instance.bastion.public_ip}" : "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${data.aws_instance.bastion.public_ip}"
}

output "tfe_scp_command_template" {
  description = "Template for copying files to TFE instance via bastion"
  value       = var.generate_new_key ? "scp -i ${path.module}/../terraform/generated-keys/${var.key_pair_name}-private-key.pem -o ProxyCommand='ssh -i ${path.module}/../terraform/generated-keys/${var.key_pair_name}-private-key.pem -W %h:%p ec2-user@${data.aws_instance.bastion.public_ip}' <local-file> ec2-user@${aws_instance.terraform_enterprise.private_ip}:<remote-path>" : "scp -i ~/.ssh/${var.key_pair_name}.pem -o ProxyCommand='ssh -i ~/.ssh/${var.key_pair_name}.pem -W %h:%p ec2-user@${data.aws_instance.bastion.public_ip}' <local-file> ec2-user@${aws_instance.terraform_enterprise.private_ip}:<remote-path>"
}

output "secondary_key_pair_name" {
  description = "Name of the secondary key pair (from base infrastructure)"
  value       = data.terraform_remote_state.base.outputs.create_secondary_user ? data.terraform_remote_state.base.outputs.secondary_key_pair_name : null
}

output "secondary_private_key_path" {
  description = "Path to the secondary private key file (if generated)"
  value       = data.terraform_remote_state.base.outputs.create_secondary_user && data.terraform_remote_state.base.outputs.generate_secondary_key ? "${path.module}/generated-keys/${data.terraform_remote_state.base.outputs.secondary_key_pair_name}-private-key.pem" : null
}

output "secondary_user_ssh_command" {
  description = "SSH command to connect to TFE instance as secondary user via bastion"
  value       = data.terraform_remote_state.base.outputs.create_secondary_user ? (data.terraform_remote_state.base.outputs.generate_secondary_key ? "ssh -i ${path.module}/generated-keys/${data.terraform_remote_state.base.outputs.secondary_key_pair_name}-private-key.pem -o ProxyCommand='ssh -i ${path.module}/../terraform/generated-keys/${var.key_pair_name}-private-key.pem -W %h:%p ec2-user@${data.aws_instance.bastion.public_ip}' ${data.terraform_remote_state.base.outputs.secondary_user_name}@${aws_instance.terraform_enterprise.private_ip}" : "ssh -i ~/.ssh/${data.terraform_remote_state.base.outputs.secondary_key_pair_name}.pem -o ProxyCommand='ssh -i ~/.ssh/${var.key_pair_name}.pem -W %h:%p ec2-user@${data.aws_instance.bastion.public_ip}' ${data.terraform_remote_state.base.outputs.secondary_user_name}@${aws_instance.terraform_enterprise.private_ip}") : "Secondary user not enabled"
}
