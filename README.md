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
  - [Branch Management](#branch-management)
  - [Basic Git Operations](#basic-git-operations)
  - [Pull Request Management](#pull-request-management)
  - [Issue Management](#issue-management)
  - [Commit Management](#commit-management)
  - [Installation Management](#installation-management)
  - [Platform-Specific Features](#platform-specific-features)
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
- **Pull Request Management**: Create, close, and merge PRs for both GitHub and Gitea.
- **Platform Authentication**: Login and logout functionality for both GitHub and Gitea.
- **Issue Management**: Fetch and save issues from both public and private repositories with flexible authentication options.
- **Branch Management**: Create, delete, and manage branches easily.
- **Repository Initialization**: Initialize a new Git repository and push it to GitHub.
- **Commit Management**: Revert to previous commits and undo reverts.
- **Repository Cloning**: Easily clone repositories and switch to their directory.
- **Easy Installation**: Simple install and uninstall process.
- **User-Friendly**: Colorized output and helpful error messages.
- **Repository Management**: Create and delete repositories on both GitHub and Gitea
- **Multiple Platform Support**: Seamless integration with both GitHub and Gitea
- **Branch Creation**: Create new branches with custom names
- **Default Branch Handling**: Automatic detection and handling of default branches
- **Force Delete Options**: Safe branch deletion with force delete capabilities
- **Pull Request Workflow**: Complete PR lifecycle management including creation, closing, and merging
- **Merge Commit Control**: Custom merge commit messages and titles
- **Branch Cleanup**: Automatic branch cleanup options after PR merges
- **Private Repository Support**: Full support for private repositories with dual authentication methods (tea CLI or API token)

## Prerequisites

To use GitS, you need:

- [git](https://git-scm.com/) - Required for all git operations
- [gh](https://cli.github.com/) - Required for GitHub PR management and authentication
- [tea](https://gitea.com/gitea/tea) - Required for Gitea PR management and authentication
- Makefile (optional)

Both `gh` and `tea` are only required if you plan to use their respective platform features.

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
- `gits login` - Login to GitHub or Gitea
- `gits logout` - Logout from GitHub or Gitea

### Repository Management
- `gits repo create` - Create a new repository
  - Interactive prompts for:
    - Platform selection (GitHub/Gitea)
    - Repository name
    - Description
    - Privacy settings
- `gits repo delete` - Delete an existing repository
  - Interactive prompts for:
    - Platform selection
    - Repository name
    - Confirmation

  ### Repository Setup
  - `gits init` - Initialize a new Git repository
    - Platform selection (GitHub/Gitea)
    - Default branch configuration
    - Initial commit setup
    - Remote repository linking
  - `gits clone <repo>` - Clone a repository
    - Supports full URLs or GitHub shorthand (org/repo)
    - Automatic directory switching

    
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
  - Platform selection (GitHub/Gitea)
  - Custom title and description
  - Base and head branch selection
- `gits pr close` - Close an existing pull request
  - Shows current PRs
  - Interactive PR selection
- `gits pr merge` - Merge a pull request
  - Custom merge commit messages
  - Branch cleanup options
  - Platform-specific merge handling


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
   - Automatically retrieves your stored token
   
2. **Option 2: Manual API Token**
   - Provide your Gitea API token directly
   - Token can be generated from Gitea settings
   - Useful if tea CLI is not available

For GitHub repositories, authentication is automatic via `gh` CLI (if logged in via `gh auth login`).

### Commit Management
- `gits revert <number>` - Revert to previous commits
  - Specify number of commits to revert
  - Stages changes without committing
- `gits unrevert` - Cancel the last revert operation
  - Useful for accidental reverts

### Installation Management
- `bash gits.sh install` - Install GitS system-wide (`cd` in the Gits CLI repo)
- `gits uninstall` - Remove GitS from the system
- `gits help` - Display detailed help information

### Platform-Specific Features

#### Gitea
- Default server: git.ourworld.tf
- Default branch: development
- Custom merge commit messages
- Manual branch cleanup options
- **API Token Generation:**
  1. Navigate to your Gitea instance (e.g., https://git.ourworld.tf)
  2. Go to Settings → Applications → Generate New Token
  3. Give it a descriptive name (e.g., "GitS CLI")
  4. Select scopes: `read:repository`, `read:issue` (minimum required)
  5. Copy the generated token (you won't see it again)
  6. Use this token when prompted by `gits fetch-issues` or `gits save-issues`

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