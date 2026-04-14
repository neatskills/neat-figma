#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dst="$HOME/.claude/skills"

usage() {
  echo "Usage: $0 {install|uninstall}" >&2
  exit 1
}

[ $# -eq 0 ] && usage
command="$1"

case "$command" in
  install|uninstall) ;;
  *) usage ;;
esac

[ "$command" = "install" ] && mkdir -p "$dst"

for src in "$root"/neat-figma-*/; do
  [ ! -d "$src" ] && continue
  [ ! -f "$src/SKILL.md" ] && continue

  name=$(grep '^name:' "$src/SKILL.md" | head -1 | sed 's/^name: *//')
  if [ -z "$name" ]; then
    echo "ERROR: no name in $src/SKILL.md frontmatter" >&2
    continue
  fi

  src="${src%/}"  # remove trailing slash

  case "$command" in
    install)
      [ -L "$dst/$name" ] && [ "$(readlink "$dst/$name")" = "$src" ] && echo "INFO: $name already installed - skipping" && continue
      [ -e "$dst/$name" ] && echo "WARN: $dst/$name already exists — skipping" && continue
      ln -s "$src" "$dst/$name" && echo "INFO: $name installed"
      ;;
    uninstall)
      if [ -L "$dst/$name" ] && [ "$(readlink "$dst/$name")" = "$src" ]; then
        rm "$dst/$name" && echo "INFO: $name uninstalled"
      elif [ -e "$dst/$name" ] || [ -L "$dst/$name" ]; then
        echo "WARN: $name exists but was not installed by this project — skipping"
      else
        echo "INFO: $name not installed — skipping"
      fi
      ;;
  esac
done
