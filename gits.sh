#!/bin/bash

# ANSI color codes
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[38;5;208m'
NC='\033[0m' # No Color

# Token cache helper functions

# Get gits config directory
get_gits_config_dir() {
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/gits"
}

# Save token to cache
save_gitea_token() {
    local server="$1"
    local token="$2"
    local config_dir=$(get_gits_config_dir)
    local tokens_file="$config_dir/tokens.conf"
    
    mkdir -p "$config_dir"
    
    # Remove old token for this server
    if [ -f "$tokens_file" ]; then
        grep -v "^$server=" "$tokens_file" > "$tokens_file.tmp" 2>/dev/null || true
        mv "$tokens_file.tmp" "$tokens_file" 2>/dev/null
    fi
    
    # Add new token
    echo "$server=$token" >> "$tokens_file"
    chmod 600 "$tokens_file"
    echo -e "${GREEN}Token cached in $(get_gits_config_dir)/tokens.conf${NC}"
}

# Get cached token
# Get cached token (unified for all platforms)
get_cached_token() {
    local platform="$1"
    local server="$2"
    local config_dir=$(get_gits_config_dir)
    local tokens_file="$config_dir/tokens.conf"
    
    if [ -f "$tokens_file" ]; then
        case "$platform" in
            "github")
                grep "^github.com=" "$tokens_file" 2>/dev/null | cut -d'=' -f2
                ;;
            "gitea"|"forgejo")
                grep "^$server=" "$tokens_file" 2>/dev/null | cut -d'=' -f2
                ;;
        esac
    fi
}

# Get cached Gitea token (legacy function)
get_cached_gitea_token() {
    get_cached_token "gitea" "$1"
}

# Save token to cache
save_token() {
    local platform="$1"
    local server="$2"
    local token="$3"
    local config_dir=$(get_gits_config_dir)
    local tokens_file="$config_dir/tokens.conf"
    
    # Ensure config directory exists
    mkdir -p "$config_dir"
    
    # Create temp file and process tokens
    if [ -f "$tokens_file" ]; then
        # Remove existing token for this platform/server
        case "$platform" in
            "github")
                grep -v "^github.com=" "$tokens_file" > "$tokens_file.tmp" 2>/dev/null || true
                ;;
            "gitea"|"forgejo")
                grep -v "^$server=" "$tokens_file" > "$tokens_file.tmp" 2>/dev/null || true
                ;;
        esac
        mv "$tokens_file.tmp" "$tokens_file"
    fi
    
    # Add new token
    case "$platform" in
        "github")
            echo "github.com=$token" >> "$tokens_file"
            ;;
        "gitea"|"forgejo")
            echo "$server=$token" >> "$tokens_file"
            ;;
    esac
    
    chmod 600 "$tokens_file" 2>/dev/null
}

# Clear cached token
clear_cached_token() {
    local platform="$1"
    local server="$2"
    local config_dir=$(get_gits_config_dir)
    local tokens_file="$config_dir/tokens.conf"
    
    if [ -f "$tokens_file" ]; then
        case "$platform" in
            "github")
                grep -v "^github.com=" "$tokens_file" > "$tokens_file.tmp" 2>/dev/null || true
                ;;
            "gitea"|"forgejo")
                grep -v "^$server=" "$tokens_file" > "$tokens_file.tmp" 2>/dev/null || true
                ;;
        esac
        mv "$tokens_file.tmp" "$tokens_file"
        echo -e "${GREEN}Cached token for $platform cleared${NC}"
    else
        echo -e "${ORANGE}No cached tokens found${NC}"
    fi
}

# Clear cached token (legacy function)
clear_cached_gitea_token() {
    clear_cached_token "gitea" "$1"
}

# Get GitHub token from gh CLI
get_github_token() {
    local token=""
    
    # Method 1: Try gh auth status and token commands
    token=$(gh auth status --show-token 2>/dev/null | grep -oE 'ghp_[a-zA-Z0-9]{36}' | head -1)
    if [ -n "$token" ]; then
        echo "$token"
        return 0
    fi
    
    # Method 2: Check gh config
    token=$(gh config get -h github.com oauth_token 2>/dev/null)
    if [ -n "$token" ]; then
        echo "$token"
        return 0
    fi
    
    # Method 3: Parse gh configuration files
    local gh_config="$HOME/.config/gh/config.yml"
    if [ -f "$gh_config" ]; then
        token=$(grep -A 1 "github.com" "$gh_config" | grep "oauth_token:" | awk '{print $2}' | head -1)
        if [ -n "$token" ]; then
            echo "$token"
            return 0
        fi
    fi
    
    return 1
}

get_cached_gitea_token() {
    local server="$1"
    local config_dir=$(get_gits_config_dir)
    local tokens_file="$config_dir/tokens.conf"
    
    if [ -f "$tokens_file" ]; then
        grep "^$server=" "$tokens_file" 2>/dev/null | cut -d'=' -f2
    fi
}

# Clear cached token
clear_cached_gitea_token() {
    local server="$1"
    local config_dir=$(get_gits_config_dir)
    local tokens_file="$config_dir/tokens.conf"
    
    if [ -f "$tokens_file" ]; then
        grep -v "^$server=" "$tokens_file" > "$tokens_file.tmp" 2>/dev/null || true
        mv "$tokens_file.tmp" "$tokens_file" 2>/dev/null
        echo -e "${GREEN}Cached token for $server cleared${NC}"
    else
        echo -e "${ORANGE}No cached tokens found${NC}"
    fi
}

# Improved tea token retrieval with multiple fallback methods
get_tea_token() {
    local server="$1"
    local token=""
    
    # Method 1: Try tea config command
    token=$(tea config get "auth.$server.token" 2>/dev/null)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        echo "$token"
        return 0
    fi
    
    # Method 2: Parse tea config YAML file directly
    local tea_config="$HOME/.config/tea/config.yml"
    if [ -f "$tea_config" ]; then
        # Look for the server section and extract token
        token=$(awk "/  $server:/{flag=1; next} /  [a-z]/{flag=0} flag && /token:/{print \$2; exit}" "$tea_config" | tr -d '"')
        if [ -n "$token" ]; then
            echo "$token"
            return 0
        fi
    fi
    
    # Method 3: Try alternative config location
    tea_config="$HOME/.tea/config.yml"
    if [ -f "$tea_config" ]; then
        token=$(awk "/  $server:/{flag=1; next} /  [a-z]/{flag=0} flag && /token:/{print \$2; exit}" "$tea_config" | tr -d '"')
        if [ -n "$token" ]; then
            echo "$token"
            return 0
        fi
    fi
    
    return 1
}

# Token management command
token() {
    local action="$1"
    local server="$2"
    local config_dir=$(get_gits_config_dir)
    local tokens_file="$config_dir/tokens.conf"
    
    case "$action" in
        list)
            echo -e "${GREEN}Cached tokens:${NC}"
            echo -e "${BLUE}Location: $tokens_file${NC}"
            echo -e ""
            
            if [ -f "$tokens_file" ]; then
                while IFS='=' read -r server_name token_value; do
                    if [ -n "$server_name" ] && [ -n "$token_value" ]; then
                        # Mask the token for security
                        local masked_token="${token_value:0:8}...${token_value: -4}"
                        echo -e "  ${PURPLE}$server_name${NC}: $masked_token"
                    fi
                done < "$tokens_file"
            else
                echo -e "${ORANGE}No cached tokens found${NC}"
            fi
            ;;
        show)
            local target_server="${server:-forge.ourworld.tf}"
            echo -e "${GREEN}Token for $target_server:${NC}"
            
            if [ -f "$tokens_file" ]; then
                local token=$(grep "^$target_server=" "$tokens_file" 2>/dev/null | cut -d'=' -f2)
                if [ -n "$token" ]; then
                    local masked_token="${token:0:8}...${token: -4}"
                    echo -e "  ${PURPLE}$masked_token${NC}"
                else
                    echo -e "${ORANGE}No token found for $target_server${NC}"
                fi
            else
                echo -e "${ORANGE}No cached tokens found${NC}"
            fi
            ;;
        clear)
            local target_server="${server:-forge.ourworld.tf}"
            echo -e "${GREEN}Clearing token for $target_server...${NC}"
            
            if [ -f "$tokens_file" ]; then
                grep -v "^$target_server=" "$tokens_file" > "$tokens_file.tmp" 2>/dev/null || true
                mv "$tokens_file.tmp" "$tokens_file"
                echo -e "${GREEN}Token cleared for $target_server${NC}"
            else
                echo -e "${ORANGE}No cached tokens found${NC}"
            fi
            ;;
        *)
            echo -e "${GREEN}Usage: gits token <command> [server]${NC}"
            echo -e ""
            echo -e "${PURPLE}Commands:${NC}"
            echo -e "  list              List all cached tokens"
            echo -e "  show [server]     Show token for server (default: forge.ourworld.tf)"
            echo -e "  clear [server]    Clear token for server (default: forge.ourworld.tf)"
            echo -e ""
            echo -e "${BLUE}Examples:${NC}"
            echo -e "  gits token list"
            echo -e "  gits token show forge.ourworld.tf"
            echo -e "  gits token show git.ourworld.tf"
            echo -e "  gits token clear forge.ourworld.tf"
            ;;
    esac
}

# Function to detect platform from git remote
detect_platform() {
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -z "$remote_url" ]]; then
        echo -e "${RED}Error: No git remote found${NC}"
        return 1
    fi
    
    if [[ "$remote_url" == *"forge.ourworld.tf"* ]] || [[ "$remote_url" == *"forgejo"* ]]; then
        echo "forgejo"
        return 0
    elif [[ "$remote_url" == *"github.com"* ]]; then
        echo "github"
        return 0
    elif [[ "$remote_url" == *"git.ourworld.tf"* ]] || [[ "$remote_url" == *"gitea"* ]]; then
        echo "gitea"
        return 0
    else
        echo -e "${RED}Error: Unsupported platform from remote: $remote_url${NC}"
        return 1
    fi
}

# Function to extract repo info from git remote
get_repo_info() {
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -z "$remote_url" ]]; then
        echo -e "${RED}Error: No git remote found${NC}"
        return 1
    fi
    
    local repo_path=""
    if [[ "$remote_url" == *"forge.ourworld.tf"* ]]; then
        repo_path=$(echo "$remote_url" | sed -E 's|.*forge\.ourworld\.tf[:/](.*)(\.git)?|\1|')
    elif [[ "$remote_url" == *"github.com"* ]]; then
        repo_path=$(echo "$remote_url" | sed -E 's|.*github\.com[:/](.*)(\.git)?|\1|')
    elif [[ "$remote_url" == *"git.ourworld.tf"* ]]; then
        repo_path=$(echo "$remote_url" | sed -E 's|.*git\.ourworld\.tf[:/](.*)(\.git)?|\1|')
    fi
    
    local owner=$(echo "$repo_path" | cut -d'/' -f1)
    local repo=$(echo "$repo_path" | cut -d'/' -f2)
    
    echo "$owner/$repo"
    return 0
}

# Function to clone a GitHub repository
clone() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Please provide a Git repository URL or just the org/repo if it's on GitHub. ${NC}"
        echo -e "Usage: gits clone <https://github.com/org/repo> or <org/repo>"
        return 1
    fi

    local repo="$1"
    if [[ $repo != http* ]]; then
        repo="https://github.com/$repo"
    fi

    echo -e "${GREEN}Cloning repository: $repo${NC}"
    if git clone "$repo"; then
        local repo_name=$(basename "$repo" .git)
        cd "$repo_name" || return 1  # Exit if directory not found

        # Determine the SSH remote URL
        original_repo_url="$repo"

        # Extract host and path from the original URL
        if [[ $original_repo_url == http* ]]; then
            host_part=$(echo "$original_repo_url" | sed -E 's|^https?://([^/]+)/.*|\1|')
            path_part=$(echo "$original_repo_url" | sed -E 's|^https?://[^/]+/(.*)|\1|')
        else
            host_part="github.com"
            path_part="$original_repo_url"
        fi

        # Remove .git suffix from path_part if present
        path_part="${path_part%.git}"

        # Construct SSH URL based on the host
        if [[ "$host_part" == *"forge.ourworld.tf"* ]]; then
            ssh_url="git@forge.ourworld.tf:$path_part.git"
        elif [[ "$host_part" == *"github.com"* ]]; then
            ssh_url="git@github.com:$path_part.git"
        elif [[ "$host_part" == *"git.ourworld.tf"* ]]; then
            ssh_url="git@git.ourworld.tf:$path_part.git"
        else
            echo -e "${ORANGE}Warning: Unsupported host '$host_part'. Remote URL not updated.${NC}"
            ssh_url=""
        fi

        if [ -n "$ssh_url" ]; then
            echo -e "${GREEN}Updating remote origin to SSH URL: $ssh_url${NC}"
            git remote set-url origin "$ssh_url"
        fi

        echo -e "${PURPLE}Repository cloned successfully. Switched to directory: $(pwd)${NC}"
        echo -e '\nHit [Ctrl]+[D] to exit this child shell.'
        exec bash
    else
        echo -e "${RED}Error: Failed to clone the repository.${NC}"
    fi
}

# Function to push changes to all repositories with uncommitted changes
push-all() {
    local dry_run=false
    local batch_mode=false
    local default_message=""
    local skip_confirmation=false
    local use_pal=false
    local use_pal_yolo=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run|-n)
                dry_run=true
                shift
                ;;
            --batch|-b)
                batch_mode=true
                shift
                ;;
            --message|-m)
                default_message="$2"
                shift 2
                ;;
            --yes|-y)
                skip_confirmation=true
                shift
                ;;
            -p)
                use_pal=true
                shift
                ;;
            -py)
                use_pal_yolo=true
                shift
                ;;
            --help|-h)
                echo -e "${GREEN}Usage: gits push-all [OPTIONS]${NC}"
                echo -e "${BLUE}Interactively add, commit, and push changes across all dirty repositories${NC}"
                echo -e ""
                echo -e "${PURPLE}Options:${NC}"
                echo -e "  -n, --dry-run     Show what would be done without executing"
                echo -e "  -b, --batch       Use same commit message for all repos"
                echo -e "  -m, --message     Default commit message (use with --batch)"
                echo -e "  -y, --yes         Skip confirmation prompts"
                echo -e "  -p                Use pal /commit for AI-generated commit messages (interactive)"
                echo -e "  -py               Use pal /commit -y for AI-generated commit messages (auto-commit)"
                echo -e "  -h, --help        Show this help message"
                echo -e ""
                echo -e "${BLUE}Examples:${NC}"
                echo -e "  gits push-all                           # Interactive mode"
                echo -e "  gits push-all --batch -m \"Update docs\" # Batch with message"
                echo -e "  gits push-all --dry-run                 # Preview actions"
                echo -e "  gits push-all -py                       # Use AI-generated messages (auto)"
                echo -e "  gits push-all -p                        # Use AI-generated messages (interactive)"
                return 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}"
                echo -e "Use 'gits push-all --help' for usage information."
                return 1
                ;;
        esac
    done
    
    # Auto-enable skip_confirmation when using -py (yolo mode)
    if [[ "$use_pal_yolo" == true ]]; then
        skip_confirmation=true
    fi
    
    echo -e "${GREEN}Finding repositories with changes...${NC}"
    echo -e ""
    
    local dirty_repos=()
    local repo_info=()
    
    # Find all dirty repositories
    while IFS= read -r -d '' gitdir; do
        local repodir=$(dirname "$gitdir")
        cd "$repodir" || continue
        
        local status_output=$(git status --porcelain 2>/dev/null)
        local unpushed=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        
        if [[ -n "$status_output" ]] || [[ "$unpushed" -gt 0 ]]; then
            dirty_repos+=("$repodir")
            repo_info+=("$status_output|$unpushed")
        fi
        
        cd - >/dev/null 2>&1
    done < <(find . -name .git -type d -print0)
    
    if [[ ${#dirty_repos[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ All repositories are clean! Nothing to push.${NC}"
        return 0
    fi
    
    echo -e "${ORANGE}Found ${#dirty_repos[@]} repositories with changes:${NC}"
    for i in "${!dirty_repos[@]}"; do
        echo -e "  ${BLUE}$((i+1)). ${dirty_repos[i]}${NC}"
    done
    echo -e ""
    
    if [[ "$dry_run" == true ]]; then
        echo -e "${ORANGE}DRY RUN MODE - No changes will be made${NC}"
        echo -e ""
    fi
    
    # Get batch commit message if in batch mode
    if [[ "$batch_mode" == true ]] && [[ -z "$default_message" ]]; then
        echo -e "${GREEN}Enter commit message for all repositories:${NC}"
        read -r default_message
        if [[ -z "$default_message" ]]; then
            echo -e "${RED}Error: Commit message cannot be empty in batch mode${NC}"
            return 1
        fi
    fi
    
    # Process each repository
    local processed=0
    local skipped=0
    local failed=0
    
    for i in "${!dirty_repos[@]}"; do
        local repodir="${dirty_repos[i]}"
        local info="${repo_info[i]}"
        local status_output=$(echo "$info" | cut -d'|' -f1)
        local unpushed=$(echo "$info" | cut -d'|' -f2)
        
        echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
        echo -e "${BLUE}📁 Repository: $repodir${NC} ($((i+1))/${#dirty_repos[@]})"
        echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
        
        cd "$repodir" || continue
        
        # Show current status
        if [[ -n "$status_output" ]]; then
            echo -e "${ORANGE}Uncommitted changes:${NC}"
            git status --short
        fi
        
        if [[ "$unpushed" -gt 0 ]]; then
            echo -e "${ORANGE}Unpushed commits: $unpushed${NC}"
        fi
        
        echo -e ""
        
        # Skip confirmation in batch mode with --yes or when using -py
        if [[ "$skip_confirmation" == true ]]; then
            action="y"
        elif [[ "$batch_mode" == true ]]; then
            echo -e "${GREEN}Process this repository with message: \"$default_message\"? (y/n/s/q):${NC}"
            read -r action
        else
            echo -e "${GREEN}Actions: (y)es, (n)o, (s)kip, (q)uit${NC}"
            read -r action
        fi
        
        case "$action" in
            y|Y|yes|Yes)
                if [[ "$dry_run" == true ]]; then
                    echo -e "${ORANGE}[DRY RUN] Would add, commit, and push changes${NC}"
                    processed=$((processed + 1))
                else
                    # Get commit message
                    local commit_msg="$default_message"
                    local commit_success=false
                    
                    # Handle commit based on pal flags
                    if [[ "$use_pal_yolo" == true ]]; then
                        echo -e "${BLUE}Using pal /commit -y for AI-generated commit message (auto-commit)${NC}"
                        if ! command -v pal &> /dev/null; then
                            echo -e "${RED}Error: pal command not found. Please install pal to use -py flag.${NC}"
                            failed=$((failed + 1))
                            cd - >/dev/null 2>&1
                            continue
                        fi
                        echo -e "${BLUE}Adding changes...${NC}"
                        if git add -A; then
                            if pal /commit -y; then
                                commit_success=true
                            else
                                echo -e "${RED}❌ Failed to commit using pal /commit -y${NC}"
                                failed=$((failed + 1))
                                cd - >/dev/null 2>&1
                                continue
                            fi
                        else
                            echo -e "${RED}❌ Failed to add changes in $repodir${NC}"
                            failed=$((failed + 1))
                            cd - >/dev/null 2>&1
                            continue
                        fi
                    elif [[ "$use_pal" == true ]]; then
                        echo -e "${BLUE}Using pal /commit for AI-generated commit message${NC}"
                        if ! command -v pal &> /dev/null; then
                            echo -e "${RED}Error: pal command not found. Please install pal to use -p flag.${NC}"
                            failed=$((failed + 1))
                            cd - >/dev/null 2>&1
                            continue
                        fi
                        echo -e "${BLUE}Adding changes...${NC}"
                        if git add -A; then
                            if pal /commit; then
                                commit_success=true
                            else
                                echo -e "${RED}❌ Failed to commit using pal /commit${NC}"
                                failed=$((failed + 1))
                                cd - >/dev/null 2>&1
                                continue
                            fi
                        else
                            echo -e "${RED}❌ Failed to add changes in $repodir${NC}"
                            failed=$((failed + 1))
                            cd - >/dev/null 2>&1
                            continue
                        fi
                    else
                        # Standard commit flow
                        if [[ "$batch_mode" == false ]]; then
                            echo -e "${GREEN}Enter commit message (or press Enter for auto-generated):${NC}"
                            read -r user_msg
                            if [[ -n "$user_msg" ]]; then
                                commit_msg="$user_msg"
                            else
                                # Auto-generate commit message based on changes
                                commit_msg="Update $(basename "$repodir"): $(date '+%Y-%m-%d %H:%M')"
                            fi
                        fi
                        
                        echo -e "${BLUE}Adding changes...${NC}"
                        if git add -A; then
                            echo -e "${BLUE}Committing with message: \"$commit_msg\"${NC}"
                            if git commit -m "$commit_msg"; then
                                commit_success=true
                            else
                                echo -e "${RED}❌ Failed to commit $repodir${NC}"
                                failed=$((failed + 1))
                                cd - >/dev/null 2>&1
                                continue
                            fi
                        else
                            echo -e "${RED}❌ Failed to add changes in $repodir${NC}"
                            failed=$((failed + 1))
                            cd - >/dev/null 2>&1
                            continue
                        fi
                    fi
                    
                    # Push if commit was successful
                    if [[ "$commit_success" == true ]]; then
                        echo -e "${BLUE}Pushing to remote...${NC}"
                        if git push 2>/dev/null; then
                            echo -e "${GREEN}✅ Successfully pushed $repodir${NC}"
                            processed=$((processed + 1))
                        else
                            # Try with --set-upstream if regular push failed
                            local current_branch=$(git branch --show-current)
                            echo -e "${ORANGE}Regular push failed, trying with --set-upstream origin $current_branch${NC}"
                            if git push --set-upstream origin "$current_branch"; then
                                echo -e "${GREEN}✅ Successfully pushed $repodir (set upstream)${NC}"
                                processed=$((processed + 1))
                            else
                                echo -e "${RED}❌ Failed to push $repodir${NC}"
                                failed=$((failed + 1))
                            fi
                        fi
                    fi
                fi
                ;;
            s|S|skip|Skip)
                echo -e "${ORANGE}⏭️  Skipped $repodir${NC}"
                skipped=$((skipped + 1))
                ;;
            q|Q|quit|Quit)
                echo -e "${ORANGE}🛑 Aborted by user${NC}"
                break
                ;;
            *)
                echo -e "${ORANGE}⏭️  Skipped $repodir (invalid choice)${NC}"
                skipped=$((skipped + 1))
                ;;
        esac
        
        echo -e ""
        cd - >/dev/null 2>&1
    done
    
    # Final summary
    echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
    echo -e "${PURPLE}Summary:${NC}"
    echo -e "  ${GREEN}Processed: $processed${NC}"
    echo -e "  ${ORANGE}Skipped: $skipped${NC}"
    if [[ "$failed" -gt 0 ]]; then
        echo -e "  ${RED}Failed: $failed${NC}"
    fi
    echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
}

 # Function to set a branch across all repositories
