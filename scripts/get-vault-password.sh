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

# Check prerequisites
if ! command -v op &> /dev/null; then
    echo "1Password CLI (op) is not installed or not in PATH" >&2
    exit 1
fi

# Check authentication
if ! op account list &> /dev/null; then
    echo "Not signed in to 1Password. Please run 'op signin' first" >&2
    exit 1
fi

# Retrieve the password
if password=$(op read "op://Development/Ansible Vault/password" 2>/dev/null); then
    echo "$password"
else
    echo "Failed to retrieve vault password from 1Password" >&2
    echo "Make sure the item exists at: op://Development/Ansible Vault/password" >&2
    exit 1
fi