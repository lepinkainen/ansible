#!/bin/bash

# Update SSH key in vault from 1Password
# This script reads the "1P SSH key" from 1Password and updates the vault file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_FILE="$SCRIPT_DIR/../inventory/group_vars/all/vault.yml"
SSH_KEY_ITEM="1P SSH key"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

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

print_status "Retrieving SSH public key from 1Password..."

# Get the SSH public key from 1Password
SSH_PUBLIC_KEY=$(op item get "$SSH_KEY_ITEM" --fields "public key" 2>/dev/null)

if [[ -z "$SSH_PUBLIC_KEY" ]]; then
    print_error "Could not retrieve SSH public key from 1Password item '$SSH_KEY_ITEM'"
    print_error "Make sure the item exists and has a 'public key' field"
    exit 1
fi

print_status "Retrieved SSH key: ${SSH_PUBLIC_KEY:0:50}..."

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

print_status "SSH key successfully updated in vault file!"
print_warning "Remember to commit your changes: git add $VAULT_FILE && git commit -m 'chore: update SSH key from 1Password'"