set-all() {
    local target_branch=""
    local dry_run=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run|-n)
                dry_run=true
                shift
                ;;
            --help|-h)
                echo -e "${GREEN}Usage: gits set-all <branch-name> [OPTIONS]${NC}"
                echo -e "${BLUE}Ensure all repositories in the current directory tree are on the same branch${NC}"
                echo -e ""
                echo -e "${PURPLE}Options:${NC}"
                echo -e "  -n, --dry-run   Show what would be done without executing"
                echo -e "  -h, --help      Show this help message"
                echo -e ""
                echo -e "${BLUE}Examples:${NC}"
                echo -e "  gits set-all feature/progress-123"
                echo -e "  gits set-all release/1.0 --dry-run"
                return 0
                ;;
            *)
                if [[ -z "$target_branch" ]]; then
                    target_branch="$1"
                    shift
                else
                    echo -e "${RED}Error: Unknown option '$1'${NC}"
                    echo -e "Use 'gits set-all --help' for usage information."
                    return 1
                fi
                ;;
        esac
    done
    
    if [[ -z "$target_branch" ]]; then
        echo -e "${RED}Error: Branch name is required.${NC}"
        echo -e "Usage: gits set-all <branch-name> [OPTIONS]"
        return 1
    fi
    
    echo -e "${GREEN}Setting branch '${target_branch}' across all repositories...${NC}"
    echo -e ""
    
    local total_repos=0
    local created=0
    local switched=0
    local already_on_branch=0
    local failed=0
    
    # Find all git repositories
    while IFS= read -r -d '' gitdir; do
        local repodir=$(dirname "$gitdir")
        cd "$repodir" || continue
        
        total_repos=$((total_repos + 1))
        
        local current_branch
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        
        echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
        echo -e "${BLUE}📁 Repository: $repodir${NC} ($total_repos)"
        echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
        if [[ -n "$current_branch" && "$current_branch" != "HEAD" ]]; then
            echo -e "Current branch: ${GREEN}$current_branch${NC}"
        else
            echo -e "Current branch: ${ORANGE}(detached HEAD)${NC}"
        fi
        
        if [[ "$current_branch" == "$target_branch" ]]; then
            echo -e "${GREEN}Already on branch '${target_branch}'. Skipping.${NC}"
            already_on_branch=$((already_on_branch + 1))
            echo -e ""
            cd - >/dev/null 2>&1
            continue
        fi
        
        # Check if the branch already exists locally
        if git show-ref --verify --quiet "refs/heads/$target_branch"; then
            if [[ "$dry_run" == true ]]; then
                echo -e "${ORANGE}[DRY RUN] Would switch to existing branch '${target_branch}'${NC}"
                switched=$((switched + 1))
            else
                echo -e "${BLUE}Switching to existing branch '${target_branch}'...${NC}"
                if git checkout "$target_branch"; then
                    echo -e "${GREEN}Switched to existing branch '${target_branch}'.${NC}"
                    switched=$((switched + 1))
                else
                    echo -e "${RED}❌ Failed to switch to branch '${target_branch}'.${NC}"
                    failed=$((failed + 1))
                fi
            fi
        else
            # If no local branch, check for a matching remote branch (e.g., origin/$target_branch)
            local remote_ref=""
            remote_ref=$(git for-each-ref --format='%(refname:short)' "refs/remotes" 2>/dev/null | grep -E ".*/$target_branch$" | head -n 1)

            if [[ -n "$remote_ref" ]]; then
                if [[ "$dry_run" == true ]]; then
                    echo -e "${ORANGE}[DRY RUN] Would checkout remote branch '${remote_ref}' as local '${target_branch}'${NC}"
                    switched=$((switched + 1))
                else
                    echo -e "${BLUE}Checking out remote branch '${remote_ref}' as local '${target_branch}'...${NC}"
                    if git checkout -b "$target_branch" --track "$remote_ref"; then
                        echo -e "${GREEN}Switched to branch '${target_branch}' tracking '${remote_ref}'.${NC}"
                        switched=$((switched + 1))
                    else
                        echo -e "${RED}❌ Failed to checkout remote branch '${remote_ref}'.${NC}"
                        failed=$((failed + 1))
                    fi
                fi
            else
                if [[ "$dry_run" == true ]]; then
                    echo -e "${ORANGE}[DRY RUN] Would create and switch to new branch '${target_branch}' from current HEAD${NC}"
                    created=$((created + 1))
                else
                    echo -e "${BLUE}Creating and switching to new branch '${target_branch}' from current HEAD...${NC}"
                    if git checkout -b "$target_branch"; then
                        echo -e "${GREEN}Created and switched to new branch '${target_branch}'.${NC}"
                        created=$((created + 1))
                    else
                        echo -e "${RED}❌ Failed to create branch '${target_branch}'.${NC}"
                        failed=$((failed + 1))
                    fi
                fi
            fi
        fi
        
        echo -e ""
        cd - >/dev/null 2>&1
    done < <(find . -name .git -type d -print0)
    
    if [[ $total_repos -eq 0 ]]; then
        echo -e "${YELLOW}No git repositories found in current directory.${NC}"
        return 0
    fi
    
    echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
    echo -e "${PURPLE}Set-all Summary:${NC}"
    echo -e "  Total repositories: $total_repos"
    echo -e "  ${GREEN}Already on '${target_branch}': $already_on_branch${NC}"
    echo -e "  ${GREEN}Switched to existing branch: $switched${NC}"
    echo -e "  ${GREEN}Created new branch: $created${NC}"
    if [[ "$failed" -gt 0 ]]; then
        echo -e "  ${RED}Failed: $failed${NC}"
    fi
    echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
}

list-all() {
    echo -e "${GREEN}Listing git repositories and current branches...${NC}"
    echo -e ""

    local total_repos=0

    while IFS= read -r -d '' gitdir; do
        local repodir=$(dirname "$gitdir")
        cd "$repodir" || continue

        total_repos=$((total_repos + 1))

        local branch
        branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        if [[ -z "$branch" || "$branch" == "HEAD" ]]; then
            branch="(detached HEAD)"
        fi

        local status_output
        status_output=$(git status --porcelain 2>/dev/null)
        local unpushed
        unpushed=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        unpushed=$(echo "$unpushed" | grep -o '^[0-9]*$' | head -1)
        [ -z "$unpushed" ] && unpushed="0"

        local flags=""
        if [[ -n "$status_output" ]]; then
            flags="${flags}[modified]"
        fi
        if [[ "$unpushed" -gt 0 ]]; then
            flags="${flags}[+$unpushed ahead]"
        fi
        if [[ -z "$flags" ]]; then
            flags="[clean]"
        fi

        printf "${BLUE}📁 %-50s${NC}  ${GREEN}%-20s${NC} %s\n" "$repodir" "$branch" "$flags"

        cd - >/dev/null 2>&1
    done < <(find . -name .git -type d -print0)

    if [[ $total_repos -eq 0 ]]; then
        echo -e "${YELLOW}No git repositories found in current directory.${NC}"
    else
        echo -e ""
        echo -e "${PURPLE}Total repositories: $total_repos${NC}"
    fi
}

 # Function to check status of all repositories
status-all() {
    local show_clean=false
    local compact=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all|-a)
                show_clean=true
                shift
                ;;
            --compact|-c)
                compact=true
                shift
                ;;
            --help|-h)
                echo -e "${GREEN}Usage: gits status-all [OPTIONS]${NC}"
                echo -e "${BLUE}Check git status across all repositories in current directory tree${NC}"
                echo -e ""
                echo -e "${PURPLE}Options:${NC}"
                echo -e "  -a, --all      Show all repositories (including clean ones)"
                echo -e "  -c, --compact  Show compact summary format"
                echo -e "  -h, --help     Show this help message"
                echo -e ""
                echo -e "${BLUE}Examples:${NC}"
                echo -e "  gits status-all           # Show only repos needing attention"
                echo -e "  gits status-all --all     # Show all repos with status"
                echo -e "  gits status-all --compact # Show compact summary"
                return 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}"
                echo -e "Use 'gits status-all --help' for usage information."
                return 1
                ;;
        esac
    done
    
    echo -e "${GREEN}Checking git repositories...${NC}"
    echo -e ""
    
    local found_repos=0
    local dirty_repos=0
    
    # Find all .git directories and process them
    while IFS= read -r -d '' gitdir; do
        local repodir=$(dirname "$gitdir")
        cd "$repodir" || continue
        
        found_repos=$((found_repos + 1))
        
        # Get repository status
        local status_output=$(git status --porcelain 2>/dev/null)
        local unpushed=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        unpushed=$(echo "$unpushed" | grep -o '^[0-9]*$' | head -1)
        [ -z "$unpushed" ] && unpushed="0"
        local has_changes=false
        
        if [[ -n "$status_output" ]] || [[ "$unpushed" -gt 0 ]]; then
            has_changes=true
            dirty_repos=$((dirty_repos + 1))
        fi
        
        # Show repository info based on options
        if [[ "$has_changes" == true ]] || [[ "$show_clean" == true ]]; then
            if [[ "$compact" == true ]]; then
                # Compact format
                local status_icon="✅"
                local status_text="[clean]"
                
                if [[ "$has_changes" == true ]]; then
                    status_icon="🔴"
                    status_text=""
                    [[ -n "$status_output" ]] && status_text="${status_text}[modified]"
                    [[ "$unpushed" -gt 0 ]] && status_text="${status_text}[+$unpushed ahead]"
                fi
                
                printf "${status_icon} %-50s %s\n" "$repodir" "$status_text"
            else
                # Detailed format
                if [[ "$has_changes" == true ]]; then
                    echo -e "${BLUE}📁 $repodir${NC}"
                    git status --short
                    if [[ "$unpushed" -gt 0 ]]; then
                        echo -e "   ${ORANGE}↑ $unpushed commits to push${NC}"
                    fi
                    echo -e ""
                else
                    echo -e "${GREEN}✅ $repodir [clean]${NC}"
                fi
            fi
        fi
        
        cd - >/dev/null 2>&1
    done < <(find . -name .git -type d -print0)
    
    # Summary
    echo -e ""
    echo -e "${PURPLE}Summary:${NC}"
    echo -e "  Total repositories: $found_repos"
    if [[ "$dirty_repos" -gt 0 ]]; then
        echo -e "  ${ORANGE}Repositories needing attention: $dirty_repos${NC}"
    else
        echo -e "  ${GREEN}All repositories are clean!${NC}"
    fi
}


# Function to fetch updates from all repositories
fetch-all() {
    local parallel=true
    local max_concurrent=5
    local verbose=false
    local fetch_tags=true
    local quiet=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-parallel)
                parallel=false
                shift
                ;;
            --max-concurrent)
                max_concurrent="$2"
                shift 2
                ;;
            --no-tags)
                fetch_tags=false
                shift
                ;;
            --quiet|-q)
                quiet=true
                shift
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            --help|-h)
                echo -e "${GREEN}Usage: gits fetch-all [OPTIONS]${NC}"
                echo -e "${BLUE}Fetch updates from all repositories in current directory tree${NC}"
                echo -e ""
                echo -e "${PURPLE}Options:${NC}"
                echo -e "  --no-parallel      Disable parallel fetching"
                echo -e "  --max-concurrent N Maximum concurrent fetches (default: 5)"
                echo -e "  --no-tags          Don't fetch tags"
                echo -e "  -q, --quiet        Suppress output (except errors)"
                echo -e "  -v, --verbose      Show detailed output"
                echo -e "  -h, --help         Show this help message"
                echo -e ""
                echo -e "${BLUE}Examples:${NC}"
                echo -e "  gits fetch-all                    # Parallel fetch with tags"
                echo -e "  gits fetch-all --no-parallel      # Sequential fetching"
                echo -e "  gits fetch-all --max-concurrent 10 # Higher concurrency"
                echo -e "  gits fetch-all --no-tags          # Skip tag fetching"
                echo -e "  gits fetch-all --verbose          # Detailed output"
                return 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}"
                echo -e "Use 'gits fetch-all --help' for usage information."
                return 1
                ;;
        esac
    done
    
    echo -e "${GREEN}Fetching updates from all repositories...${NC}"
    echo -e ""
    
    # Collect all repository directories
    local repos=()
    while IFS= read -r -d '' gitdir; do
        repos+=("$(dirname "$gitdir")")
    done < <(find . -name .git -type d -print0)
    
    if [[ ${#repos[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No git repositories found in current directory.${NC}"
        return 0
    fi
    
    local total_repos=${#repos[@]}
    # Make counters global for helper functions
    success_count=0
    failed_count=0
    
    if [[ "$quiet" == true ]]; then
        echo -e "${BLUE}Processing $total_repos repositories...${NC}"
    fi
    
    if [[ "$parallel" == true ]]; then
        fetch_repositories_parallel "${repos[@]}"
    else
        fetch_repositories_sequential "${repos[@]}"
    fi
    
    # Summary
    echo -e ""
    echo -e "${PURPLE}Fetch Summary:${NC}"
    echo -e "  Total repositories: $total_repos"
    if [[ "$success_count" -gt 0 ]]; then
        echo -e "  ${GREEN}Successfully fetched: $success_count${NC}"
    fi
    if [[ "$failed_count" -gt 0 ]]; then
        echo -e "  ${RED}Failed: $failed_count${NC}"
    fi
}

# Helper function for sequential repository fetching
fetch_repositories_sequential() {
    local repos=("$@")
    local fetch_cmd="git fetch"
    
    if [[ "$fetch_tags" == false ]]; then
        fetch_cmd="$fetch_cmd --no-tags"
    fi
    
    for repo in "${repos[@]}"; do
        if [[ "$verbose" == true ]]; then
            echo -e "${BLUE}📁 $repo${NC}"
        elif [[ "$quiet" == false ]]; then
            echo -e "${PURPLE}Fetching $repo...${NC}"
        fi
        
        cd "$repo" || continue
        
        if $fetch_cmd 2>/dev/null; then
            ((success_count++))
            if [[ "$verbose" == true ]]; then
                echo -e "  ${GREEN}✅ Success${NC}"
            elif [[ "$quiet" == false ]]; then
                echo -e "  ${GREEN}✅ Success${NC}"
            fi
        else
            ((failed_count++))
            if [[ "$verbose" == true ]]; then
                echo -e "  ${RED}❌ Failed${NC}"
            elif [[ "$quiet" == false ]]; then
                echo -e "  ${RED}❌ Failed${NC}"
            fi
        fi
        
        cd - >/dev/null 2>&1
    done
}

# Helper function for parallel repository fetching
fetch_repositories_parallel() {
    local repos=("$@")
    local max_concurrent_local="${max_concurrent:-5}"
    local current_concurrent=0
    local pids=()
    local fetch_cmd="git fetch"
    
    if [[ "$fetch_tags" == false ]]; then
        fetch_cmd="$fetch_cmd --no-tags"
    fi
    
    for repo in "${repos[@]}"; do
        # Wait if we've reached the maximum concurrent processes
        while [[ $current_concurrent -ge $max_concurrent_local ]]; do
            # Check if any process has finished
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[i]}" 2>/dev/null; then
                    wait "${pids[i]}"
                    local exit_code=$?
                    if [[ $exit_code -eq 0 ]]; then
                        ((success_count++))
                    else
                        ((failed_count++))
                    fi
                    unset pids[i]
                    ((current_concurrent--))
                fi
            done
            if [[ $current_concurrent -ge $max_concurrent_local ]]; then
                sleep 0.1
            fi
        done
        
        # Start fetch in background
        {
            cd "$repo" 2>/dev/null || exit 1
            
            local verbose_prefix=""
            if [[ "$verbose" == true ]]; then
                verbose_prefix="${BLUE}📁 $repo${NC} - "
            elif [[ "$quiet" == false ]]; then
                verbose_prefix="Fetching $repo... "
            fi
            
            if $fetch_cmd 2>/dev/null; then
                if [[ "$verbose" == true ]]; then
                    echo -e "${verbose_prefix}${GREEN}✅ Success${NC}"
                elif [[ "$quiet" == false ]]; then
                    echo -e "${verbose_prefix}${GREEN}✅${NC}"
                fi
                exit 0
            else
                if [[ "$verbose" == true ]]; then
                    echo -e "${verbose_prefix}${RED}❌ Failed${NC}"
                elif [[ "$quiet" == false ]]; then
                    echo -e "${verbose_prefix}${RED}❌${NC}"
                fi
                exit 1
            fi
        } &
        
        pids+=("$!")
        ((current_concurrent++))
    done
    
    # Wait for all remaining background processes
    for pid in "${pids[@]}"; do
        wait "$pid"
        local exit_code=$?
        if [[ $exit_code -eq 0 ]]; then
            ((success_count++))
        else
            ((failed_count++))
        fi
    done
}

# Function to pull updates from all repositories
pull-all() {
    local parallel=true
    local max_concurrent=5
    local verbose=false
    local auto_merge=false
    local abort_on_conflict=false
    local strategy="merge"  # merge, rebase, or ff-only
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-parallel)
                parallel=false
                shift
                ;;
            --max-concurrent)
                max_concurrent="$2"
                shift 2
                ;;
            --auto-merge)
                auto_merge=true
                shift
                ;;
            --abort-on-conflict)
                abort_on_conflict=true
                shift
                ;;
            --strategy)
                strategy="$2"
                if [[ "$strategy" != "merge" && "$strategy" != "rebase" && "$strategy" != "ff-only" ]]; then
                    echo -e "${RED}Error: Invalid strategy '$strategy'. Must be 'merge', 'rebase', or 'ff-only'${NC}"
                    return 1
                fi
                shift 2
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            --help|-h)
                echo -e "${GREEN}Usage: gits pull-all [OPTIONS]${NC}"
                echo -e "${BLUE}Pull updates from all repositories in current directory tree${NC}"
                echo -e ""
                echo -e "${PURPLE}Options:${NC}"
                echo -e "  --no-parallel         Disable parallel pulling"
                echo -e "  --max-concurrent N    Maximum concurrent pulls (default: 5)"
                echo -e "  --auto-merge          Automatically merge without conflicts (use carefully)"
                echo -e "  --abort-on-conflict   Abort on first merge conflict"
                echo -e "  --strategy STRATEGY   Merge strategy: merge, rebase, or ff-only (default: merge)"
                echo -e "  -v, --verbose         Show detailed output"
                echo -e "  -h, --help            Show this help message"
                echo -e ""
                echo -e "${BLUE}Examples:${NC}"
                echo -e "  gits pull-all                    # Standard pull with merge strategy"
                echo -e "  gits pull-all --strategy rebase  # Use rebase strategy"
                echo -e "  gits pull-all --auto-merge       # Auto-merge when possible"
                echo -e "  gits pull-all --verbose          # Detailed output"
                echo -e "  gits pull-all --abort-on-conflict # Stop on first conflict"
                return 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}"
                echo -e "Use 'gits pull-all --help' for usage information."
                return 1
                ;;
        esac
    done
    
    echo -e "${GREEN}Pulling updates from all repositories...${NC}"
    echo -e ""
    
    # Collect all repository directories
    local repos=()
    while IFS= read -r -d '' gitdir; do
        repos+=("$(dirname "$gitdir")")
    done < <(find . -name .git -type d -print0)
    
    if [[ ${#repos[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No git repositories found in current directory.${NC}"
        return 0
    fi
    
    local total_repos=${#repos[@]}
    # Make counters global for helper functions
    success_count=0
    conflict_count=0
    failed_count=0
    
    if [[ "$parallel" == true ]]; then
        pull_repositories_parallel "${repos[@]}"
    else
        pull_repositories_sequential "${repos[@]}"
    fi
    
    # Summary
    echo -e ""
    echo -e "${PURPLE}Pull Summary:${NC}"
    echo -e "  Total repositories: $total_repos"
    if [[ "$success_count" -gt 0 ]]; then
        echo -e "  ${GREEN}Successfully pulled: $success_count${NC}"
    fi
    if [[ "$conflict_count" -gt 0 ]]; then
        echo -e "  ${YELLOW}Merge conflicts: $conflict_count${NC}"
    fi
    if [[ "$failed_count" -gt 0 ]]; then
        echo -e "  ${RED}Failed: $failed_count${NC}"
    fi
}

# Helper function for sequential repository pulling
pull_repositories_sequential() {
    local repos=("$@")
    
    for repo in "${repos[@]}"; do
        if [[ "$verbose" == true ]]; then
            echo -e "${BLUE}📁 $repo${NC}"
        elif [[ "$quiet" == false ]]; then
            echo -e "${PURPLE}Pulling $repo...${NC}"
        fi
        
        cd "$repo" || continue
        
        local result=$(perform_git_pull)
        
        case "$result" in
            "success")
                ((success_count++))
                if [[ "$verbose" == true ]]; then
                    echo -e "  ${GREEN}✅ Success${NC}"
                elif [[ "$quiet" == false ]]; then
                    echo -e "  ${GREEN}✅ Success${NC}"
                fi
                ;;
            "conflict")
                ((conflict_count++))
                if [[ "$verbose" == true ]]; then
                    echo -e "  ${YELLOW}⚠️  Merge conflict${NC}"
                elif [[ "$quiet" == false ]]; then
                    echo -e "  ${YELLOW}⚠️  Merge conflict${NC}"
                fi
                
                if [[ "$abort_on_conflict" == true ]]; then
                    echo -e "${RED}Aborting due to --abort-on-conflict flag.${NC}"
                    git merge --abort 2>/dev/null
                    return 1
                fi
                ;;
            "no-updates")
                if [[ "$verbose" == true ]]; then
                    echo -e "  ${BLUE}ℹ️  No updates${NC}"
                elif [[ "$quiet" == false ]]; then
                    echo -e "  ${BLUE}ℹ️  No updates${NC}"
                fi
                ((success_count++))
                ;;
            "failed")
                ((failed_count++))
                if [[ "$verbose" == true ]]; then
                    echo -e "  ${RED}❌ Failed${NC}"
                elif [[ "$quiet" == false ]]; then
                    echo -e "  ${RED}❌ Failed${NC}"
                fi
                ;;
        esac
        
        cd - >/dev/null 2>&1
    done
}

# Helper function for parallel repository pulling
pull_repositories_parallel() {
    local repos=("$@")
    local max_concurrent_local="${max_concurrent:-5}"
    local current_concurrent=0
    local pids=()
    
    for repo in "${repos[@]}"; do
        # Wait if we've reached the maximum concurrent processes
        while [[ $current_concurrent -ge $max_concurrent_local ]]; do
            # Check if any process has finished
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[i]}" 2>/dev/null; then
                    wait "${pids[i]}"
                    local exit_code=$?
                    case $exit_code in
                        0) ((success_count++)) ;;
                        1) ((conflict_count++)) ;;
                        2) ((failed_count++)) ;;
                    esac
                    unset pids[i]
                    ((current_concurrent--))
                fi
            done
            if [[ $current_concurrent -ge $max_concurrent_local ]]; then
                sleep 0.1
            fi
        done
        
        # Start pull in background
        {
            cd "$repo" 2>/dev/null || exit 3
            
            local verbose_prefix=""
            if [[ "$verbose" == true ]]; then
                verbose_prefix="${BLUE}📁 $repo${NC} - "
            elif [[ "$quiet" == false ]]; then
                verbose_prefix="Pulling $repo... "
            fi
            
            local result=$(perform_git_pull)
            
            case "$result" in
                "success")
                    if [[ "$verbose" == true ]]; then
                        echo -e "${verbose_prefix}${GREEN}✅ Success${NC}"
                    elif [[ "$quiet" == false ]]; then
                        echo -e "${verbose_prefix}${GREEN}✅${NC}"
                    fi
                    exit 0
                    ;;
                "conflict")
                    if [[ "$verbose" == true ]]; then
                        echo -e "${verbose_prefix}${YELLOW}⚠️  Merge conflict${NC}"
                    elif [[ "$quiet" == false ]]; then
                        echo -e "${verbose_prefix}${YELLOW}⚠️  Merge conflict${NC}"
                    fi
                    exit 1
                    ;;
                "no-updates")
                    if [[ "$verbose" == true ]]; then
                        echo -e "${verbose_prefix}${BLUE}ℹ️  No updates${NC}"
                    elif [[ "$quiet" == false ]]; then
                        echo -e "${verbose_prefix}${BLUE}ℹ️  No updates${NC}"
                    fi
                    exit 0
                    ;;
                "failed")
                    if [[ "$verbose" == true ]]; then
                        echo -e "${verbose_prefix}${RED}❌ Failed${NC}"
                    elif [[ "$quiet" == false ]]; then
                        echo -e "${verbose_prefix}${RED}❌${NC}"
                    fi
                    exit 2
                    ;;
            esac
        } &
        
        pids+=("$!")
        ((current_concurrent++))
    done
    
    # Wait for all remaining background processes
    for pid in "${pids[@]}"; do
        wait "$pid"
        local exit_code=$?
        case $exit_code in
            0) ((success_count++)) ;;
            1) ((conflict_count++)) ;;
            2) ((failed_count++)) ;;
        esac
    done
}

