#!/bin/bash

# ANSI color codes
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
ORANGE='\033[38;5;208m'
NC='\033[0m' # No Color

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
        if [[ "$host_part" == *"github.com"* ]]; then
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
            --help|-h)
                echo -e "${GREEN}Usage: gits push-all [OPTIONS]${NC}"
                echo -e "${BLUE}Interactively add, commit, and push changes across all dirty repositories${NC}"
                echo -e ""
                echo -e "${PURPLE}Options:${NC}"
                echo -e "  -n, --dry-run     Show what would be done without executing"
                echo -e "  -b, --batch       Use same commit message for all repos"
                echo -e "  -m, --message     Default commit message (use with --batch)"
                echo -e "  -y, --yes         Skip confirmation prompts"
                echo -e "  -h, --help        Show this help message"
                echo -e ""
                echo -e "${BLUE}Examples:${NC}"
                echo -e "  gits push-all                           # Interactive mode"
                echo -e "  gits push-all --batch -m \"Update docs\" # Batch with message"
                echo -e "  gits push-all --dry-run                 # Preview actions"
                return 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}"
                echo -e "Use 'gits push-all --help' for usage information."
                return 1
                ;;
        esac
    done
    
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
        
        # Skip confirmation in batch mode with --yes
        if [[ "$batch_mode" == true ]] && [[ "$skip_confirmation" == true ]]; then
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
                            echo -e "${BLUE}Pushing to remote...${NC}"
                            if git push; then
                                echo -e "${GREEN}✅ Successfully pushed $repodir${NC}"
                                processed=$((processed + 1))
                            else
                                echo -e "${RED}❌ Failed to push $repodir${NC}"
                                failed=$((failed + 1))
                            fi
                        else
                            echo -e "${RED}❌ Failed to commit $repodir${NC}"
                            failed=$((failed + 1))
                        fi
                    else
                        echo -e "${RED}❌ Failed to add changes in $repodir${NC}"
                        failed=$((failed + 1))
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

