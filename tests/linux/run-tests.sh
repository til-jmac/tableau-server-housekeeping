#!/bin/bash
# Runs the Linux housekeeping scripts against the stub tsm and asserts exit codes and files.
# Needs: sudo, group tsmadmin containing the current user, and an existing /etc/profile.d/tableau_server.sh
# (the workflow arranges these). Scripts run as the current user with primary group tsmadmin.
set -u

repo="$(cd "$(dirname "$0")/../.." && pwd)"
stubs="$repo/tests/stubs/linux"
backup="$repo/linux/tableau-server-backup.bash"
logs="$repo/linux/tableau-server-log-archive.bash"
cleanup="$repo/linux/tableau-server-cleanup.bash"
root="$(mktemp -d)"
today="$(date +%Y-%m-%d)"
failed=0
current=""

# run_member <cmd...>: run as the current user in group tsmadmin with the stub tsm first on PATH
run_member() {
  sudo -u "$USER" -g tsmadmin env "PATH=$stubs:$PATH" "STUB_BACKUP_DIR=$b" "STUB_ARCHIVE_DIR=$a" "STUB_FAIL=${STUB_FAIL:-}" "$@"
}

case_start() {
  [ -n "$current" ] && echo "::endgroup::"
  current="$1"
  echo "::group::$1"
  b="$root/$1/${2:-backups}"
  a="$root/$1/archive"
  mkdir -p "$b" "$a"
  unset STUB_FAIL
}

check() { # check <description> <command...>
  local msg="$1"; shift
  if "$@"; then echo "  ok:   $msg"; else echo "  FAIL: $msg"; failed=$((failed + 1)); echo "        ($current)"; fi
}
expect() { # expect <description> <want> <got>
  check "$1 exit code is $2 (got $3)" [ "$3" -eq "$2" ]
}
has() { [ -e "$1" ]; }
hasnt() { [ ! -e "$1" ]; }
empty_dir() { [ -z "$(ls -A "$1")" ]; }
runrc() { run_member "$@" >&2; local rc=$?; echo "  -> exit $rc" >&2; echo "$rc"; }
aged() { # aged <file> <touch -d date>
  echo x > "$1"; touch -d "$2" "$1"
}

check "stub tsm is first on PATH" [ "$(PATH="$stubs:$PATH" command -v tsm)" = "$stubs/tsm" ]
check "current user is a member of tsmadmin" bash -c 'getent group tsmadmin | grep -qw "$(id -un)"'

# group check: not root and not in tsmadmin gives exit 1
case_start group
sudo setpriv --reuid="$(id -u)" --regid="$(id -g)" --clear-groups env "PATH=$stubs:$PATH" "STUB_BACKUP_DIR=$b" "STUB_ARCHIVE_DIR=$a" "$backup" >&2
expect "backup as non-member" 1 $?

# backup
case_start backup-normal
expect "first run" 0 "$(runrc "$backup")"
check "backup file exists" has "$b/tableau-server-backup-$today.tsbak"
check "settings file exists" has "$b/tableau-server-backup-settings-$today.json"
expect "second run same day (stub refuses to overwrite)" 7 "$(runrc "$backup")"
check "backup survives failed second run" has "$b/tableau-server-backup-$today.tsbak"

case_start backup-retention
n="tableau-server-backup"
yesterday="$(date -d yesterday +%Y-%m-%d)"
aged "$b/$n-2020-01-01.tsbak" "5 days ago"
aged "$b/$n-2020-01-02.tsbak" "2 days ago"
aged "$b/$n-settings-2020-01-01.json" "5 days ago"
aged "$b/$n-weekly-2020-01-01.tsbak" "5 days ago"
aged "$b/unrelated.txt" "5 days ago"
aged "$b/$n-$yesterday.tsbak" "1 day ago"
aged "$b/$n-settings-$yesterday.json" "1 day ago"
mkdir "$b/$n-2019-12-31.tsbak"
aged "$b/$n-2019-12-31.tsbak/inner.txt" "5 days ago"
touch -d "5 days ago" "$b/$n-2019-12-31.tsbak"
expect "run with default 2 day retention" 0 "$(runrc "$backup")"
check "5 day old backup deleted" hasnt "$b/$n-2020-01-01.tsbak"
check "2 day old backup deleted (N or more days old)" hasnt "$b/$n-2020-01-02.tsbak"
check "old settings deleted" hasnt "$b/$n-settings-2020-01-01.json"
check "1 day old backup kept" has "$b/$n-$yesterday.tsbak"
check "1 day old settings kept" has "$b/$n-settings-$yesterday.json"
check "weekly file kept" has "$b/$n-weekly-2020-01-01.tsbak"
check "unrelated file kept" has "$b/unrelated.txt"
check "directory named like old backup kept" has "$b/$n-2019-12-31.tsbak/inner.txt"
check "todays backup kept" has "$b/$n-$today.tsbak"