# Helper function to perform git pull with strategy and conflict handling
perform_git_pull() {
    local pull_cmd="git pull"
    
    # Set strategy based on option
    case "$strategy" in
        "rebase")
            pull_cmd="$pull_cmd --rebase"
            ;;
        "ff-only")
            pull_cmd="$pull_cmd --ff-only"
            ;;
        "merge"|*)
            pull_cmd="$pull_cmd --no-rebase"
            ;;
    esac
    
    # Try to pull
    if $pull_cmd 2>/tmp/pull_error_$$; then
        # Check if there were any updates
        if [[ -s /tmp/pull_error_$$ ]]; then
            echo "success"
        else
            echo "no-updates"
        fi
    else
        local error_output=$(cat /tmp/pull_error_$$ 2>/dev/null)
        rm -f /tmp/pull_error_$$
        
        # Check for merge conflict
        if echo "$error_output" | grep -q "CONFLICT"; then
            if [[ "$auto_merge" == true ]]; then
                # Try to auto-resolve simple conflicts
                local conflict_file
                conflict_file=$(git diff --name-only --diff-filter=U | head -1)
                if [[ -n "$conflict_file" ]] && git checkout --theirs "$conflict_file" 2>/dev/null; then
                    if git add -A && git commit --no-edit 2>/dev/null; then
                        echo "success"
                    else
                        echo "conflict"
                    fi
                else
                    echo "conflict"
                fi
            else
                echo "conflict"
            fi
        else
            echo "failed"
        fi
    fi
    
    rm -f /tmp/pull_error_$$
}

# Enhanced repository cloning with improved architecture and token management
clone-all() {
    local username=""
    local platform=""
    local gitea_server="git.ourworld.tf"
    local use_auth=false
    local parallel_cloning=true
    local max_concurrent=5
    local include_archived=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                echo -e "${GREEN}Usage: gits clone-all [URL|username] [OPTIONS]${NC}"
                echo -e "${BLUE}Clone all repositories from a user or organization${NC}"
                echo -e ""
                echo -e "${PURPLE}Options:${NC}"
                echo -e "  --help, -h           Show this help message"
                echo -e "  --server URL         Gitea server URL (default: git.ourworld.tf)"
                echo -e "  --no-parallel        Disable parallel cloning"
                echo -e "  --max-concurrent N   Maximum concurrent clones (default: 5)"
                echo -e "  --archived           Include archived repositories"
                echo -e ""
                echo -e "${BLUE}Examples:${NC}"
                echo -e "  gits clone-all myusername"
                echo -e "  gits clone-all github.com/myusername"
                echo -e "  gits clone-all git.ourworld.tf/myorg --server git.ourworld.tf"
                echo -e "  gits clone-all myusername --max-concurrent 10"
                return 0
                ;;
            --server)
                gitea_server="$2"
                shift 2
                ;;
            --no-parallel)
                parallel_cloning=false
                shift
                ;;
            --max-concurrent)
                max_concurrent="$2"
                shift 2
                ;;
            --archived)
                include_archived=true
                shift
                ;;
            *)
                username="$1"
                shift
                ;;
        esac
    done
    
    # Detect platform and extract username if not provided
    local is_org=false
    local server_url=""  # Generic server URL for Forgejo/Gitea
    if [ -n "$username" ]; then
        # Parse input to detect platform and extract username
        if [[ "$username" == *"forge.ourworld.tf"* ]] || [[ "$username" == *"forgejo"* ]]; then
            platform="forgejo"
            if [[ "$username" == http* ]]; then
                server_url=$(echo "$username" | sed -E 's|https?://([^/]+)/.*|\1|')
                username=$(echo "$username" | sed -E 's|https?://[^/]+/([^/]+).*|\1|')
                # Check if this looks like an organization URL
                if [[ "$username" == *"/"* ]]; then
                    is_org=true
                    server_url=$(echo "$username" | cut -d'/' -f1)
                    username=$(echo "$username" | cut -d'/' -f2)
                fi
            else
                server_url=$(echo "$username" | cut -d'/' -f1)
                username=$(echo "$username" | cut -d'/' -f2)
                # Check if this looks like an organization URL (has slash)
                if [[ "$username" == *"/"* ]]; then
                    is_org=true
                    username=$(echo "$username" | cut -d'/' -f2)
                fi
            fi
            [ -z "$server_url" ] && server_url="forge.ourworld.tf"
        elif [[ "$username" == *"github.com"* ]]; then
            platform="github"
            # Extract username from various GitHub URL formats
            if [[ "$username" == http* ]]; then
                username=$(echo "$username" | sed -E 's|https?://github\.com/([^/]+).*|\1|')
            else
                username=$(echo "$username" | sed 's|github\.com/||' | sed 's|/.*||')
            fi
        elif [[ "$username" == *"git.ourworld.tf"* ]] || [[ "$username" == *"gitea"* ]]; then
            platform="gitea"
            if [[ "$username" == http* ]]; then
                gitea_server=$(echo "$username" | sed -E 's|https?://([^/]+)/.*|\1|')
                username=$(echo "$username" | sed -E 's|https?://[^/]+/([^/]+).*|\1|')
                # Check if this looks like an organization URL
                if [[ "$username" == *"/"* ]]; then
                    is_org=true
                    gitea_server=$(echo "$username" | cut -d'/' -f1)
                    username=$(echo "$username" | cut -d'/' -f2)
                fi
            else
                gitea_server=$(echo "$username" | cut -d'/' -f1)
                username=$(echo "$username" | cut -d'/' -f2)
                # Check if this looks like an organization URL (has slash)
                if [[ "$username" == *"/"* ]]; then
                    is_org=true
                    username=$(echo "$username" | cut -d'/' -f2)
                fi
            fi
        else
            # Assume GitHub for username-only input
            platform="github"
        fi
    else
        # Interactive mode
        echo -e "${GREEN}Which platform would you like to use?${NC}"
        echo -e "1) Forgejo (forge.ourworld.tf)"
        echo -e "2) Gitea (git.ourworld.tf)"
        echo -e "3) GitHub"
        read -p "Enter your choice (1/2/3): " platform_choice
        
        case "$platform_choice" in
            1) platform="forgejo" ;;
            2) platform="gitea" ;;
            3) platform="github" ;;
            *)
                echo -e "${RED}Invalid choice. Defaulting to GitHub.${NC}"
                platform="github"
                ;;
        esac
        
        if [[ "$platform" == "forgejo" ]]; then
            echo -e "${GREEN}Enter Forgejo server URL (default: forge.ourworld.tf):${NC}"
            read server_input
            server_url="${server_input:-forge.ourworld.tf}"
        elif [[ "$platform" == "gitea" ]]; then
            echo -e "${GREEN}Enter Gitea server URL (default: git.ourworld.tf):${NC}"
            read server_input
            [ -n "$server_input" ] && gitea_server="$server_input"
        fi
        
        echo -e "${GREEN}Enter username or organization name:${NC}"
        read username
        
        if [ -z "$username" ]; then
            echo -e "${RED}Error: Username cannot be empty.${NC}"
            return 1
        fi
    fi
    
    # Validate platform
    case "$platform" in
        forgejo|github|gitea)
            echo -e "${GREEN}Platform: ${platform}${NC}"
            echo -e "${GREEN}Username: $username${NC}"
            [[ "$platform" == "forgejo" ]] && echo -e "${GREEN}Server: $server_url${NC}"
            [[ "$platform" == "gitea" ]] && echo -e "${GREEN}Server: $gitea_server${NC}"
            ;;
        *)
            echo -e "${RED}Unsupported platform: $platform${NC}"
            return 1
            ;;
    esac
    
    # Validate dependencies
    case "$platform" in
        github)
            if ! command -v gh &> /dev/null; then
                echo -e "${RED}Error: GitHub CLI (gh) is required but not installed.${NC}"
                echo -e "${BLUE}Install it from: https://cli.github.com/${NC}"
                return 1
            fi
            ;;
        forgejo|gitea)
            if ! command -v curl &> /dev/null; then
                echo -e "${RED}Error: curl is required but not installed.${NC}"
                return 1
            fi
            if ! command -v jq &> /dev/null; then
                echo -e "${RED}Error: jq is required but not installed.${NC}"
                return 1
            fi
            ;;
    esac
    
    # Create directory for cloning
    mkdir -p "$username"
    cd "$username" || return 1
    
    local repos_json=""
    local auth_header=""
    
    echo -e "\n${BLUE}Fetching repositories...${NC}"
    
    # Fetch repositories using platform-specific method
    case "$platform" in
        github)
            # GitHub repository access with proper private repo support
            echo -e "${GREEN}Do you want to access private repositories? (y/n):${NC}"
            echo -e "${BLUE}This allows cloning private repositories you have access to${NC}"
            read -r use_auth_response
            
            if [[ "$use_auth_response" =~ ^[Yy]$ ]]; then
                # Check for cached token first
                local cached_token=$(get_cached_token "github" "github.com")
                
                if [ -n "$cached_token" ]; then
                    echo -e "${GREEN}Found cached authentication token for GitHub${NC}"
                    echo -e "${GREEN}Use cached token? (y/n):${NC}"
                    read -r use_cached
                    
                    if [[ "$use_cached" =~ ^[Yy]$ ]]; then
                        auth_header="Authorization: token $cached_token"
                        echo -e "${BLUE}Using cached token${NC}"
                    fi
                fi
                
                # If no cached token or user declined, get from gh CLI
                if [ -z "$auth_header" ]; then
                    if ! command -v gh &> /dev/null; then
                        echo -e "${RED}Error: GitHub CLI (gh) is required for private repository access.${NC}"
                        echo -e "${BLUE}Install it from: https://cli.github.com/${NC}"
                        cd - > /dev/null
                        return 1
                    fi
                    
                    echo -e "${GREEN}Checking GitHub CLI authentication...${NC}"
                    local github_token=$(get_github_token)
                    
                    if [ -n "$github_token" ]; then
                        auth_header="Authorization: token $github_token"
                        save_token "github" "github.com" "$github_token"
                        echo -e "${GREEN}Retrieved and cached token from GitHub CLI${NC}"
                    else
                        echo -e "${RED}Could not retrieve GitHub token.${NC}"
                        echo -e "${ORANGE}Please run 'gh auth login' and try again.${NC}"
                        cd - > /dev/null
                        return 1
                    fi
                fi
                
                # Use GitHub CLI for private repository access (better permission handling)
                echo -e "${BLUE}Fetching repositories using GitHub CLI...${NC}"
                
                # Test token scopes by trying to access repos
                local test_result=$(gh repo list "$username" --json=id,name,clone_url,private,visibility --limit 1 2>&1)
                local test_exit_code=$?
                
                if [ $test_exit_code -ne 0 ]; then
                    echo -e "${RED}Failed to access repositories.${NC}"
                    
                    # Check for scope-related errors
                    if echo "$test_result" | grep -qi "scope\|permission\|unauthorized\|forbidden"; then
                        echo -e "${YELLOW}Token scopes may be insufficient.${NC}"
                        echo -e "${BLUE}Required scopes for private/organization repositories:${NC}"
                        echo -e "  - 'repo' for private repositories"
                        echo -e "  - 'read:org' for organization repositories"
                        echo -e "${BLUE}To fix:${NC}"
                        echo -e "  1. Go to: https://github.com/settings/tokens"
                        echo -e "  2. Edit your token and add missing scopes"
                        echo -e "  3. Or run: gh auth login --with-token"
                        echo -e "${ORANGE}Falling back to public repository access only.${NC}"
                        
                        # Fallback to public access
                        repos_json=$(curl -s "https://api.github.com/users/$username/repos?per_page=100&type=all" 2>/dev/null)
                        if ! echo "$repos_json" | jq . &>/dev/null; then
                            echo -e "${RED}Failed to fetch public repositories.${NC}"
                            cd - > /dev/null
                            return 1
                        fi
                    elif echo "$test_result" | grep -qi "not found\|404"; then
                        echo -e "${RED}User or organization '$username' not found.${NC}"
                        echo -e "${ORANGE}Please check the username/organization name.${NC}"
                        cd - > /dev/null
                        return 1
                    else
                        echo -e "${RED}Error details: $test_result${NC}"
                        cd - > /dev/null
                        return 1
                    fi
                else
                    # Successfully accessed repos with GitHub CLI
                    repos_json=$(gh repo list "$username" --json=id,name,sshUrl,url,isPrivate,isArchived --limit 100 2>/dev/null)
                fi
            else
                # Public access only - use GitHub API
                echo -e "${BLUE}Fetching public repositories using GitHub API...${NC}"
                repos_json=$(curl -s "https://api.github.com/users/$username/repos?per_page=100&type=all" 2>/dev/null)
                
                # Validate response
                if ! echo "$repos_json" | jq . &>/dev/null; then
                    echo -e "${RED}Failed to fetch repositories from GitHub.${NC}"
                    echo -e "${ORANGE}Please check your connection.${NC}"
                    cd - > /dev/null
                    return 1
                fi
            fi
            ;;
        forgejo)
            # Handle Forgejo authentication using cached token system
            echo -e "${GREEN}Do you want to access private and internal repositories? (y/n):${NC}"
            echo -e "${BLUE}Note: This will also show organization repositories if '$username' is an organization${NC}"
            read -r use_auth_response
            
            if [[ "$use_auth_response" =~ ^[Yy]$ ]]; then
                # Use token caching system
                local cached_token=$(get_cached_token "forgejo" "$server_url")
                
                if [ -n "$cached_token" ]; then
                    echo -e "${GREEN}Found cached authentication token for $server_url${NC}"
                    echo -e "${GREEN}Use cached token? (y/n):${NC}"
                    read -r use_cached
                    
                    if [[ "$use_cached" =~ ^[Yy]$ ]]; then
                        auth_header="Authorization: token $cached_token"
                        echo -e "${BLUE}Using cached token${NC}"
                    fi
                fi
                
                # If no cached token or user declined, prompt for token
                if [ -z "$auth_header" ]; then
                    echo -e "${GREEN}Enter your Forgejo API token:${NC}"
                    echo -e "${BLUE}Generate one at: https://$server_url/user/settings/applications${NC}"
                    read -s API_TOKEN
                    echo
                    
                    if [ -n "$API_TOKEN" ]; then
                        auth_header="Authorization: token $API_TOKEN"
                        save_token "forgejo" "$server_url" "$API_TOKEN"
                        echo -e "${GREEN}Token saved for future use${NC}"
                    else
                        echo -e "${RED}No token provided.${NC}"
                        cd - > /dev/null
                        return 1
                    fi
                fi
            fi
            
            # Construct API endpoint (Forgejo uses same API as Gitea)
            local base_url
            if [[ "$server_url" != http* ]]; then
                base_url="https://$server_url"
            else
                base_url="$server_url"
            fi
            
            # Smart endpoint selection based on whether we want organization or user repos
            local primary_endpoint=""
            local secondary_endpoints=()
            local endpoint_names=()
            
            if [[ "$is_org" == true ]]; then
                # For organizations, prefer org endpoint first
                echo -e "${BLUE}Detected organization request for '$username'${NC}"
                primary_endpoint="$base_url/api/v1/orgs/$username/repos"
                endpoint_names+=("organization")
                secondary_endpoints+=("$base_url/api/v1/users/$username/repos")
                endpoint_names+=("user")
            else
                # For users, prefer user endpoint first
                primary_endpoint="$base_url/api/v1/users/$username/repos"
                endpoint_names+=("user")
                if [ -n "$auth_header" ]; then
                    secondary_endpoints+=("$base_url/api/v1/user/repos")
                    endpoint_names+=("authenticated_user")
                fi
            fi
            
            local found_repos=false
            local best_response=""
            local best_endpoint=""
            local best_count=0
            
            # Try primary endpoint first
            echo -e "${BLUE}Trying primary endpoint: ${endpoint_names[0]}${NC}"
            local response=""
            if [ -n "$auth_header" ]; then
                response=$(curl -s -H "$auth_header" "$primary_endpoint")
            else
                response=$(curl -s "$primary_endpoint")
            fi
            
            # Validate primary response
            if echo "$response" | jq . &>/dev/null; then
                local repo_count=$(echo "$response" | jq 'length')
                if [ "$repo_count" -gt 0 ]; then
                    echo -e "${GREEN}Found $repo_count repositories via ${endpoint_names[0]} endpoint${NC}"
                    best_response="$response"
                    best_endpoint="${endpoint_names[0]}"
                    best_count="$repo_count"
                    found_repos=true
                else
                    echo -e "${ORANGE}No repositories found via ${endpoint_names[0]} endpoint${NC}"
                fi
            else
                echo -e "${ORANGE}Invalid response from ${endpoint_names[0]} endpoint${NC}"
            fi
            
            # Try secondary endpoints only if primary didn't work well
            if [ "$found_repos" = false ]; then
                for i in "${!secondary_endpoints[@]}"; do
                    local api_endpoint="${secondary_endpoints[i]}"
                    local endpoint_name="${endpoint_names[i+1]}"
                    
                    echo -e "${BLUE}Trying secondary endpoint: $endpoint_name${NC}"
                    
                    local response=""
                    if [ -n "$auth_header" ]; then
                        response=$(curl -s -H "$auth_header" "$api_endpoint")
                    else
                        response=$(curl -s "$api_endpoint")
                    fi
                    
                    if echo "$response" | jq . &>/dev/null; then
                        local repo_count=$(echo "$response" | jq 'length')
                        if [ "$repo_count" -gt "$best_count" ]; then
                            echo -e "${GREEN}Found $repo_count repositories via $endpoint_name endpoint${NC}"
                            best_response="$response"
                            best_endpoint="$endpoint_name"
                            best_count="$repo_count"
                            found_repos=true
                        fi
                    fi
                done
            fi
            
            if [ "$found_repos" = false ]; then
                echo -e "${RED}Failed to fetch repositories from Forgejo.${NC}"
                echo -e "${ORANGE}Please check your username/organization and try again.${NC}"
                cd - > /dev/null
                return 1
            fi
            
            repos_json="$best_response"
            echo -e "${GREEN}Using $best_endpoint endpoint with $best_count repositories${NC}"
            ;;
        gitea)
            # Handle Gitea authentication using existing token system
            echo -e "${GREEN}Do you want to access private and internal repositories? (y/n):${NC}"
            echo -e "${BLUE}Note: This will also show organization repositories if '$username' is an organization${NC}"
            read -r use_auth_response
            
            if [[ "$use_auth_response" =~ ^[Yy]$ ]]; then
                # Use existing token caching system from save-issues
                local cached_token=$(get_cached_gitea_token "$gitea_server")
                
                if [ -n "$cached_token" ]; then
                    echo -e "${GREEN}Found cached authentication token for $gitea_server${NC}"
                    echo -e "${GREEN}Use cached token? (y/n):${NC}"
                    read -r use_cached
                    
                    if [[ "$use_cached" =~ ^[Yy]$ ]]; then
                        auth_header="Authorization: token $cached_token"
                        echo -e "${BLUE}Using cached token${NC}"
                    fi
                fi
                
                # If no cached token or user declined, prompt for authentication
                if [ -z "$auth_header" ]; then
                    echo -e "${GREEN}Choose authentication method:${NC}"
                    echo -e "1) Use existing Gitea login (via tea CLI)"
                    echo -e "2) Provide an API token (will be cached for future use)"
                    read -p "Enter your choice (1/2): " auth_choice
                    
                    case "$auth_choice" in
                        1)
                            if ! command -v tea &> /dev/null; then
                                echo -e "${RED}Error: tea CLI is required but not installed.${NC}"
                                cd - > /dev/null
                                return 1
                            fi
                            
                            local gitea_token=$(get_tea_token "$gitea_server")
                            if [ -n "$gitea_token" ]; then
                                auth_header="Authorization: token $gitea_token"
                                save_gitea_token "$gitea_server" "$gitea_token"
                                echo -e "${GREEN}Retrieved and cached token from tea CLI${NC}"
                            else
                                echo -e "${RED}Could not retrieve token from tea configuration.${NC}"
                                cd - > /dev/null
                                return 1
                            fi
                            ;;
                        2)
                            echo -e "${GREEN}Enter your Gitea API token:${NC}"
                            read -s API_TOKEN
                            echo
                            
                            if [ -n "$API_TOKEN" ]; then
                                auth_header="Authorization: token $API_TOKEN"
                                save_gitea_token "$gitea_server" "$API_TOKEN"
                                echo -e "${GREEN}Token saved for future use${NC}"
                            else
                                echo -e "${RED}No token provided.${NC}"
                                cd - > /dev/null
                                return 1
                            fi
                            ;;
                        *)
                            echo -e "${RED}Invalid choice.${NC}"
                            cd - > /dev/null
                            return 1
                            ;;
                    esac
                fi
            fi
            
            # Construct API endpoint
            local base_url
            if [[ "$gitea_server" != http* ]]; then
                base_url="https://$gitea_server"
            else
                base_url="$gitea_server"
            fi
            
            # Smart endpoint selection based on whether we want organization or user repos
            local primary_endpoint=""
            local secondary_endpoints=()
            local endpoint_names=()
            
            if [[ "$is_org" == true ]]; then
                # For organizations, prefer org endpoint first
                echo -e "${BLUE}Detected organization request for '$username'${NC}"
                primary_endpoint="$base_url/api/v1/orgs/$username/repos"
                endpoint_names+=("organization")
                secondary_endpoints+=("$base_url/api/v1/users/$username/repos")
                endpoint_names+=("user")
            else
                # For users, prefer user endpoint first
                primary_endpoint="$base_url/api/v1/users/$username/repos"
                endpoint_names+=("user")
                if [ -n "$auth_header" ]; then
                    secondary_endpoints+=("$base_url/api/v1/user/repos")
                    endpoint_names+=("authenticated_user")
                fi
            fi
            
            local found_repos=false
            local best_response=""
            local best_endpoint=""
            local best_count=0
            
            # Try primary endpoint first
            echo -e "${BLUE}Trying primary endpoint: ${endpoint_names[0]}${NC}"
            local response=""
            if [ -n "$auth_header" ]; then
                response=$(curl -s -H "$auth_header" "$primary_endpoint")
            else
                response=$(curl -s "$primary_endpoint")
            fi
            
            # Validate primary response
            if echo "$response" | jq . &>/dev/null; then
                local repo_count=$(echo "$response" | jq 'length')
                if [ "$repo_count" -gt 0 ]; then
                    echo -e "${GREEN}Found $repo_count repositories via ${endpoint_names[0]} endpoint${NC}"
                    best_response="$response"
                    best_endpoint="${endpoint_names[0]}"
                    best_count="$repo_count"
                    found_repos=true
                else
                    echo -e "${ORANGE}No repositories found via ${endpoint_names[0]} endpoint${NC}"
                fi
            else
                echo -e "${ORANGE}Invalid response from ${endpoint_names[0]} endpoint${NC}"
            fi
            
            # Try secondary endpoints only if primary didn't work well
            if [ "$found_repos" = false ] || [ "$best_count" -gt 50 ]; then
                for i in "${!secondary_endpoints[@]}"; do
                    local api_endpoint="${secondary_endpoints[i]}"
                    local endpoint_name="${endpoint_names[i+1]}"
                    
                    echo -e "${BLUE}Trying secondary endpoint: $endpoint_name${NC}"
                    
                    local response=""
                    if [ -n "$auth_header" ]; then
                        response=$(curl -s -H "$auth_header" "$api_endpoint")
                    else
                        response=$(curl -s "$api_endpoint")
                    fi
                    
                    # Validate response
                    if echo "$response" | jq . &>/dev/null; then
                        local repo_count=$(echo "$response" | jq 'length')
                        if [ "$repo_count" -gt 0 ]; then
                            echo -e "${GREEN}Found $repo_count repositories via $endpoint_name endpoint${NC}"
                            
                            # Use this endpoint if it has reasonable results or primary failed
                            if [ "$found_repos" = false ] || [ "$repo_count" -lt "$best_count" ]; then
                                best_response="$response"
                                best_endpoint="$endpoint_name"
                                best_count="$repo_count"
                                found_repos=true
                            fi
                        else
                            echo -e "${ORANGE}No repositories found via $endpoint_name endpoint${NC}"
                        fi
                    else
                        echo -e "${ORANGE}Invalid response from $endpoint_name endpoint${NC}"
                    fi
                done
            fi
            
            if [ "$found_repos" = false ]; then
                echo -e "${RED}No repositories found for '$username' on $gitea_server.${NC}"
                echo -e "${ORANGE}This might be because:${NC}"
                echo -e "  - The user/organization doesn't exist"
                echo -e "  - All repositories are private and no authentication was provided"
                echo -e "  - The server is not accessible"
                cd - > /dev/null
                return 1
            fi
            
            repos_json="$best_response"
            
            echo -e "${GREEN}Using repositories from $best_endpoint endpoint ($best_count repos)${NC}"
            
            # Check final repository count
            local total_count=$(echo "$repos_json" | jq 'length')
            if [ "$total_count" -eq 0 ]; then
                echo -e "${RED}No repositories found.${NC}"
                cd - > /dev/null
                return 1
            fi
            ;;
    esac
    
    # Debug: Show repository count
    local total_count=$(echo "$repos_json" | jq 'length' 2>/dev/null)
    echo -e "${BLUE}Found $total_count repositories to process${NC}"
    
    if [ "$total_count" -eq 0 ]; then
        echo -e "${YELLOW}No repositories found to clone.${NC}"
        cd - >/dev/null 2>&1
        return 0
    fi
    
    # Process repositories
    echo -e "\n${BLUE}Processing repositories...${NC}"
    
    local repos_list=()
    local clone_urls=()
    local ssh_urls=()
    local repo_names=()
    local processed_count=0
    local skipped_existing=0
    local invalid_count=0
    
    # Parse repositories
    while read -r repo; do
        local repo_name=""
        local clone_url=""
        local ssh_url=""
        local is_archived="false"
        
        # Handle platform-specific field names
        case "$platform" in
            github)
                repo_name=$(echo "$repo" | jq -r '.name')
                clone_url=$(echo "$repo" | jq -r '.clone_url // (.url + ".git")')
                ssh_url=$(echo "$repo" | jq -r '.sshUrl // .ssh_url')
                is_archived=$(echo "$repo" | jq -r '.isArchived // .archived // false')
                ;;
            forgejo)
                repo_name=$(echo "$repo" | jq -r '.name')
                clone_url=$(echo "$repo" | jq -r '.clone_url // .http_url')
                ssh_url=$(echo "$repo" | jq -r '.ssh_url // .git_url')
                is_archived=$(echo "$repo" | jq -r '.archived // false')
                ;;
            gitea)
                repo_name=$(echo "$repo" | jq -r '.name')
                clone_url=$(echo "$repo" | jq -r '.clone_url // .http_url')
                ssh_url=$(echo "$repo" | jq -r '.ssh_url // .git_url')
                is_archived=$(echo "$repo" | jq -r '.archived // false')
                ;;
        esac
        
        # Skip archived repositories unless explicitly requested
        if [[ "$include_archived" != true ]] && [[ "$is_archived" == "true" ]]; then
            if [[ "$verbose" == true ]]; then
                echo -e "${ORANGE}Repository $repo_name is archived. Skipping...${NC}"
            fi
            continue
        fi

        # Skip if we couldn't get a valid repository name
        if [[ -z "$repo_name" ]] || [[ "$repo_name" == "null" ]]; then
            echo -e "${ORANGE}Skipping repository with invalid name${NC}"
            ((invalid_count++))
            continue
        fi
        
        # Skip if directory already exists
        if [ -d "$repo_name" ]; then
            if [[ "$verbose" == true ]]; then
                echo -e "${ORANGE}Repository $repo_name already exists. Skipping...${NC}"
            fi
            ((skipped_existing++))
            continue
        fi
        
        # Debug output for verbose mode
        if [[ "$verbose" == true ]]; then
            echo -e "${BLUE}Processing: $repo_name${NC}"
            echo -e "${BLUE}  Clone URL: $clone_url${NC}"
            echo -e "${BLUE}  SSH URL: $ssh_url${NC}"
        fi
        
        # Store repository info
        repo_names+=("$repo_name")
        clone_urls+=("$clone_url")
        
        # Handle SSH URL construction if missing
        if [[ -z "$ssh_url" ]] || [[ "$ssh_url" == "null" ]]; then
            case "$platform" in
                github)
                    ssh_url="git@github.com:$username/$repo_name.git"
                    ;;
                forgejo)
                    ssh_url="git@$server_url:$username/$repo_name.git"
                    ;;
                gitea)
                    ssh_url="git@$gitea_server:$username/$repo_name.git"
                    ;;
            esac
        fi
        ssh_urls+=("$ssh_url")
        ((processed_count++))
        
    done < <(echo "$repos_json" | jq -c '.[]')
    
    # Summary statistics
    if [[ "$verbose" == true ]]; then
        echo -e "\n${BLUE}Repository Processing Summary:${NC}"
        echo -e "${GREEN}  Successfully parsed: $processed_count${NC}"
        echo -e "${YELLOW}  Skipped (existing): $skipped_existing${NC}"
        echo -e "${RED}  Invalid (skipped): $invalid_count${NC}"
    fi
    
    if [ $processed_count -eq 0 ]; then
        echo -e "\n${YELLOW}No new repositories to clone.${NC}"
        echo -e "${BLUE}This could be because:${NC}"
        echo -e "  - All repositories already exist locally"
        echo -e "  - Authentication permissions prevent access to repositories"
        echo -e "  - No valid repositories found"
        cd - >/dev/null 2>&1
        return 0
    fi
    
    echo -e "\n${GREEN}Ready to clone $processed_count repositories${NC}"
    
    local total_repos=${#repo_names[@]}
    local successful_clones=0
    local failed_clones=0
    
    if [ "$total_repos" -eq 0 ]; then
        echo -e "${ORANGE}No repositories to clone.${NC}"
        cd - > /dev/null
        return 0
    fi
    
    echo -e "${GREEN}Found $total_repos repositories to clone${NC}"
    
    # Clone repositories
    if [[ "$parallel_cloning" == true ]] && [ "$total_repos" -gt 1 ]; then
        echo -e "${BLUE}Using parallel cloning (max concurrent: $max_concurrent)${NC}"
        # Set global variables for helper functions (bash function limitation)
        CLONE_REPO_NAMES=("${repo_names[@]}")
        CLONE_CLONE_URLS=("${clone_urls[@]}")
        CLONE_SSH_URLS=("${ssh_urls[@]}")
        CLONE_MAX_CONCURRENT="$max_concurrent"
        clone_repositories_parallel
    else
        echo -e "${BLUE}Using sequential cloning${NC}"
        # Set global variables for helper functions (bash function limitation)
        CLONE_REPO_NAMES=("${repo_names[@]}")
        CLONE_CLONE_URLS=("${clone_urls[@]}")
        CLONE_SSH_URLS=("${ssh_urls[@]}")
        clone_repositories_sequential
    fi
    
    # Summary
    echo -e "\n${BLUE}Cloning Summary:${NC}"
    echo -e "Total Repositories: ${total_repos}"
    echo -e "${GREEN}Successfully Cloned: ${successful_clones}${NC}"
    echo -e "${RED}Failed to Clone: ${failed_clones}${NC}"
    
    cd - > /dev/null
}

