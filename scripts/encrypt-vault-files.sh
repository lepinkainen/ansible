#!/bin/bash

# Encrypt Ansible Vault Files
# Simple script to encrypt all sensitive files using ansible.cfg configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
DRY_RUN=false
VERBOSE=false

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Encrypt all sensitive Ansible files using ansible.cfg configuration.

OPTIONS:
    -n, --dry-run    Show what would be encrypted without making changes
    -v, --verbose    Enable verbose output
    -h, --help       Show this help message

FILES PROCESSED:
    - inventory/production.yml
    - inventory/**/vault.yml

REQUIREMENTS:
    - ansible-vault command must be available
    - ansible.cfg must be configured with vault_password_file
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if ansible-vault is available
if ! command -v ansible-vault &> /dev/null; then
    print_error "ansible-vault command not found. Please install Ansible."
    exit 1
fi

# Function to check if file is already encrypted
is_encrypted() {
    local file="$1"
    [[ -f "$file" ]] && head -1 "$file" | grep -q '^\$ANSIBLE_VAULT'
}

# Function to encrypt a file
encrypt_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        [[ "$VERBOSE" == true ]] && print_warning "File does not exist: $file"
        return 0
    fi
    
    if is_encrypted "$file"; then
        [[ "$VERBOSE" == true ]] && print_info "Already encrypted: $file"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would encrypt: $file"
        return 0
    fi
    
    print_info "Encrypting: $file"
    
    # Use ansible-vault without password args - it will use ansible.cfg
    if ansible-vault encrypt "$file"; then
        print_success "Encrypted: $file"
    else
        print_error "Failed to encrypt: $file"
        return 1
    fi
}

# Main execution
main() {
    print_info "Starting vault file encryption process..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No files will be modified"
    fi
    
    local files_processed=0
    local files_encrypted=0
    local errors=0
    
    # Find all sensitive files
    local sensitive_files=()
    
    # Add inventory file
    if [[ -f "inventory/production.yml" ]]; then
        sensitive_files+=("inventory/production.yml")
    fi
    
    # Add all vault.yml files
    while IFS= read -r -d '' file; do
        sensitive_files+=("$file")
    done < <(find inventory -name "vault.yml" -type f -print0 2>/dev/null)
    
    # Process each file
    for file in "${sensitive_files[@]}"; do
        ((files_processed++))
        if encrypt_file "$file"; then
            if [[ "$DRY_RUN" == false ]] && ! is_encrypted "$file"; then
                # File wasn't encrypted (probably didn't exist)
                continue
            elif [[ "$DRY_RUN" == false ]] || ([[ "$DRY_RUN" == true ]] && [[ -f "$file" ]] && ! is_encrypted "$file"); then
                ((files_encrypted++))
            fi
        else
            ((errors++))
        fi
    done
    
    # Summary
    echo
    print_info "=== SUMMARY ==="
    print_info "Files processed: $files_processed"
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Files that would be encrypted: $files_encrypted"
    else
        print_info "Files encrypted: $files_encrypted"
    fi
    
    if [[ $errors -gt 0 ]]; then
        print_error "Errors encountered: $errors"
        exit 1
    else
        if [[ "$DRY_RUN" == true ]]; then
            print_success "Dry run completed successfully"
        else
            print_success "All files encrypted successfully"
        fi
    fi
}

# Run main function
main "$@"