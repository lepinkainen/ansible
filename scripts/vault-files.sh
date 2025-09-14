#!/bin/bash

# Ansible Vault Files Manager
# Encrypt or decrypt all sensitive Ansible files using ansible.cfg configuration

set -euo pipefail

# Styled output functions using gum
print_info() { gum style --foreground="#89b4fa" "ℹ️  $1"; }
print_success() { gum style --foreground="#a6e3a1" "✅ $1"; }
print_warning() { gum style --foreground="#f9e2af" "⚠️  $1"; }
print_error() { gum style --foreground="#f38ba8" "❌ $1"; }
print_header() { gum style --border="rounded" --padding="1 2" --margin="1 0" --foreground="#cba6f7" "$1"; }

# Configuration
DRY_RUN=false
VERBOSE=false
MODE=""

# Function to show usage
show_usage() {
    print_header "🔐 Ansible Vault Files Manager"
    
    echo
    gum style --foreground="#fab387" "Usage: $0 <encrypt|decrypt> [OPTIONS]"
    echo
    
    gum style --bold "Encrypt or decrypt all sensitive Ansible files using ansible.cfg configuration."
    echo
    
    gum style --foreground="#94e2d5" --bold "COMMANDS:"
    gum style --margin="0 2" "• encrypt     Encrypt all vault files"
    gum style --margin="0 2" "• decrypt     Decrypt all vault files"
    echo
    
    gum style --foreground="#94e2d5" --bold "OPTIONS:"
    gum style --margin="0 2" "• -n, --dry-run    Show what would be processed without making changes"
    gum style --margin="0 2" "• -v, --verbose    Enable verbose output"
    gum style --margin="0 2" "• -h, --help       Show this help message"
    echo
    
    gum style --foreground="#94e2d5" --bold "FILES PROCESSED:"
    gum style --margin="0 2" "• inventory/production.yml"
    gum style --margin="0 2" "• inventory/**/vault.yml"
    echo
    
    gum style --foreground="#94e2d5" --bold "EXAMPLES:"
    gum style --margin="0 2" "• $0 encrypt                    # Encrypt all vault files"
    gum style --margin="0 2" "• $0 decrypt --dry-run          # Show what would be decrypted"
    gum style --margin="0 2" "• $0 encrypt --verbose          # Encrypt with detailed output"
    echo
    
    gum style --foreground="#94e2d5" --bold "REQUIREMENTS:"
    gum style --margin="0 2" "• ansible-vault command must be available"
    gum style --margin="0 2" "• ansible.cfg must be configured with vault_password_file"
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
fi

# First argument must be the mode
case "$1" in
    encrypt|decrypt)
        MODE="$1"
        shift
        ;;
    -h|--help)
        show_usage
        exit 0
        ;;
    *)
        print_error "Invalid command: $1"
        echo
        show_usage
        exit 1
        ;;
esac

# Parse remaining options
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

# Function to check if file is encrypted
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
    
    if ansible-vault encrypt "$file" &>/dev/null; then
        print_success "Encrypted: $file"
    else
        print_error "Failed to encrypt: $file"
        return 1
    fi
}

# Function to decrypt a file
decrypt_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        [[ "$VERBOSE" == true ]] && print_warning "File does not exist: $file"
        return 0
    fi
    
    if ! is_encrypted "$file"; then
        [[ "$VERBOSE" == true ]] && print_info "Already decrypted: $file"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would decrypt: $file"
        return 0
    fi
    
    print_info "Decrypting: $file"
    
    if ansible-vault decrypt "$file" &>/dev/null; then
        print_success "Decrypted: $file"
    else
        print_error "Failed to decrypt: $file"
        return 1
    fi
}

# Main execution
main() {
    if [[ "$MODE" == "encrypt" ]]; then
        print_header "🔐 Vault File Encryption Process"
    else
        print_header "🔓 Vault File Decryption Process"
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No files will be modified"
    fi
    
    local files_processed=0
    local files_changed=0
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
    
    if [[ ${#sensitive_files[@]} -eq 0 ]]; then
        print_warning "No vault files found to process"
        exit 0
    fi
    
    # Process each file
    for file in "${sensitive_files[@]}"; do
        ((files_processed++))
        
        if [[ "$MODE" == "encrypt" ]]; then
            if encrypt_file "$file"; then
                if [[ "$DRY_RUN" == false ]] && is_encrypted "$file"; then
                    ((files_changed++))
                elif [[ "$DRY_RUN" == true ]] && [[ -f "$file" ]] && ! is_encrypted "$file"; then
                    ((files_changed++))
                fi
            else
                ((errors++))
            fi
        else
            if decrypt_file "$file"; then
                if [[ "$DRY_RUN" == false ]] && ! is_encrypted "$file"; then
                    ((files_changed++))
                elif [[ "$DRY_RUN" == true ]] && [[ -f "$file" ]] && is_encrypted "$file"; then
                    ((files_changed++))
                fi
            else
                ((errors++))
            fi
        fi
    done
    
    # Summary
    echo
    print_header "📊 Summary"
    
    gum style --margin="0 2" "Files processed: $files_processed"
    if [[ "$DRY_RUN" == true ]]; then
        gum style --margin="0 2" "Files that would be ${MODE}ed: $files_changed"
    else
        gum style --margin="0 2" "Files ${MODE}ed: $files_changed"
    fi
    
    if [[ $errors -gt 0 ]]; then
        print_error "Errors encountered: $errors"
        exit 1
    else
        if [[ "$DRY_RUN" == true ]]; then
            print_success "Dry run completed successfully"
        else
            print_success "All files ${MODE}ed successfully"
        fi
        
        # Show warning about decrypted files in git
        if [[ "$MODE" == "decrypt" && "$DRY_RUN" == false && $files_changed -gt 0 ]]; then
            echo
            print_warning "Security reminder: Decrypted files contain sensitive data"
            print_warning "Remember to encrypt them again before committing: $0 encrypt"
        fi
    fi
}

# Run main function
main "$@"