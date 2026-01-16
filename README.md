<h1> Git Speed (GitS) </h1>

<h2> Table of Contents</h2>

- [Introduction](#introduction)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
  - [Authentication](#authentication)
  - [Repository Management](#repository-management)
  - [Repository Setup](#repository-setup)
  - [Batch Repository Operations](#batch-repository-operations)
  - [Branch Management](#branch-management)
  - [Basic Git Operations](#basic-git-operations)
  - [Pull Request Management](#pull-request-management)
  - [Issue Management](#issue-management)
  - [Commit Management](#commit-management)
  - [Token Management](#token-management)
  - [Installation Management](#installation-management)
  - [Platform-Specific Features](#platform-specific-features)
    - [Forgejo](#forgejo)
    - [Gitea](#gitea)
    - [GitHub](#github)
- [Issues and Feature Requests](#issues-and-feature-requests)
- [Contributing](#contributing)
- [Using Makefile](#using-makefile)
- [License](#license)

## Introduction

GitS is a bash script designed to streamline the git workflow by combining common git, gh and tea commands into quick, easy-to-use operations. It's perfect for developers who want to speed up their Git interactions and simplify their daily version control tasks. 

## Features

- **Quick Pull**: Combines checkout, stash, fetch, pull, and status operations.
- **Rapid Push**: Stages all changes, prompts for a commit message, commits, and pushes in one command.
- **Easy Commit**: Quickly commit changes with a custom message.
- **Pull Request Management**: Create, close, and merge PRs for Forgejo, Gitea, and GitHub.
- **Platform Authentication**: Login and logout functionality for Forgejo, Gitea, and GitHub.
- **Issue Management**: Fetch and save issues from both public and private repositories with flexible authentication options.
- **Branch Management**: Create, delete, and manage branches easily.
- **Repository Initialization**: Initialize a new Git repository and push it to Forgejo, Gitea, or GitHub.
- **Commit Management**: Revert to previous commits and undo reverts.
- **Repository Cloning**: Easily clone repositories and switch to their directory.
- **Batch Repository Operations**: Clone, push, fetch, pull, and check status across multiple repositories simultaneously.
- **Parallel Processing**: Clone, fetch, and pull multiple repositories concurrently for better performance.
- **Smart Conflict Detection**: Advanced merge conflict detection and optional auto-resolution for pull operations.
- **Multiple Merge Strategies**: Support for merge, rebase, and fast-forward only strategies in batch operations.
- **Organization Repository Support**: Smart detection and cloning of organization repositories.
- **Easy Installation**: Simple install and uninstall process.
- **User-Friendly**: Colorized output and helpful error messages.
- **Repository Management**: Create and delete repositories on Forgejo, Gitea, and GitHub
- **Multiple Platform Support**: Seamless integration with Forgejo, Gitea, and GitHub
- **Branch Creation**: Create new branches with custom names
- **Default Branch Handling**: Automatic detection and handling of default branches
- **Force Delete Options**: Safe branch deletion with force delete capabilities
- **Pull Request Workflow**: Complete PR lifecycle management including creation, closing, and merging
- **Merge Commit Control**: Custom merge commit messages and titles
- **Branch Cleanup**: Automatic branch cleanup options after PR merges
- **Private Repository Support**: Full support for private repositories with dual authentication methods (tea CLI or API token)
- **AI-Powered Commits**: Integration with AI commit message generation using `pal` command
- **Cross-Repository Workflows**: Manage changes across multiple repositories with intelligent batch operations

## Prerequisites

To use GitS, you need:

- [git](https://git-scm.com/) - Required for all git operations
- [jq](https://stedolan.github.io/jq/) - Required for JSON parsing (Forgejo API)
- [curl](https://curl.se/) - Required for API calls (Forgejo)
- [gh](https://cli.github.com/) - Required for GitHub PR management and authentication
- [tea](https://gitea.com/gitea/tea) - Required for Gitea PR management and authentication
- Makefile (optional)

**Note:** `gh` and `tea` are only required for their respective platforms (GitHub and Gitea). Forgejo uses native API calls via `curl` and `jq`, so no additional CLI tools are needed for Forgejo.

## Installation

If you have `make` installed, you can simply run:

```bash
git clone https://github.com/ucli-tools/gits.git
cd gits
bash gits.sh install
```

This will copy the script to `/usr/local/bin/gits`, making it accessible system-wide. You'll need to enter your sudo password.

## Usage

After installation, you can use GitS with the following commands:

### Authentication
- `gits login` - Login to Forgejo, Gitea, or GitHub (supports custom Forgejo hosts)
- `gits logout` - Logout from Forgejo, Gitea, or GitHub

### Repository Management
- `gits repo create` - Create a new repository
  - Interactive prompts for:
    - Platform selection (Forgejo/Gitea/GitHub)
    - Repository name
    - Description
    - Privacy settings
- `gits repo delete` - Delete an existing repository
  - Interactive prompts for:
    - Platform selection (Forgejo/Gitea/GitHub)
    - Repository name
    - Confirmation

### Repository Setup
- `gits init` - Initialize a new Git repository
  - Platform selection (Forgejo/Gitea/GitHub, with custom self-hosted option)
  - Default branch: `main` for all platforms (can be overridden interactively)
  - Initial commit setup
  - Remote repository linking
- `gits clone <repo>` - Clone a repository
  - Supports full URLs or GitHub shorthand (org/repo)
  - Automatic directory switching

### Batch Repository Operations
- `gits clone-all [URL|username] [OPTIONS]` - Clone all repositories from a user or organization
  - **Smart Organization Detection**: Automatically detects organization vs user from URL format
  - **Multiple Platform Support**: Forgejo, Gitea, and GitHub with intelligent endpoint selection
  - **Parallel Cloning**: Configurable concurrent repository cloning (default: 5 concurrent)
  - **Enhanced Authentication**: Supports cached tokens and multiple authentication methods
  - **Cross-platform Field Mapping**: Handles GitHub (`cloneUrl`, `sshUrl`) and Gitea (`clone_url`, `ssh_url`) field differences
  - **Options:**
    - `--server URL` - Specify Gitea server URL (default: git.ourworld.tf)
    - `--no-parallel` - Disable parallel cloning for sequential processing
    - `--max-concurrent N` - Set maximum concurrent clones (default: 5)
    - `--help, -h` - Show comprehensive help information
  - **Examples:**
    ```bash
    # Clone repositories from a GitHub user
    gits clone-all myusername
    
    # Clone repositories from a Gitea organization with custom server
    gits clone-all git.ourworld.tf/myorg --server git.ourworld.tf
    
    # Clone repositories from a Forgejo organization (interactive platform selection)
    gits clone-all forge.ourworld.tf/myorg
    
    # Clone with parallel processing (faster for many repositories)
    gits clone-all myusername --max-concurrent 10
    
    # Sequential cloning (useful for debugging)
    gits clone-all myusername --no-parallel
    ```
  - **Authentication Features:**
    - Automatically detects and uses cached authentication tokens
    - Supports private and internal repository access
    - Clear prompts for tea CLI vs API token authentication

- `gits push-all [OPTIONS]` - Interactively add, commit, and push changes across all dirty repositories
  - **Smart Repository Detection**: Automatically finds all repositories with changes in current directory tree
  - **Multiple Operation Modes**:
    - Interactive mode: Prompts for each repository
    - Batch mode: Uses same commit message for all repositories
    - Dry run mode: Preview actions without executing
  - **AI-Powered Commit Messages**: Integration with `pal` command for intelligent commit messages
  - **Safety Features**: Skip confirmation prompts, individual repository control
  - **Options:**
    - `--dry-run, -n` - Show what would be done without executing
    - `--batch, -b` - Use same commit message for all repos
    - `--message, -m` - Default commit message (use with --batch)
    - `--yes, -y` - Skip confirmation prompts
    - `-p` - Use pal /commit for AI-generated commit messages (interactive)
    - `-py` - Use pal /commit -y for AI-generated commit messages (auto-commit)
    - `--help, -h` - Show help information
  - **Examples:**
    ```bash
    # Interactive mode - prompts for each repository
    gits push-all

    # Batch mode with custom message
    gits push-all --batch -m "Update documentation"

    # Preview what would be done
    gits push-all --dry-run

    # Use AI-generated commit messages
    gits push-all -py
    ```

- `gits diff-all [branch] [OPTIONS]` - Compare branches across all repositories
  - **Cross-Repository Branch Comparison**: Shows differences between branches across multiple repositories
  - **Remote Comparison Mode**: Compare local branches against their remote tracking branches
  - **Flexible Output Modes**: Summary statistics or detailed diff output
  - **Smart Branch Detection**: Checks if branches exist locally or remotely before comparison
  - **Colorized Output**: Clear visual indicators for repositories with/without differences
  - **Options:**
    - `--remote, -r` - Compare local branch vs its remote tracking branch (origin/branch)
    - `--no-fetch` - Skip fetching from remote (use with --remote)
    - `--suffix SUFFIX` - Compare default branch with default-branch+SUFFIX
    - `--detailed, -d` - Show full diff output (not just summary)
    - `--quiet, -q` - Only show repositories with differences
    - `--no-color` - Disable colored output
    - `--help, -h` - Show help information
  - **Examples:**
    ```bash
    # Compare local vs remote (check sync status)
    gits diff-all --remote              # Current branch vs origin/current-branch
    gits diff-all main --remote         # main vs origin/main
    gits diff-all --remote --no-fetch   # Skip fetch, use cached remote refs

    # Show summary of differences between branches
    gits diff-all main feature-branch

    # Use suffix mode for branch comparison
    gits diff-all --suffix -v1-work     # Compare main vs main-v1-work

    # Show detailed diff output for all repositories with differences
    gits diff-all main develop --detailed

    # Only show repositories that have differences
    gits diff-all main main-update --quiet
    ```

- `gits status-all [OPTIONS]` - Check git status across all repositories in directory tree
  - **Comprehensive Status Reporting**: Shows status for all repositories with intelligent filtering
  - **Multiple Display Modes**: Compact, detailed, and filtered views
  - **Performance Optimized**: Efficient directory traversal and status checking
  - **Options:**
    - `--all` - Show all repositories with status (default: only repos needing attention)
    - `--compact` - Show compact summary format
    - `--help, -h` - Show help information
  - **Examples:**
    ```bash
    # Show only repositories needing attention
    gits status-all
    
    # Show all repositories with detailed status
    gits status-all --all
    
    # Compact summary of all repositories
    gits status-all --all --compact
    ```

- `gits list-all` - List git repositories and their current branches
  - **Overview:** Shows each repository path, current branch, and simple status flags
  - **Status Flags:** `[modified]`, `[+N ahead]`, or `[clean]`
  - **Examples:**
    ```bash
    gits list-all
    ```

- `gits set-all <branch-name>` / `gits change-all <branch-name>` - Align branches across all repositories
  - **Purpose:** Ensure all repositories under the current directory tree are on the same branch
  - **Local Only:** Creates or switches local branches; pushing and upstream setup are still handled by `gits push-all`
  - **Options:**
    - `--dry-run, -n` - Show what would be done without executing
  - **Examples:**
    ```bash
    # Preview branch alignment
    gits set-all feature/my-progress-branch --dry-run

    # Align branches, then batch-commit and push
    gits set-all feature/my-progress-branch
    gits push-all --batch -m "Progress update"
    ```

- `gits fetch-all [OPTIONS]` - Fetch updates from all repositories in directory tree
  - **Parallel Fetching**: Simultaneously fetch from multiple repositories for better performance
  - **Flexible Output Control**: Quiet mode for scripting or verbose mode for monitoring
  - **Tag Management**: Optional tag fetching with `--no-tags` flag
  - **Configurable Concurrency**: Adjust parallel processing with `--max-concurrent`
  - **Options:**
    - `--no-parallel` - Disable parallel fetching for sequential processing
    - `--max-concurrent N` - Set maximum concurrent fetches (default: 5)
    - `--no-tags` - Skip fetching tags for faster operation
    - `-q, --quiet` - Suppress output except errors
    - `-v, --verbose` - Show detailed output with repository names
    - `--help, -h` - Show help information
  - **Examples:**
    ```bash
    # Parallel fetch with tags (default behavior)
    gits fetch-all
    
    # Sequential fetching for debugging
    gits fetch-all --no-parallel
    
    # Higher concurrency for large repository sets
    gits fetch-all --max-concurrent 10
    
    # Fast fetch without tags
    gits fetch-all --no-tags
    
    # Quiet mode for automation scripts
    gits fetch-all --quiet
    ```

- `gits pull-all [OPTIONS]` - Pull updates from all repositories with conflict detection
  - **Smart Conflict Detection**: Automatically detects and reports merge conflicts
  - **Multiple Merge Strategies**: Support for merge, rebase, and fast-forward only
  - **Auto-merge Options**: Optional automatic conflict resolution for simple cases
  - **Parallel Operation**: Process multiple repositories simultaneously
  - **Conflict Handling**: Options to abort on first conflict or continue processing
  - **Options:**
    - `--no-parallel` - Disable parallel pulling for sequential processing
    - `--max-concurrent N` - Set maximum concurrent pulls (default: 5)
    - `--strategy STRATEGY` - Merge strategy: `merge`, `rebase`, or `ff-only` (default: merge)
    - `--auto-merge` - Automatically resolve simple conflicts (use with caution)
    - `--abort-on-conflict` - Stop on first merge conflict encountered
    - `-v, --verbose` - Show detailed output with repository names and results
    - `--help, -h` - Show help information
  - **Examples:**
    ```bash
    # Standard pull with merge strategy (default)
    gits pull-all
    
    # Use rebase strategy for linear history
    gits pull-all --strategy rebase
    
    # Fast-forward only pulls (safest option)
    gits pull-all --strategy ff-only
    
    # Attempt auto-merge for simple conflicts
    gits pull-all --auto-merge
    
    # Stop immediately on first conflict
    gits pull-all --abort-on-conflict
    
    # High concurrency for many repositories
    gits pull-all --max-concurrent 10
    ```
  - **Performance Optimized**: Efficient directory traversal and status checking
  - **Options:**
    - `--all` - Show all repositories with status (default: only repos needing attention)
    - `--compact` - Show compact summary format
    - `--help, -h` - Show help information
  - **Examples:**
    ```bash
    # Show only repositories needing attention
    gits status-all
    
    # Show all repositories with detailed status
    gits status-all --all
    
    # Compact summary of all repositories
    gits status-all --all --compact
    ```

### Branch Management
- `gits new [branch-name]` - Create and switch to a new branch
  - Optional branch name argument
  - Interactive prompt if no name provided
- `gits delete [branch-name]` - Delete a branch
  - Optional branch name argument
  - Safe deletion with force option
  - Remote deletion option
  - Prevents default branch deletion

### Basic Git Operations
- `gits pull [branch]` - Update your local repository
  - Combines: checkout, stash, fetch, pull, status
  - Default branch is 'development'
- `gits push` - Stage and push changes
  - Stages all changes
  - Prompts for commit message
  - Sets upstream branch if needed
- `gits up` - Quick workflow with AI-generated commit
  - Executes: git add . && pal /commit -y && git push
  - Automatically stages all changes, commits with AI-generated message, and pushes
  - Requires pal command to be installed
- `gits commit` - Commit changes with a message
  - Prompts for commit message

### Pull Request Management
- `gits pr create` - Create a new pull request
  - Platform selection (GitHub/Gitea/Forgejo)
  - Custom title and description
  - Base and head branch selection
- `gits pr close` - Close an existing pull request
  - Shows current PRs
  - Interactive PR selection
- `gits pr merge` - Merge a pull request
  - Custom merge commit messages
  - Branch cleanup options
  - Platform-specific merge handling
- `gits pr create-all [OPTIONS]` - Create PRs across all repositories with differences
  - **Smart Diff Detection**: Only creates PRs for repositories with actual code differences
  - **Multiple Modes**:
    - Suffix mode: `--suffix -qr` creates PRs from `{default}-qr` → base branch
    - Explicit mode: `--head feature` creates PRs from `feature` → base branch
    - Auto mode: Uses current branch as head
  - **Options:**
    - `--title TITLE` - PR title (required)
    - `--base BRANCH` - Target branch to merge into (required)
    - `--suffix SUFFIX` - Branch suffix mode (e.g., `-qr`, `-feature`)
    - `--head BRANCH` - Explicit head branch name
    - `--body TEXT` - PR description
    - `--dry-run` - Preview what would be created without actually creating PRs
  - **Examples:**
    ```bash
    # Dry run to preview PR creation
    gits pr create-all --title "Feature X" --base main --suffix -qr --dry-run

    # Create PRs from main-qr branches to main
    gits pr create-all --title "QR Verification" --base main --suffix -qr

    # Create PRs with explicit head branch
    gits pr create-all --title "Update" --base main --head feature-branch

    # Create PRs with description
    gits pr create-all --title "Fix" --base main --body "Bug fixes"
    ```

- `gits pr merge-all [OPTIONS]` - Merge latest open PRs across all repositories
  - **Automatic PR Detection**: Finds the latest open PR in each repository
  - **Smart Skipping**: Skips repositories without open PRs
  - **Options:**
    - `--delete-branch, -d` - Delete head branch after merge
    - `--dry-run` - Preview what would be merged without actually merging
  - **Examples:**
    ```bash
    # Dry run to preview merges
    gits pr merge-all --dry-run

    # Merge all open PRs
    gits pr merge-all

    # Merge and delete branches
    gits pr merge-all --delete-branch
    ```

- `gits pr-latest` - Get the latest PR number for current repository
  - Works across all platforms (Forgejo/Gitea/GitHub)
  - Useful for scripting: `gits pr merge --pr-number $(gits pr-latest)`


### Issue Management
- `gits fetch-issues [OPTIONS]` - Fetch and display issues from the current repository
  - Supports both public and private repositories
  - **Authentication Methods:**
    - For private Gitea repositories: tea CLI login or API token
    - For GitHub: Uses gh CLI authentication (automatic)
  - **Options:**
    - `--state STATE` - Filter by state: open, closed, all (default: open)
    - `--format FORMAT` - Output format: display, json (default: display)
  - **Examples:**
    ```bash
    # Fetch open issues from current repository
    gits fetch-issues
    
    # Fetch all issues (open and closed)
    gits fetch-issues --state all
    
    # Fetch issues in JSON format
    gits fetch-issues --format json
    
    # Access private repository issues (with authentication prompt)
    gits fetch-issues --state all
    # When prompted:
    # - Choose "1" to use tea CLI login
    # - Choose "2" to provide API token manually
    ```

- `gits fetch-issues-all [OPTIONS]` - Fetch and display issues from **all repositories under the current directory tree**
  - Uses the same platform detection and authentication as `gits fetch-issues`
  - Iterates over each git repository (found via `.git` directories) and runs `gits fetch-issues` inside it
  - **Options:**
    - `--state STATE` - Filter by state: open, closed, all (default: open)
    - `--format FORMAT` - Output format: display, json (default: display)
  - **Examples:**
    ```bash
    # Fetch open issues for all repositories under the current directory
    gits fetch-issues-all

    # Fetch all issues in JSON format across all repositories
    gits fetch-issues-all --state all --format json
    ```

- `gits save-issues [OPTIONS]` - Save issues to files in organized directory
  - Supports both public and private repositories
  - **Authentication Methods:**
    - For private Gitea repositories: tea CLI login or API token
    - For GitHub: Uses gh CLI authentication (automatic)
  - **Options:**
    - `--state STATE` - Filter by state: open, closed, all (default: open)
    - `--format FORMAT` - File format: markdown, json, plain (default: markdown)
  - **Output Structure:**
    - Creates directory: `./repo-name-issues/`
    - File naming: `ISSUE_NUMBER-title.md` (or `.json` for JSON format)
    - Automatically syncs: removes stale files for resolved issues
  - **Examples:**
    ```bash
    # Save open issues as markdown files
    gits save-issues
    
    # Save all issues in JSON format
    gits save-issues --state all --format json
    
    # Save closed issues
    gits save-issues --state closed
    
    # Access private repository issues (with authentication prompt)
    gits save-issues
    # When prompted:
    # - Choose "1" to use tea CLI login
    # - Choose "2" to provide API token manually
    ```

**Authentication for Private Repositories:**

For Gitea private repositories, you'll be prompted to authenticate:
1. **Option 1: Use tea CLI (recommended)**
   - Requires tea CLI to be installed and configured
   - Run `gits login` first to set up authentication
   - Automatically retrieves and caches your token for future use
   
2. **Option 2: Manual API Token**
   - Provide your Gitea API token directly
   - Token is automatically cached in `~/.config/gits/tokens.conf`
   - Won't need to re-enter on subsequent commands
   - Token can be generated from Gitea settings

**Token Caching:**
- Tokens are securely stored in `~/.config/gits/tokens.conf` (permissions: 600)
- Cached tokens are automatically used on subsequent commands
- You'll be prompted to confirm using cached token
- Manage tokens with `gits token` command (see Token Management section below)

For GitHub repositories, authentication is automatic via `gh` CLI (if logged in via `gh auth login`).

### Commit Management
- `gits revert <number>` - Revert to previous commits
  - Specify number of commits to revert
  - Stages changes without committing
- `gits unrevert` - Cancel the last revert operation
  - Useful for accidental reverts

### Token Management
- `gits token list` - List all cached authentication tokens
  - Shows masked tokens for security
  - Displays storage location
- `gits token show [server]` - Show cached token for specific server
  - Default server: git.ourworld.tf
  - Token is masked for security
- `gits token clear [server]` - Clear cached token
  - Removes stored token for server
  - Will prompt for authentication on next command

### Installation Management
- `bash gits.sh install` - Install GitS system-wide (`cd` in the Gits CLI repo)
- `gits uninstall` - Remove GitS from the system
- `gits help` - Display detailed help information

### Platform-Specific Features

#### Forgejo
- Default server: forge.ourworld.tf
- Native API integration (no external CLI required)
- Token-based authentication
- **API Token Generation:**
  1. Navigate to your Forgejo instance (e.g., https://forge.ourworld.tf)
  2. Go to Settings → Applications → Generate New Token
  3. Give it a descriptive name (e.g., "GitS CLI")
  4. Select scopes: `repo` (for full repository access including PRs)
  5. Copy the generated token (you won't see it again)
  6. Use `gits login` and select Forgejo to save your token
- **Token Management:**
  - View cached tokens: `gits token list`
  - Clear cached token: `gits token clear forge.ourworld.tf`
  - Tokens stored in: `~/.config/gits/tokens.conf` (secure, 600 permissions)
- **Supported Operations:**
  - `gits clone-all forge.ourworld.tf/username` - Clone all repositories
  - `gits fetch-issues` - Fetch issues from Forgejo repositories
  - `gits save-issues` - Save issues to local files
  - `gits pr create` - Create pull requests via native API
  - `gits pr merge --pr-number N` - Merge pull requests via native API
  - `gits pr close` - Close pull requests via native API
  - `gits pr-latest` - Get the latest PR number

#### Gitea
- Default server: git.ourworld.tf
- Default branch: main
- Custom merge commit messages
- Manual branch cleanup options
- **API Token Generation:**
  1. Navigate to your Gitea instance (e.g., https://git.ourworld.tf)
  2. Go to Settings → Applications → Generate New Token
  3. Give it a descriptive name (e.g., "GitS CLI")
  4. Select scopes: `read:repository`, `read:issue` (minimum required)
  5. Copy the generated token (you won't see it again)
  6. Use this token when prompted by `gits fetch-issues` or `gits save-issues`
  7. Token will be automatically cached for future use
- **Token Management:**
  - View cached tokens: `gits token list`
  - Clear cached token: `gits token clear git.ourworld.tf`
  - Tokens stored in: `~/.config/gits/tokens.conf` (secure, 600 permissions)

#### GitHub
- Default branch: main
- Automatic branch deletion after PR merge
- GitHub CLI integration
- Enhanced PR descriptions
- **Authentication:** Automatically handled via `gh auth login`

For detailed usage information and examples, run `gits help`.

## Issues and Feature Requests

We use GitHub issues to track bugs and feature requests. If you encounter any problems or have ideas for improvements:

- **Bugs**: If you find a bug, please open an issue on our GitHub repository. Provide as much detail as possible, including your operating system, bash version, and steps to reproduce the bug.

- **Feature Requests**: Have an idea to make GitS even better? We'd love to hear it! Open an issue and label it as a feature request. Describe the feature you'd like to see, why you need it, and how it should work.

- **Questions**: If you have questions about using GitS, feel free to open an issue as well. We're here to help!

To create an issue, visit the [Issues page](https://github.com/Mik-TF/gits/issues) of our GitHub repository.

## Contributing

Contributions are welcome! If you'd like to contribute:

1. Fork the repository
2. Create your feature branch (`git checkout -b development_some_details`)
3. Commit your changes (`git commit -m 'Write a commit message'`)
4. Push to the branch (`git push origin development_some_details`)
5. Open a Pull Request

## Using Makefile

For development purpose, we set 3 basic Makefile commands that are useful to run within the repo if you are working on an updated version of Gits.

- Build
  ```
  make build
  ```
- Rebuild
  ```
  make rebuild
  ```
- Uninstall
  ```
  make delete
  ```

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.
