#!/bin/bash

# Update SSH key in vault from 1Password
# This script reads the "1P SSH key" from 1Password and updates the vault file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_FILE="$SCRIPT_DIR/../inventory/group_vars/all/vault.yml"
SSH_KEY_ITEM="1P SSH key"

# Styled output functions using gum
print_status() { gum style --foreground="#89b4fa" "ℹ️  $1"; }
print_warning() { gum style --foreground="#f9e2af" "⚠️  $1"; }
print_error() { gum style --foreground="#f38ba8" "❌ $1"; }
print_success() { gum style --foreground="#a6e3a1" "✅ $1"; }
print_header() { gum style --border="rounded" --padding="1 2" --margin="1 0" --foreground="#cba6f7" "$1"; }

# Check if 1Password CLI is available and authenticated
if ! command -v op &> /dev/null; then
    print_error "1Password CLI (op) is not installed or not in PATH"
    exit 1
fi

# Check if user is signed in to 1Password
if ! op account list &> /dev/null; then
    print_error "Not signed in to 1Password. Please run 'op signin' first"
    exit 1
fi

# Check if vault file exists
if [[ ! -f "$VAULT_FILE" ]]; then
    print_error "Vault file not found: $VAULT_FILE"
    exit 1
fi

print_header "🔑 SSH Key Update Process"

print_status "Retrieving SSH public key from 1Password..."

# Get the SSH public key from 1Password
if SSH_PUBLIC_KEY=$(op item get "$SSH_KEY_ITEM" --fields "public key" 2>/dev/null) && [[ -n "$SSH_PUBLIC_KEY" ]]; then
    gum style --foreground="#a6e3a1" "✅ Retrieved SSH key: $(echo "$SSH_PUBLIC_KEY" | cut -c1-50)..."
else
    print_error "Could not retrieve SSH public key from 1Password item '$SSH_KEY_ITEM'"
    print_error "Make sure the item exists and has a 'public key' field"
    exit 1
fi

# Create a temporary file for the decrypted vault
TEMP_VAULT=$(mktemp)
trap "rm -f $TEMP_VAULT" EXIT

print_status "Decrypting vault file..."

# Decrypt the vault file
if ! ansible-vault decrypt "$VAULT_FILE" --output="$TEMP_VAULT" 2>/dev/null; then
    print_error "Failed to decrypt vault file"
    exit 1
fi

print_status "Updating SSH key in vault..."

# Update the SSH key in the temporary file
# Use sed to replace the vault_user_ssh_key line
if grep -q "^vault_user_ssh_key:" "$TEMP_VAULT"; then
    # Key exists, replace it
    sed -i.bak "s|^vault_user_ssh_key:.*|vault_user_ssh_key: $SSH_PUBLIC_KEY|" "$TEMP_VAULT"
    rm -f "${TEMP_VAULT}.bak"
else
    # Key doesn't exist, add it after vault_deploy_user
    if grep -q "^vault_deploy_user:" "$TEMP_VAULT"; then
        sed -i.bak "/^vault_deploy_user:/a\\
vault_user_ssh_key: $SSH_PUBLIC_KEY" "$TEMP_VAULT"
        rm -f "${TEMP_VAULT}.bak"
    else
        print_error "Could not find vault_deploy_user line to insert SSH key after"
        exit 1
    fi
fi

print_status "Re-encrypting vault file..."

# Encrypt the vault file back
if ! ansible-vault encrypt "$TEMP_VAULT" --output="$VAULT_FILE" 2>/dev/null; then
    print_error "Failed to encrypt vault file"
    exit 1
fi

print_success "SSH key successfully updated in vault file!"
echo
print_header "📝 Next Steps"
gum style --margin="0 2" "• Review the changes: git diff $VAULT_FILE"
gum style --margin="0 2" "• Commit the changes: git add $VAULT_FILE && git commit -m 'chore: update SSH key from 1Password'"
echo
if gum confirm "Would you like to view the diff now?"; then
    git diff "$VAULT_FILE" || true
fi