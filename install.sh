#!/usr/bin/env bash
# install.sh — consensus-review one-line installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/NB3025/consensus-review/main/install.sh | bash -s <tool>
#
# Supported tools:
#   kiro         → ~/.kiro/skills/consensus-review
#   kiro-local   → ./.kiro/skills/consensus-review
#   claude-code  → ~/.claude/skills/consensus-review
#   claude-local → ./.claude/skills/consensus-review
#   cursor       → ./.cursor/skills/consensus-review
#   codex        → ~/.agents/skills/consensus-review
#   codex-local  → ./.agents/skills/consensus-review
#   gemini       → ./.gemini/skills/consensus-review
#   opencode     → ./.opencode/skills/consensus-review
#   copilot      → ./.github/skills/consensus-review
#
# Examples:
#   curl -fsSL .../install.sh | bash -s kiro
#   curl -fsSL .../install.sh | bash -s claude-code
#   curl -fsSL .../install.sh | bash -s kiro-local
#
# Environment variables:
#   CONSENSUS_REVIEW_REF   Branch/tag to install (default: main)
#   CONSENSUS_REVIEW_REPO  Repo URL (default: https://github.com/NB3025/consensus-review)

set -euo pipefail

REPO="${CONSENSUS_REVIEW_REPO:-https://github.com/NB3025/consensus-review}"
REF="${CONSENSUS_REVIEW_REF:-main}"
SKILL_NAME="consensus-review"

# Colors
if [ -t 1 ]; then
  C_BOLD=$'\033[1m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'; C_BLUE=$'\033[34m'; C_RESET=$'\033[0m'
else
  C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BLUE=""; C_RESET=""
fi

say() { printf "%s\n" "$*"; }
info() { say "${C_BLUE}▶${C_RESET} $*"; }
ok()   { say "${C_GREEN}✓${C_RESET} $*"; }
warn() { say "${C_YELLOW}!${C_RESET} $*"; }
err()  { say "${C_RED}✗${C_RESET} $*" >&2; }

usage() {
  cat <<EOF
${C_BOLD}consensus-review installer${C_RESET}

Usage:
  curl -fsSL ${REPO}/raw/${REF}/install.sh | bash -s <tool>

Supported tools:
  kiro         Kiro (global)       → ~/.kiro/skills/${SKILL_NAME}
  kiro-local   Kiro (workspace)    → ./.kiro/skills/${SKILL_NAME}
  claude-code  Claude Code (global)→ ~/.claude/skills/${SKILL_NAME}
  claude-local Claude Code (proj)  → ./.claude/skills/${SKILL_NAME}
  cursor       Cursor              → ./.cursor/skills/${SKILL_NAME}
  codex        Codex CLI (user)    → ~/.agents/skills/${SKILL_NAME}
  codex-local  Codex CLI (proj)    → ./.agents/skills/${SKILL_NAME}
  gemini       Gemini CLI (proj)   → ./.gemini/skills/${SKILL_NAME}
  opencode     OpenCode (proj)     → ./.opencode/skills/${SKILL_NAME}
  copilot      GitHub Copilot      → ./.github/skills/${SKILL_NAME}

Examples:
  curl -fsSL ${REPO}/raw/${REF}/install.sh | bash -s kiro
  curl -fsSL ${REPO}/raw/${REF}/install.sh | bash -s claude-code
EOF
}

# Resolve install target
resolve_target() {
  case "$1" in
    kiro)         echo "$HOME/.kiro/skills/$SKILL_NAME" ;;
    kiro-local)   echo "./.kiro/skills/$SKILL_NAME" ;;
    claude|claude-code) echo "$HOME/.claude/skills/$SKILL_NAME" ;;
    claude-local) echo "./.claude/skills/$SKILL_NAME" ;;
    cursor)       echo "./.cursor/skills/$SKILL_NAME" ;;
    codex)        echo "$HOME/.agents/skills/$SKILL_NAME" ;;
    codex-local)  echo "./.agents/skills/$SKILL_NAME" ;;
    gemini)       echo "./.gemini/skills/$SKILL_NAME" ;;
    opencode)     echo "./.opencode/skills/$SKILL_NAME" ;;
    copilot)      echo "./.github/skills/$SKILL_NAME" ;;
    *)            return 1 ;;
  esac
}