clone-all() {
    echo -e "${GREEN}Which platform would you like to use?${NC}"
    echo -e "1) Gitea"
    echo -e "2) GitHub"
    read -p "Enter your choice (1/2): " platform_choice

    echo -e "${GREEN}Enter the username:${NC}"
    read USERNAME

    if [ -z "$USERNAME" ]; then
        echo -e "${RED}Error: Username cannot be empty.${NC}"
        return 1
    fi

    # Create a directory for cloning
    mkdir -p "$USERNAME"
    cd "$USERNAME" || return 1

    local repos_json=""
    local successful_clones=0
    local failed_clones=0
    local total_repos=0

    # Fetch repositories based on the selected platform
    case "$platform_choice" in
        1)
            # For Gitea, we need to ask for the server URL
            echo -e "${GREEN}Enter Gitea server URL (e.g., git.ourworld.tf):${NC}"
            read GITEA_SERVER
            
            if [ -z "$GITEA_SERVER" ]; then
                GITEA_SERVER="git.ourworld.tf"
                echo -e "${ORANGE}Using default Gitea server: $GITEA_SERVER${NC}"
            fi
            
            echo -e "${GREEN}Cloning all repositories for user: $USERNAME from $GITEA_SERVER${NC}"
            
            # Check if curl is available
            if ! command -v curl &> /dev/null; then
                echo -e "${RED}Error: curl is required but not installed. Please install curl and try again.${NC}"
                cd - > /dev/null
                return 1
            fi
            
            # Ask if user wants to use authentication to access private repositories
            echo -e "${GREEN}Do you want to access private repositories? (y/n):${NC}"
            read use_auth
            
            local auth_header=""
            local api_endpoint=""
            
            if [[ $use_auth =~ ^[Yy]$ ]]; then
                echo -e "${GREEN}Choose authentication method:${NC}"
                echo -e "1) Use existing Gitea login (via tea CLI)"
                echo -e "2) Provide an API token"
                read -p "Enter your choice (1/2): " auth_choice
                
                case "$auth_choice" in
                    1)
                        # Check if tea CLI is available
                        if ! command -v tea &> /dev/null; then
                            echo -e "${RED}Error: tea CLI is required but not installed. Please install tea CLI or use API token instead.${NC}"
                            cd - > /dev/null
                            return 1
                        fi
                        
                        # Check if already logged in
                        if tea login list | grep -q "$GITEA_SERVER"; then
                            echo -e "${GREEN}Already logged in to $GITEA_SERVER.${NC}"
                        else
                            echo -e "${ORANGE}Not logged in to $GITEA_SERVER. Initiating login...${NC}"
                            tea login add
                            
                            # Check if login was successful
                            if ! tea login list | grep -q "$GITEA_SERVER"; then
                                echo -e "${RED}Login failed. Continuing without authentication (only public repos will be accessible).${NC}"
                            else
                                echo -e "${GREEN}Login successful.${NC}"
                            fi
                        fi
                        
                        # Get token from tea config
                        local tea_token=$(tea config get auth.$GITEA_SERVER.token 2>/dev/null)
                        if [ -n "$tea_token" ]; then
                            auth_header="Authorization: token $tea_token"
                            echo -e "${GREEN}Using token from tea configuration.${NC}"
                            # Construct base API URL with proper protocol
                            local base_url
                            if [[ $GITEA_SERVER != http* ]]; then
                                base_url="https://$GITEA_SERVER"
                            else
                                base_url="$GITEA_SERVER"
                            fi
                            
                            # Ask for API path pattern
                            echo -e "${GREEN}Select API endpoint pattern:${NC}"
                            echo -e "1) Standard Gitea API (/api/v1/user/repos)"
                            echo -e "2) Alternative pattern (/api/v1/orgs/$USERNAME/repos)"
                            echo -e "3) Custom API endpoint"
                            read -p "Enter your choice (1/2/3): " api_pattern_choice
                            
                            case "$api_pattern_choice" in
                                1)
                                    api_endpoint="$base_url/api/v1/user/repos"
                                    ;;
                                2)
                                    api_endpoint="$base_url/api/v1/orgs/$USERNAME/repos"
                                    ;;
                                3)
                                    echo -e "${GREEN}Enter custom API endpoint (without base URL):${NC}"
                                    echo -e "${ORANGE}Example: /api/v1/users/$USERNAME/repos${NC}"
                                    read custom_endpoint
                                    api_endpoint="$base_url$custom_endpoint"
                                    ;;
                                *)
                                    # Default to standard pattern
                                    api_endpoint="$base_url/api/v1/user/repos"
                                    ;;
                            esac
                        else
                            echo -e "${ORANGE}Could not retrieve token from tea configuration. Falling back to public repos only.${NC}"
                            # Construct base API URL with proper protocol
                            local base_url
                            if [[ $GITEA_SERVER != http* ]]; then
                                base_url="https://$GITEA_SERVER"
                            else
                                base_url="$GITEA_SERVER"
                            fi
                            
                            # For public repos, use the users endpoint
                            api_endpoint="$base_url/api/v1/users/$USERNAME/repos"
                        fi
                        ;;
                    2)
                        echo -e "${GREEN}Enter your Gitea API token:${NC}"
                        read -s API_TOKEN
                        echo
                        
                        if [ -n "$API_TOKEN" ]; then
                            auth_header="Authorization: token $API_TOKEN"
                            # Construct base API URL with proper protocol
                            local base_url
                            if [[ $GITEA_SERVER != http* ]]; then
                                base_url="https://$GITEA_SERVER"
                            else
                                base_url="$GITEA_SERVER"
                            fi
                            
                            # Ask for API path pattern
                            echo -e "${GREEN}Select API endpoint pattern:${NC}"
                            echo -e "1) Standard Gitea API (/api/v1/user/repos)"
                            echo -e "2) Alternative pattern (/api/v1/orgs/$USERNAME/repos)"
                            echo -e "3) Custom API endpoint"
                            read -p "Enter your choice (1/2/3): " api_pattern_choice
                            
                            case "$api_pattern_choice" in
                                1)
                                    api_endpoint="$base_url/api/v1/user/repos"
                                    ;;
                                2)
                                    api_endpoint="$base_url/api/v1/orgs/$USERNAME/repos"
                                    ;;
                                3)
                                    echo -e "${GREEN}Enter custom API endpoint (without base URL):${NC}"
                                    echo -e "${ORANGE}Example: /api/v1/users/$USERNAME/repos${NC}"
                                    read custom_endpoint
                                    api_endpoint="$base_url$custom_endpoint"
                                    ;;
                                *)
                                    # Default to standard pattern
                                    api_endpoint="$base_url/api/v1/user/repos"
                                    ;;
                            esac
                        else
                            echo -e "${ORANGE}No token provided. Falling back to public repos only.${NC}"
                            # Construct base API URL with proper protocol
                            local base_url
                            if [[ $GITEA_SERVER != http* ]]; then
                                base_url="https://$GITEA_SERVER"
                            else
                                base_url="$GITEA_SERVER"
                            fi
                            
                            # For public repos, use the users endpoint
                            api_endpoint="$base_url/api/v1/users/$USERNAME/repos"
                        fi
                        ;;
                    *)
                        echo -e "${ORANGE}Invalid choice. Falling back to public repos only.${NC}"
                        # Construct base API URL with proper protocol
                        local base_url
                        if [[ $GITEA_SERVER != http* ]]; then
                            base_url="https://$GITEA_SERVER"
                        else
                            base_url="$GITEA_SERVER"
                        fi
                        
                        # For public repos, use the users endpoint
                        api_endpoint="$base_url/api/v1/users/$USERNAME/repos"
                        ;;
                esac
            else
                # No authentication, use public API
                # Construct base API URL with proper protocol
                local base_url
                if [[ $GITEA_SERVER != http* ]]; then
                    base_url="https://$GITEA_SERVER"
                else
                    base_url="$GITEA_SERVER"
                fi
                
                # Ask for API path pattern for public repos
                echo -e "${GREEN}Select API endpoint pattern for public repositories:${NC}"
                echo -e "1) Standard Gitea API (/api/v1/users/$USERNAME/repos)"
                echo -e "2) Alternative pattern (/api/v1/orgs/$USERNAME/repos)"
                echo -e "3) Custom API endpoint"
                read -p "Enter your choice (1/2/3): " api_pattern_choice
                
                case "$api_pattern_choice" in
                    1)
                        api_endpoint="$base_url/api/v1/users/$USERNAME/repos"
                        ;;
                    2)
                        api_endpoint="$base_url/api/v1/orgs/$USERNAME/repos"
                        ;;
                    3)
                        echo -e "${GREEN}Enter custom API endpoint (without base URL):${NC}"
                        echo -e "${ORANGE}Example: /api/v1/users/$USERNAME/repos${NC}"
                        read custom_endpoint
                        api_endpoint="$base_url$custom_endpoint"
                        ;;
                    *)
                        # Default to standard pattern
                        api_endpoint="$base_url/api/v1/users/$USERNAME/repos"
                        ;;
                esac
            fi
            
            # Use Gitea API to get repositories
            echo -e "${PURPLE}Fetching repositories from Gitea API...${NC}"
            echo -e "${BLUE}Using API endpoint: $api_endpoint${NC}"
            
            # Fetch repositories using curl with or without authentication
            if [ -n "$auth_header" ]; then
                repos_json=$(curl -s -H "$auth_header" "$api_endpoint")
            else
                repos_json=$(curl -s "$api_endpoint")
            fi
            
            # Check if we got valid JSON
            if ! echo "$repos_json" | jq . &>/dev/null; then
                echo -e "${RED}Error: Failed to get valid JSON response from Gitea API.${NC}"
                echo -e "${ORANGE}Response: $repos_json${NC}"
                echo -e "${BLUE}API Endpoint: $api_endpoint${NC}"
                
                # Check if the response contains HTML, which might indicate a redirect or error page
                if echo "$repos_json" | grep -q "<html"; then
                    echo -e "${RED}Received HTML response instead of JSON. The server might be redirecting or returning an error page.${NC}"
                    echo -e "${ORANGE}Try using the full URL including 'https://' when entering the server URL.${NC}"
                fi
                
                cd - > /dev/null
                return 1
            fi
            
            # Check if we got an empty array or error
            if [ "$(echo "$repos_json" | jq 'length')" -eq 0 ]; then
                echo -e "${RED}No repositories found for user $USERNAME on $GITEA_SERVER.${NC}"
                echo -e "${ORANGE}Possible reasons:${NC}"
                echo -e "  - The username might be incorrect"
                echo -e "  - The user might not have any public repositories"
                echo -e "  - You might need authentication to access the repositories"
                echo -e "  - The API endpoint might be incorrect: $api_endpoint"
                cd - > /dev/null
                return 1
            fi
            
            # Debug: Show the raw API response
            echo -e "${BLUE}API Response:${NC}"
            echo "$repos_json" | jq '.' | head -n 20
            
            # Check the structure of the first repository to determine owner field name
            local first_repo=$(echo "$repos_json" | jq -c '.[0] // {}')
            echo -e "${BLUE}First repository structure:${NC}"
            echo "$first_repo" | jq '.'
            
            # Determine the owner field name (Gitea API might use different field names)
            local owner_field="login"
            if echo "$first_repo" | jq -e '.owner.username' &>/dev/null; then
                owner_field="username"
            fi
            
            # Filter repositories by owner if using authenticated endpoint
            if [[ $api_endpoint == *"/user/repos"* ]]; then
                echo -e "${BLUE}Filtering repositories owned by $USERNAME (using owner.$owner_field)...${NC}"
                repos_json=$(echo "$repos_json" | jq "[.[] | select(.owner.$owner_field == \"$USERNAME\")]")
                
                # Check if we have any repositories after filtering
                if [ "$(echo "$repos_json" | jq 'length')" -eq 0 ]; then
                    echo -e "${RED}No repositories found owned by $USERNAME on $GITEA_SERVER.${NC}"
                    echo -e "${ORANGE}Try using the exact username as shown in the API response above.${NC}"
                    cd - > /dev/null
                    return 1
                fi
            fi
            
            # Process each repository
            while read -r repo; do
                local repo_name=$(echo "$repo" | jq -r '.name')
                local clone_url=$(echo "$repo" | jq -r '.clone_url')
                local ssh_url=$(echo "$repo" | jq -r '.ssh_url')
                
                # If SSH URL is not available, construct it
                if [ -z "$ssh_url" ] || [ "$ssh_url" = "null" ]; then
                    ssh_url="git@$GITEA_SERVER:$USERNAME/$repo_name.git"
                fi
                
                ((total_repos++))
                
                # Skip if repository directory already exists
                if [ -d "$repo_name" ]; then
                    echo -e "${ORANGE}Repository $repo_name already exists. Skipping...${NC}"
                    continue
                fi
                
                echo -e "${PURPLE}Cloning $repo_name...${NC}"
                
                # Attempt to clone
                if git clone "$clone_url" "$repo_name"; then
                    ((successful_clones++))
                    echo -e "${GREEN}Completed cloning $repo_name${NC}"
                    
                    # Set SSH URL for future operations
                    (cd "$repo_name" && {
                        echo -e "${PURPLE}Setting SSH URL: $ssh_url${NC}"
                        git remote set-url origin "$ssh_url"
                    })
                else
                    ((failed_clones++))
                    echo -e "${RED}Failed to clone $repo_name${NC}"
                fi
            done < <(echo "$repos_json" | jq -c '.[]')
            ;;
        2)
            echo -e "${GREEN}Cloning all repositories for user: $USERNAME from GitHub${NC}"
            
            # Fetch repositories using gh for GitHub
            echo -e "${PURPLE}Fetching repositories from GitHub...${NC}"
            repos_json=$(gh repo list "$USERNAME" --json name,sshUrl --limit 100)
            
            # Use process substitution to avoid subshell variable scope issues
            while read -r repo; do
                local repo_name=$(echo "$repo" | jq -r '.name')
                local repo_url=$(echo "$repo" | jq -r '.sshUrl')

                ((total_repos++))

                # Skip if repository directory already exists
                if [ -d "$repo_name" ]; then
                    echo -e "${ORANGE}Repository $repo_name already exists. Skipping...${NC}"
                    continue
                fi
                
                echo -e "${PURPLE}Cloning $repo_name...${NC}"
                
                # Attempt to clone via SSH
                if git clone "$repo_url" "$repo_name"; then
                    ((successful_clones++))
                    echo -e "${GREEN}Completed cloning $repo_name${NC}"
                else
                    ((failed_clones++))
                    echo -e "${RED}Failed to clone $repo_name${NC}"
                fi
            done < <(echo "$repos_json" | jq -c '.[]')
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
            cd - > /dev/null
            return 1
            ;;
    esac

    # Display summary
    echo -e "\n${BLUE}Cloning Summary:${NC}"
    echo -e "Total Repositories: ${total_repos}"
    echo -e "${GREEN}Successfully Cloned: ${successful_clones}${NC}"
    echo -e "${RED}Failed to Clone: ${failed_clones}${NC}"
    
    # Return to original directory
    cd - > /dev/null
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
    if [[ $remote_url == *"github.com"* ]]; then
        echo "2"  # GitHub
    elif [[ $remote_url == *"git.ourworld.tf"* ]] || [[ $remote_url == *"gitea"* ]]; then
        echo "1"  # Gitea
    else
        echo "2"  # Default to GitHub
    fi
}