# Helper function for sequential repository cloning
clone_repositories_sequential() {
    for i in "${!CLONE_REPO_NAMES[@]}"; do
        local repo_name="${CLONE_REPO_NAMES[i]}"
        local clone_url="${CLONE_CLONE_URLS[i]}"
        local ssh_url="${CLONE_SSH_URLS[i]}"
        
        echo -e "${PURPLE}Cloning ${repo_name}...${NC}"
        
        if git clone "$clone_url" "$repo_name" 2>/dev/null; then
            ((successful_clones++))
            echo -e "${GREEN}✅ Cloned ${repo_name}${NC}"
            
            # Set SSH URL for future operations
            (cd "$repo_name" && git remote set-url origin "$ssh_url" 2>/dev/null)
        else
            ((failed_clones++))
            echo -e "${RED}❌ Failed to clone ${repo_name}${NC}"
        fi
    done
    
    # Clean up global variables
    unset CLONE_REPO_NAMES CLONE_CLONE_URLS CLONE_SSH_URLS
}

# Helper function for parallel repository cloning
clone_repositories_parallel() {
    local max_concurrent="${CLONE_MAX_CONCURRENT:-5}"
    local current_concurrent=0
    local pids=()
    
    for i in "${!CLONE_REPO_NAMES[@]}"; do
        local repo_name="${CLONE_REPO_NAMES[i]}"
        local clone_url="${CLONE_CLONE_URLS[i]}"
        local ssh_url="${CLONE_SSH_URLS[i]}"
        
        # Wait if we've reached the maximum concurrent processes
        while [ "$current_concurrent" -ge "$max_concurrent" ]; do
            for pid_index in "${!pids[@]}"; do
                if ! kill -0 "${pids[$pid_index]}" 2>/dev/null; then
                    unset "pids[$pid_index]"
                    ((current_concurrent--))
                fi
            done
            pids=("${pids[@]}")  # Reindex array
            sleep 0.1
        done
        
        # Start clone in background
        {
            echo -e "${PURPLE}Cloning ${repo_name}...${NC}"
            
            if git clone "$clone_url" "$repo_name" 2>/dev/null; then
                ((successful_clones++))
                echo -e "${GREEN}✅ Cloned ${repo_name}${NC}"
                
                # Set SSH URL for future operations
                (cd "$repo_name" && git remote set-url origin "$ssh_url" 2>/dev/null)
            else
                ((failed_clones++))
                echo -e "${RED}❌ Failed to clone ${repo_name}${NC}"
            fi
        } &
        
        pids+=("$!")
        ((current_concurrent++))
    done
    
    # Wait for all background processes to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # Clean up global variables
    unset CLONE_REPO_NAMES CLONE_CLONE_URLS CLONE_SSH_URLS CLONE_MAX_CONCURRENT
}

# Function to delete a branch
delete() {
    # If branch name is provided as argument, use it; otherwise ask
    if [ -z "$1" ]; then
        # Show all branches first
        echo -e "${BLUE}Current branches:${NC}"
        git branch -a
        
        echo -e "\n${GREEN}Enter branch name to delete:${NC}"
        read branch_name
    else
        branch_name="$1"
    fi

    # Get the default branch (usually main or master)
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
    
    # If we couldn't get the default branch, ask the user
    if [ -z "$default_branch" ]; then
        echo -e "${GREEN}Enter the name of your main branch (main/master):${NC}"
        read default_branch
        default_branch=${default_branch:-main}
    fi
    
    # Check if the branch exists
    if ! git show-ref --verify --quiet refs/heads/"$branch_name"; then
        echo -e "${RED}Error: Branch '$branch_name' does not exist locally.${NC}"
        return 1
    fi

    # Don't allow deletion of the default branch
    if [ "$branch_name" = "$default_branch" ]; then
        echo -e "${RED}Error: Cannot delete the default branch ($default_branch).${NC}"
        return 1
    fi
    
    # Switch to the default branch first if needed
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$current_branch" = "$branch_name" ]; then
        echo -e "${PURPLE}Switching to $default_branch before deletion...${NC}"
        if ! git checkout "$default_branch"; then
            echo -e "${RED}Failed to switch to $default_branch branch. Branch deletion aborted.${NC}"
            return 1
        fi
    fi

    # Try to delete the branch
    if git branch -d "$branch_name"; then
        echo -e "${PURPLE}Branch deleted locally.${NC}"
        
        echo -e "${GREEN}Push branch deletion to remote? (y/n)${NC}"
        read push_delete

        if [[ $push_delete == "y" ]]; then
            if git push origin :"$branch_name"; then
                echo -e "${PURPLE}Branch deletion pushed to remote.${NC}"
            else
                echo -e "${RED}Failed to delete remote branch. It might not exist or you may not have permission.${NC}"
            fi
        fi
    else
        echo -e "${RED}Failed to delete branch locally.${NC}"
        echo -e "${ORANGE}If the branch has unmerged changes, use -D instead of -d to force deletion.${NC}"
        echo -e "${GREEN}Would you like to force delete the branch? (y/n)${NC}"
        read force_delete
        
        if [[ $force_delete == "y" ]]; then
            if git branch -D "$branch_name"; then
                echo -e "${PURPLE}Branch force deleted locally.${NC}"
                
                echo -e "${GREEN}Push branch deletion to remote? (y/n)${NC}"
                read push_delete

                if [[ $push_delete == "y" ]]; then
                    if git push origin :"$branch_name"; then
                        echo -e "${PURPLE}Branch deletion pushed to remote.${NC}"
                    else
                        echo -e "${RED}Failed to delete remote branch. It might not exist or you may not have permission.${NC}"
                    fi
                fi
            else
                echo -e "${RED}Failed to force delete the branch.${NC}"
            fi
        fi
    fi
}

# Function to detect platform based on remote URL
detect_platform() {
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ $remote_url == *"forge.ourworld.tf"* ]] || [[ $remote_url == *"forgejo"* ]]; then
        echo "forgejo"  # Forgejo
    elif [[ $remote_url == *"github.com"* ]]; then
        echo "github"  # GitHub
    elif [[ $remote_url == *"git.ourworld.tf"* ]] || [[ $remote_url == *"gitea"* ]]; then
        echo "gitea"  # Gitea
    else
        echo "github"  # Default to GitHub
    fi
}

# Function to extract repo info from git remote
get_repo_info() {
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [[ -z "$remote_url" ]]; then
        echo -e "${RED}Error: No git remote found${NC}"
        return 1
    fi
    
    local repo_path=""
    if [[ "$remote_url" == *"forge.ourworld.tf"* ]]; then
        repo_path=$(echo "$remote_url" | sed -E 's|.*forge\.ourworld\.tf[:/](.*)(\.git)?|\1|')
    elif [[ "$remote_url" == *"github.com"* ]]; then
        repo_path=$(echo "$remote_url" | sed -E 's|.*github\.com[:/](.*)(\.git)?|\1|')
    elif [[ "$remote_url" == *"git.ourworld.tf"* ]]; then
        repo_path=$(echo "$remote_url" | sed -E 's|.*git\.ourworld\.tf[:/](.*)(\.git)?|\1|')
    fi
    
    local owner=$(echo "$repo_path" | cut -d'/' -f1)
    local repo=$(echo "$repo_path" | cut -d'/' -f2)
    
    echo "$owner/$repo"
    return 0
}

# Function to get the latest PR number regardless of platform
get_latest_pr_number() {
    local platform_choice=$(detect_platform)
    
    if [ "$platform_choice" = "forgejo" ]; then
        # Forgejo - use API
        local remote_url=$(git remote get-url origin)
        local server_url=""
        local repo_path=""
        
        # Check ssh:// first since it also contains "git@"
        if [[ $remote_url == ssh://* ]]; then
            server_url=$(echo "$remote_url" | sed -E 's|ssh://git@([^/]+)/.*|\1|')
            repo_path=$(echo "$remote_url" | sed -E 's|ssh://git@[^/]+/||; s|\.git$||')
        elif [[ $remote_url == *"git@"* ]]; then
            server_url=$(echo "$remote_url" | sed -E 's/git@([^:]+):.*/\1/')
            repo_path=$(echo "$remote_url" | sed 's/.*://; s/\.git$//')
        elif [[ $remote_url == *"https://"* ]]; then
            server_url=$(echo "$remote_url" | sed -E 's|https://([^/]+)/.*|\1|')
            repo_path=$(echo "$remote_url" | sed 's|https://[^/]*/||; s/\.git$//')
        fi
        
        [ -z "$server_url" ] && server_url="forge.ourworld.tf"
        local target_org=$(echo "$repo_path" | cut -d'/' -f1)
        local target_repo=$(echo "$repo_path" | cut -d'/' -f2)
        
        local auth_token=$(get_cached_token "forgejo" "$server_url")
        if [ -n "$auth_token" ]; then
            curl -s -H "Authorization: token $auth_token" \
                "https://$server_url/api/v1/repos/$target_org/$target_repo/pulls?state=open&limit=1" \
                | jq -r '.[0].number // empty' 2>/dev/null
        fi
    elif [ "$platform_choice" = "gitea" ]; then
        # Gitea - use tea
        tea pr list --output simple 2>/dev/null | head -n 1 | awk '{print $1}' | sed 's/#//'
    else
        # GitHub - use gh
        gh pr list --json number --jq '.[0].number' 2>/dev/null
    fi
}

# Function to handle pull request operations
pr() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Please specify an action (create/close/merge)${NC}"
        echo -e "Usage: gits pr <create|close|merge> [options]"
        echo -e "  create --title 'Title' --base main --head feature --body 'Description' [--platform forgejo|gitea|github]"
        echo -e "  merge --pr-number 123 [--platform forgejo|gitea|github]"
        return 1
    fi

    local action="$1"
    shift
    
    # Parse platform option or auto-detect
    local platform_choice=""
    local args=("$@")
    
    for i in "${!args[@]}"; do
        if [[ "${args[i]}" == "--platform" ]]; then
            local platform_val="${args[i+1]}"
            if [[ "$platform_val" == "forgejo" ]]; then
                platform_choice="forgejo"
            elif [[ "$platform_val" == "gitea" ]]; then
                platform_choice="gitea"
            elif [[ "$platform_val" == "github" ]]; then
                platform_choice="github"
            fi
            # Remove platform args from array
            unset 'args[i]' 'args[i+1]'
            break
        fi
    done
    
    # Auto-detect platform if not specified
    if [ -z "$platform_choice" ]; then
        platform_choice=$(detect_platform)
    fi
    
    case "$action" in
        create)
            pr_create "$platform_choice" "${args[@]}"
            ;;
        close)
            pr_close "$platform_choice" "${args[@]}"
            ;;
        merge)
            pr_merge "$platform_choice" "${args[@]}"
            ;;
        *)
            echo -e "${RED}Invalid action. Use create, close, or merge${NC}"
            return 1
            ;;
    esac
}

