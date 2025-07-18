# Bastion Host
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.bastion_instance_type
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id              = aws_subnet.public.id

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y htop

              # Create secondary user if enabled
              if [ "${var.create_secondary_user}" = "true" ]; then
                echo "Creating secondary user: ${var.secondary_user_name}"
                
                # Create user with home directory
                useradd -m -s /bin/bash ${var.secondary_user_name}
                
                # Create .ssh directory
                mkdir -p /home/${var.secondary_user_name}/.ssh
                chmod 700 /home/${var.secondary_user_name}/.ssh
                
                # Add public key to authorized_keys
                cat <<SECONDARY_KEY > /home/${var.secondary_user_name}/.ssh/authorized_keys
${var.generate_secondary_key ? (var.create_secondary_user ? tls_private_key.secondary[0].public_key_openssh : "") : var.secondary_user_public_key}
SECONDARY_KEY
                
                # Set proper permissions
                chmod 600 /home/${var.secondary_user_name}/.ssh/authorized_keys
                chown -R ${var.secondary_user_name}:${var.secondary_user_name} /home/${var.secondary_user_name}/.ssh
                
                # Add user to sudo group for administrative access
                usermod -aG wheel ${var.secondary_user_name}
                
                echo "✅ Secondary user '${var.secondary_user_name}' created successfully on bastion host"
              fi
              EOF

  tags = {
    Name = "${var.project_name}-bastion"
    Type = "Bastion"
  }
}