# Function to get the latest PR number regardless of platform
get_latest_pr_number() {
    local platform_choice=$(detect_platform)
    
    if [ "$platform_choice" = "1" ]; then
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
        echo -e "  create --title 'Title' --base main --head feature --body 'Description' [--platform github|gitea]"
        echo -e "  merge --pr-number 123 [--platform github|gitea]"
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
            if [[ "$platform_val" == "gitea" ]]; then
                platform_choice="1"
            elif [[ "$platform_val" == "github" ]]; then
                platform_choice="2"
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

    if [ "$platform_choice" = "1" ]; then
        # Gitea PR creation
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
            if [ -z "$title" ] || [ -z "$head" ]; then
                echo -e "${RED}Error: --title and --head are required for non-interactive mode${NC}"
                return 1
            fi
        fi

        echo -e "\n${PURPLE}Creating Pull Request...${NC}"
        gh pr create --base "$base" --head "$head" --title "$title" --body "$description"
    fi
}

# Function to close a pull request
pr_close() {
    local platform_choice=$1

    if [ "$platform_choice" = "1" ]; then
        # Show current PRs
        echo -e "${BLUE}Current Pull Requests:${NC}"
        tea pr

        echo -e "\n${GREEN}Enter repository (organization/repository):${NC}"
        read repo

        echo -e "${GREEN}Enter PR number to close:${NC}"
        read pr_number

        echo -e "\n${PURPLE}Closing Pull Request #$pr_number...${NC}"
        tea pr close "$pr_number" --repo "$repo"
    else
        # Show current PRs
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

    if [ "$platform_choice" = "1" ]; then
        # Gitea PR merge
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

    # If arguments are provided
    if [ $# -gt 0 ]; then
        # First argument is the branch
        branch="$1"
        shift
        
        # Remaining arguments form the commit message
        if [ $# -gt 0 ]; then
            commit_message="$*"
        fi
    fi

    # If branch was provided, checkout to it
    if [ ! -z "$branch" ]; then
        if ! git checkout "$branch"; then
            echo -e "${RED}Failed to checkout branch: $branch${NC}"
            return 1
        fi
    fi

    git add .

    # If no commit message was provided in arguments, prompt for it
    if [ -z "$commit_message" ]; then
        echo "Enter commit message:"
        read commit_message
    fi

    git commit -m "$commit_message"

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
    echo -e "1) Gitea"
    echo -e "2) GitHub"
    read -p "Enter your choice (1/2): " platform_choice

    case "$platform_choice" in
        1)
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
        2)
            echo -e "${PURPLE}Logging into GitHub...${NC}"
            if gh auth login; then
                echo -e "${GREEN}Successfully logged into GitHub.${NC}"
            else
                echo -e "${RED}Failed to login to GitHub.${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
            return 1
            ;;
    esac
}