case_start backup-failures
STUB_FAIL=version; expect "tsm version failing" 3 "$(runrc "$backup")"
STUB_FAIL=config; expect "configuration get failing" 4 "$(runrc "$backup")"
STUB_FAIL=""
saved="$b"; b=""; expect "empty backup path" 5 "$(runrc "$backup")"; b="$saved"
STUB_FAIL=export; expect "settings export failing" 6 "$(runrc "$backup")"
check "backup exists when only settings export failed" has "$b/tableau-server-backup-$today.tsbak"
rm -f "$b"/*
STUB_FAIL=backup; expect "backup failing" 7 "$(runrc "$backup")"
check "no settings export after failed backup" hasnt "$b/tableau-server-backup-settings-$today.json"
aged "$b/tableau-server-backup-2020-01-01.tsbak" "5 days ago"
expect "backup failing again" 7 "$(runrc "$backup")"
check "old backup not deleted when new backup failed" has "$b/tableau-server-backup-2020-01-01.tsbak"

case_start backup-spaces "backup dir with spaces"
aged "$b/tableau-server-backup-2020-01-01.tsbak" "5 days ago"
expect "run" 0 "$(runrc "$backup")"
check "backup created" has "$b/tableau-server-backup-$today.tsbak"
check "settings created" has "$b/tableau-server-backup-settings-$today.json"
check "old backup deleted" hasnt "$b/tableau-server-backup-2020-01-01.tsbak"

# log archive
case_start logs-args
expect "no arguments" 1 "$(runrc "$logs")"
expect "two arguments" 1 "$(runrc "$logs" 7 8)"
for bad in 0 abc -1 07 1.5 ""; do expect "days [$bad]" 7 "$(runrc "$logs" "$bad")"; done
check "no files written by invalid runs" empty_dir "$a"

case_start logs-normal
aged "$a/logs-2020-01-01.zip" "30 days ago"
aged "$a/logs-$(date -d '6 days ago' +%Y-%m-%d).zip" "6 days ago"
aged "$a/logs-$(date -d '7 days ago' +%Y-%m-%d).zip" "7 days ago"
aged "$a/other-2020-01-01.zip" "30 days ago"
expect "run" 0 "$(runrc "$logs" 7)"
check "todays archive exists" has "$a/logs-$today.zip"
check "old archive deleted" hasnt "$a/logs-2020-01-01.zip"
check "6 day old archive kept with 7" has "$a/logs-$(date -d '6 days ago' +%Y-%m-%d).zip"
check "7 day old archive deleted with 7 (N or more days old)" hasnt "$a/logs-$(date -d '7 days ago' +%Y-%m-%d).zip"
check "unrelated zip kept" has "$a/other-2020-01-01.zip"
expect "second run same day" 0 "$(runrc "$logs" 7)"

case_start logs-failures
aged "$a/logs-2020-01-01.zip" "30 days ago"
STUB_FAIL=version; expect "tsm version failing" 3 "$(runrc "$logs" 7)"
STUB_FAIL=config; expect "configuration get failing" 4 "$(runrc "$logs" 7)"
STUB_FAIL=""
saved="$a"; a=""; expect "empty archive path" 5 "$(runrc "$logs" 7)"; a="$saved"
STUB_FAIL=ziplogs; expect "ziplogs failing" 6 "$(runrc "$logs" 7)"
check "old archive not deleted when ziplogs failed" has "$a/logs-2020-01-01.zip"

# cleanup
case_start cleanup
expect "success" 0 "$(runrc "$cleanup")"
STUB_FAIL=version; expect "tsm version failing" 3 "$(runrc "$cleanup")"
STUB_FAIL=status; expect "tsm status failing" 4 "$(runrc "$cleanup")"
STUB_FAIL=cleanup; expect "cleanup failing" 5 "$(runrc "$cleanup")"

echo "::endgroup::"
echo
if [ "$failed" -gt 0 ]; then echo "$failed FAILED CHECKS"; exit 1; fi
echo "All checks passed"