# Function to create a pull request
pr_create() {
    local platform_choice=$1
    shift
    
    # Parse arguments
    local title="" base="main" head="" description="" target_org="" target_repo="" interactive=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --title)
                title="$2"
                interactive=false
                shift 2
                ;;
            --base)
                base="$2"
                shift 2
                ;;
            --head)
                head="$2"
                interactive=false
                shift 2
                ;;
            --body|--description)
                description="$2"
                shift 2
                ;;
            --repo)
                if [[ "$2" == *"/"* ]]; then
                    target_org=$(echo "$2" | cut -d'/' -f1)
                    target_repo=$(echo "$2" | cut -d'/' -f2)
                else
                    target_repo="$2"
                fi
                shift 2
                ;;
            --org)
                target_org="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                return 1
                ;;
        esac
    done

    if [ "$platform_choice" = "forgejo" ]; then
        # Forgejo PR creation using API directly
        local remote_url=$(git remote get-url origin)
        local server_url=""
        local repo_path=""
        
        # Extract server and repo path from remote URL
        # Check ssh:// first since it also contains "git@"
        if [[ $remote_url == ssh://* ]]; then
            server_url=$(echo "$remote_url" | sed -E 's|ssh://git@([^/]+)/.*|\1|')
            repo_path=$(echo "$remote_url" | sed -E 's|ssh://git@[^/]+/||; s|\.git$||')
        elif [[ $remote_url == *"git@"* ]]; then
            server_url=$(echo "$remote_url" | sed -E 's/git@([^:]+):.*/\1/')
            repo_path=$(echo "$remote_url" | sed 's/.*://; s/\.git$//')
        elif [[ $remote_url == *"https://"* ]]; then
            server_url=$(echo "$remote_url" | sed -E 's|https://([^/]+)/.*|\1|')
            repo_path=$(echo "$remote_url" | sed 's|https://[^/]*/||; s/\.git$//')
        fi
        
        if [ -z "$server_url" ]; then
            server_url="forge.ourworld.tf"
        fi
        
        target_org=$(echo "$repo_path" | cut -d'/' -f1)
        target_repo=$(echo "$repo_path" | cut -d'/' -f2)
        
        if [ "$interactive" = "true" ]; then
            echo -e "${GREEN}Enter Pull Request title:${NC}"
            read title

            echo -e "${GREEN}Enter base branch (default: main):${NC}"
            read base
            base=${base:-main}

            echo -e "${GREEN}Enter head branch (default: current branch):${NC}"
            read head
            [ -z "$head" ] && head=$(git branch --show-current 2>/dev/null)

            echo -e "${GREEN}Enter PR description (optional):${NC}"
            read description
        else
            # Validate required parameters for non-interactive mode
            if [ -z "$title" ]; then
                echo -e "${RED}Error: --title is required for non-interactive mode${NC}"
                return 1
            fi
            
            # Auto-detect current branch if --head not provided
            if [ -z "$head" ]; then
                head=$(git branch --show-current 2>/dev/null)
                if [ -z "$head" ]; then
                    echo -e "${RED}Error: Could not detect current branch. Please specify --head${NC}"
                    return 1
                fi
            fi
        fi
        
        # Get cached token
        local auth_token=$(get_cached_token "forgejo" "$server_url")
        if [ -z "$auth_token" ]; then
            echo -e "${RED}Error: No cached token for $server_url. Run 'gits login' first.${NC}"
            return 1
        fi
        
        echo -e "\n${PURPLE}Creating Pull Request on $server_url...${NC}"
        echo -e "${BLUE}Repository: $target_org/$target_repo${NC}"
        echo -e "${BLUE}Base: $base <- Head: $head${NC}"
        
        # Create PR using Forgejo API
        local api_url="https://$server_url/api/v1/repos/$target_org/$target_repo/pulls"
        local pr_data=$(jq -n \
            --arg title "$title" \
            --arg body "${description:-}" \
            --arg head "$head" \
            --arg base "$base" \
            '{title: $title, body: $body, head: $head, base: $base}')
        
        local response=$(curl -s -X POST \
            -H "Authorization: token $auth_token" \
            -H "Content-Type: application/json" \
            -d "$pr_data" \
            "$api_url")
        
        # Check response
        if echo "$response" | jq -e '.number' &>/dev/null; then
            local pr_number=$(echo "$response" | jq -r '.number')
            local pr_url=$(echo "$response" | jq -r '.html_url')
            echo -e "${GREEN}Successfully created PR #$pr_number${NC}"
            echo -e "${BLUE}URL: $pr_url${NC}"
        else
            local error_msg=$(echo "$response" | jq -r '.message // "Unknown error"')
            echo -e "${RED}Failed to create PR: $error_msg${NC}"
            return 1
        fi
    elif [ "$platform_choice" = "gitea" ]; then
        # Gitea PR creation using tea CLI
        if [ "$interactive" = "true" ]; then
            # Show current PRs
            echo -e "${BLUE}Current Pull Requests:${NC}"
            tea pr list

            # Get the full repository path from git remote
            remote_url=$(git remote get-url origin)
            echo -e "Remote URL: $remote_url"

            echo -e "${GREEN}Enter target organization or username:${NC}"
            read target_org

            echo -e "${GREEN}Enter target repository name:${NC}"
            read target_repo

            echo -e "${GREEN}Enter Pull Request title:${NC}"
            read title

            echo -e "${GREEN}Enter base branch (default: main):${NC}"
            read base
            base=${base:-main}

            echo -e "${GREEN}Enter head branch:${NC}"
            read head

            echo -e "${GREEN}Enter PR description (optional):${NC}"
            read description
        else
            # Validate required parameters for non-interactive mode
            if [ -z "$title" ]; then
                echo -e "${RED}Error: --title is required for non-interactive mode${NC}"
                return 1
            fi
            
            # Auto-detect current branch if --head not provided
            if [ -z "$head" ]; then
                head=$(git branch --show-current 2>/dev/null)
                if [ -z "$head" ]; then
                    echo -e "${RED}Error: Could not detect current branch. Please specify --head${NC}"
                    return 1
                fi
            fi
            
            # Auto-detect repo if not provided
            if [ -z "$target_org" ] || [ -z "$target_repo" ]; then
                local remote_url=$(git remote get-url origin)
                local repo_path=""
                
                if [[ $remote_url == *"git@"* ]]; then
                    # SSH URL format: git@host:org/repo.git
                    repo_path=$(echo "$remote_url" | sed 's/.*://; s/\.git$//')
                elif [[ $remote_url == *"https://"* ]]; then
                    # HTTPS URL format: https://host/org/repo.git
                    repo_path=$(echo "$remote_url" | sed 's|https://[^/]*/||; s/\.git$//')
                fi
                
                if [ -n "$repo_path" ] && [[ $repo_path == *"/"* ]]; then
                    target_org=$(echo "$repo_path" | cut -d'/' -f1)
                    target_repo=$(echo "$repo_path" | cut -d'/' -f2)
                fi
            fi
        fi

        # Construct the full repository path
        local full_repo="${target_org}/${target_repo}"
        echo -e "\n${PURPLE}Creating Pull Request to ${full_repo}...${NC}"
        
        # For Gitea, check if we're creating PR in the same repo
        local current_repo_path=""
        local remote_url=$(git remote get-url origin)
        if [[ $remote_url == *"git@"* ]]; then
            current_repo_path=$(echo "$remote_url" | sed 's/.*://; s/\.git$//')
        elif [[ $remote_url == *"https://"* ]]; then
            current_repo_path=$(echo "$remote_url" | sed 's|https://[^/]*/||; s/\.git$//')
        fi
        
        # If creating PR in same repo, use simple branch names
        if [ "$current_repo_path" = "$full_repo" ]; then
            if [ -n "$description" ]; then
                tea pr create \
                    --title "$title" \
                    --base "$base" \
                    --head "$head" \
                    --description "$description"
            else
                tea pr create \
                    --title "$title" \
                    --base "$base" \
                    --head "$head"
            fi
        else
            # Cross-repo PR, use full repo specification
            if [ -n "$description" ]; then
                tea pr create \
                    --repo "$full_repo" \
                    --title "$title" \
                    --base "$base" \
                    --head "$head" \
                    --description "$description"
            else
                tea pr create \
                    --repo "$full_repo" \
                    --title "$title" \
                    --base "$base" \
                    --head "$head"
            fi
        fi
    else
        # GitHub PR creation
        if [ "$interactive" = "true" ]; then
            echo -e "${BLUE}Current Pull Requests:${NC}"
            gh pr list

            echo -e "${GREEN}Enter Pull Request title:${NC}"
            read title

            echo -e "${GREEN}Enter base branch (default: main):${NC}"
            read base
            base=${base:-main}

            echo -e "${GREEN}Enter head branch:${NC}"
            read head

            echo -e "${GREEN}Enter PR description:${NC}"
            read description
        else
            # Validate required parameters for non-interactive mode
            if [ -z "$title" ]; then
                echo -e "${RED}Error: --title is required for non-interactive mode${NC}"
                return 1
            fi
            
            # Auto-detect current branch if --head not provided
            if [ -z "$head" ]; then
                head=$(git branch --show-current 2>/dev/null)
                if [ -z "$head" ]; then
                    echo -e "${RED}Error: Could not detect current branch. Please specify --head${NC}"
                    return 1
                fi
            fi
        fi

        echo -e "\n${PURPLE}Creating Pull Request...${NC}"
        gh pr create --base "$base" --head "$head" --title "$title" --body "$description"
    fi
}

# Function to close a pull request
pr_close() {
    local platform_choice=$1

    if [ "$platform_choice" = "forgejo" ]; then
        # Forgejo PR close using API
        local remote_url=$(git remote get-url origin)
        local server_url=""
        local repo_path=""
        
        # Extract server and repo path from remote URL
        # Check ssh:// first since it also contains "git@"
        if [[ $remote_url == ssh://* ]]; then
            server_url=$(echo "$remote_url" | sed -E 's|ssh://git@([^/]+)/.*|\1|')
            repo_path=$(echo "$remote_url" | sed -E 's|ssh://git@[^/]+/||; s|\.git$||')
        elif [[ $remote_url == *"git@"* ]]; then
            server_url=$(echo "$remote_url" | sed -E 's/git@([^:]+):.*/\1/')
            repo_path=$(echo "$remote_url" | sed 's/.*://; s/\.git$//')
        elif [[ $remote_url == *"https://"* ]]; then
            server_url=$(echo "$remote_url" | sed -E 's|https://([^/]+)/.*|\1|')
            repo_path=$(echo "$remote_url" | sed 's|https://[^/]*/||; s/\.git$//')
        fi
        
        [ -z "$server_url" ] && server_url="forge.ourworld.tf"
        local target_org=$(echo "$repo_path" | cut -d'/' -f1)
        local target_repo=$(echo "$repo_path" | cut -d'/' -f2)
        
        # Get cached token
        local auth_token=$(get_cached_token "forgejo" "$server_url")
        if [ -z "$auth_token" ]; then
            echo -e "${RED}Error: No cached token for $server_url. Run 'gits login' first.${NC}"
            return 1
        fi
        
        # List open PRs
        echo -e "${BLUE}Open Pull Requests:${NC}"
        local prs=$(curl -s -H "Authorization: token $auth_token" \
            "https://$server_url/api/v1/repos/$target_org/$target_repo/pulls?state=open")
        echo "$prs" | jq -r '.[] | "#\(.number) - \(.title) (\(.user.login))"' 2>/dev/null || echo "No open PRs"
        
        echo -e "\n${GREEN}Enter PR number to close:${NC}"
        read pr_number

        echo -e "\n${PURPLE}Closing Pull Request #$pr_number...${NC}"
        
        # Close PR using API (update state to closed)
        local response=$(curl -s -X PATCH \
            -H "Authorization: token $auth_token" \
            -H "Content-Type: application/json" \
            -d '{"state": "closed"}' \
            "https://$server_url/api/v1/repos/$target_org/$target_repo/pulls/$pr_number")
        
        if echo "$response" | jq -e '.number' &>/dev/null; then
            echo -e "${GREEN}Successfully closed PR #$pr_number${NC}"
        else
            local error_msg=$(echo "$response" | jq -r '.message // "Unknown error"')
            echo -e "${RED}Failed to close PR: $error_msg${NC}"
            return 1
        fi
    elif [ "$platform_choice" = "gitea" ]; then
        # Gitea PR close using tea CLI
        echo -e "${BLUE}Current Pull Requests:${NC}"
        tea pr

        echo -e "\n${GREEN}Enter repository (organization/repository):${NC}"
        read repo

        echo -e "${GREEN}Enter PR number to close:${NC}"
        read pr_number

        echo -e "\n${PURPLE}Closing Pull Request #$pr_number...${NC}"
        tea pr close "$pr_number" --repo "$repo"
    else
        # GitHub PR close
        echo -e "${BLUE}Current Pull Requests:${NC}"
        gh pr list

        echo -e "${GREEN}Enter PR number to close:${NC}"
        read pr_number

        echo -e "\n${PURPLE}Closing Pull Request #$pr_number...${NC}"
        gh pr close "$pr_number"
    fi
}

# Function to merge a pull request
pr_merge() {
    local platform_choice=$1
    shift
    
    # Parse arguments
    local pr_number="" repo="" merge_title="" merge_message="" delete_branch="" branch_name="" interactive=true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --pr-number|--number)
                pr_number="$2"
                interactive=false
                shift 2
                ;;
            --repo)
                repo="$2"
                shift 2
                ;;
            --title)
                merge_title="$2"
                shift 2
                ;;
            --message)
                merge_message="$2"
                shift 2
                ;;
            --delete-branch|-d)
                delete_branch="y"
                shift
                ;;
            --branch-name)
                branch_name="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                return 1
                ;;
        esac
    done

    if [ "$platform_choice" = "forgejo" ]; then
        # Forgejo PR merge using API
        local remote_url=$(git remote get-url origin)
        local server_url=""
        local repo_path=""
        
        # Extract server and repo path from remote URL
        # Check ssh:// first since it also contains "git@"
        if [[ $remote_url == ssh://* ]]; then
            server_url=$(echo "$remote_url" | sed -E 's|ssh://git@([^/]+)/.*|\1|')
            repo_path=$(echo "$remote_url" | sed -E 's|ssh://git@[^/]+/||; s|\.git$||')
        elif [[ $remote_url == *"git@"* ]]; then
            server_url=$(echo "$remote_url" | sed -E 's/git@([^:]+):.*/\1/')
            repo_path=$(echo "$remote_url" | sed 's/.*://; s/\.git$//')
        elif [[ $remote_url == *"https://"* ]]; then
            server_url=$(echo "$remote_url" | sed -E 's|https://([^/]+)/.*|\1|')
            repo_path=$(echo "$remote_url" | sed 's|https://[^/]*/||; s/\.git$//')
        fi
        
        [ -z "$server_url" ] && server_url="forge.ourworld.tf"
        local target_org=$(echo "$repo_path" | cut -d'/' -f1)
        local target_repo=$(echo "$repo_path" | cut -d'/' -f2)
        
        # Get cached token
        local auth_token=$(get_cached_token "forgejo" "$server_url")
        if [ -z "$auth_token" ]; then
            echo -e "${RED}Error: No cached token for $server_url. Run 'gits login' first.${NC}"
            return 1
        fi
        
        if [ "$interactive" = "true" ]; then
            # List open PRs
            echo -e "${BLUE}Open Pull Requests:${NC}"
            local prs=$(curl -s -H "Authorization: token $auth_token" \
                "https://$server_url/api/v1/repos/$target_org/$target_repo/pulls?state=open")
            echo "$prs" | jq -r '.[] | "#\(.number) - \(.title) (\(.head.ref) -> \(.base.ref))"' 2>/dev/null || echo "No open PRs"

            echo -e "\n${GREEN}Enter PR number to merge:${NC}"
            read pr_number
        else
            # Validate required parameters for non-interactive mode
            if [ -z "$pr_number" ]; then
                echo -e "${RED}Error: --pr-number is required for non-interactive mode${NC}"
                return 1
            fi
        fi

        echo -e "\n${PURPLE}Merging Pull Request #$pr_number...${NC}"
        
        # Get PR details first to know the branch name
        local pr_details=$(curl -s -H "Authorization: token $auth_token" \
            "https://$server_url/api/v1/repos/$target_org/$target_repo/pulls/$pr_number")
        local head_branch=$(echo "$pr_details" | jq -r '.head.ref')
        
        # Merge PR using API
        local merge_data=$(jq -n \
            --arg style "merge" \
            '{Do: $style, delete_branch_after_merge: true}')
        
        local response=$(curl -s -X POST \
            -H "Authorization: token $auth_token" \
            -H "Content-Type: application/json" \
            -d "$merge_data" \
            "https://$server_url/api/v1/repos/$target_org/$target_repo/pulls/$pr_number/merge")
        
        # Check if merge was successful (empty response means success for this endpoint)
        if [ -z "$response" ] || echo "$response" | jq -e 'has("sha")' &>/dev/null 2>&1; then
            echo -e "${GREEN}Successfully merged PR #$pr_number${NC}"
            
            # Handle local branch deletion
            if [ "$interactive" = "true" ] && [ -z "$delete_branch" ]; then
                echo -e "\n${GREEN}Would you like to delete the branch locally? (y/n)${NC}"
                read delete_branch
            fi

            if [[ $delete_branch == "y" ]]; then
                branch_name="${branch_name:-$head_branch}"
                if [ -n "$branch_name" ]; then
                    # Get the default branch
                    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
                    [ -z "$default_branch" ] && default_branch="main"
                    
                    # Switch to the default branch first
                    if git checkout "$default_branch" 2>/dev/null; then
                        git pull
                        if git branch -d "$branch_name" 2>/dev/null; then
                            echo -e "${PURPLE}Branch '$branch_name' deleted locally.${NC}"
                        else
                            echo -e "${ORANGE}Branch '$branch_name' not found locally or has unmerged changes.${NC}"
                        fi
                    fi
                fi
            fi
        else
            local error_msg=$(echo "$response" | jq -r '.message // "Unknown error"')
            echo -e "${RED}Failed to merge PR: $error_msg${NC}"
            return 1
        fi
    elif [ "$platform_choice" = "gitea" ]; then
        # Gitea PR merge using tea CLI
        if [ "$interactive" = "true" ]; then
            # Show current PRs
            echo -e "${BLUE}Current Pull Requests:${NC}"
            tea pr

            echo -e "\n${GREEN}Enter repository (organization/repository):${NC}"
            read repo

            echo -e "${GREEN}Enter PR number to merge:${NC}"
            read pr_number

            echo -e "${GREEN}Enter merge commit title:${NC}"
            read merge_title

            echo -e "${GREEN}Enter merge commit message:${NC}"
            read merge_message
        else
            # Validate required parameters for non-interactive mode
            if [ -z "$pr_number" ]; then
                echo -e "${RED}Error: --pr-number is required for non-interactive mode${NC}"
                return 1
            fi
            
            # Auto-detect repo if not provided
            if [ -z "$repo" ]; then
                local remote_url=$(git remote get-url origin)
                local repo_path=""
                
                if [[ $remote_url == *"git@"* ]]; then
                    # SSH URL format: git@host:org/repo.git
                    repo_path=$(echo "$remote_url" | sed 's/.*://; s/\.git$//')
                elif [[ $remote_url == *"https://"* ]]; then
                    # HTTPS URL format: https://host/org/repo.git
                    repo_path=$(echo "$remote_url" | sed 's|https://[^/]*/||; s/\.git$//')
                fi
                
                if [ -n "$repo_path" ] && [[ $repo_path == *"/"* ]]; then
                    repo="$repo_path"
                fi
            fi
            
            # Set default merge title/message if not provided
            if [ -z "$merge_title" ]; then
                merge_title="Merge PR #$pr_number"
            fi
            if [ -z "$merge_message" ]; then
                merge_message="Merged via gits script"
            fi
        fi

        echo -e "\n${PURPLE}Merging Pull Request #$pr_number...${NC}"
        tea pr merge --repo "$repo" --title "$merge_title" --message "$merge_message" "$pr_number"

        # Branch deletion option only for Gitea
        if [ "$interactive" = "true" ] && [ -z "$delete_branch" ]; then
            echo -e "\n${GREEN}Would you like to delete the branch locally? (y/n)${NC}"
            read delete_branch
        fi

        if [[ $delete_branch == "y" ]]; then
            if [ "$interactive" = "true" ] && [ -z "$branch_name" ]; then
                echo -e "${GREEN}Enter branch name to delete:${NC}"
                read branch_name
            fi
            
            if [ -n "$branch_name" ]; then
                # Get the default branch (usually main or master)
                default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
                
                # If we couldn't get the default branch, use main as default
                if [ -z "$default_branch" ]; then
                    default_branch="main"
                fi
                
                # Switch to the default branch first
                if git checkout "$default_branch"; then
                    if git branch -d "$branch_name"; then
                        echo -e "${PURPLE}Branch deleted locally.${NC}"
                        
                        if [ "$interactive" = "true" ]; then
                            echo -e "${GREEN}Push branch deletion to remote? (y/n)${NC}"
                            read push_delete
                        else
                            push_delete="y"  # Auto-push in non-interactive mode
                        fi

                        if [[ $push_delete == "y" ]]; then
                            git push origin :"$branch_name"
                            echo -e "${PURPLE}Branch deletion pushed to remote.${NC}"
                        fi
                    else
                        echo -e "${RED}Failed to delete branch locally.${NC}"
                    fi
                else
                    echo -e "${RED}Failed to switch to $default_branch branch. Branch deletion aborted.${NC}"
                fi
            fi
        fi
    else
        # GitHub PR merge
        if [ "$interactive" = "true" ]; then
            # Show current PRs
            echo -e "${BLUE}Current Pull Requests:${NC}"
            gh pr list

            echo -e "${GREEN}Enter PR number to merge:${NC}"
            read pr_number
        else
            # Validate required parameters for non-interactive mode
            if [ -z "$pr_number" ]; then
                echo -e "${RED}Error: --pr-number is required for non-interactive mode${NC}"
                return 1
            fi
        fi

        echo -e "\n${PURPLE}Merging Pull Request #$pr_number...${NC}"
        gh pr merge "$pr_number"
        echo -e "${PURPLE}Note: GitHub automatically handles branch deletion during PR merge.${NC}"
    fi
}

# Function to perform git pull operations
pull() {
    local branch=${1:-development}
    git checkout "$branch" && git stash && git fetch && git pull && git status
}

# Function to perform git push operations
push() {
    local branch=""
    local commit_message=""
    local use_pal=false
    local use_pal_yolo=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p)
                use_pal=true
                shift
                ;;
            -py)
                use_pal_yolo=true
                shift
                ;;
            *)
                # First non-flag argument is the branch
                if [ -z "$branch" ]; then
                    branch="$1"
                    shift
                    # Remaining arguments form the commit message
                    if [ $# -gt 0 ]; then
                        commit_message="$*"
                        break
                    fi
                else
                    # This is part of commit message
                    if [ -z "$commit_message" ]; then
                        commit_message="$1"
                    else
                        commit_message="$commit_message $1"
                    fi
                    shift
                fi
                ;;
        esac
    done

    # If branch was provided, checkout to it
    if [ ! -z "$branch" ]; then
        if ! git checkout "$branch"; then
            echo -e "${RED}Failed to checkout branch: $branch${NC}"
            return 1
        fi
    fi

    # Handle commit based on flags
    if [ "$use_pal_yolo" = true ]; then
        echo -e "${BLUE}Using pal /commit -y for AI-generated commit message (auto-commit)${NC}"
        if ! command -v pal &> /dev/null; then
            echo -e "${RED}Error: pal command not found. Please install pal to use -py flag.${NC}"
            return 1
        fi
        if ! pal /commit -y; then
            echo -e "${RED}Failed to commit using pal /commit -y${NC}"
            return 1
        fi
    elif [ "$use_pal" = true ]; then
        echo -e "${BLUE}Using pal /commit for AI-generated commit message${NC}"
        if ! command -v pal &> /dev/null; then
            echo -e "${RED}Error: pal command not found. Please install pal to use -p flag.${NC}"
            return 1
        fi
        if ! pal /commit; then
            echo -e "${RED}Failed to commit using pal /commit${NC}"
            return 1
        fi
    else
        # Traditional commit flow
        git add .

        # If no commit message was provided in arguments, prompt for it
        if [ -z "$commit_message" ]; then
            echo "Enter commit message:"
            read commit_message
        fi

        git commit -m "$commit_message"
    fi

    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if git config --get branch."$current_branch".merge &>/dev/null; then
        echo -e "${GREEN}Pushing changes to existing upstream branch${NC}"
        git push
    else
        echo -e "${ORANGE}No upstream branch set. Setting upstream to origin/$current_branch${NC}"
        git push --set-upstream origin "$current_branch"
    fi
}

# Function to perform git commit operation
commit() {
    echo "Enter commit message:"
    read commit_message
    git commit -m "$commit_message"
}

# Function to perform quick up operation (add, pal commit, push)
up() {
    echo -e "${BLUE}Running quick up: git add . && pal /commit -y && git push${NC}"
    
    # Check if pal is available
    if ! command -v pal &> /dev/null; then
        echo -e "${RED}Error: pal command not found. Please install pal to use the up command.${NC}"
        return 1
    fi
    
    # Stage all changes
    git add .
    
    # Commit using pal with auto-confirm
    if ! pal /commit -y; then
        echo -e "${RED}Failed to commit using pal /commit -y${NC}"
        return 1
    fi
    
    # Push changes
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if git config --get branch."$current_branch".merge &>/dev/null; then
        echo -e "${GREEN}Pushing changes to existing upstream branch${NC}"
        git push
    else
        echo -e "${ORANGE}No upstream branch set. Setting upstream to origin/$current_branch${NC}"
        git push --set-upstream origin "$current_branch"
    fi
}

# Function to handle repository operations
repo() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Please specify an action (create/delete)${NC}"
        echo -e "Usage: gits repo <create|delete>"
        return 1
    fi

    case "$1" in
        create)
            repo_create
            ;;
        delete)
            repo_delete
            ;;
        *)
            echo -e "${RED}Invalid action. Use create or delete${NC}"
            return 1
            ;;
    esac
}

# Function to create a repository
repo_create() {
    echo -e "${GREEN}Which platform would you like to use?${NC}"
    echo -e "1) Gitea"
    echo -e "2) GitHub"
    read -p "Enter your choice (1/2): " platform_choice

    echo -e "${GREEN}Enter repository name:${NC}"
    read repo_name

    echo -e "${GREEN}Enter repository description:${NC}"
    read description

    echo -e "${GREEN}Make repository private? (y/n):${NC}"
    read is_private

    case "$platform_choice" in
        1)
            visibility=""
            if [[ $is_private == "y" ]]; then
                visibility="--private"
            else
                visibility="--public"
            fi

            echo -e "\n${PURPLE}Creating repository on Gitea...${NC}"
            if tea repo create --name "$repo_name" --description "$description" $visibility; then
                echo -e "${GREEN}Repository created successfully on Gitea!${NC}"
            else
                echo -e "${RED}Failed to create repository on Gitea.${NC}"
            fi
            ;;
        2)
            visibility=""
            if [[ $is_private == "y" ]]; then
                visibility="--private"
            else
                visibility="--public"
            fi

            echo -e "\n${PURPLE}Creating repository on GitHub...${NC}"
            if gh repo create "$repo_name" --description "$description" $visibility --confirm; then
                echo -e "${GREEN}Repository created successfully on GitHub!${NC}"
            else
                echo -e "${RED}Failed to create repository on GitHub.${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
            return 1
            ;;
    esac
}

# Function to delete a repository
repo_delete() {
    echo -e "${GREEN}Which platform would you like to use?${NC}"
    echo -e "1) Gitea"
    echo -e "2) GitHub"
    read -p "Enter your choice (1/2): " platform_choice

    case "$platform_choice" in
        1)
            echo -e "${GREEN}Enter repository (organization/repository):${NC}"
            read repo_name

            echo -e "${RED}WARNING: This action cannot be undone!${NC}"
            echo -e "${GREEN}Are you sure you want to delete $repo_name? (y/n):${NC}"
            read confirm

            if [[ $confirm == "y" ]]; then
                echo -e "\n${PURPLE}Deleting repository from Gitea...${NC}"
                if tea repo delete "$repo_name" --confirm; then
                    echo -e "${GREEN}Repository deleted successfully from Gitea!${NC}"
                else
                    echo -e "${RED}Failed to delete repository from Gitea.${NC}"
                fi
            fi
            ;;
        2)
            echo -e "${GREEN}Enter repository name:${NC}"
            read repo_name

            echo -e "${RED}WARNING: This action cannot be undone!${NC}"
            echo -e "${GREEN}Are you sure you want to delete $repo_name? (y/n):${NC}"
            read confirm

            if [[ $confirm == "y" ]]; then
                echo -e "\n${PURPLE}Deleting repository from GitHub...${NC}"
                if gh repo delete "$repo_name" --confirm; then
                    echo -e "${GREEN}Repository deleted successfully from GitHub!${NC}"
                else
                    echo -e "${RED}Failed to delete repository from GitHub.${NC}"
                fi
            fi
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
            return 1
            ;;
    esac
}

