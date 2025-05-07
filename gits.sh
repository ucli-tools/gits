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

    echo -e "${GREEN}Cloning all repositories for user: $USERNAME${NC}"

    # Fetch repositories using gh to include private repositories
    local repos_json=$(gh repo list "$USERNAME" --json name,sshUrl --limit 100)

    local successful_clones=0
    local failed_clones=0
    local total_repos=0

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

# Function to handle pull request operations
pr() {
    if [ -z "$1" ]; then
        echo -e "${RED}Error: Please specify an action (create/close/merge)${NC}"
        echo -e "Usage: gits pr <create|close|merge>"
        return 1
    fi

    # Ask user which platform to use
    echo -e "${GREEN}Which platform would you like to use?${NC}"
    echo -e "1) Gitea"
    echo -e "2) GitHub"
    read -p "Enter your choice (1/2): " platform_choice

    case "$1" in
        create)
            pr_create "$platform_choice"
            ;;
        close)
            pr_close "$platform_choice"
            ;;
        merge)
            pr_merge "$platform_choice"
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

    if [ "$platform_choice" = "1" ]; then
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

        # Construct the full repository path
        full_repo="${target_org}/${target_repo}"
        echo -e "\n${PURPLE}Creating Pull Request to ${full_repo}...${NC}"
        
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
    else
        # GitHub PR creation
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

    if [ "$platform_choice" = "1" ]; then
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

        echo -e "\n${PURPLE}Merging Pull Request #$pr_number...${NC}"
        tea pr merge --repo "$repo" --title "$merge_title" --message "$merge_message" "$pr_number"

        # Branch deletion option only for Gitea
        echo -e "\n${GREEN}Would you like to delete the branch locally? (y/n)${NC}"
        read delete_branch

        if [[ $delete_branch == "y" ]]; then
            echo -e "${GREEN}Enter branch name to delete:${NC}"
            read branch_name
            
            # Get the default branch (usually main or master)
            default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
            
            # If we couldn't get the default branch, ask the user
            if [ -z "$default_branch" ]; then
                echo -e "${GREEN}Enter the name of your main branch (main/master):${NC}"
                read default_branch
                default_branch=${default_branch:-main}
            fi
            
            # Switch to the default branch first
            if git checkout "$default_branch"; then
                if git branch -d "$branch_name"; then
                    echo -e "${PURPLE}Branch deleted locally.${NC}"
                    
                    echo -e "${GREEN}Push branch deletion to remote? (y/n)${NC}"
                    read push_delete

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
    else
        # Show current PRs
        echo -e "${BLUE}Current Pull Requests:${NC}"
        gh pr list

        echo -e "${GREEN}Enter PR number to merge:${NC}"
        read pr_number

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
            echo -e "${PURPLE}Logging into Gitea...${NC}"
            tea login add
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Successfully logged into Gitea.${NC}"
            else
                echo -e "${RED}Failed to login to Gitea.${NC}"
            fi
            ;;
        2)
            echo -e "${PURPLE}Logging into GitHub...${NC}"
            gh auth login
            if [ $? -eq 0 ]; then
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
            echo -e "${PURPLE}Logging out from Gitea...${NC}"
            tea logout
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Successfully logged out from Gitea.${NC}"
            else
                echo -e "${RED}Failed to logout from Gitea.${NC}"
            fi
            ;;
        2)
            echo -e "${PURPLE}Logging out from GitHub...${NC}"
            gh auth logout
            if [ $? -eq 0 ]; then
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
    
    echo -e "  ${GREEN}pr <action>${NC}"
    echo -e "                  ${BLUE}Actions:${NC} create, close, merge"
    echo -e "                  ${BLUE}Example:${NC} gits pr create"
    echo -e "                  ${BLUE}Example:${NC} gits pr close"
    echo -e "                  ${BLUE}Example:${NC} gits pr merge\n"
    
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
    echo -e "                  ${BLUE}Actions:${NC} Clone multiple repositories from a pasted list"
    echo -e "                  ${BLUE}Note:${NC}    Creates directory structure code/<domain>/<org>/<repo>"
    echo -e "                  ${BLUE}Note:${NC}    Supports various URL formats including github.com and git.ourworld.tf"
    echo -e "                  ${BLUE}Example:${NC} gits clone-list\n"

    echo -e "  ${GREEN}login${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Interactive login to selected platform"
    echo -e "                  ${BLUE}Example:${NC} gits login\n"
    
    echo -e "  ${GREEN}logout${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Logout from selected platform"
    echo -e "                  ${BLUE}Example:${NC} gits logout\n"
    
    echo -e "  ${GREEN}install${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Install GitS to /usr/local/bin"
    echo -e "                  ${BLUE}Example:${NC} gits install\n"
    
    echo -e "  ${GREEN}uninstall${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Remove GitS from /usr/local/bin"
    echo -e "                  ${BLUE}Example:${NC} gits uninstall\n"
    
    echo -e "  ${GREEN}help${NC}"
    echo -e "                  ${BLUE}Actions:${NC} Display this help message"
    echo -e "                  ${BLUE}Example:${NC} gits help\n"
    
    echo -e "${PURPLE}Git Commands:${NC}"
    echo -e "  ${BLUE}All standard Git commands are supported through automatic passthrough${NC}"
    echo -e "  ${BLUE}Example:${NC} gits status       → runs git status"
    echo -e "  ${BLUE}Example:${NC} gits log          → runs git log"
    echo -e "  ${BLUE}Example:${NC} gits diff         → runs git diff\n"
    echo -e "  ${BLUE}Note:${NC} Any Git command not listed above will be passed directly to Git\n"
    
    echo -e "${PURPLE}Note:${NC} Ensure you're in your git repository directory when running git-related commands."
    echo -e "${PURPLE}Tip:${NC}  Use 'git help' to see all available Git commands that can be used with GitS.\n"
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