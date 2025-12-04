#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; ((ERRORS++)) || true; }
log_warning() { echo -e "${YELLOW}!${NC} $1"; ((WARNINGS++)) || true; }
log_info() { echo -e "  $1"; }

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Load valid categories
load_categories() {
    if [[ -f "$REPO_ROOT/categories.yml" ]]; then
        yq '.categories[].id' "$REPO_ROOT/categories.yml" 2>/dev/null | tr -d '"' || echo ""
    fi
}

VALID_CATEGORIES=$(load_categories)

# Get YAML value, return empty string if null or missing
get_yaml() {
    local file="$1"
    local path="$2"
    local value
    value=$(yq "$path" "$file" 2>/dev/null || echo "null")
    if [[ "$value" == "null" || "$value" == "~" ]]; then
        echo ""
    else
        echo "$value" | tr -d '"'
    fi
}

# Get YAML array values
get_yaml_array() {
    local file="$1"
    local path="$2"
    yq "$path" "$file" 2>/dev/null | grep -v "^null$" | tr -d '"' || true
}

# Validate checksum format (sha256:64hexchars)
validate_checksum() {
    local checksum="$1"
    if [[ "$checksum" =~ ^sha256:[a-f0-9]{64}$ ]]; then
        return 0
    fi
    return 1
}

# Validate URL is accessible
validate_url() {
    local url="$1"
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" -L --max-time 10 "$url" 2>/dev/null || echo "000")
    if [[ "$response" =~ ^(200|301|302)$ ]]; then
        return 0
    fi
    return 1
}