# Function to initialize a new Git repository and push to GitHub or Gitea
init() {
    echo -e "${GREEN}Which platform would you like to use?${NC}"
    echo -e "1) Gitea (git.ourworld.tf)"
    echo -e "2) GitHub (github.com)"
    read -p "Enter your choice (1/2): " platform_choice

    # Set platform-specific variables
    case "$platform_choice" in
        1)
            git_url="https://git.ourworld.tf"
            initial_branch="development"
            platform="Gitea"
            ;;
        2)
            git_url="https://github.com"
            initial_branch="main"
            platform="GitHub"
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
            return 1
            ;;
    esac

    echo -e "${GREEN}Initializing new Git repository...${NC}"
    
    echo -e "Enter your $platform username:"
    read username
    echo -e "Enter the repository name:"
    read repo_name

    echo -e "${GREEN}Make sure to create a repository on $platform with the proper username (${username}) and repository (${repo_name})${NC}"
    echo -e "Press Enter when you're ready to continue..."
    read

    git init

    echo -e "${GREEN}Setting initial branch as '${initial_branch}'. Press ENTER to continue or type 'replace' to change the branch name:${NC}"
    read branch_choice

    if [[ $branch_choice == "replace" ]]; then
        echo -e "Enter the new branch name:"
        read new_branch_name
        initial_branch=$new_branch_name
    fi

    git checkout -b $initial_branch
    git add .

    echo "Enter initial commit message:"
    read commit_message
    git commit -m "$commit_message"

    git remote add origin "$git_url/$username/$repo_name.git"
    git push -u origin $initial_branch

    echo -e "${PURPLE}Repository initialized and pushed to $platform successfully.${NC}"
    echo -e "Branch: ${BLUE}$initial_branch${NC}"
}

# Function to initialize multiple repositories at once
init-list() {
    echo -e "${GREEN}Which platform would you like to use?${NC}"
    echo -e "1) Gitea (git.ourworld.tf)"
    echo -e "2) GitHub (github.com)"
    read -p "Enter your choice (1/2): " platform_choice

    # Set platform-specific variables
    case "$platform_choice" in
        1)
            git_url="https://git.ourworld.tf"
            initial_branch="development"
            platform="Gitea"
            ;;
        2)
            git_url="https://github.com"
            initial_branch="main"
            platform="GitHub"
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
            return 1
            ;;
    esac

    echo -e "Enter your $platform username:"
    read username

    if [ -z "$username" ]; then
        echo -e "${RED}Error: Username cannot be empty.${NC}"
        return 1
    fi

    echo -e "${GREEN}Enter the list of repository names (one per line, end with an empty line):${NC}"
    echo -e "${BLUE}You can now type or paste the list. Press Enter twice to finish.${NC}"
    
    # Create a parent directory for all repositories
    parent_dir="$username-repos"
    mkdir -p "$parent_dir"
    cd "$parent_dir" || return 1
    
    # Read the list of repository names
    local successful_inits=0
    local failed_inits=0
    local total_repos=0
    
    while IFS= read -r repo_name; do
        # Break the loop if an empty line is entered
        if [ -z "$repo_name" ]; then
            break
        fi
        
        # Clean the repo name
        repo_name=$(echo "$repo_name" | sed 's/^[[:space:]]*-[[:space:]]*//; s/^[[:space:]]*//; s/[[:space:]]*$//')
        
        ((total_repos++))
        
        echo -e "\n${BLUE}═══════════════════════════════════════════${NC}"
        echo -e "${BLUE}Processing: $repo_name${NC}"
        
        # Skip if repository directory already exists
        if [ -d "$repo_name" ]; then
            echo -e "${ORANGE}Repository $repo_name already exists. Skipping...${NC}"
            continue
        fi
        
        # Create directory for the repository
        mkdir -p "$repo_name"
        cd "$repo_name" || continue
        
        echo -e "${GREEN}Initializing new Git repository for $repo_name...${NC}"
        
        # Make sure to create a repository on the platform first
        echo -e "${GREEN}Make sure to create a repository on $platform with the proper username (${username}) and repository (${repo_name})${NC}"
        echo -e "Press Enter when you're ready to continue..."
        read
        
        # Initialize git repository
        if git init; then
            echo -e "${GREEN}Setting initial branch as '${initial_branch}'...${NC}"
            git checkout -b $initial_branch
            
            # Create a README.md file if it doesn't exist
            if [ ! -f "README.md" ]; then
                echo "# $repo_name" > README.md
                echo "Repository created with GitS init-list" >> README.md
            fi
            
            git add .
            
            # Commit with a standard message
            commit_message="Initial commit from GitS init-list"
            git commit -m "$commit_message"
            
            # Set remote origin
            git remote add origin "$git_url/$username/$repo_name.git"
            
            # Push to remote
            if git push -u origin $initial_branch; then
                ((successful_inits++))
                echo -e "${GREEN}Repository $repo_name initialized and pushed to $platform successfully.${NC}"
                echo -e "Branch: ${BLUE}$initial_branch${NC}"
            else
                ((failed_inits++))
                echo -e "${RED}Failed to push repository $repo_name to $platform.${NC}"
            fi
        else
            ((failed_inits++))
            echo -e "${RED}Failed to initialize repository $repo_name.${NC}"
        fi
        
        # Return to parent directory
        cd ..
    done
    
    # Display summary
    echo -e "\n${BLUE}Initialization Summary:${NC}"
    echo -e "Total Repositories: ${total_repos}"
    echo -e "${GREEN}Successfully Initialized: ${successful_inits}${NC}"
    echo -e "${RED}Failed to Initialize: ${failed_inits}${NC}"
    
    # Return to original directory
    cd - > /dev/null
}

# Function to create a new branch
new() {
    if [ -z "$1" ]; then
        echo -e "Enter the name of the new branch:"
        read branch_name
    else
        branch_name="$1"
    fi
    git checkout -b "$branch_name"
    echo -e "${PURPLE}New branch '${branch_name}' created and checked out.${NC}"
}

# Function to revert a specified number of commits
revert() {
    if [ -z "$1" ] || ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Please provide a valid number of commits to revert.${NC}"
        echo -e "Usage: gits revert <number>"
        return 1
    fi

    num_commits=$1
    commit_to_revert="HEAD~$((num_commits-1))"

    echo -e "${GREEN}Reverting to $num_commits commit(s) ago...${NC}"
    
    if git revert --no-commit "$commit_to_revert"; then
        echo -e "${PURPLE}Changes have been staged. Review the changes and commit when ready.${NC}"
        echo -e "Use ${BLUE}git status${NC} to see the changes."
        echo -e "Use ${BLUE}git commit -m 'Revert message'${NC} to commit the revert."
    else
        echo -e "${RED}Error occurred while reverting. Please resolve conflicts if any.${NC}"
    fi
}

# Function to cancel the last revert
unrevert() {
    echo -e "${GREEN}Cancelling the last revert...${NC}"
    if git reset --hard HEAD; then
        echo -e "${PURPLE}Last revert has been cancelled successfully.${NC}"
    else
        echo -e "${RED}Error occurred while cancelling the revert. Please check your Git status.${NC}"
    fi
}

# Function to handle login
login() {
    echo -e "${GREEN}Which platform would you like to login to?${NC}"
    echo -e "1) Forgejo (forge.ourworld.tf or custom)"
    echo -e "2) Gitea (git.ourworld.tf)"
    echo -e "3) GitHub"
    read -p "Enter your choice (1/2/3): " platform_choice

    case "$platform_choice" in
        1)
            # Forgejo login - token-based authentication
            echo -e "${PURPLE}Logging into Forgejo...${NC}"
            
            echo -e "${GREEN}Enter Forgejo server URL (default: forge.ourworld.tf):${NC}"
            read -r forgejo_server
            [ -z "$forgejo_server" ] && forgejo_server="forge.ourworld.tf"
            
            # Remove protocol if provided
            forgejo_server=$(echo "$forgejo_server" | sed -E 's|^https?://||' | sed 's|/$||')
            
            # Check for existing token
            local existing_token=$(get_cached_token "forgejo" "$forgejo_server")
            if [ -n "$existing_token" ]; then
                echo -e "${ORANGE}A token for $forgejo_server already exists.${NC}"
                echo -e "${GREEN}What would you like to do?${NC}"
                echo -e "1) Replace with a new token"
                echo -e "2) Keep existing token"
                read -p "Enter your choice (1/2): " token_choice
                
                if [[ "$token_choice" != "1" ]]; then
                    echo -e "${GREEN}Keeping existing token for $forgejo_server${NC}"
                    return 0
                fi
            fi
            
            echo -e ""
            echo -e "${BLUE}To generate an API token:${NC}"
            echo -e "  1. Go to https://$forgejo_server/user/settings/applications"
            echo -e "  2. Under 'Manage Access Tokens', enter a token name"
            echo -e "  3. Select scopes: 'repo' (for repository access)"
            echo -e "  4. Click 'Generate Token' and copy it"
            echo -e ""
            
            echo -e "${GREEN}Enter your Forgejo API token:${NC}"
            read -s forgejo_token
            echo
            
            if [ -z "$forgejo_token" ]; then
                echo -e "${RED}Error: Token cannot be empty.${NC}"
                return 1
            fi
            
            # Validate token by making a test API call
            echo -e "${BLUE}Validating token...${NC}"
            local test_response=$(curl -s -H "Authorization: token $forgejo_token" "https://$forgejo_server/api/v1/user" 2>/dev/null)
            
            if echo "$test_response" | jq -e '.login' &>/dev/null; then
                local username=$(echo "$test_response" | jq -r '.login')
                save_token "forgejo" "$forgejo_server" "$forgejo_token"
                echo -e "${GREEN}Successfully logged into Forgejo as '$username' on $forgejo_server${NC}"
                echo -e "${GREEN}Token saved to $(get_gits_config_dir)/tokens.conf${NC}"
            else
                echo -e "${RED}Failed to validate token. Please check your token and try again.${NC}"
                if echo "$test_response" | jq -e '.message' &>/dev/null; then
                    echo -e "${ORANGE}Error: $(echo "$test_response" | jq -r '.message')${NC}"
                fi
                return 1
            fi
            ;;
        2)
            # Check if tea CLI is available
            if ! command -v tea &> /dev/null; then
                echo -e "${RED}Error: tea CLI is required but not installed.${NC}"
                return 1
            fi
            
            echo -e "${PURPLE}Preparing to login to Gitea...${NC}"
            
            # Check for existing logins
            echo -e "${BLUE}Checking for existing Gitea logins...${NC}"
            logins_output=$(tea login list 2>/dev/null)
            
            if [ -n "$logins_output" ] && echo "$logins_output" | grep -q "Login"; then
                echo -e "${GREEN}Existing Gitea logins found:${NC}"
                echo "$logins_output"
                
                # Ask for the desired login name
                echo -e "${GREEN}Enter the login name you want to use:${NC}"
                read desired_login
                
                if [ -z "$desired_login" ]; then
                    echo -e "${RED}Error: Login name cannot be empty.${NC}"
                    return 1
                fi
                
                # Check if this login name already exists
                if echo "$logins_output" | grep -q "$desired_login"; then
                    echo -e "${ORANGE}A login with the name '$desired_login' already exists.${NC}"
                    echo -e "${GREEN}What would you like to do?${NC}"
                    echo -e "1) Remove the existing login and create a new one"
                    echo -e "2) Use a different login name"
                    echo -e "3) Cancel login process"
                    read -p "Enter your choice (1/2/3): " conflict_choice
                    
                    case "$conflict_choice" in
                        1)
                            echo -e "${PURPLE}Removing existing login '$desired_login'...${NC}"
                            if tea logout "$desired_login"; then
                                echo -e "${GREEN}Successfully removed existing login.${NC}"
                                echo -e "${PURPLE}Now you can create a new login with the same name.${NC}"
                                echo -e "${PURPLE}Please proceed with the interactive login process...${NC}"
                                
                                if tea login add; then
                                    echo -e "${GREEN}Successfully created new Gitea login.${NC}"
                                else
                                    echo -e "${RED}Failed to create new Gitea login.${NC}"
                                fi
                            else
                                echo -e "${RED}Failed to remove existing login. Login process aborted.${NC}"
                                return 1
                            fi
                            ;;
                        2)
                            echo -e "${PURPLE}Please proceed with the interactive login process...${NC}"
                            echo -e "${ORANGE}When prompted for a login name, use a different name than '$desired_login'.${NC}"
                            
                            if tea login add; then
                                echo -e "${GREEN}Successfully created new Gitea login.${NC}"
                            else
                                echo -e "${RED}Failed to create new Gitea login.${NC}"
                            fi
                            ;;
                        3)
                            echo -e "${ORANGE}Login process cancelled.${NC}"
                            return 0
                            ;;
                        *)
                            echo -e "${RED}Invalid choice. Login process aborted.${NC}"
                            return 1
                            ;;
                    esac
                else
                    # Login name doesn't exist, proceed with normal login
                    echo -e "${PURPLE}Please proceed with the interactive login process...${NC}"
                    echo -e "${ORANGE}When prompted for a login name, enter '$desired_login'.${NC}"
                    
                    if tea login add; then
                        echo -e "${GREEN}Successfully created new Gitea login.${NC}"
                    else
                        echo -e "${RED}Failed to create new Gitea login.${NC}"
                    fi
                fi
            else
                # No existing logins, proceed with normal login
                echo -e "${GREEN}No existing Gitea logins found. Creating a new login...${NC}"
                echo -e "${PURPLE}Please proceed with the interactive login process...${NC}"
                
                if tea login add; then
                    echo -e "${GREEN}Successfully created new Gitea login.${NC}"
                else
                    echo -e "${RED}Failed to create new Gitea login.${NC}"
                fi
            fi
            ;;
        3)
            echo -e "${PURPLE}Logging into GitHub...${NC}"
            if gh auth login; then
                echo -e "${GREEN}Successfully logged into GitHub.${NC}"
            else
                echo -e "${RED}Failed to login to GitHub.${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Forgejo, 2 for Gitea, or 3 for GitHub.${NC}"
            return 1
            ;;
    esac
}

# Function to handle logout
logout() {
    echo -e "${GREEN}Which platform would you like to logout from?${NC}"
    echo -e "1) Forgejo (forge.ourworld.tf or custom)"
    echo -e "2) Gitea (git.ourworld.tf)"
    echo -e "3) GitHub"
    read -p "Enter your choice (1/2/3): " platform_choice

    case "$platform_choice" in
        1)
            # Forgejo logout - clear cached token
            echo -e "${PURPLE}Logging out from Forgejo...${NC}"
            
            echo -e "${GREEN}Enter Forgejo server URL (default: forge.ourworld.tf):${NC}"
            read -r forgejo_server
            [ -z "$forgejo_server" ] && forgejo_server="forge.ourworld.tf"
            
            # Remove protocol if provided
            forgejo_server=$(echo "$forgejo_server" | sed -E 's|^https?://||' | sed 's|/$||')
            
            # Check if token exists
            local existing_token=$(get_cached_token "forgejo" "$forgejo_server")
            if [ -z "$existing_token" ]; then
                echo -e "${ORANGE}No token found for $forgejo_server. You are not logged in.${NC}"
                return 1
            fi
            
            clear_cached_token "forgejo" "$forgejo_server"
            echo -e "${GREEN}Successfully logged out from Forgejo ($forgejo_server).${NC}"
            ;;
        2)
            # Check if tea CLI is available
            if ! command -v tea &> /dev/null; then
                echo -e "${RED}Error: tea CLI is required but not installed.${NC}"
                return 1
            fi
            
            # List available logins
            echo -e "${BLUE}Checking available Gitea logins...${NC}"
            logins_output=$(tea login list 2>/dev/null)
            
            if [ -z "$logins_output" ] || ! echo "$logins_output" | grep -q "Login"; then
                echo -e "${RED}No Gitea logins found. You are not logged in.${NC}"
                return 1
            fi
            
            echo -e "${GREEN}Available Gitea logins:${NC}"
            echo "$logins_output"
            
            echo -e "${GREEN}Enter the login name to logout from:${NC}"
            read login_name
            
            if [ -z "$login_name" ]; then
                echo -e "${RED}Error: Login name cannot be empty.${NC}"
                return 1
            fi
            
            echo -e "${PURPLE}Logging out from Gitea login: $login_name...${NC}"
            if tea logout "$login_name"; then
                echo -e "${GREEN}Successfully logged out from Gitea login: $login_name.${NC}"
            else
                echo -e "${RED}Failed to logout from Gitea.${NC}"
            fi
            ;;
        3)
            echo -e "${PURPLE}Logging out from GitHub...${NC}"
            if gh auth logout; then
                echo -e "${GREEN}Successfully logged out from GitHub.${NC}"
            else
                echo -e "${RED}Failed to logout from GitHub.${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Forgejo, 2 for Gitea, or 3 for GitHub.${NC}"
            return 1
            ;;
    esac
}

# Function to install the script
install() {
    echo
    echo -e "${GREEN}Installing GitS...${NC}"
    if sudo -v; then
        sudo cp "$0" /usr/local/bin/gits
        sudo chown root:root /usr/local/bin/gits
        sudo chmod 755 /usr/local/bin/gits

        echo
        echo -e "${PURPLE}GitS has been installed successfully.${NC}"
        echo -e "You can now use ${GREEN}gits${NC} command from anywhere."
        echo
        echo -e "Use ${BLUE}gits help${NC} to see the commands."
        echo
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Installation aborted.${NC}"
        exit 1
    fi
}

# Function to uninstall the script
uninstall() {
    echo
    echo -e "${GREEN}Uninstalling GitS...${NC}"
    if sudo -v; then
        sudo rm -f /usr/local/bin/gits
        echo -e "${PURPLE}GitS has been uninstalled successfully.${NC}"
        echo
    else
        echo -e "${RED}Error: Failed to obtain sudo privileges. Uninstallation aborted.${NC}"
        exit 1
    fi
}

