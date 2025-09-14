#!/bin/bash
#
# Ansible Vault Password Script
# Retrieves vault password from 1Password using CLI
#
# Prerequisites:
# - 1Password CLI (op) must be installed
# - Must be authenticated: op signin
# - Password must exist at: op://Development/Ansible Vault/password

set -euo pipefail

# Styled output functions using gum
print_info() { gum style --foreground="#89b4fa" "🔑 $1"; }
print_error() { gum style --foreground="#f38ba8" "❌ $1"; }
print_success() { gum style --foreground="#a6e3a1" "✅ $1"; }

# Show what we're doing
if [[ "${ANSIBLE_VAULT_PASSWORD_FILE:-}" == *"get-vault-password.sh"* ]]; then
    # Running as vault password script, be quiet
    :
else
    print_info "Retrieving vault password from 1Password..."
fi

# Check prerequisites
if ! command -v op &> /dev/null; then
    print_error "1Password CLI (op) is not installed or not in PATH"
    exit 1
fi

# Check authentication
if ! op account list &> /dev/null; then
    print_error "Not signed in to 1Password. Please run 'op signin' first"
    exit 1
fi

# Retrieve the password
if password=$(op read "op://Development/Ansible Vault/password" 2>/dev/null); then
    echo "$password"
    if [[ "${ANSIBLE_VAULT_PASSWORD_FILE:-}" != *"get-vault-password.sh"* ]]; then
        print_success "Vault password retrieved successfully"
    fi
else
    print_error "Failed to retrieve vault password from 1Password"
    print_error "Make sure the item exists at: op://Development/Ansible Vault/password"
    exit 1
fi