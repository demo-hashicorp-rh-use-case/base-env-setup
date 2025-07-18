#!/bin/bash
yum update -y
yum install -y htop unzip wget docker git nc jq awscli

# Start and enable Docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Create TFE directories
mkdir -p /opt/tfe
mkdir -p /etc/tfe
chown ec2-user:ec2-user /opt/tfe
chown ec2-user:ec2-user /etc/tfe

# Create TFE configuration
cat <<EOT > /etc/tfe/settings.json
{
  "hostname": {
    "value": "${tfe_hostname}"
  },
  "installation_type": {
    "value": "production"
  },
  "production_type": {
    "value": "external"
  },
  "disk_path": {
    "value": "/opt/tfe"
  },
  "pg_netloc": {
    "value": "localhost"
  },
  "pg_dbname": {
    "value": "tfe"
  },
  "pg_user": {
    "value": "tfe"
  },
  "pg_password": {
    "value": "terraform_enterprise_password"
  },
  "redis_host": {
    "value": "localhost"
  },
  "redis_port": {
    "value": "6379"
  },
  "redis_use_password_auth": {
    "value": "0"
  },
  "tls_cert_file": {
    "value": "/etc/tfe/cert.pem"
  },
  "tls_key_file": {
    "value": "/etc/tfe/key.pem"
  },
  "tls_ca_bundle_file": {
    "value": "/etc/tfe/ca-bundle.pem"
  }
}
EOT

# Install PostgreSQL
amazon-linux-extras install postgresql13 -y
yum install -y postgresql13-server postgresql13

# Initialize PostgreSQL
postgresql-setup initdb
systemctl start postgresql
systemctl enable postgresql

# Configure PostgreSQL
sudo -u postgres psql <<PSQL
CREATE DATABASE tfe;
CREATE USER tfe WITH PASSWORD 'terraform_enterprise_password';
GRANT ALL PRIVILEGES ON DATABASE tfe TO tfe;
\q
PSQL

# Configure PostgreSQL authentication
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf
echo "host all all 127.0.0.1/32 md5" >> /var/lib/pgsql/data/pg_hba.conf
systemctl restart postgresql

# Install Redis
amazon-linux-extras install redis6 -y
systemctl start redis
systemctl enable redis

# Generate self-signed certificates for development
openssl req -x509 -newkey rsa:4096 -keyout /etc/tfe/key.pem -out /etc/tfe/cert.pem -days 365 -nodes -subj "/C=US/ST=State/L=City/O=Organization/CN=${tfe_hostname}"
cp /etc/tfe/cert.pem /etc/tfe/ca-bundle.pem

