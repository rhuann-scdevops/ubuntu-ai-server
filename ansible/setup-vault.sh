#!/bin/bash
# Setup Ansible Vault with server credentials
# This script securely creates the encrypted vault file

set -e

cd "$(dirname "$0")"

VAULT_FILE="group_vars/vault.yml"
VAULT_PASS_FILE="$HOME/.vault_pass"

echo "=== Ansible Vault Setup ==="
echo ""

# Check vault password file exists
if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo "Error: Vault password file not found at $VAULT_PASS_FILE"
    exit 1
fi

# Remove existing vault file if present
[ -f "$VAULT_FILE" ] && rm -f "$VAULT_FILE"

# Prompt for server password (hidden input)
echo -n "Enter the SSH/sudo password for rhuann@192.168.0.101: "
read -s SERVER_PASSWORD
echo ""

# Create the vault content
cat > "$VAULT_FILE" << EOF
---
# Ansible Vault - Encrypted Credentials
vault_ansible_password: "${SERVER_PASSWORD}"
vault_ansible_become_password: "${SERVER_PASSWORD}"
EOF

# Encrypt using password file directly (bypass ansible.cfg)
ANSIBLE_CONFIG=/dev/null ansible-vault encrypt "$VAULT_FILE" --vault-password-file "$VAULT_PASS_FILE"

# Clear password from memory
SERVER_PASSWORD=""

echo ""
echo "Vault created and encrypted successfully!"
echo "File: $VAULT_FILE"
echo ""
echo "To view: ansible-vault view $VAULT_FILE"
echo "To edit: ansible-vault edit $VAULT_FILE"