# Function to handle logout
logout() {
    echo -e "${GREEN}Which platform would you like to logout from?${NC}"
    echo -e "1) Gitea"
    echo -e "2) GitHub"
    read -p "Enter your choice (1/2): " platform_choice

    case "$platform_choice" in
        1)
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
        2)
            echo -e "${PURPLE}Logging out from GitHub...${NC}"
            if gh auth logout; then
                echo -e "${GREEN}Successfully logged out from GitHub.${NC}"
            else
                echo -e "${RED}Failed to logout from GitHub.${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Invalid choice. Please select 1 for Gitea or 2 for GitHub.${NC}"
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
    echo -e "  ${GREEN}push [branch] [commit-message]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} add all changes, commit with message, push"
    echo -e "                  ${BLUE}Note:${NC}    Automatically sets upstream branch if not set"
    echo -e "                  ${BLUE}Note:${NC}    If no commit message is provided, you'll be prompted"
    echo -e "                  ${BLUE}Example:${NC} gits push"
    echo -e "                  ${BLUE}Example:${NC} gits push main"
    echo -e "                  ${BLUE}Example:${NC} gits push main \"Initial commit\"\n"
    
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
    
    echo -e "  ${GREEN}clone-all${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Clone all repositories from a user"
    echo -e "                  ${BLUE}Note:${NC}    Creates a directory with username and clones all repos into it"
    echo -e "                  ${BLUE}Example:${NC} gits clone-all\n"
    
    echo -e "  ${GREEN}clone-list${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Clone all repositories from a user on selected platform"
    echo -e "                  ${BLUE}Note:${NC}    Creates a directory with username and clones all repos into it"
    echo -e "                  ${BLUE}Note:${NC}    Supports various URL formats including github.com and git.ourworld.tf"
    echo -e "                  ${BLUE}Example:${NC} gits clone-list\n"
    
    echo -e "  ${GREEN}status-all [OPTIONS]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Check git status across all repositories in directory tree"
    echo -e "                  ${BLUE}Options:${NC} --all (show clean repos), --compact (summary format)"
    echo -e "                  ${BLUE}Note:${NC}    By default only shows repositories needing attention"
    echo -e "                  ${BLUE}Example:${NC} gits status-all"
    echo -e "                  ${BLUE}Example:${NC} gits status-all --all --compact\n"
    
    echo -e "  ${GREEN}push-all [OPTIONS]${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Interactively add, commit, and push changes across all dirty repositories"
    echo -e "                  ${BLUE}Options:${NC} --batch (same message), --dry-run (preview), --yes (skip prompts)"
    echo -e "                  ${BLUE}Note:${NC}    Interactive workflow with safety features and auto-generated messages"
    echo -e "                  ${BLUE}Example:${NC} gits push-all"
    echo -e "                  ${BLUE}Example:${NC} gits push-all --batch -m \"Update documentation\"\n"

    echo -e "  ${GREEN}login${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Interactive login to selected platform"
    echo -e "                  ${BLUE}Example:${NC} gits login\n"
    
    echo -e "  ${GREEN}logout${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Logout from selected platform"
    echo -e "                  ${BLUE}Example:${NC} gits logout\n"
    
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
        status-all)
            shift
            status-all "$@"
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