# Validate plugin.yml
validate_plugin_yml() {
    local file="$1"
    local plugin_name
    plugin_name=$(basename "$(dirname "$file")")

    echo ""
    echo "Validating $file"

    # Check file exists and is valid YAML
    if ! yq '.' "$file" > /dev/null 2>&1; then
        log_error "Invalid YAML syntax"
        return
    fi

    # Required fields
    local required_fields=("name" "description" "author" "repository" "license" "latest" "stable")
    for field in "${required_fields[@]}"; do
        local value
        value=$(get_yaml "$file" ".$field")
        if [[ -z "$value" ]]; then
            log_error "Missing required field: $field"
        else
            log_success "Field '$field' present"
        fi
    done

    # Validate name matches directory
    local name
    name=$(get_yaml "$file" ".name")
    if [[ "$name" != "$plugin_name" ]]; then
        log_error "Plugin name '$name' doesn't match directory '$plugin_name'"
    else
        log_success "Plugin name matches directory"
    fi

    # Validate categories exist
    local categories
    categories=$(get_yaml_array "$file" ".categories[]")
    if [[ -n "$categories" ]]; then
        while IFS= read -r category; do
            [[ -z "$category" ]] && continue
            if echo "$VALID_CATEGORIES" | grep -q "^${category}$"; then
                log_success "Category '$category' is valid"
            else
                log_error "Category '$category' not found in categories.yml"
            fi
        done <<< "$categories"
    else
        log_warning "No categories defined"
    fi

    # Validate repository URL format
    local repo_url
    repo_url=$(get_yaml "$file" ".repository")
    if [[ -n "$repo_url" && "$repo_url" =~ ^https://github.com/ ]]; then
        log_success "Repository URL format valid"
    elif [[ -n "$repo_url" ]]; then
        log_warning "Repository URL is not a GitHub URL"
    fi

    # Check version files exist for latest/stable
    local latest stable
    latest=$(get_yaml "$file" ".latest")
    stable=$(get_yaml "$file" ".stable")

    local versions_dir
    versions_dir="$(dirname "$file")/versions"

    if [[ -n "$latest" ]]; then
        if [[ -f "$versions_dir/$latest.yml" ]]; then
            log_success "Version file exists for latest ($latest)"
        else
            log_error "Version file missing for latest: $versions_dir/$latest.yml"
        fi
    fi

    if [[ -n "$stable" && "$stable" != "$latest" ]]; then
        if [[ -f "$versions_dir/$stable.yml" ]]; then
            log_success "Version file exists for stable ($stable)"
        else
            log_error "Version file missing for stable: $versions_dir/$stable.yml"
        fi
    fi
}

# Validate version file
validate_version_yml() {
    local file="$1"
    local filename
    filename=$(basename "$file" .yml)

    echo ""
    echo "Validating $file"

    # Check file exists and is valid YAML
    if ! yq '.' "$file" > /dev/null 2>&1; then
        log_error "Invalid YAML syntax"
        return
    fi

    # Required fields
    local required_fields=("version" "releaseDate" "minGlideVersion")
    for field in "${required_fields[@]}"; do
        local value
        value=$(get_yaml "$file" ".$field")
        if [[ -z "$value" ]]; then
            log_error "Missing required field: $field"
        else
            log_success "Field '$field' present"
        fi
    done

    # Validate version matches filename
    local version
    version=$(get_yaml "$file" ".version")
    if [[ "$version" != "$filename" ]]; then
        log_error "Version '$version' doesn't match filename '$filename'"
    else
        log_success "Version matches filename"
    fi

    # Check if this is a builtin plugin (no checksums needed)
    local type
    type=$(get_yaml "$file" ".type")
    if [[ "$type" == "builtin" ]]; then
        log_info "Built-in plugin - skipping checksum and URL validation"
        return
    fi

    # Validate releaseURL
    local release_url
    release_url=$(get_yaml "$file" ".releaseURL")
    if [[ -z "$release_url" ]]; then
        log_error "Missing releaseURL"
    else
        log_success "releaseURL present"
        if [[ "${VALIDATE_URLS:-false}" == "true" ]]; then
            if validate_url "$release_url"; then
                log_success "releaseURL is accessible"
            else
                log_error "releaseURL is not accessible: $release_url"
            fi
        fi
    fi

    # Validate checksums
    local platforms=("darwin-amd64" "darwin-arm64" "linux-amd64" "linux-arm64" "windows-amd64")
    local has_checksums=false

    for platform in "${platforms[@]}"; do
        local checksum
        checksum=$(get_yaml "$file" ".checksums.\"$platform\"")
        if [[ -n "$checksum" ]]; then
            has_checksums=true
            if validate_checksum "$checksum"; then
                log_success "Checksum for $platform is valid format"
            else
                log_error "Invalid checksum format for $platform: $checksum"
            fi
        fi
    done

    if [[ "$has_checksums" == "false" ]]; then
        log_error "No checksums defined"
    fi

    # Check minimum platforms (darwin-arm64 and linux-amd64)
    local darwin_arm64 linux_amd64
    darwin_arm64=$(get_yaml "$file" ".checksums.\"darwin-arm64\"")
    linux_amd64=$(get_yaml "$file" ".checksums.\"linux-amd64\"")

    if [[ -z "$darwin_arm64" ]]; then
        log_warning "Missing recommended platform: darwin-arm64"
    fi
    if [[ -z "$linux_amd64" ]]; then
        log_warning "Missing recommended platform: linux-amd64"
    fi
}

# Main validation
main() {
    echo "========================================"
    echo "Glide Plugin Registry Validator"
    echo "========================================"

    # Check for yq
    if ! command -v yq &> /dev/null; then
        echo -e "${RED}Error: yq is required but not installed${NC}"
        echo "Install with: brew install yq"
        exit 1
    fi

    # Validate categories.yml exists
    if [[ ! -f "$REPO_ROOT/categories.yml" ]]; then
        log_error "categories.yml not found"
    else
        log_success "categories.yml exists"
    fi

    # Find and validate all plugin.yml files
    local plugin_files
    plugin_files=$(find "$REPO_ROOT/plugins" -name "plugin.yml" 2>/dev/null || true)

    if [[ -z "$plugin_files" ]]; then
        echo ""
        log_warning "No plugin.yml files found"
    else
        while IFS= read -r file; do
            validate_plugin_yml "$file"
        done <<< "$plugin_files"
    fi

    # Find and validate all version files
    local version_files
    version_files=$(find "$REPO_ROOT/plugins" -path "*/versions/*.yml" 2>/dev/null || true)

    if [[ -z "$version_files" ]]; then
        echo ""
        log_warning "No version files found"
    else
        while IFS= read -r file; do
            validate_version_yml "$file"
        done <<< "$version_files"
    fi

    # Summary
    echo ""
    echo "========================================"
    echo "Validation Summary"
    echo "========================================"
    echo -e "Errors:   ${RED}$ERRORS${NC}"
    echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"

    if [[ $ERRORS -gt 0 ]]; then
        echo ""
        echo -e "${RED}Validation failed with $ERRORS error(s)${NC}"
        exit 1
    else
        echo ""
        echo -e "${GREEN}Validation passed${NC}"
        exit 0
    fi
}

main "$@"
