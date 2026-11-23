#!/bin/sh
# The whole release (make release): checks, version, commit, push, pull request, merge, and a check of what is live.
# Usage: M="a tighter snare" [V=0.0.9] [DRY=1] tools/release.sh
#   M    what is new, for the commit and the pull request (required)
#   V    the version (default: the last number of the version on main + 1)
#   DRY  1 = only the checks and the builds, nothing is changed, committed or published
# It stops at the first problem. Run it again with the same V and M: it goes on where it stopped.
set -e
say()  { echo "== $*"; }
stop() { echo "release: $*" >&2; exit 1; }

site=https://ddecoene.github.io/raster-rumble
raw=https://raw.githubusercontent.com/DDecoene/raster-rumble/play
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

say "checks"
[ -n "$M" ] || stop 'say what is new: make release M="a tighter snare"'
for tool in acme c1541 gh git curl; do command -v $tool >/dev/null || stop "$tool is not installed"; done
[ "$(git branch --show-current)" = dev ] || stop "not on dev"
[ -z "$(git status --porcelain)" ] || stop "there are changes that are not committed (git status)"
git fetch -q origin
git merge-base --is-ancestor origin/dev HEAD || stop "dev is behind origin/dev, pull first"
git merge-base --is-ancestor origin/main HEAD || stop "dev does not have main, run: git pull --no-rebase origin main"
git show origin/main:src/version.asm > "$tmp/main.asm"
old=$(tools/version.sh "$tmp/main.asm")
[ -n "$V" ] || V=$(echo "$old" | awk -F. '{ print $1 "." $2 "." $3 + 1 }')
echo "$V" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || stop "$V is not a version like 0.0.9"
[ "$V" = "$old" ] || [ "$(printf '%s\n%s\n' "$old" "$V" | sort -V | tail -n 1)" = "$V" ] || stop "$V is lower than $old on main"
say "main has $old, this is $V: $M"

if [ "$V" != "$old" ]; then
  if [ "$(git rev-list --count origin/main..HEAD)" = 0 ]; then stop "nothing new on dev"; fi
  say "build"
  make -B dist site >"$tmp/log" 2>&1 || { cat "$tmp/log"; stop "the build failed"; }
  if [ "$DRY" = 1 ]; then say "dry run: all good, nothing published"; exit 0; fi

  if [ "$(tools/version.sh)" != "$V" ]; then
    say "version $V"
    sed "s/!scr \"v[0-9][0-9.]*\"/!scr \"v$V\"/" src/version.asm > "$tmp/version.asm"
    cat "$tmp/version.asm" > src/version.asm
    [ "$(tools/version.sh)" = "$V" ] || stop "could not change src/version.asm"
    git commit -qm "Version $V: $M" src/version.asm
  fi

  say "push and pull request"
  git push -q origin dev
  pr=$(gh pr list --base main --head dev --state open --json number -q '.[0].number')
  if [ -z "$pr" ]; then
    { echo "What is new: $M"; echo; git log --no-merges --reverse --format='- %s' origin/main..HEAD; } > "$tmp/body"
    gh pr create --base main --head dev --title "Version $V: $M" --body-file "$tmp/body"
    pr=$(gh pr list --base main --head dev --state open --json number -q '.[0].number')
  fi

  say "wait for the check of pull request $pr"
  head=$(git rev-parse HEAD)
  n=0
  until [ "$(gh pr view "$pr" --json headRefOid -q .headRefOid)" = "$head" ] && gh pr checks "$pr" 2>&1 | grep -q '^check'; do
    n=$((n + 1)); [ $n -lt 30 ] || stop "the check did not start"
    sleep 3
  done
  gh pr checks "$pr" --watch --interval 5 >/dev/null || stop "the check failed: gh pr checks $pr"
  gh pr merge "$pr" --merge --match-head-commit "$head"
  git fetch -q origin
elif [ "$DRY" = 1 ]; then
  say "dry run: $V is on main already"; exit 0
fi

say "wait for the release workflow"
sha=$(git rev-parse origin/main)
n=0
run=
while [ -z "$run" ]; do
  run=$(gh run list --workflow Release --commit "$sha" --limit 1 --json databaseId -q '.[0].databaseId')
  n=$((n + 1)); [ $n -lt 30 ] || stop "the release workflow did not start"
  [ -n "$run" ] || sleep 3
done
gh run watch "$run" --exit-status >/dev/null || stop "the release workflow failed: gh run view $run"

say "check what is live"
gh release download "v$V" --dir "$tmp" --pattern "raster-rumble-v$V.*"
[ -s "$tmp/raster-rumble-v$V.d64" ] || stop "the release has no .d64"
make -B >"$tmp/log" 2>&1 || { cat "$tmp/log"; stop "the build failed"; }
cmp "$tmp/raster-rumble-v$V.prg" build/raster-rumble.prg || stop "the released .prg is not this build"
# GitHub's caches can lag behind a little (raw files up to five minutes), so try for a while
live() {
  curl -fsS "$site/raster-rumble-v$V.prg" -o "$tmp/live.prg" && cmp -s "$tmp/live.prg" build/raster-rumble.prg &&
  curl -fsS "$site/" | grep -q "v$V" && curl -fsS "$site/play/" | grep -q "raster-rumble-v$V.prg" &&
  curl -fsS "$raw/README.txt" | grep -q "v$V,"
}
n=0
until live 2>/dev/null; do
  n=$((n + 1)); [ $n -lt 36 ] || stop "the site or the play branch does not show v$V"
  sleep 10
done

say "bring dev up to date with main"
git merge -q --ff-only origin/main 2>/dev/null || git merge -q --no-edit origin/main
git push -q origin dev
say "v$V is released and live: $site/"
