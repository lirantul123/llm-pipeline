#!/usr/bin/env bash
# Manual install of the llm-pipeline skill (for people not using the plugin marketplace).
# Usage: ./install.sh [--link] [--project]
#   --link     symlink instead of copy (repo edits apply after a Claude Code restart)
#   --project  install into ./.claude/skills of the current directory instead of ~/.claude/skills
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$repo_dir/skills/llm-pipeline"
mode=copy
dest_root="$HOME/.claude/skills"

for arg in "$@"; do
  case "$arg" in
    --link) mode=link ;;
    --project) dest_root="$(pwd)/.claude/skills" ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

dest="$dest_root/llm-pipeline"

if [ ! -f "$src/SKILL.md" ]; then
  echo "error: $src/SKILL.md not found. Run this from a clone of the repo." >&2
  exit 1
fi

if [ -f "$dest_root/llm-pipeline.md" ]; then
  echo "note: found an old flat install at $dest_root/llm-pipeline.md. Claude Code ignores it; remove it with:"
  echo "      rm \"$dest_root/llm-pipeline.md\""
fi

if [ -e "$dest" ] || [ -L "$dest" ]; then
  echo "error: $dest already exists. Remove it first: rm -rf \"$dest\"" >&2
  exit 1
fi

mkdir -p "$dest_root"
if [ "$mode" = link ]; then
  ln -s "$src" "$dest"
else
  cp -R "$src" "$dest"
fi

echo "Installed ($mode): $dest"
echo "Restart Claude Code, then run: /llm-pipeline <your task>"