# Vault Instance
resource "aws_instance" "vault" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.vault_instance_type
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.vault.id]
  subnet_id              = aws_subnet.private.id

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y htop unzip wget

              # Create vault user
              useradd --system --home /etc/vault.d --shell /bin/false vault

              # Install Vault
              cd /tmp
              wget https://releases.hashicorp.com/vault/1.15.4/vault_1.15.4_linux_amd64.zip
              unzip vault_1.15.4_linux_amd64.zip
              chown root:root vault
              mv vault /usr/local/bin/
              vault --version

              # Create vault directories
              mkdir --parents /opt/vault/data
              mkdir --parents /etc/vault.d
              chown --recursive vault:vault /opt/vault
              chown --recursive vault:vault /etc/vault.d

              # Create vault configuration
              cat <<EOT > /etc/vault.d/vault.hcl
              ui = true
              disable_mlock = true

              storage "file" {
                path = "/opt/vault/data"
              }

              listener "tcp" {
                address     = "0.0.0.0:8200"
                tls_disable = 1
              }

              api_addr = "http://127.0.0.1:8200"
              cluster_addr = "https://127.0.0.1:8201"
              EOT

              chown vault:vault /etc/vault.d/vault.hcl
              chmod 640 /etc/vault.d/vault.hcl

              # Create systemd service
              cat <<EOT > /etc/systemd/system/vault.service
              [Unit]
              Description="HashiCorp Vault - A tool for managing secrets"
              Documentation=https://www.vaultproject.io/docs/
              Requires=network-online.target
              After=network-online.target
              ConditionFileNotEmpty=/etc/vault.d/vault.hcl
              StartLimitIntervalSec=60
              StartLimitBurst=3

              [Service]
              Type=notify
              User=vault
              Group=vault
              ProtectSystem=full
              ProtectHome=read-only
              PrivateTmp=yes
              PrivateDevices=yes
              SecureBits=keep-caps
              AmbientCapabilities=CAP_IPC_LOCK
              Capabilities=CAP_IPC_LOCK+ep
              CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
              NoNewPrivileges=yes
              ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
              ExecReload=/bin/kill --signal HUP \$MAINPID
              KillMode=process
              Restart=on-failure
              RestartSec=5
              TimeoutStopSec=30
              StartLimitInterval=60
              StartLimitBurst=3
              LimitNOFILE=65536
              LimitMEMLOCK=infinity

              [Install]
              WantedBy=multi-user.target
              EOT

              # Enable and start vault service
              systemctl daemon-reload
              systemctl enable vault
              systemctl start vault

              # Wait for vault to start
              sleep 10

              # Set vault address for local commands
              export VAULT_ADDR='http://127.0.0.1:8200'
              echo 'export VAULT_ADDR="http://127.0.0.1:8200"' >> /home/ec2-user/.bashrc

              # Create secondary user if enabled
              if [ "${var.create_secondary_user}" = "true" ]; then
                echo "Creating secondary user: ${var.secondary_user_name}"
                
                # Create user with home directory
                useradd -m -s /bin/bash ${var.secondary_user_name}
                
                # Create .ssh directory
                mkdir -p /home/${var.secondary_user_name}/.ssh
                chmod 700 /home/${var.secondary_user_name}/.ssh
                
                # Add public key to authorized_keys
                cat <<SECONDARY_KEY > /home/${var.secondary_user_name}/.ssh/authorized_keys
              ${var.generate_secondary_key ? (var.create_secondary_user ? tls_private_key.secondary[0].public_key_openssh : "") : var.secondary_user_public_key}
              SECONDARY_KEY
                
                # Set proper permissions
                chmod 600 /home/${var.secondary_user_name}/.ssh/authorized_keys
                chown -R ${var.secondary_user_name}:${var.secondary_user_name} /home/${var.secondary_user_name}/.ssh
                
                # Add user to sudo group for vault management
                usermod -aG wheel ${var.secondary_user_name}
                
                # Set vault environment for secondary user
                echo 'export VAULT_ADDR="http://127.0.0.1:8200"' >> /home/${var.secondary_user_name}/.bashrc
                
                # Create vault management scripts for secondary user
                cp /home/ec2-user/vault-manager.sh /home/${var.secondary_user_name}/
                cp /home/ec2-user/setup-secret-engines.sh /home/${var.secondary_user_name}/
                cp /home/ec2-user/vault-status.sh /home/${var.secondary_user_name}/
                cp /home/ec2-user/init-vault.sh /home/${var.secondary_user_name}/
                chown ${var.secondary_user_name}:${var.secondary_user_name} /home/${var.secondary_user_name}/*.sh
                
                echo "✅ Secondary user '${var.secondary_user_name}' created successfully"
              fi

              # Create initialization script
              cat <<EOT > /home/ec2-user/init-vault.sh
              #!/bin/bash
              export VAULT_ADDR='http://127.0.0.1:8200'
              
              echo "Initializing Vault..."
              vault operator init -key-shares=5 -key-threshold=3 > /home/ec2-user/vault-init.txt
              
              echo "Vault initialization complete. Keys saved to /home/ec2-user/vault-init.txt"
              echo "Please securely store these keys and delete this file after copying them."
              EOT

              chmod +x /home/ec2-user/init-vault.sh
              chown ec2-user:ec2-user /home/ec2-user/init-vault.sh

              # Create vault status check script
              cat <<EOT > /home/ec2-user/vault-status.sh
              #!/bin/bash
              export VAULT_ADDR='http://127.0.0.1:8200'
              vault status
              EOT

              chmod +x /home/ec2-user/vault-status.sh
              chown ec2-user:ec2-user /home/ec2-user/vault-status.sh

              # Create secret engines setup script
              cat <<EOT > /home/ec2-user/setup-secret-engines.sh
              #!/bin/bash
              export VAULT_ADDR='http://127.0.0.1:8200'

              echo "Setting up Cloud Secret Engines..."
              echo "Note: This script should be run after Vault is initialized and unsealed."
              echo

              # Check if Vault is unsealed
              if ! vault status | grep -q "Sealed.*false"; then
                echo "❌ Vault is sealed or not accessible. Please unseal Vault first."
                echo "   Run: vault operator unseal <key>"
                exit 1
              fi

              # Check if we're authenticated
              if ! vault token lookup >/dev/null 2>&1; then
                echo "❌ Not authenticated to Vault. Please login first."
                echo "   Run: vault login <initial-root-token>"
                exit 1
              fi

              echo "✅ Vault is unsealed and accessible"
              echo

              # Enable AWS Secret Engine
              echo "🔧 Enabling AWS Secret Engine..."
              if vault secrets enable -path=aws aws; then
                echo "✅ AWS Secret Engine enabled at path: aws/"
                
                # Configure AWS Secret Engine with example configuration
                cat <<AWSCONFIG > /tmp/aws-config.json
              {
                "access_key": "PLACEHOLDER_ACCESS_KEY",
                "secret_key": "PLACEHOLDER_SECRET_KEY",
                "region": "us-west-2"
              }
              AWSCONFIG
                
                echo "📝 AWS configuration template created at /tmp/aws-config.json"
                echo "   Update with your AWS credentials and run:"
                echo "   vault write aws/config/root @/tmp/aws-config.json"
              else
                echo "⚠️  AWS Secret Engine may already be enabled"
              fi
              echo

              # Enable Azure Secret Engine
              echo "🔧 Enabling Azure Secret Engine..."
              if vault secrets enable -path=azure azure; then
                echo "✅ Azure Secret Engine enabled at path: azure/"
                
                # Create Azure configuration template
                cat <<AZURECONFIG > /tmp/azure-config.json
              {
                "subscription_id": "PLACEHOLDER_SUBSCRIPTION_ID",
                "tenant_id": "PLACEHOLDER_TENANT_ID",
                "client_id": "PLACEHOLDER_CLIENT_ID",
                "client_secret": "PLACEHOLDER_CLIENT_SECRET"
              }
              AZURECONFIG
                
                echo "📝 Azure configuration template created at /tmp/azure-config.json"
                echo "   Update with your Azure credentials and run:"
                echo "   vault write azure/config @/tmp/azure-config.json"
              else
                echo "⚠️  Azure Secret Engine may already be enabled"
              fi
              echo

              # Enable GCP Secret Engine
              echo "🔧 Enabling GCP Secret Engine..."
              if vault secrets enable -path=gcp gcp; then
                echo "✅ GCP Secret Engine enabled at path: gcp/"
                
                # Create GCP configuration template
                cat <<GCPCONFIG > /tmp/gcp-config.json
              {
                "credentials": "PLACEHOLDER_SERVICE_ACCOUNT_JSON"
              }
              GCPCONFIG
                
                echo "📝 GCP configuration template created at /tmp/gcp-config.json"
                echo "   Update with your GCP service account JSON and run:"
                echo "   vault write gcp/config @/tmp/gcp-config.json"
              else
                echo "⚠️  GCP Secret Engine may already be enabled"
              fi
              echo

              # Create example role configurations
              echo "📋 Creating example role configuration scripts..."
              
              # AWS Role Example
              cat <<AWSROLE > /home/ec2-user/aws-role-example.sh
              #!/bin/bash
              export VAULT_ADDR='http://127.0.0.1:8200'

              # Example AWS role for EC2 instances
              vault write aws/roles/ec2-role \\
                  credential_type=iam_user \\
                  policy_document='-' <<POLICY
              {
                "Version": "2012-10-17",
                "Statement": [
                  {
                    "Effect": "Allow",
                    "Action": [
                      "ec2:Describe*",
                      "ec2:List*"
                    ],
                    "Resource": "*"
                  }
                ]
              }
              POLICY

              echo "AWS role 'ec2-role' created. Generate credentials with:"
              echo "vault read aws/creds/ec2-role"
              AWSROLE

              # Azure Role Example
              cat <<AZUREROLE > /home/ec2-user/azure-role-example.sh
              #!/bin/bash
              export VAULT_ADDR='http://127.0.0.1:8200'

              # Example Azure role for resource group access
              vault write azure/roles/reader-role \\
                  azure_roles='-' <<ROLES
              [
                {
                  "role_name": "Reader",
                  "scope":  "/subscriptions/PLACEHOLDER_SUBSCRIPTION_ID/resourceGroups/PLACEHOLDER_RESOURCE_GROUP"
                }
              ]
              ROLES

              echo "Azure role 'reader-role' created. Generate credentials with:"
              echo "vault read azure/creds/reader-role"
              AZUREROLE

              # GCP Role Example
              cat <<GCPROLE > /home/ec2-user/gcp-role-example.sh
              #!/bin/bash
              export VAULT_ADDR='http://127.0.0.1:8200'

              # Example GCP role for storage access
              vault write gcp/roleset/storage-reader \\
                  project="PLACEHOLDER_PROJECT_ID" \\
                  bindings='-' <<BINDINGS
              resource "//cloudresourcemanager.googleapis.com/projects/PLACEHOLDER_PROJECT_ID" {
                roles = ["roles/storage.objectViewer"]
              }
              BINDINGS

              echo "GCP roleset 'storage-reader' created. Generate credentials with:"
              echo "vault read gcp/key/storage-reader"
              GCPROLE

              chmod +x /home/ec2-user/aws-role-example.sh
              chmod +x /home/ec2-user/azure-role-example.sh
              chmod +x /home/ec2-user/gcp-role-example.sh

              echo "🎉 Cloud Secret Engines setup complete!"
              echo
              echo "Next steps:"
              echo "1. Configure each cloud provider with your credentials"
              echo "2. Run the role example scripts to create sample roles"
              echo "3. Test credential generation with 'vault read <engine>/creds/<role>'"
              echo
              echo "📁 Configuration files created:"
              echo "   - /tmp/aws-config.json"
              echo "   - /tmp/azure-config.json" 
              echo "   - /tmp/gcp-config.json"
              echo "   - /home/ec2-user/aws-role-example.sh"
              echo "   - /home/ec2-user/azure-role-example.sh"
              echo "   - /home/ec2-user/gcp-role-example.sh"
              EOT

              chmod +x /home/ec2-user/setup-secret-engines.sh
              chown ec2-user:ec2-user /home/ec2-user/setup-secret-engines.sh

              # Create a comprehensive Vault management script
              cat <<EOT > /home/ec2-user/vault-manager.sh
              #!/bin/bash
              export VAULT_ADDR='http://127.0.0.1:8200'

              show_help() {
                echo "Vault Management Script"
                echo "======================="
                echo
                echo "Usage: ./vault-manager.sh [command]"
                echo
                echo "Commands:"
                echo "  init          - Initialize Vault"
                echo "  status        - Show Vault status"
                echo "  unseal        - Interactive unseal process"
                echo "  login         - Authenticate with root token"
                echo "  setup-clouds  - Setup cloud secret engines"
                echo "  list-engines  - List enabled secret engines"
                echo "  list-policies - List Vault policies"
                echo "  help          - Show this help"
                echo
              }

              vault_init() {
                echo "Initializing Vault..."
                vault operator init -key-shares=5 -key-threshold=3 | tee /home/ec2-user/vault-init.txt
                echo
                echo "⚠️  IMPORTANT: Securely store the unseal keys and root token!"
                echo "    Keys saved to: /home/ec2-user/vault-init.txt"
              }

              vault_status() {
                vault status
              }

              vault_login() {
                echo "Vault Authentication"
                echo "==================="
                vault status
                echo
                if vault status | grep -q "Sealed.*true"; then
                  echo "❌ Vault is sealed. Please unseal it first with: ./vault-manager.sh unseal"
                  exit 1
                fi
                
                echo -n "Enter root token (or any valid token): "
                read -s token
                echo
                
                if vault login "$token" >/dev/null 2>&1; then
                  echo "✅ Successfully authenticated to Vault"
                  echo "🔧 Current token info:"
                  vault token lookup
                else
                  echo "❌ Authentication failed. Please check your token."
                  exit 1
                fi
              }

              vault_unseal() {
                echo "Vault Unseal Process"
                echo "==================="
                vault status
                echo
                if vault status | grep -q "Sealed.*true"; then
                  echo "Vault is sealed. You need 3 unseal keys."
                  for i in {1..3}; do
                    echo -n "Enter unseal key \$i: "
                    read -s key
                    echo
                    vault operator unseal \$key
                  done
                else
                  echo "✅ Vault is already unsealed"
                fi
              }

              list_engines() {
                echo "Enabled Secret Engines:"
                echo "======================"
                vault secrets list
              }

              list_policies() {
                echo "Vault Policies:"
                echo "=============="
                vault policy list
              }

              case "\$1" in
                init)
                  vault_init
                  ;;
                status)
                  vault_status
                  ;;
                unseal)
                  vault_unseal
                  ;;
                login)
                  vault_login
                  ;;
                setup-clouds)
                  /home/ec2-user/setup-secret-engines.sh
                  ;;
                list-engines)
                  list_engines
                  ;;
                list-policies)
                  list_policies
                  ;;
                help|"")
                  show_help
                  ;;
                *)
                  echo "Unknown command: \$1"
                  show_help
                  exit 1
                  ;;
              esac
              EOT

              chmod +x /home/ec2-user/vault-manager.sh
              chown ec2-user:ec2-user /home/ec2-user/vault-manager.sh
              EOF

  tags = {
    Name    = "${var.project_name}-vault-instance"
    Type    = "Vault"
    Service = "HashiCorp Vault"
  }
}
