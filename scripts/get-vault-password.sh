#!/bin/bash
#
# Ansible Vault Password Script
# Retrieves vault password from 1Password using CLI
#
# Prerequisites:
# - 1Password CLI (op) must be installed
# - Must be authenticated: op signin
# - Password must exist at: op://Development/Ansible Vault/password

op read "op://Development/Ansible Vault/password"