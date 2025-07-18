# Terraform Enterprise Instance
resource "aws_instance" "terraform_enterprise" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.tfe_instance_type
  key_name               = data.aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.terraform_enterprise.id]
  subnet_id              = data.aws_subnet.private.id

  # TFE requires more storage
  root_block_device {
    volume_type = "gp3"
    volume_size = 50
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    vault_ip                  = data.aws_instance.vault.private_ip
    tfe_hostname             = var.tfe_hostname
    create_secondary_user    = data.terraform_remote_state.base.outputs.create_secondary_user
    secondary_user_name      = data.terraform_remote_state.base.outputs.secondary_user_name
    secondary_user_public_key = data.terraform_remote_state.base.outputs.secondary_public_key
  })

  tags = {
    Name    = "${var.tfe_project_name}-instance"
    Type    = "TerraformEnterprise"
    Service = "Terraform Enterprise"
  }
}