clone-list() {
    echo -e "${GREEN}Enter the list of repositories (one per line, end with an empty line):${NC}"
    echo -e "${BLUE}Supported formats:${NC}"
    echo -e "- https://github.com/org/repo"
    echo -e "- github.com/org/repo"
    echo -e "- https://git.ourworld.tf/org/repo"
    echo -e "- git.ourworld.tf/org/repo\n"
    
    # Ask for credentials upfront
    echo -e "${GREEN}Do you need to provide credentials? (y/N):${NC}"
    read -r need_auth
    
    if [[ $need_auth =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Enter username:${NC}"
        read -r git_username
        echo -e "${GREEN}Enter password/token:${NC}"
        read -rs git_password
        echo -e "\n${GREEN}Password accepted.${NC}"  # Add confirmation message
        echo
        
        # Store credentials temporarily
        export GIT_USERNAME="$git_username"
        export GIT_PASSWORD="$git_password"
    fi

    # Prompt the user to paste the list of repositories
    echo -e "${GREEN}Please paste the list of repositories (one per line, end with an empty line):${NC}"
    echo -e "${BLUE}You can now paste the list. Press Enter twice to finish.${NC}"
    
    # Read the list of repositories
    while IFS= read -r line; do
        # Break the loop if an empty line is entered
        if [ -z "$line" ]; then
            break
        fi
        
        # Clean the line
        line=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//; s/^[[:space:]]*//; s/[[:space:]]*$//')
        
        # Extract URL pattern
        if [[ $line =~ (https?://)?([a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]+)/([a-zA-Z0-9_-]+)/([a-zA-Z0-9_-]+) ]]; then
            domain="${BASH_REMATCH[2]}"
            org="${BASH_REMATCH[3]}"
            repo="${BASH_REMATCH[4]}"
            
            # Construct URL with credentials if provided
            if [[ $need_auth =~ ^[Yy]$ ]]; then
                url="https://$GIT_USERNAME:$GIT_PASSWORD@$domain/$org/$repo"
            else
                if [[ $line =~ ^https?:// ]]; then
                    url=$(echo "$line" | cut -d' ' -f1)
                else
                    url="https://$domain/$org/$repo"
                fi
            fi
            
            target_dir="code/$domain/$org/$repo"
            
            echo -e "\n${BLUE}═══════════════════════════════════════════${NC}"
            echo -e "${BLUE}Processing: $org/$repo${NC}"
            echo -e "${BLUE}Target: $target_dir${NC}"
            
            if [ -d "$target_dir" ]; then
                echo -e "${ORANGE}Repository exists, pulling updates...${NC}"
                (cd "$target_dir" && {
                    if [[ $need_auth =~ ^[Yy]$ ]]; then
                        git remote set-url origin "$url"
                    fi
                    git fetch
                    git pull
                    if [[ $need_auth =~ ^[Yy]$ ]]; then
                        ssh_url="git@$domain:$org/$repo.git"
                        git remote set-url origin "$ssh_url"
                    fi
                })
            else
                echo -e "${PURPLE}Cloning repository...${NC}"
                mkdir -p "$(dirname "$target_dir")"
                if git clone "$url" "$target_dir"; then
                    echo -e "${GREEN}Successfully cloned${NC}"
                    (cd "$target_dir" && {
                        ssh_url="git@$domain:$org/$repo.git"
                        echo -e "${PURPLE}Setting SSH URL: $ssh_url${NC}"
                        git remote set-url origin "$ssh_url"
                    })
                else
                    echo -e "${RED}Failed to clone${NC}"
                fi
            fi
        else
            echo -e "${RED}Invalid repository format: $line${NC}"
        fi
    done

    # Clean up
    if [[ $need_auth =~ ^[Yy]$ ]]; then
        unset GIT_USERNAME
        unset GIT_PASSWORD
    fi

    echo -e "\n${GREEN}Clone list operation completed${NC}"
}

# Function to fetch issues from the current repository
fetch-issues() {
    local state="open"
    local format="display"
    local repo_info=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --state)
                state="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --help|-h)
                echo -e "${GREEN}Usage: gits fetch-issues [OPTIONS]${NC}"
                echo -e "${BLUE}Fetch issues from the current repository${NC}"
                echo -e ""
                echo -e "${PURPLE}Options:${NC}"
                echo -e "  --state STATE    Filter by state: open, closed, all (default: open)"
                echo -e "  --format FORMAT  Output format: display, json (default: display)"
                echo -e "  -h, --help       Show this help message"
                echo -e ""
                echo -e "${BLUE}Examples:${NC}"
                echo -e "  gits fetch-issues                    # Fetch open issues (display format)"
                echo -e "  gits fetch-issues --state all        # Fetch all issues"
                echo -e "  gits fetch-issues --format json      # Fetch issues in JSON format"
                echo -e "  gits fetch-issues --state closed     # Fetch closed issues"
                return 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}"
                echo -e "Use 'gits fetch-issues --help' for usage information."
                return 1
                ;;
        esac
    done
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Not in a git repository${NC}"
        return 1
    fi
    
    # Get repository info
    if ! repo_info=$(get_repo_info); then
        echo -e "${RED}Error: Could not determine repository information${NC}"
        return 1
    fi
    
    # Detect platform
    local platform=$(detect_platform)
    if [[ -z "$platform" ]]; then
        echo -e "${RED}Error: Could not detect platform from git remote${NC}"
        echo -e "${ORANGE}Supported platforms: Forgejo, Gitea, GitHub${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Fetching $state issues for repository: $repo_info${NC}"
    echo -e "${BLUE}Platform: $([ "$platform" = "forgejo" ] && echo "Forgejo" || ([ "$platform" = "gitea" ] && echo "Gitea" || echo "GitHub"))${NC}"
    echo -e ""
    
    local issues_json=""
    
    case "$platform" in
        "forgejo")
            # Extract Forgejo server info
            local remote_url=$(git remote get-url origin 2>/dev/null)
            local forgejo_server=""
            
            if [[ "$remote_url" == *"forge.ourworld.tf"* ]]; then
                forgejo_server="forge.ourworld.tf"
            else
                # Try to extract server from URL
                forgejo_server=$(echo "$remote_url" | sed -E 's|.*@([^:/]+)[:/].*|\1|' | sed -E 's|https?://([^/]+)/.*|\1|')
            fi
            
            # Check for authentication with token caching
            local auth_header=""
            
            # Check for cached token first
            local cached_token=$(get_cached_token "forgejo" "$forgejo_server")
            
            if [ -n "$cached_token" ]; then
                if [[ "$GITS_ISSUES_NONINTERACTIVE" == "1" ]]; then
                    auth_header="Authorization: token $cached_token"
                    echo -e "${BLUE}Using cached token for $forgejo_server (non-interactive)${NC}"
                else
                    echo -e "${GREEN}Found cached authentication token for $forgejo_server${NC}"
                    echo -e "${GREEN}Use cached token? (y/n):${NC}"
                    read -r use_cached
                    
                    if [[ $use_cached =~ ^[Yy]$ ]]; then
                        auth_header="Authorization: token $cached_token"
                        echo -e "${BLUE}Using cached token${NC}"
                    fi
                fi
            fi
            
            # If no cached token or user declined, prompt for authentication (interactive mode only)
            if [ -z "$auth_header" ] && [[ "$GITS_ISSUES_NONINTERACTIVE" != "1" ]]; then
                echo -e "${GREEN}Do you want to access private issues? (y/n):${NC}"
                read -r use_auth
                
                if [[ $use_auth =~ ^[Yy]$ ]]; then
                    echo -e "${GREEN}Enter your Forgejo API token:${NC}"
                    echo -e "${BLUE}Generate one at: https://$forgejo_server/user/settings/applications${NC}"
                    read -s API_TOKEN
                    echo
                    
                    if [ -n "$API_TOKEN" ]; then
                        auth_header="Authorization: token $API_TOKEN"
                        save_token "forgejo" "$forgejo_server" "$API_TOKEN"
                        echo -e "${GREEN}Token saved for future use${NC}"
                    else
                        echo -e "${RED}No token provided. Falling back to public access only.${NC}"
                    fi
                fi
            fi
            
            echo -e "${PURPLE}Fetching issues from Forgejo...${NC}"
            
            # Extract owner and repo from repo_info
            local owner=$(echo "$repo_info" | cut -d'/' -f1)
            local repo=$(echo "$repo_info" | cut -d'/' -f2)
            
            # Construct API endpoint
            local base_url="https://$forgejo_server"
            local api_endpoint="$base_url/api/v1/repos/$owner/$repo/issues"
            
            # Add state filter
            if [[ "$state" != "all" ]]; then
                api_endpoint="$api_endpoint?state=$state"
            fi
            
            # Fetch issues
            if [ -n "$auth_header" ]; then
                issues_json=$(curl -s -H "$auth_header" "$api_endpoint")
            else
                issues_json=$(curl -s "$api_endpoint")
            fi
            
            # Check if we got valid JSON
            if ! echo "$issues_json" | jq . &>/dev/null; then
                echo -e "${RED}Error: Failed to get valid JSON response from Forgejo API${NC}"
                echo -e "${ORANGE}Response: $issues_json${NC}"
                return 1
            fi
            ;;
        "1"|"gitea")
            # Extract Gitea server info
            local remote_url=$(git remote get-url origin 2>/dev/null)
            local gitea_server=""
            local gitea_token=""
            
            if [[ "$remote_url" == *"git.ourworld.tf"* ]]; then
                gitea_server="git.ourworld.tf"
            else
                echo -e "${RED}Error: Could not determine Gitea server${NC}"
                return 1
            fi
            
            # Check for authentication with token caching
            local auth_header=""
            local gitea_token=""
            
            # Check for cached token first
            local cached_token=$(get_cached_gitea_token "$gitea_server")
            
            if [ -n "$cached_token" ]; then
                if [[ "$GITS_ISSUES_NONINTERACTIVE" == "1" ]]; then
                    auth_header="Authorization: token $cached_token"
                    echo -e "${BLUE}Using cached token for $gitea_server (non-interactive)${NC}"
                else
                    echo -e "${GREEN}Found cached authentication token for $gitea_server${NC}"
                    echo -e "${GREEN}Use cached token? (y/n):${NC}"
                    read -r use_cached
                    
                    if [[ $use_cached =~ ^[Yy]$ ]]; then
                        auth_header="Authorization: token $cached_token"
                        echo -e "${BLUE}Using cached token${NC}"
                    fi
                fi
            fi
            
            # If no cached token or user declined, prompt for authentication (interactive mode only)
            if [ -z "$auth_header" ] && [[ "$GITS_ISSUES_NONINTERACTIVE" != "1" ]]; then
                echo -e "${GREEN}Do you want to access private issues? (y/n):${NC}"
                read -r use_auth
                
                if [[ $use_auth =~ ^[Yy]$ ]]; then
                    echo -e "${GREEN}Choose authentication method:${NC}"
                    echo -e "1) Use existing Gitea login (via tea CLI)"
                    echo -e "2) Provide an API token (will be cached for future use)"
                    read -p "Enter your choice (1/2): " auth_choice
                    
                    case "$auth_choice" in
                        1)
                            # Check if tea CLI is available
                            if ! command -v tea &> /dev/null; then
                                echo -e "${RED}Error: tea CLI is required but not installed. Please install tea CLI or use option 2.${NC}"
                                return 1
                            fi
                            
                            # Try to get token from tea using improved method
                            gitea_token=$(get_tea_token "$gitea_server")
                            if [ -n "$gitea_token" ]; then
                                auth_header="Authorization: token $gitea_token"
                                # Cache the tea token for future use
                                save_gitea_token "$gitea_server" "$gitea_token"
                                echo -e "${GREEN}Retrieved and cached token from tea CLI${NC}"
                            else
                                echo -e "${RED}Could not retrieve token from tea configuration.${NC}"
                                echo -e "${ORANGE}Please try option 2 (API token) or run 'gits login' first.${NC}"
                                return 1
                            fi
                            ;;
                        2)
                            echo -e "${GREEN}Enter your Gitea API token:${NC}"
                            read -s API_TOKEN
                            echo
                            
                            if [ -n "$API_TOKEN" ]; then
                                auth_header="Authorization: token $API_TOKEN"
                                # Cache the token
                                save_gitea_token "$gitea_server" "$API_TOKEN"
                                echo -e "${GREEN}Token saved for future use${NC}"
                            else
                                echo -e "${RED}No token provided. Falling back to public access only.${NC}"
                            fi
                            ;;
                        *)
                            echo -e "${RED}Invalid choice. Falling back to public access only.${NC}"
                            ;;
                    esac
                fi
            fi
            
            echo -e "${PURPLE}Fetching issues from Gitea...${NC}"
            
            # Extract owner and repo from repo_info
            local owner=$(echo "$repo_info" | cut -d'/' -f1)
            local repo=$(echo "$repo_info" | cut -d'/' -f2)
            
            # Construct API endpoint
            local base_url="https://$gitea_server"
            local api_endpoint="$base_url/api/v1/repos/$owner/$repo/issues"
            
            # Add state filter
            if [[ "$state" != "all" ]]; then
                api_endpoint="$api_endpoint?state=$state"
            fi
            
            # Fetch issues
            if [ -n "$auth_header" ]; then
                issues_json=$(curl -s -H "$auth_header" "$api_endpoint")
            else
                issues_json=$(curl -s "$api_endpoint")
            fi
            
            # Check if we got valid JSON
            if ! echo "$issues_json" | jq . &>/dev/null; then
                echo -e "${RED}Error: Failed to get valid JSON response from Gitea API${NC}"
                echo -e "${ORANGE}Response: $issues_json${NC}"
                return 1
            fi
            ;;
        "2"|"github"|*)
            # Check if gh is available
            if ! command -v gh &> /dev/null; then
                echo -e "${RED}Error: GitHub CLI (gh) is required but not installed${NC}"
                return 1
            fi
            
            echo -e "${PURPLE}Fetching issues from GitHub...${NC}"
            if [[ "$format" == "json" ]]; then
                issues_json=$(gh issue list --state "$state" --json number,title,body,state,author,assignees,labels,createdAt,updatedAt,url --jq '.')
            else
                issues_json=$(gh issue list --state "$state" --limit 50)
            fi
            ;;
    esac
    
    # Display results
    if [[ "$format" == "json" ]]; then
        echo "$issues_json" | jq '.'
    else
        echo "$issues_json"
    fi
    
    echo -e "\n${GREEN}Issues fetched successfully${NC}"
}
fetch-issues-all() {
    local state="open"
    local format="display"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --state)
                state="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --help|-h)
                echo -e "${GREEN}Usage: gits fetch-issues-all [OPTIONS]${NC}"
                echo -e "${BLUE}Fetch issues from all repositories in current directory tree${NC}"
                echo -e ""
                echo -e "${PURPLE}Options:${NC}"
                echo -e "  --state STATE    Filter by state: open, closed, all (default: open)"
                echo -e "  --format FORMAT  Output format: display, json (default: display)"
                echo -e "  -h, --help       Show this help message"
                echo -e ""
                echo -e "${BLUE}Examples:${NC}"
                echo -e "  gits fetch-issues-all"
                echo -e "  gits fetch-issues-all --state all --format json"
                return 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}"
                echo -e "Use 'gits fetch-issues-all --help' for usage information."
                return 1
                ;;
        esac
    done
    
    echo -e "${GREEN}Fetching issues from all repositories...${NC}"
    echo -e ""
    
    local repos=()
    while IFS= read -r -d '' gitdir; do
        repos+=("$(dirname "$gitdir")")
    done < <(find . -name .git -type d -print0)
    
    if [[ ${#repos[@]} -eq 0 ]]; then
        echo -e "${ORANGE}No git repositories found in current directory.${NC}"
        return 0
    fi
    
    local total_repos=${#repos[@]}
    local success_count=0
    local failed_count=0
    
    for repodir in "${repos[@]}"; do
        echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
        echo -e "${BLUE}📁 Repository: $repodir${NC}"
        echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
        
        if ( cd "$repodir" && GITS_ISSUES_NONINTERACTIVE=1 fetch-issues --state "$state" --format "$format" ); then
            ((success_count++))
        else
            ((failed_count++))
            echo -e "${RED}Failed to fetch issues for $repodir${NC}"
        fi
        
        echo -e ""
    done
    
    echo -e "${PURPLE}Summary:${NC}"
    echo -e "  Total repositories: $total_repos"
    echo -e "  ${GREEN}Successful: $success_count${NC}"
    if [[ "$failed_count" -gt 0 ]]; then
        echo -e "  ${RED}Failed: $failed_count${NC}"
    fi
}

# Function to save issues to files
save-issues() {
    local state="open"
    local format="markdown"
    local output_dir=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --state)
                state="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --help|-h)
                echo -e "${GREEN}Usage: gits save-issues [OPTIONS]${NC}"
                echo -e "${BLUE}Save issues from the current repository to files${NC}"
                echo -e ""
                echo -e "${PURPLE}Options:${NC}"
                echo -e "  --state STATE    Filter by state: open, closed, all (default: open)"
                echo -e "  --format FORMAT  Output format: markdown, json, plain (default: markdown)"
                echo -e "  -h, --help       Show this help message"
                echo -e ""
                echo -e "${BLUE}Output:${NC}"
                echo -e "  Issues are saved to: ./repo-name-issues/"
                echo -e "  Format: repo-name-issues/ISSUE_NUMBER-title.md"
                echo -e ""
                echo -e "${BLUE}Examples:${NC}"
                echo -e "  gits save-issues                     # Save open issues as markdown"
                echo -e "  gits save-issues --state all         # Save all issues"
                echo -e "  gits save-issues --format json       # Save issues in JSON format"
                echo -e "  gits save-issues --state closed      # Save closed issues"
                return 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}"
                echo -e "Use 'gits save-issues --help' for usage information."
                return 1
                ;;
            esac
    done
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}Error: Not in a git repository${NC}"
        return 1
    fi
    
    # Get repository info
    local repo_info=$(get_repo_info)
    if [[ -z "$repo_info" ]]; then
        echo -e "${RED}Error: Could not determine repository information${NC}"
        return 1
    fi
    
    # Normalize repo info (strip optional .git suffix from the repo portion)
    local repo_owner_part=$(echo "$repo_info" | cut -d'/' -f1)
    local repo_name_part=$(echo "$repo_info" | cut -d'/' -f2)
    repo_name_part="${repo_name_part%.git}"
    repo_info="$repo_owner_part/$repo_name_part"

    # Create output directory
    local safe_repo_name=$(echo "$repo_info" | tr '/' '-' | tr '[:upper:]' '[:lower:]')
    output_dir="./${safe_repo_name}-issues"
    mkdir -p "$output_dir"
    
    echo -e "${GREEN}Saving $state issues for repository: $repo_info${NC}"
    echo -e "${BLUE}Output directory: $output_dir${NC}"
    echo -e "${BLUE}Format: $format${NC}"
    echo -e ""
    
    # Get platform info
    local platform=$(detect_platform)
    
    # Fetch issues directly based on platform
    local issues_json=""
    
    case "$platform" in
        "forgejo")
            # Extract Forgejo server info
            local remote_url=$(git remote get-url origin 2>/dev/null)
            local forgejo_server=""
            local owner=$(echo "$repo_info" | cut -d'/' -f1)
            local repo=$(echo "$repo_info" | cut -d'/' -f2)
            repo="${repo%.git}"
            
            if [[ "$remote_url" == *"forge.ourworld.tf"* ]]; then
                forgejo_server="forge.ourworld.tf"
            else
                forgejo_server=$(echo "$remote_url" | sed -E 's|.*@([^:/]+)[:/].*|\1|' | sed -E 's|https?://([^/]+)/.*|\1|')
            fi
            
            # Check for authentication with token caching
            local auth_header=""
            
            # Check for cached token first
            local cached_token=$(get_cached_token "forgejo" "$forgejo_server")
            
            if [ -n "$cached_token" ]; then
                if [[ "$GITS_ISSUES_NONINTERACTIVE" == "1" ]]; then
                    auth_header="Authorization: token $cached_token"
                    echo -e "${BLUE}Using cached token for $forgejo_server (non-interactive)${NC}"
                else
                    echo -e "${GREEN}Found cached authentication token for $forgejo_server${NC}"
                    echo -e "${GREEN}Use cached token? (y/n):${NC}"
                    read -r use_cached
                    
                    if [[ $use_cached =~ ^[Yy]$ ]]; then
                        auth_header="Authorization: token $cached_token"
                        echo -e "${BLUE}Using cached token${NC}"
                    fi
                fi
            fi
            
            # If no cached token or user declined, prompt for authentication (interactive mode only)
            if [ -z "$auth_header" ] && [[ "$GITS_ISSUES_NONINTERACTIVE" != "1" ]]; then
                echo -e "${GREEN}Do you want to access private issues? (y/n):${NC}"
                read -r use_auth
                
                if [[ $use_auth =~ ^[Yy]$ ]]; then
                    echo -e "${GREEN}Enter your Forgejo API token:${NC}"
                    echo -e "${BLUE}Generate one at: https://$forgejo_server/user/settings/applications${NC}"
                    read -s API_TOKEN
                    echo
                    
                    if [ -n "$API_TOKEN" ]; then
                        auth_header="Authorization: token $API_TOKEN"
                        save_token "forgejo" "$forgejo_server" "$API_TOKEN"
                        echo -e "${GREEN}Token saved for future use${NC}"
                    else
                        echo -e "${RED}No token provided. Falling back to public access only.${NC}"
                    fi
                fi
            fi
            
            echo -e "${PURPLE}Fetching issues from Forgejo...${NC}"
            
            # Construct API endpoint
            local base_url="https://$forgejo_server"
            local api_endpoint="$base_url/api/v1/repos/$owner/$repo/issues"
            
            # Add state filter
            if [[ "$state" != "all" ]]; then
                api_endpoint="$api_endpoint?state=$state"
            fi
            
            # Fetch issues
            if [ -n "$auth_header" ]; then
                issues_json=$(curl -s -H "$auth_header" "$api_endpoint")
            else
                issues_json=$(curl -s "$api_endpoint")
            fi
            
            # Check if we got valid JSON
            if ! echo "$issues_json" | jq . &>/dev/null; then
                echo -e "${RED}Error: Failed to get valid JSON response from Forgejo API${NC}"
                echo -e "${ORANGE}Response: $issues_json${NC}"
                return 1
            fi
            ;;
        "1"|"gitea")
            # Extract Gitea server info
            local remote_url=$(git remote get-url origin 2>/dev/null)
            local gitea_server="git.ourworld.tf"
            local owner=$(echo "$repo_info" | cut -d'/' -f1)
            local repo=$(echo "$repo_info" | cut -d'/' -f2)
            repo="${repo%.git}"
            
            # Check for authentication with token caching
            local auth_header=""
            local gitea_token=""
            
            # Check for cached token first
            local cached_token=$(get_cached_gitea_token "$gitea_server")
            
            if [ -n "$cached_token" ]; then
                if [[ "$GITS_ISSUES_NONINTERACTIVE" == "1" ]]; then
                    auth_header="Authorization: token $cached_token"
                    echo -e "${BLUE}Using cached token for $gitea_server (non-interactive)${NC}"
                else
                    echo -e "${GREEN}Found cached authentication token for $gitea_server${NC}"
                    echo -e "${GREEN}Use cached token? (y/n):${NC}"
                    read -r use_cached
                    
                    if [[ $use_cached =~ ^[Yy]$ ]]; then
                        auth_header="Authorization: token $cached_token"
                        echo -e "${BLUE}Using cached token${NC}"
                    fi
                fi
            fi
            
            # If no cached token or user declined, prompt for authentication (interactive mode only)
            if [ -z "$auth_header" ] && [[ "$GITS_ISSUES_NONINTERACTIVE" != "1" ]]; then
                echo -e "${GREEN}Do you want to access private issues? (y/n):${NC}"
                read -r use_auth
                
                if [[ $use_auth =~ ^[Yy]$ ]]; then
                    echo -e "${GREEN}Choose authentication method:${NC}"
                    echo -e "1) Use existing Gitea login (via tea CLI)"
                    echo -e "2) Provide an API token (will be cached for future use)"
                    read -p "Enter your choice (1/2): " auth_choice
                    
                    case "$auth_choice" in
                        1)
                            # Check if tea CLI is available
                            if ! command -v tea &> /dev/null; then
                                echo -e "${RED}Error: tea CLI is required but not installed. Please install tea CLI or use option 2.${NC}"
                                return 1
                            fi
                            
                            # Try to get token from tea using improved method
                            gitea_token=$(get_tea_token "$gitea_server")
                            if [ -n "$gitea_token" ]; then
                                auth_header="Authorization: token $gitea_token"
                                # Cache the tea token for future use
                                save_gitea_token "$gitea_server" "$gitea_token"
                                echo -e "${GREEN}Retrieved and cached token from tea CLI${NC}"
                            else
                                echo -e "${RED}Could not retrieve token from tea configuration.${NC}"
                                echo -e "${ORANGE}Please try option 2 (API token) or run 'gits login' first.${NC}"
                                return 1
                            fi
                            ;;
                        2)
                            echo -e "${GREEN}Enter your Gitea API token:${NC}"
                            read -s API_TOKEN
                            echo
                            
                            if [ -n "$API_TOKEN" ]; then
                                auth_header="Authorization: token $API_TOKEN"
                                # Cache the token
                                save_gitea_token "$gitea_server" "$API_TOKEN"
                                echo -e "${GREEN}Token saved for future use${NC}"
                            else
                                echo -e "${RED}No token provided. Falling back to public access only.${NC}"
                            fi
                            ;;
                        *)
                            echo -e "${RED}Invalid choice. Falling back to public access only.${NC}"
                            ;;
                    esac
                fi
            fi
            
            local base_url="https://$gitea_server"
            local api_endpoint="$base_url/api/v1/repos/$owner/$repo/issues"
            
            # Add state filter
            if [[ "$state" != "all" ]]; then
                api_endpoint="$api_endpoint?state=$state"
            fi
            
            # Fetch issues with or without authentication
            if [ -n "$auth_header" ]; then
                issues_json=$(curl -s -H "$auth_header" "$api_endpoint")
            else
                issues_json=$(curl -s "$api_endpoint")
            fi
            ;;
        "2"|"github"|*)
            # Use gh CLI for GitHub
            if command -v gh &> /dev/null; then
                issues_json=$(gh issue list --state "$state" --json number,title,body,state,author,assignees,labels,createdAt,updatedAt,url --jq '.')
            else
                echo -e "${RED}Error: GitHub CLI (gh) is required but not installed${NC}"
                return 1
            fi
            ;;
    esac
    
    # Check if we got valid JSON
    if ! echo "$issues_json" | jq . &>/dev/null; then
        echo -e "${RED}Error: Failed to get valid JSON response${NC}"
        echo -e "${ORANGE}Response: $issues_json${NC}"
        return 1
    fi

    # Ensure the response is an array of issues (not an error object or other shape)
    if ! echo "$issues_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
        echo -e "${RED}Error: API response is not a list of issues${NC}"
        echo -e "${ORANGE}Response:${NC}"
        echo "$issues_json" | jq '.'
        return 1
    fi
    
    # Process and save issues
    local saved_count=0
    
    while read -r issue; do
        # Skip any non-object items defensively
        if ! echo "$issue" | jq -e 'type == "object"' >/dev/null 2>&1; then
            continue
        fi

        local issue_number=$(echo "$issue" | jq -r '.number // .id')
        local title=$(echo "$issue" | jq -r '.title // ""')
        local body=$(echo "$issue" | jq -r '.body // empty')
        local state=$(echo "$issue" | jq -r '.state // ""')
        local author=$(echo "$issue" | jq -r '.author.login // .user.login // "Unknown"')
        local created_at=$(echo "$issue" | jq -r '.createdAt // .created_at // ""')
        local url=$(echo "$issue" | jq -r '.url // .html_url // ""')
        
        # If we still don't have a usable identifier, skip this entry
        if [[ -z "$issue_number" || "$issue_number" == "null" ]]; then
            continue
        fi

        # Fetch comments for this issue (platform-specific)
        local comments_json=""
        case "$platform" in
            "forgejo"|"gitea")
                # Use Gitea/Forgejo issues comments API
                local comments_endpoint="$base_url/api/v1/repos/$owner/$repo/issues/$issue_number/comments"
                if [ -n "$auth_header" ]; then
                    comments_json=$(curl -s -H "$auth_header" "$comments_endpoint")
                else
                    comments_json=$(curl -s "$comments_endpoint")
                fi
                ;;
            "github"|*)
                # Use gh CLI to get comments for GitHub issues
                if command -v gh &> /dev/null; then
                    comments_json=$(gh issue view "$issue_number" --json comments --jq '.comments' 2>/dev/null)
                fi
                ;;
        esac

        # Validate comments JSON is an array; otherwise ignore
        if ! echo "$comments_json" | jq . >/dev/null 2>&1; then
            comments_json=""
        elif ! echo "$comments_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
            comments_json=""
        fi

        # Create safe filename
        local safe_title=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' | sed 's/-+/-/g' | sed 's/^-//; s/-$//')
        local filename="${issue_number}-${safe_title}.md"
        
        case "$format" in
            markdown)
                # Create markdown file
                cat > "$output_dir/$filename" << EOF
# Issue #$issue_number: $title

**Status:** $state
**Author:** $author
**Created:** $created_at
**URL:** $url

## Description