main() {
  local tool="${1:-}"

  if [ -z "$tool" ] || [ "$tool" = "-h" ] || [ "$tool" = "--help" ]; then
    usage
    exit 0
  fi

  local target
  if ! target="$(resolve_target "$tool")"; then
    err "Unknown tool: $tool"
    say ""
    usage
    exit 1
  fi

  # Pre-flight
  for dep in curl tar mkdir; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      err "Required command not found: $dep"
      exit 1
    fi
  done

  info "Installing ${C_BOLD}${SKILL_NAME}${C_RESET} for ${C_BOLD}${tool}${C_RESET}"
  info "Source: ${REPO} (ref: ${REF})"
  info "Target: ${target}"

  # Confirm if target already exists
  if [ -e "$target" ]; then
    warn "Target already exists: $target"
    if [ -t 0 ]; then
      printf "Overwrite? [y/N] "
      read -r reply
      case "$reply" in
        y|Y|yes) ;;
        *) err "Aborted."; exit 1 ;;
      esac
    else
      warn "Non-interactive mode: overwriting existing target."
    fi
    rm -rf "$target"
  fi

  # Download tarball from GitHub
  # (global so cleanup can see it; `local` in main() hides it from exit handler)
  tmpdir="$(mktemp -d)"

  local tarball_url="${REPO}/archive/refs/heads/${REF}.tar.gz"
  # Fallback: if ref looks like a tag/sha, tarball path differs, but heads first
  info "Downloading ${tarball_url}"
  if ! curl -fsSL "$tarball_url" -o "$tmpdir/skill.tar.gz"; then
    # Try tag/ref path
    tarball_url="${REPO}/archive/${REF}.tar.gz"
    info "Retrying with ${tarball_url}"
    curl -fsSL "$tarball_url" -o "$tmpdir/skill.tar.gz"
  fi

  info "Extracting"
  tar -xzf "$tmpdir/skill.tar.gz" -C "$tmpdir"

  # Find the extracted root (one top-level dir from GitHub tarball)
  local extracted_root
  extracted_root="$(find "$tmpdir" -maxdepth 1 -mindepth 1 -type d ! -name 'skill.tar.gz*' | head -1)"
  if [ -z "$extracted_root" ] || [ ! -f "$extracted_root/SKILL.md" ]; then
    err "Unexpected tarball structure (no SKILL.md at root)."
    exit 1
  fi

  # Prepare target parent
  mkdir -p "$(dirname "$target")"

  # Copy skill files (excluding repo-only files like .git, install.sh itself, tests)
  info "Installing files"
  mkdir -p "$target"
  # Rsync would be cleaner, but keep dependency-free
  (
    cd "$extracted_root"
    # Include the files users need:
    for item in SKILL.md LICENSE README.md prompts references examples; do
      if [ -e "$item" ]; then
        cp -R "$item" "$target/"
      fi
    done
  )

  ok "Installed ${SKILL_NAME} to ${C_BOLD}${target}${C_RESET}"
  say ""
  case "$tool" in
    kiro|kiro-local)
      info "Next: open Kiro and check the skill in 'AGENT STEERING & SKILLS'."
      ;;
    claude|claude-code|claude-local)
      info "Next: run 'claude /skills list' to verify, then try 'review this doc' on a document."
      ;;
    cursor)
      warn "Cursor: ensure Nightly channel + Agent Skills enabled (Settings → Beta / Rules)."
      ;;
    gemini)
      warn "Gemini CLI: install preview via 'npm i -g @google/gemini-cli@preview', then /settings → enable Skills."
      ;;
  esac
  say ""
  ok "Try it: share a document with your agent and ask '리뷰해줘' or 'review this document'."

  # Explicit cleanup (avoids trap + set -u interaction under `curl | bash`)
  rm -rf "${tmpdir:-}"
}

main "$@"
