# Generate a new private key if requested
resource "tls_private_key" "generated" {
  count     = var.generate_new_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create directory for generated keys
resource "local_file" "key_directory" {
  count    = var.generate_new_key ? 1 : 0
  content  = ""
  filename = "${path.module}/generated-keys/.gitkeep"
}

# AWS Key Pair - Use generated key if generate_new_key is true, otherwise use provided public key
resource "aws_key_pair" "main" {
  key_name   = var.key_pair_name
  public_key = var.generate_new_key ? tls_private_key.generated[0].public_key_openssh : var.public_key_content

  tags = {
    Name = "${var.project_name}-keypair"
  }

  # Ensure we have a public key to use
  lifecycle {
    precondition {
      condition     = var.generate_new_key || (var.public_key_content != null && var.public_key_content != "")
      error_message = "Either set generate_new_key = true or provide a valid public_key_content."
    }
  }
}

# Save the generated private key to file
resource "local_file" "private_key" {
  count           = var.generate_new_key ? 1 : 0
  content         = tls_private_key.generated[0].private_key_pem
  filename        = "${path.module}/generated-keys/${var.key_pair_name}-private-key.pem"
  file_permission = "0600"

  depends_on = [local_file.key_directory]
}

# Secondary Key Pair for Vault Admin User
resource "tls_private_key" "secondary" {
  count     = var.create_secondary_user && var.generate_secondary_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "secondary_private_key" {
  count           = var.create_secondary_user && var.generate_secondary_key ? 1 : 0
  content         = tls_private_key.secondary[0].private_key_pem
  filename        = "${path.module}/generated-keys/${var.secondary_key_pair_name}-private-key.pem"
  file_permission = "0600"

  depends_on = [local_file.key_directory]
}

resource "aws_key_pair" "secondary" {
  count      = var.create_secondary_user ? 1 : 0
  key_name   = var.secondary_key_pair_name
  public_key = var.generate_secondary_key ? tls_private_key.secondary[0].public_key_openssh : var.secondary_user_public_key

  lifecycle {
    precondition {
      condition = var.generate_secondary_key || var.secondary_user_public_key != ""
      error_message = "Either generate_secondary_key must be true or secondary_user_public_key must be provided."
    }
  }

  tags = {
    Name = "${var.project_name}-${var.secondary_key_pair_name}"
  }
}