$body
EOF

                # Append comments section if any
                if [[ -n "$comments_json" ]] && echo "$comments_json" | jq -e 'length > 0' >/dev/null 2>&1; then
                    {
                        echo ""
                        echo "## Comments"
                        echo ""
                        while read -r comment; do
                            if ! echo "$comment" | jq -e 'type == "object"' >/dev/null 2>&1; then
                                continue
                            fi
                            local comment_author
                            local comment_created
                            local comment_body
                            comment_author=$(echo "$comment" | jq -r '.author.login // .user.login // .user.username // .poster.login // .poster.username // "Unknown"')
                            comment_created=$(echo "$comment" | jq -r '.createdAt // .created_at // ""')
                            comment_body=$(echo "$comment" | jq -r '.body // empty')

                            echo "- [$comment_created] $comment_author:"
                            echo ""
                            echo "$comment_body"
                            echo ""
                        done < <(echo "$comments_json" | jq -c '.[]')
                    } >> "$output_dir/$filename"
                fi
                ;;
            json)
                # Save as individual JSON file, including comments if available
                if [[ -n "$comments_json" ]]; then
                    echo "$issue" | jq --argjson comments "$comments_json" '. + {comments: $comments}' > "$output_dir/${issue_number}.json"
                else
                    echo "$issue" | jq '.' > "$output_dir/${issue_number}.json"
                fi
                filename="${issue_number}.json"
                ;;
            plain)
                # Save as plain text
                cat > "$output_dir/$filename" << EOF
Issue #$issue_number: $title
Status: $state
Author: $author
Created: $created_at
URL: $url

$body
EOF

                # Append comments section if any
                if [[ -n "$comments_json" ]] && echo "$comments_json" | jq -e 'length > 0' >/dev/null 2>&1; then
                    {
                        echo ""
                        echo "Comments:"
                        echo ""
                        while read -r comment; do
                            if ! echo "$comment" | jq -e 'type == "object"' >/dev/null 2>&1; then
                                continue
                            fi
                            local comment_author
                            local comment_created
                            local comment_body
                            comment_author=$(echo "$comment" | jq -r '.author.login // .user.login // .user.username // .poster.login // .poster.username // "Unknown"')
                            comment_created=$(echo "$comment" | jq -r '.createdAt // .created_at // ""')
                            comment_body=$(echo "$comment" | jq -r '.body // empty')

                            echo "- [$comment_created] $comment_author:"
                            echo ""
                            echo "$comment_body"
                            echo ""
                        done < <(echo "$comments_json" | jq -c '.[]')
                    } >> "$output_dir/$filename"
                fi
                ;;
        esac
        
        echo -e "${GREEN}Saved: $filename${NC}"
        ((saved_count++))
        
    done < <(echo "$issues_json" | jq -c '.[]')
    
    # Sync functionality: Remove stale files for closed/resolved issues
    echo -e "\n${BLUE}Syncing with repository state...${NC}"
    local removed_count=0
    local current_issues=()
    
    # Collect current issue numbers
    while read -r issue; do
        # Skip non-object entries
        if ! echo "$issue" | jq -e 'type == "object"' >/dev/null 2>&1; then
            continue
        fi

        local num=$(echo "$issue" | jq -r '.number // .id')
        if [[ -n "$num" && "$num" != "null" ]]; then
            current_issues+=("$num")
        fi
    done < <(echo "$issues_json" | jq -c '.[]')
    
    # Check for stale files
    for file in "$output_dir"/*; do
        if [[ -f "$file" ]]; then
            local filename=$(basename "$file")
            # Extract issue number from filename
            local issue_num=$(echo "$filename" | sed 's/-.*$//' | sed 's/\.json$//' | sed 's/\.md$//')
            
            # Check if this issue number exists in current issues
            local found=false
            for current_num in "${current_issues[@]}"; do
                if [[ "$current_num" == "$issue_num" ]]; then
                    found=true
                    break
                fi
            done
            
            # Remove stale file
            if [[ "$found" == false ]]; then
                echo -e "${ORANGE}Removed stale file: $filename${NC}"
                rm "$file"
                ((removed_count++))
            fi
        fi
    done
    
    if [[ $removed_count -gt 0 ]]; then
        echo -e "${GREEN}Removed $removed_count stale files${NC}"
    else
        echo -e "${GREEN}All issue files are up to date${NC}"
    fi
        
    
    echo -e "\n${GREEN}Successfully saved $saved_count issues to $output_dir${NC}"
}
save-issues-all() {
    local state="open"
    local format="markdown"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --state)
                state="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --help|-h)
                echo -e "${GREEN}Usage: gits save-issues-all [OPTIONS]${NC}"
                echo -e "${BLUE}Save issues from all repositories to per-repository files${NC}"
                echo -e ""
                echo -e "${PURPLE}Options:${NC}"
                echo -e "  --state STATE    Filter by state: open, closed, all (default: open)"
                echo -e "  --format FORMAT  Output format: markdown, json, plain (default: markdown)"
                echo -e "  -h, --help       Show this help message"
                echo -e ""
                echo -e "${BLUE}Examples:${NC}"
                echo -e "  gits save-issues-all"
                echo -e "  gits save-issues-all --state all --format json"
                return 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}"
                echo -e "Use 'gits save-issues-all --help' for usage information."
                return 1
                ;;
        esac
    done
    
    echo -e "${GREEN}Saving issues for all repositories...${NC}"
    echo -e ""
    
    local repos=()
    while IFS= read -r -d '' gitdir; do
        repos+=("$(dirname "$gitdir")")
    done < <(find . -name .git -type d -print0)
    
    if [[ ${#repos[@]} -eq 0 ]]; then
        echo -e "${ORANGE}No git repositories found in current directory.${NC}"
        return 0
    fi
    
    local total_repos=${#repos[@]}
    local success_count=0
    local failed_count=0
    
    for repodir in "${repos[@]}"; do
        echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
        echo -e "${BLUE}📁 Repository: $repodir${NC}"
        echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
        
        if ( cd "$repodir" && GITS_ISSUES_NONINTERACTIVE=1 save-issues --state "$state" --format "$format" ); then
            ((success_count++))
        else
            ((failed_count++))
            echo -e "${RED}Failed to save issues for $repodir${NC}"
        fi
        
        echo -e ""
    done
    
    echo -e "${PURPLE}Summary:${NC}"
    echo -e "  Total repositories: $total_repos"
    echo -e "  ${GREEN}Successful: $success_count${NC}"
    if [[ "$failed_count" -gt 0 ]]; then
        echo -e "  ${RED}Failed: $failed_count${NC}"
    fi
}

help() {
    echo -e "\n${ORANGE}═══════════════════════════════════════════${NC}"
    echo -e "${ORANGE}              GitS - Git Speed              ${NC}"
    echo -e "${ORANGE}═══════════════════════════════════════════${NC}\n"
    
    echo -e "${PURPLE}Description:${NC} GitS is a Bash CLI tool that enhances Git with additional features while maintaining full Git compatibility."
    echo -e "${PURPLE}Key Feature:${NC} GitS automatically passes through any native Git commands that aren't specifically handled by GitS."
    echo -e "${PURPLE}Example:${NC}     'gits status' will execute 'git status' since it's not a GitS command"
    echo -e "${PURPLE}Usage:${NC}       gits <command> [arguments]"
    echo -e "${PURPLE}License:${NC}     Apache 2.0"
    echo -e "${PURPLE}Code:${NC}        https://github.com/Mik-TF/gits.git\n"
    
    echo -e "${PURPLE}Command Handling:${NC}"
    echo -e "  1. First tries to execute GitS-specific commands (listed below)"
    echo -e "  2. If not found, automatically passes the command to Git"
    echo -e "  3. If neither GitS nor Git recognizes the command, shows an error\n"
    
    echo -e "${PURPLE}GitS-specific commands:${NC}"
    echo -e "  ${GREEN}push [branch] [commit-message] [-p] [-py]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} add all changes, commit with message, push"
    echo -e "                  ${BLUE}Note:${NC}    Automatically sets upstream branch if not set"
    echo -e "                  ${BLUE}Note:${NC}    If no commit message is provided, you'll be prompted"
    echo -e "                  ${BLUE}Flag -p:${NC} Use pal /commit for AI-generated commit message (interactive)"
    echo -e "                  ${BLUE}Flag -py:${NC} Use pal /commit -y for AI-generated commit message (auto-commit)"
    echo -e "                  ${BLUE}Example:${NC} gits push"
    echo -e "                  ${BLUE}Example:${NC} gits push main"
    echo -e "                  ${BLUE}Example:${NC} gits push main \"Initial commit\""
    echo -e "                  ${BLUE}Example:${NC} gits push -p"
    echo -e "                  ${BLUE}Example:${NC} gits push -py\n"
    
    echo -e "  ${GREEN}up${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Quick workflow: git add . && pal /commit -y && git push"
    echo -e "                  ${BLUE}Note:${NC}    Automatically stages all changes, commits with AI-generated message, and pushes"
    echo -e "                  ${BLUE}Note:${NC}    Requires pal command to be installed"
    echo -e "                  ${BLUE}Example:${NC} gits up\n"
    
    echo -e "  ${GREEN}pull [branch]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Checkout branch, stash changes, fetch, pull, show status"
    echo -e "                  ${BLUE}Note:${NC}    Default branch is 'development' if not specified"
    echo -e "                  ${BLUE}Example:${NC} gits pull"
    echo -e "                  ${BLUE}Example:${NC} gits pull main\n"
    
    echo -e "  ${GREEN}pr <action> [OPTIONS]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} create, close, merge"
    echo -e "                  ${BLUE}Interactive:${NC} gits pr create"
    echo -e "                  ${BLUE}Parameterized:${NC} gits pr create --title 'Title' --base main --head feature"
    echo -e "                  ${BLUE}One-liner:${NC} gits pr create --title 'Update' --base development --body 'Changes' && gits pr merge --pr-number \$(gits pr-latest)"
    echo -e "                  ${BLUE}Example:${NC} gits pr close"
    echo -e "                  ${BLUE}Example:${NC} gits pr merge --pr-number 123 --delete-branch --branch-name feature"
    echo -e "                  ${BLUE}Example:${NC} gits pr merge --pr-number 123 -d --branch-name feature\n"
    
    echo -e "  ${GREEN}pr-latest${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Get the latest PR number regardless of platform"
    echo -e "                  ${BLUE}Example:${NC} gits pr-latest"
    echo -e "                  ${BLUE}Example:${NC} gits pr merge --pr-number $(gits pr-latest)\n"
    
    echo -e "  ${GREEN}commit${NC}"
    echo -e "                  ${BLUE}Actions:${NC} prompt for commit message, commit"
    echo -e "                  ${BLUE}Example:${NC} gits commit\n"
    
    echo -e "  ${GREEN}repo <action>${NC}"
    echo -e "                  ${BLUE}Actions:${NC} create, delete"
    echo -e "                  ${BLUE}Example:${NC} gits repo create"
    echo -e "                  ${BLUE}Example:${NC} gits repo delete\n"
    
    echo -e "  ${GREEN}init${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Choose platform, init repo, create branch, add files"
    echo -e "                  ${BLUE}Note:${NC}    Default branch: 'development' (Gitea), 'main' (GitHub)"
    echo -e "                  ${BLUE}Note:${NC}    Gitea URL will be git.ourworld.tf"
    echo -e "                  ${BLUE}Example:${NC} gits init\n"
    
    echo -e "  ${GREEN}new [name]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} create new branch, switch to it"
    echo -e "                  ${BLUE}Note:${NC}    If no name provided, you'll be prompted"
    echo -e "                  ${BLUE}Example:${NC} gits new"
    echo -e "                  ${BLUE}Example:${NC} gits new feature-branch\n"
    
    echo -e "  ${GREEN}delete [branch-name]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Switch to default, delete branch locally/remotely"
    echo -e "                  ${BLUE}Note:${NC}    If no name provided, you'll be prompted"
    echo -e "                  ${BLUE}Example:${NC} gits delete"
    echo -e "                  ${BLUE}Example:${NC} gits delete feature-branch\n"
    
    echo -e "  ${GREEN}revert <number>${NC}"
    echo -e "                  ${BLUE}Actions:${NC} revert changes to X commits ago, stage changes"
    echo -e "                  ${BLUE}Note:${NC}    Changes are staged but not committed"
    echo -e "                  ${BLUE}Example:${NC} gits revert 1"
    echo -e "                  ${BLUE}Example:${NC} gits revert 3\n"
    
    echo -e "  ${GREEN}unrevert${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Undo the last revert if not committed"
    echo -e "                  ${BLUE}Example:${NC} gits unrevert\n"
    
    echo -e "  ${GREEN}clone <repo>${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Clone repository, switch to repo directory"
    echo -e "                  ${BLUE}Example:${NC} gits clone https://github.com/org/repo"
    echo -e "                  ${BLUE}Example:${NC} gits clone org/repo\n"
    
    echo -e "  ${GREEN}clone-all [URL|username]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Clone all repositories from a user (interactive or with argument)"
    echo -e "                  ${BLUE}Note:${NC}    Creates a directory with username and clones all repos into it"
    echo -e "                  ${BLUE}Platforms:${NC} Forgejo (forge.ourworld.tf), Gitea (git.ourworld.tf), GitHub"
    echo -e "                  ${BLUE}Options:${NC} --no-parallel, --max-concurrent N (default: 5)"
    echo -e "                  ${BLUE}Example:${NC} gits clone-all"
    echo -e "                  ${BLUE}Example:${NC} gits clone-all myusername"
    echo -e "                  ${BLUE}Example:${NC} gits clone-all github.com/myusername"
    echo -e "                  ${BLUE}Example:${NC} gits clone-all forge.ourworld.tf/myorg"
    echo -e "                  ${BLUE}Example:${NC} gits clone-all git.ourworld.tf/myorg\n"
    
    echo -e "  ${GREEN}clone-list${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Clone all repositories from a user on selected platform"
    echo -e "                  ${BLUE}Note:${NC}    Creates a directory with username and clones all repos into it"
    echo -e "                  ${BLUE}Note:${NC}    Supports various URL formats including github.com and git.ourworld.tf"
    echo -e "                  ${BLUE}Example:${NC} gits clone-list\n"
    
    echo -e "  ${GREEN}fetch-issues${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Fetch issues from current repository and display in console"
    echo -e "                  ${BLUE}Options:${NC} --state (open/closed/all), --format (display/json)"
    echo -e "                  ${BLUE}Example:${NC} gits fetch-issues"
    echo -e "                  ${BLUE}Example:${NC} gits fetch-issues --state all --format json\n"
    
    echo -e "  ${GREEN}fetch-issues-all [OPTIONS]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Fetch issues from all repositories in directory tree"
    echo -e "                  ${BLUE}Options:${NC} --state (open/closed/all), --format (display/json)"
    echo -e "                  ${BLUE}Example:${NC} gits fetch-issues-all"
    echo -e "                  ${BLUE}Example:${NC} gits fetch-issues-all --state all --format json\n"
    
    echo -e "  ${GREEN}save-issues${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Save issues to files in organized directory structure"
    echo -e "                  ${BLUE}Options:${NC} --state (open/closed/all), --format (markdown/json/plain)"
    echo -e "                  ${BLUE}Output:${NC} ./repo-name-issues/ directory with individual issue files"
    echo -e "                  ${BLUE}Example:${NC} gits save-issues"
    echo -e "                  ${BLUE}Example:${NC} gits save-issues --state all --format markdown\n"
    
    echo -e "  ${GREEN}save-issues-all [OPTIONS]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Save issues for all repositories to per-repository directories"
    echo -e "                  ${BLUE}Options:${NC} --state (open/closed/all), --format (markdown/json/plain)"
    echo -e "                  ${BLUE}Output:${NC} ./owner-repo-issues/ directories inside each repository"
    echo -e "                  ${BLUE}Example:${NC} gits save-issues-all"
    echo -e "                  ${BLUE}Example:${NC} gits save-issues-all --state all --format json\n"
    
    echo -e "  ${GREEN}list-all${NC}"
    echo -e "                  ${BLUE}Actions:${NC} List repositories with current branch and simple status flags"
    echo -e "                  ${BLUE}Note:${NC}    Shows [modified], [+N ahead], or [clean] per repository"
    echo -e "                  ${BLUE}Example:${NC} gits list-all\n"
    
    echo -e "  ${GREEN}status-all [OPTIONS]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Check git status across all repositories in directory tree"
    echo -e "                  ${BLUE}Options:${NC} --all (show clean repos), --compact (summary format)"
    echo -e "                  ${BLUE}Note:${NC}    By default only shows repositories needing attention"
    echo -e "                  ${BLUE}Example:${NC} gits status-all"
    echo -e "                  ${BLUE}Example:${NC} gits status-all --all --compact\n"
    
    echo -e "  ${GREEN}fetch-all [OPTIONS]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Fetch updates from all repositories in directory tree"
    echo -e "                  ${BLUE}Options:${NC} --no-parallel (disable parallel), --max-concurrent N (default: 5)"
    echo -e "                  ${BLUE}Options:${NC} --no-tags (skip tags), --quiet (suppress output)"
    echo -e "                  ${BLUE}Example:${NC} gits fetch-all"
    echo -e "                  ${BLUE}Example:${NC} gits fetch-all --no-parallel"
    echo -e "                  ${BLUE}Example:${NC} gits fetch-all --max-concurrent 10\n"
    
    echo -e "  ${GREEN}pull-all [OPTIONS]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Pull updates from all repositories with conflict detection"
    echo -e "                  ${BLUE}Options:${NC} --strategy (merge/rebase/ff-only), --auto-merge (attempt auto-resolve)"
    echo -e "                  ${BLUE}Options:${NC} --abort-on-conflict (stop on conflicts), --no-parallel (disable parallel)"
    echo -e "                  ${BLUE}Example:${NC} gits pull-all"
    echo -e "                  ${BLUE}Example:${NC} gits pull-all --strategy rebase"
    echo -e "                  ${BLUE}Example:${NC} gits pull-all --auto-merge --verbose\n"
    
    echo -e "  ${GREEN}push-all [OPTIONS]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Interactively add, commit, and push changes across all dirty repositories"
    echo -e "                  ${BLUE}Options:${NC} --batch (same message), --dry-run (preview), --yes (skip prompts)"
    echo -e "                  ${BLUE}Note:${NC}    Interactive workflow with safety features and auto-generated messages"
    echo -e "                  ${BLUE}Example:${NC} gits push-all"
    echo -e "                  ${BLUE}Example:${NC} gits push-all --batch -m \"Update documentation\"\n"

    echo -e "  ${GREEN}set-all <branch-name>${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Create or switch to the same branch across all repositories"
    echo -e "                  ${BLUE}Options:${NC} --dry-run (preview changes without modifying branches)"
    echo -e "                  ${BLUE}Example:${NC} gits set-all feature/my-progress-branch"
    echo -e "                  ${BLUE}Example:${NC} gits set-all feature/my-progress-branch --dry-run\n"

    echo -e "  ${GREEN}change-all <branch-name>${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Alias for set-all for multi-repo branch changes"
    echo -e "                  ${BLUE}Example:${NC} gits change-all feature/my-progress-branch\n"

    echo -e "  ${GREEN}login${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Interactive login to selected platform"
    echo -e "                  ${BLUE}Platforms:${NC} Forgejo (forge.ourworld.tf), Gitea (git.ourworld.tf), GitHub"
    echo -e "                  ${BLUE}Example:${NC} gits login\n"
    
    echo -e "  ${GREEN}logout${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Logout from selected platform"
    echo -e "                  ${BLUE}Platforms:${NC} Forgejo, Gitea, GitHub"
    echo -e "                  ${BLUE}Example:${NC} gits logout\n"
    
    echo -e "  ${GREEN}token <command> [server]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Manage cached API tokens"
    echo -e "                  ${BLUE}Commands:${NC} list, show, clear"
    echo -e "                  ${BLUE}Note:${NC}    Tokens cached in ~/.config/gits/tokens.conf"
    echo -e "                  ${BLUE}Example:${NC} gits token list"
    echo -e "                  ${BLUE}Example:${NC} gits token show forge.ourworld.tf"
    echo -e "                  ${BLUE}Example:${NC} gits token clear forge.ourworld.tf\n"
    
    echo -e "  ${GREEN}install${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Install GitS globally"
    echo -e "                  ${BLUE}Example:${NC} gits install\n"
    
    echo -e "  ${GREEN}uninstall${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Remove GitS from system"
    echo -e "                  ${BLUE}Example:${NC} gits uninstall\n"
    
    echo -e "  ${GREEN}help${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Show this help message"
    echo -e "                  ${BLUE}Example:${NC} gits help\n"
    
    echo -e "${ORANGE}═══════════════════════════════════════════${NC}"
    
    echo -e "${PURPLE}QUICK REFERENCE - PR WORKFLOWS:${NC}"
    echo -e "${BLUE}Interactive:${NC} gits pr create"
    echo -e "${BLUE}Parameterized:${NC} gits pr create --title 'My PR' --base development"
    echo -e "${BLUE}One-liner:${NC} gits pr create --title 'Update' --base development && gits pr merge --pr-number \$(gits pr-latest)"
    echo -e "${BLUE}Current Branch:${NC} gits pr create --title 'My changes' --base development"
    echo -e "  ${BLUE}All standard Git commands are supported through automatic passthrough${NC}"
    echo -e "  ${BLUE}Example:${NC} gits status       → runs git status"
    echo -e "  ${BLUE}Example:${NC} gits log          → runs git log"
    echo -e "  ${BLUE}Example:${NC} gits diff         → runs git diff\n"
    echo -e "  ${BLUE}Note:${NC} Any Git command not listed above will be passed directly to Git\n"
    
    echo -e "${PURPLE}Note:${NC} Ensure you're in your git repository directory when running git-related commands."
    echo -e "${PURPLE}Tip:${NC}  Use 'git help' to see all available Git commands that can be used with GitS.\n"
    
    echo -e "  ${GREEN}init-list${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Initialize multiple repositories at once"
    echo -e "                  ${BLUE}Note:${NC}    Creates a directory with username-repos and initializes all repos into it"
    echo -e "                  ${BLUE}Note:${NC}    Default branch: 'development' (Gitea), 'main' (GitHub)"
    echo -e "                  ${BLUE}Example:${NC} gits init-list\n"
}

# Main execution logic
main() {
    if [ $# -eq 0 ]; then
        help
        exit 1
    fi

    case "$1" in
        login)
            login
            ;;
        logout)
            logout
            ;;
        token)
            shift
            token "$@"
            ;;
        repo)
            shift
            repo "$@"
            ;;
        pr)
            shift
            pr "$@"
            ;;
        pr-latest)
            get_latest_pr_number
            ;;
        delete)
            shift
            delete "$@"
            ;;
        pull)
            shift
            pull "$@"
            ;;
        push)
            shift
            push "$@"
            ;;
        commit)
            commit
            ;;
        up)
            up
            ;;
        init)
            init
            ;;
        init-list)
            init-list
            ;;
        new)
            shift
            new "$@"
            ;;
        revert)
            shift
            revert "$@"
            ;;
        unrevert)
            unrevert
            ;;
        clone)
            shift
            clone "$@"
            ;;
        clone-all)
            shift
            clone-all "$@"
            ;;
        clone-list)
            clone-list
            ;;
        fetch-issues)
            shift
            fetch-issues "$@"
            ;;
        save-issues)
            shift
            save-issues "$@"
            ;;
        fetch-issues-all)
            shift
            fetch-issues-all "$@"
            ;;
        save-issues-all)
            shift
            save-issues-all "$@"
            ;;
        status-all)
            shift
            status-all "$@"
            ;;
        list-all)
            shift
            list-all "$@"
            ;;
        set-all)
            shift
            set-all "$@"
            ;;
        change-all)
            shift
            set-all "$@"
            ;;
        fetch-all)
            shift
            fetch-all "$@"
            ;;
        pull-all)
            shift
            pull-all "$@"
            ;;
        push-all)
            shift
            push-all "$@"
            ;;
        install)
            install
            ;;
        uninstall)
            uninstall
            ;;
        help)
            help
            ;;
        *)
            # Check if the command exists in git
            if git help "$1" >/dev/null 2>&1; then
                # Command exists in git, pass all arguments to git
                git "$@"
            else
                echo -e "${RED}Error: Command '$1' not found in gits or git${NC}"
                echo -e "Run '${GREEN}gits help${NC}' for usage information or '${GREEN}git help${NC}' for git commands."
                exit 1
            fi
            ;;
    esac
}

# Run the main function
main "$@"