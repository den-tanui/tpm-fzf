#!/usr/bin/env bash

# Utility functions for tpm_fzf_v2

# Escape string for safe fzf usage
escape_for_fzf() {
  local str="$1"
  printf '%s' "$str" | sed 's/"/\\"/g'
}

# Ensure directory exists, create if missing
ensure_dir_exists() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir" 2>/dev/null
  fi
}

# Run git clone or gh repo clone
run_git_clone() {
  local url="$1"
  local dest_dir="$2"
  local git_cmd="${3:-git clone}"

  if [ "$git_cmd" = "gh repo clone" ]; then
    # Use gh CLI if available
    if command -v gh &>/dev/null; then
      gh repo clone "$url" "$dest_dir" -- --source --single-branch 2>/dev/null
    else
      # Fallback to git
      git clone "$url" "$dest_dir" --single-branch 2>/dev/null
    fi
  else
    # Default to git clone
    GIT_TERMINAL_PROMPT=0 git clone "$url" "$dest_dir" --single-branch 2>/dev/null
  fi
}

# Check if file contains pattern
file_contains() {
  local file="$1"
  local pattern="$2"
  grep -q "$pattern" "$file" 2>/dev/null
}

# Get git remote URL from local repo
get_git_remote_url() {
  local dir="$1"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" remote get-url origin 2>/dev/null
  fi
}

# Check if git repo has updates
check_git_updates() {
  local dir="$1"
  if [ -d "$dir/.git" ]; then
    local current_branch
    current_branch=$(git -C "$dir" branch --show-current 2>/dev/null)
    if [ -n "$current_branch" ]; then
      git -C "$dir" fetch origin "$current_branch" 2>/dev/null
      local behind
      behind=$(git -C "$dir" rev-list "origin/$current_branch..HEAD" --count 2>/dev/null)
      [ "$behind" -gt 0 ] && echo 1 || echo 0
    fi
  fi
}

# Get current version tag from git
get_git_version() {
  local dir="$1"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" describe --tags --abbrev=0 2>/dev/null
  fi
}

# Get file extension
get_file_extension() {
  local file="$1"
  echo "${file##*.}"
}

# Check if command exists
command_exists() {
  command -v "$1" &>/dev/null
}

# Trim whitespace from string
trim() {
  local var="$*"
  var="${var#"${var%%%%*}"}"
  var="${var%"${var##*}"}"
  echo "$var"
}

# Join array with delimiter
join_by() {
  local IFS="$1"
  shift
  echo "$*"
}