# Local file for secondary private key (copied from base infrastructure)
resource "local_file" "secondary_private_key" {
  count           = data.terraform_remote_state.base.outputs.create_secondary_user && data.terraform_remote_state.base.outputs.generate_secondary_key ? 1 : 0
  content         = data.terraform_remote_state.base.outputs.secondary_private_key
  filename        = "${path.module}/generated-keys/${data.terraform_remote_state.base.outputs.secondary_key_pair_name}-private-key.pem"
  file_permission = "0600"
}

# Create generated-keys directory
resource "local_file" "tfe_key_directory" {
  count           = data.terraform_remote_state.base.outputs.create_secondary_user && data.terraform_remote_state.base.outputs.generate_secondary_key ? 1 : 0
  content         = "# TFE Generated Keys Directory\n"
  filename        = "${path.module}/generated-keys/.gitignore"
  file_permission = "0644"
}