# Set permissions
chown root:root /etc/tfe/*.pem
chmod 600 /etc/tfe/key.pem
chmod 644 /etc/tfe/cert.pem /etc/tfe/ca-bundle.pem

# Create TFE installation script
cat <<'EOT' > /home/ec2-user/install-tfe.sh
#!/bin/bash

echo "Terraform Enterprise Installation Script"
echo "======================================="
echo

echo "⚠️  This script requires a TFE license file and installer."
echo "   Please obtain these from HashiCorp before proceeding."
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root (use sudo)"
  exit 1
fi

# Check if license file exists
if [ ! -f "/tmp/license.rli" ]; then
  echo "❌ License file not found at /tmp/license.rli"
  echo "   Please upload your TFE license file to /tmp/license.rli"
  exit 1
fi

echo "✅ License file found"

# Download TFE installer if not present
if [ ! -f "/tmp/install.sh" ]; then
  echo "📥 Downloading TFE installer..."
  curl -o /tmp/install.sh https://install.terraform.io/ptfe/stable
  chmod +x /tmp/install.sh
fi

echo "✅ TFE installer ready"
echo
echo "🚀 Starting TFE installation..."
echo "   This may take 10-15 minutes..."

# Run TFE installer
/tmp/install.sh \
  no-proxy \
  private-address=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) \
  public-address=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

echo
echo "🎉 TFE installation script completed!"
echo
echo "Next steps:"
echo "1. Wait for the installation to complete (check with: sudo systemctl status tfe)"
echo "2. Access TFE via SSH tunnel: ssh -L 8800:localhost:8800 ec2-user@<bastion-ip>"
echo "3. Open browser to: https://localhost:8800"
echo "4. Complete the initial setup wizard"
EOT

chmod +x /home/ec2-user/install-tfe.sh
chown ec2-user:ec2-user /home/ec2-user/install-tfe.sh

# Create TFE management script
cat <<'EOT' > /home/ec2-user/tfe-manager.sh
#!/bin/bash

show_help() {
  echo "Terraform Enterprise Management Script"
  echo "====================================="
  echo
  echo "Usage: ./tfe-manager.sh [command]"
  echo
  echo "Commands:"
  echo "  status        - Show TFE service status"
  echo "  logs          - Show TFE logs"
  echo "  restart       - Restart TFE services"
  echo "  backup        - Create TFE backup"
  echo "  install       - Run TFE installation"
  echo "  upgrade       - Upgrade TFE (requires new installer)"
  echo "  help          - Show this help"
  echo
}

tfe_status() {
  echo "Terraform Enterprise Status"
  echo "==========================="
  echo
  echo "TFE Application Status:"
  sudo systemctl status tfe 2>/dev/null || echo "TFE not installed yet"
  echo
  echo "PostgreSQL Status:"
  sudo systemctl status postgresql
  echo
  echo "Redis Status:"
  sudo systemctl status redis
  echo
  echo "Docker Status:"
  sudo systemctl status docker
}

tfe_logs() {
  echo "TFE Application Logs:"
  echo "===================="
  sudo journalctl -u tfe -f --lines=50
}

tfe_restart() {
  echo "Restarting TFE services..."
  sudo systemctl restart postgresql
  sudo systemctl restart redis
  sudo systemctl restart docker
  sudo systemctl restart tfe 2>/dev/null || echo "TFE service not found (may not be installed yet)"
  echo "✅ Services restarted"
}

tfe_backup() {
  echo "Creating TFE backup..."
  backup_dir="/opt/tfe/backups/$(date +%Y%m%d_%H%M%S)"
  sudo mkdir -p "$backup_dir"
  
  # Backup PostgreSQL
  sudo -u postgres pg_dump tfe > "$backup_dir/tfe_database.sql"
  
  # Backup TFE data
  sudo cp -r /opt/tfe/data "$backup_dir/" 2>/dev/null || echo "No TFE data directory found"
  
  echo "✅ Backup created at: $backup_dir"
}

tfe_install() {
  sudo /home/ec2-user/install-tfe.sh
}

case "$1" in
  status)
    tfe_status
    ;;
  logs)
    tfe_logs
    ;;
  restart)
    tfe_restart
    ;;
  backup)
    tfe_backup
    ;;
  install)
    tfe_install
    ;;
  help|"")
    show_help
    ;;
  *)
    echo "Unknown command: $1"
    show_help
    exit 1
    ;;
esac
EOT

chmod +x /home/ec2-user/tfe-manager.sh
chown ec2-user:ec2-user /home/ec2-user/tfe-manager.sh

# Create Vault connectivity test script
cat <<EOT > /home/ec2-user/test-vault-connectivity.sh
#!/bin/bash

echo "Testing TFE to Vault Connectivity"
echo "================================="
echo

# Vault IP from template variable
VAULT_IP="${vault_ip}"

echo "🔍 Testing connectivity to Vault at \$VAULT_IP:8200"

# Test basic network connectivity
if nc -z \$VAULT_IP 8200 2>/dev/null; then
  echo "✅ Network connectivity to Vault: OK"
else
  echo "❌ Network connectivity to Vault: FAILED"
  echo "   Check security groups and network configuration"
  exit 1
fi

# Test HTTP connectivity
if curl -s --connect-timeout 5 http://\$VAULT_IP:8200/v1/sys/health >/dev/null; then
  echo "✅ HTTP connectivity to Vault: OK"
else
  echo "❌ HTTP connectivity to Vault: FAILED"
  echo "   Vault may not be running or accessible"
fi

# Test Vault API
VAULT_STATUS=\$(curl -s http://\$VAULT_IP:8200/v1/sys/health | jq -r '.sealed // "unknown"' 2>/dev/null)
case "\$VAULT_STATUS" in
  "false")
    echo "✅ Vault API Status: Unsealed and ready"
    ;;
  "true")
    echo "⚠️  Vault API Status: Sealed (needs to be unsealed)"
    ;;
  *)
    echo "❓ Vault API Status: Unknown (\$VAULT_STATUS)"
    ;;
esac

echo
echo "🔧 Vault Integration Commands:"
echo "   export VAULT_ADDR=\"http://\$VAULT_IP:8200\""
echo "   vault status"
echo "   vault login <token>"
echo

# Create Vault environment file
cat <<VAULT_ENV > /home/ec2-user/.vault_env
export VAULT_ADDR="http://\$VAULT_IP:8200"
export VAULT_SKIP_VERIFY=true
VAULT_ENV

echo "📝 Vault environment variables saved to /home/ec2-user/.vault_env"
echo "   Source with: source ~/.vault_env"
EOT

chmod +x /home/ec2-user/test-vault-connectivity.sh
chown ec2-user:ec2-user /home/ec2-user/test-vault-connectivity.sh

# Create TFE-Vault integration setup script
cat <<EOT > /home/ec2-user/setup-tfe-vault-integration.sh
#!/bin/bash

echo "TFE-Vault Integration Setup"
echo "=========================="
echo

# Source Vault environment
if [ -f /home/ec2-user/.vault_env ]; then
  source /home/ec2-user/.vault_env
  echo "✅ Loaded Vault environment from ~/.vault_env"
else
  echo "❌ Vault environment not found. Run ./test-vault-connectivity.sh first"
  exit 1
fi

echo "🔧 Setting up TFE-Vault integration..."
echo
echo "This script helps configure TFE to use Vault for:"
echo "  - Dynamic credentials for cloud providers"
echo "  - Secure secret management"
echo "  - Policy-based access control"
echo

# Install Vault CLI if not present
if ! command -v vault &> /dev/null; then
  echo "📥 Installing Vault CLI..."
  cd /tmp
  wget -q https://releases.hashicorp.com/vault/1.15.4/vault_1.15.4_linux_amd64.zip
  unzip -q vault_1.15.4_linux_amd64.zip
  sudo mv vault /usr/local/bin/
  vault version
  echo "✅ Vault CLI installed"
else
  echo "✅ Vault CLI already available"
fi

# Test Vault connectivity
echo
echo "🔍 Testing Vault connectivity..."
if vault status >/dev/null 2>&1; then
  echo "✅ Vault is accessible from TFE instance"
else
  echo "❌ Cannot connect to Vault. Check connectivity and Vault status."
  echo "   Run: ./test-vault-connectivity.sh"
  exit 1
fi

# Create TFE Vault policy template
cat <<POLICY > /tmp/tfe-vault-policy.hcl
# TFE Vault Policy - allows TFE to read secrets and generate dynamic credentials

# Allow reading from KV secrets engine
path "secret/data/tfe/*" {
  capabilities = ["read"]
}

# Allow access to AWS secrets engine
path "aws/creds/*" {
  capabilities = ["read"]
}

# Allow access to Azure secrets engine  
path "azure/creds/*" {
  capabilities = ["read"]
}

# Allow access to GCP secrets engine
path "gcp/key/*" {
  capabilities = ["read"]
}

# Allow listing secret engines
path "sys/mounts" {
  capabilities = ["read"]
}
POLICY

echo "📝 TFE Vault policy template created at /tmp/tfe-vault-policy.hcl"
echo
echo "🚀 Next steps for TFE-Vault integration:"
echo "1. Authenticate to Vault with admin token:"
echo "   vault login <root-token>"
echo
echo "2. Create TFE policy in Vault:"
echo "   vault policy write tfe-policy /tmp/tfe-vault-policy.hcl"
echo
echo "3. Create a token for TFE:"
echo "   vault token create -policy=tfe-policy -ttl=720h"
echo
echo "4. Configure TFE to use the token in workspace variables:"
echo "   VAULT_ADDR = \$VAULT_ADDR"
echo "   VAULT_TOKEN = <token-from-step-3>"
echo
echo "5. Test dynamic credentials in Terraform code:"
echo "   data \"vault_aws_access_credentials\" \"creds\" {"
echo "     backend = \"aws\""
echo "     role    = \"ec2-role\""
echo "   }"
EOT

chmod +x /home/ec2-user/setup-tfe-vault-integration.sh
chown ec2-user:ec2-user /home/ec2-user/setup-tfe-vault-integration.sh

# Create comprehensive test script
cat <<'EOT' > /home/ec2-user/tfe-vault-test.sh
#!/bin/bash

echo "TFE-Vault Integration Test"
echo "========================="

# Run connectivity test
./test-vault-connectivity.sh

echo
echo "🧪 Testing Vault integration..."

# Source Vault environment
source /home/ec2-user/.vault_env 2>/dev/null || true

if command -v vault &> /dev/null && [ -n "$VAULT_ADDR" ]; then
  echo "✅ Vault CLI and environment configured"
  
  # Test if we can reach Vault API
  if vault status >/dev/null 2>&1; then
    echo "✅ Vault API accessible"
    vault status
  else
    echo "❌ Vault API not accessible"
  fi
else
  echo "❌ Vault CLI or environment not properly configured"
fi

echo
echo "🔧 Integration scripts available:"
echo "  ./test-vault-connectivity.sh      - Test network connectivity"
echo "  ./setup-tfe-vault-integration.sh  - Setup integration"
echo "  ./tfe-vault-test.sh               - This test script"
EOT

chmod +x /home/ec2-user/tfe-vault-test.sh
chown ec2-user:ec2-user /home/ec2-user/tfe-vault-test.sh

# Create setup instructions
cat <<EOT > /home/ec2-user/tfe-setup-instructions.txt
Terraform Enterprise Setup Instructions
======================================

Prerequisites:
1. Obtain a TFE license file from HashiCorp
2. Upload the license file to /tmp/license.rli

Installation:
1. Upload your TFE license file:
   scp license.rli ec2-user@<ip>:/tmp/license.rli

2. Run the installation:
   sudo ./install-tfe.sh

3. Monitor installation progress:
   ./tfe-manager.sh status
   ./tfe-manager.sh logs

4. Access TFE via SSH tunnel:
   ssh -L 8800:localhost:8800 ec2-user@<bastion-ip>
   
5. Open browser to: https://localhost:8800

Vault Integration:
1. Test connectivity: ./test-vault-connectivity.sh
2. Setup integration: ./setup-tfe-vault-integration.sh
3. Run tests: ./tfe-vault-test.sh

Management Commands:
- ./tfe-manager.sh status     # Check status
- ./tfe-manager.sh logs       # View logs  
- ./tfe-manager.sh restart    # Restart services
- ./tfe-manager.sh backup     # Create backup

Notes:
- PostgreSQL database: tfe
- Redis cache: localhost:6379
- TFE data: /opt/tfe
- Certificates: /etc/tfe/*.pem (self-signed for development)
- Vault IP: ${vault_ip}
EOT

chown ec2-user:ec2-user /home/ec2-user/tfe-setup-instructions.txt

# Create secondary user if enabled
if [ "${create_secondary_user}" = "true" ]; then
  echo "Creating secondary user: ${secondary_user_name}"
  
  # Create user with home directory
  useradd -m -s /bin/bash ${secondary_user_name}
  
  # Create .ssh directory
  mkdir -p /home/${secondary_user_name}/.ssh
  chmod 700 /home/${secondary_user_name}/.ssh
  
  # Add public key to authorized_keys
  cat <<SECONDARY_KEY > /home/${secondary_user_name}/.ssh/authorized_keys
${secondary_user_public_key}
SECONDARY_KEY
  
  # Set proper permissions
  chmod 600 /home/${secondary_user_name}/.ssh/authorized_keys
  chown -R ${secondary_user_name}:${secondary_user_name} /home/${secondary_user_name}/.ssh
  
  # Add user to sudo group for TFE management
  usermod -aG wheel ${secondary_user_name}
  
  # Configure passwordless sudo for TFE management
  echo "${secondary_user_name} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${secondary_user_name}
  chmod 440 /etc/sudoers.d/${secondary_user_name}
  
  # Verify sudo configuration
  echo "✅ Sudo privileges configured for ${secondary_user_name}"
  
  # Copy TFE management scripts to secondary user
  cp /home/ec2-user/install-tfe.sh /home/${secondary_user_name}/
  cp /home/ec2-user/tfe-manager.sh /home/${secondary_user_name}/
  cp /home/ec2-user/test-vault-connectivity.sh /home/${secondary_user_name}/
  cp /home/ec2-user/setup-tfe-vault-integration.sh /home/${secondary_user_name}/
  cp /home/ec2-user/tfe-vault-test.sh /home/${secondary_user_name}/
  cp /home/ec2-user/tfe-setup-instructions.txt /home/${secondary_user_name}/
  chown ${secondary_user_name}:${secondary_user_name} /home/${secondary_user_name}/*.sh
  chown ${secondary_user_name}:${secondary_user_name} /home/${secondary_user_name}/*.txt
  
  echo "✅ Secondary user '${secondary_user_name}' created successfully"
fi

echo "Terraform Enterprise base setup completed!"
echo "TFE-Vault connectivity scripts installed!"
echo "See /home/ec2-user/tfe-setup-instructions.txt for next steps"
