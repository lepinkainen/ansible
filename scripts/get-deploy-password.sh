#!/bin/bash
#
# Ansible Deploy Password Script
# Retrieves deploy user password from 1Password using CLI
#
# Prerequisites:
# - 1Password CLI (op) must be installed
# - Must be authenticated: op signin
# - Password must exist at: op://Development/Ansible Deploy user/password

op read "op://Development/Ansible Deploy user/password"