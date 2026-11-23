# Runs the Windows housekeeping scripts against the stub tsm.cmd and asserts exit codes and files.
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$dir = Join-Path $repo 'windows\2019.2 and later'
$backup = Join-Path $dir 'tableau-server-backup-script.cmd'
$logs = Join-Path $dir 'tableau-server-log-archive-script.cmd'
$cleanup = Join-Path $dir 'tableau-server-cleanup-script.cmd'
$env:PATH = (Join-Path $repo 'tests\stubs\windows') + ';' + $env:PATH
$base = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }
$root = Join-Path $base ('tsm-smoke-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$inv = [Globalization.CultureInfo]::InvariantCulture
$today = [datetime]::Now.ToString('yyyy-MM-dd', $inv)
$old = [datetime]::new(2020, 1, 1)
$fails = New-Object System.Collections.Generic.List[string]
$script:current = ''
$script:b = ''
$script:a = ''

function Check([bool]$ok, [string]$msg) {
  if ($ok) { Write-Host "  ok:   $msg" } else { Write-Host "  FAIL: $msg"; $fails.Add("$script:current :: $msg") }
}
function Has([string]$p) { Test-Path -LiteralPath $p }
function Run([string]$script, [string]$argLine) {
  $p = Start-Process cmd.exe -ArgumentList "/d /s /c `"`"$script`" $argLine`"" -NoNewWindow -Wait -PassThru
  Write-Host "  -> exit $($p.ExitCode)"
  return $p.ExitCode
}
function Start-Case([string]$name, [string]$sub = 'backups') {
  Write-Host "::group::$name"
  $script:current = $name
  $script:b = Join-Path $root "$name\$sub"
  $script:a = Join-Path $root "$name\archive"
  New-Item -ItemType Directory -Force $script:b, $script:a | Out-Null
  $env:STUB_BACKUP_DIR = $script:b
  $env:STUB_ARCHIVE_DIR = $script:a
  Remove-Item Env:STUB_FAIL -ErrorAction SilentlyContinue
}
function End-Case { Write-Host '::endgroup::' }
function New-Aged([string]$path, [datetime]$when) {
  Set-Content -LiteralPath $path -Value 'x'
  (Get-Item -LiteralPath $path).LastWriteTime = $when
}
function Expect([string]$what, [int]$got, [int]$want) { Check ($got -eq $want) "$what exit code is $want (got $got)" }

# Environment sanity
fltmc *> $null
if ($LASTEXITCODE -ne 0) { Write-Host 'Runner is not elevated, fltmc failed'; exit 2 }
Write-Host "Elevated: yes. stub tsm: $((Get-Command tsm).Source)"
Check ((Get-Command tsm).Source -like '*tests\stubs\windows\tsm.cmd') 'stub tsm.cmd is first on PATH'

# help
Start-Case 'help'
foreach ($s in $backup, $logs, $cleanup) {
  foreach ($h in '-h', '--help') { Expect "$(Split-Path $s -Leaf) $h" (Run $s $h) 0 }
}
End-Case

# invalid arguments: exit 10 and tsm never reached (nothing written)
Start-Case 'invalid-args-backup'
$bad = @('-n smoke -d 0', '-n smoke -d abc', '-n smoke -d 32769', '-n smoke -d 007', '-n smoke -d -5', '-n smoke -d ""',
  '-n a.b -d 7', '-n a* -d 7', '-n "a b" -d 7', '-n "a&b" -d 7', '-n "a;b" -d 7', '-n smoke -d 7 -o maybe', '-n smoke -d 7 --bogus',
  '-d 7', '-n smoke', '')
foreach ($x in $bad) { Expect "backup [$x]" (Run $backup $x) 10 }
Check ((Get-ChildItem -Force $script:b | Measure-Object).Count -eq 0) 'no files written by invalid runs'
End-Case

Start-Case 'invalid-args-other'
foreach ($x in '', '-d 0', '-d abc', '-d 32769', '-d 7 --bogus', '--bogus') { Expect "log-archive [$x]" (Run $logs $x) 10 }
foreach ($x in '--bogus', '-d 7', 'x') { Expect "cleanup [$x]" (Run $cleanup $x) 10 }
Check ((Get-ChildItem -Force $script:a | Measure-Object).Count -eq 0) 'no files written by invalid runs'
End-Case

# normal run, then same day again
Start-Case 'backup-normal'
Expect 'first run' (Run $backup '-n smoke -d 7 -o false') 0
Check (Has "$b\smoke-$today.tsbak") "smoke-$today.tsbak exists"
Check (Has "$b\smoke-settings-$today.json") "smoke-settings-$today.json exists"
Expect 'second run without -o' (Run $backup '-n smoke -d 7') 6
Expect 'second run with -o false' (Run $backup '-n smoke -d 7 -o false') 6
Check (Has "$b\smoke-$today.tsbak") 'backup survives failed second run'
Expect 'second run with -o true' (Run $backup '-n smoke -d 7 -o true') 0
Check (Has "$b\smoke-$today.tsbak") 'backup exists after overwrite'
Check (Has "$b\smoke-settings-$today.json") 'settings exists after overwrite'
Expect 'long form args' (Run $backup '--name smoke --days 32768 --overwrite TRUE') 0
End-Case

# retention
Start-Case 'backup-retention'
New-Aged "$b\smoke-2020-01-01.tsbak" $old
New-Aged "$b\smoke-settings-2020-01-01.json" $old
New-Aged "$b\smoke-weekly-2020-01-01.tsbak" $old
New-Aged "$b\unrelated.txt" $old
New-Item -ItemType Directory "$b\smoke-2019-12-31.tsbak" | Out-Null
New-Aged "$b\smoke-2019-12-31.tsbak\inner.txt" $old
(Get-Item "$b\smoke-2019-12-31.tsbak").LastWriteTime = $old
New-Aged "$b\smoke-2026-01-01.tsbak" ([datetime]::Now.AddDays(-3))
Expect 'run' (Run $backup '-n smoke -d 7 -o false') 0
Check (-not (Has "$b\smoke-2020-01-01.tsbak")) 'old backup deleted'
Check (-not (Has "$b\smoke-settings-2020-01-01.json")) 'old settings deleted'
Check (Has "$b\smoke-weekly-2020-01-01.tsbak") 'weekly file kept'
Check (Has "$b\unrelated.txt") 'unrelated file kept'
Check (Has "$b\smoke-2019-12-31.tsbak\inner.txt") 'file inside directory named like old backup kept'
Check (Has "$b\smoke-2019-12-31.tsbak") 'directory named like old backup kept'
Check (Has "$b\smoke-2026-01-01.tsbak") '3 day old backup kept with -d 7'
Check (Has "$b\smoke-$today.tsbak") 'todays backup kept'
End-Case

Start-Case 'backup-retention-boundary'
New-Aged "$b\smoke-2026-02-01.tsbak" ([datetime]::Now.AddDays(-6))
New-Aged "$b\smoke-2026-02-02.tsbak" ([datetime]::Now.AddDays(-7))
Expect 'run' (Run $backup '-n smoke -d 7 -o false') 0
Check (Has "$b\smoke-2026-02-01.tsbak") '6 day old backup kept with -d 7'
Write-Host "  info: 7 day old backup kept = $(Has "$b\smoke-2026-02-02.tsbak")"
End-Case

# tsm failure paths
Start-Case 'backup-failures'
$env:STUB_FAIL = 'version'; Expect 'tsm version failing' (Run $backup '-n smoke -d 7') 2
$env:STUB_FAIL = 'config'; Expect 'configuration get failing' (Run $backup '-n smoke -d 7') 3
Remove-Item Env:STUB_FAIL
$env:STUB_BACKUP_DIR = ''; Expect 'empty backup path' (Run $backup '-n smoke -d 7') 5
$env:STUB_BACKUP_DIR = $script:b
$env:STUB_FAIL = 'backup'; Expect 'backup failing' (Run $backup '-n smoke -d 7') 6
Check (-not (Has "$b\smoke-settings-$today.json")) 'no settings export after failed backup'
$env:STUB_FAIL = 'export'; Expect 'settings export failing' (Run $backup '-n smoke -d 7') 7
Check (Has "$b\smoke-$today.tsbak") 'backup exists when only settings export failed'
End-Case

Start-Case 'backup-failure-keeps-old'
New-Aged "$b\smoke-2020-01-01.tsbak" $old
$env:STUB_FAIL = 'backup'; Expect 'backup failing' (Run $backup '-n smoke -d 7') 6
Check (Has "$b\smoke-2020-01-01.tsbak") 'old backup not deleted when new backup failed'
End-Case

# log archive
Start-Case 'logs-normal'
New-Aged "$a\logs-2020-01-01.zip" $old
New-Aged "$a\other-2020-01-01.zip" $old
Expect 'run' (Run $logs '-d 7') 0
Check (Has "$a\logs-$today.zip") "logs-$today.zip exists"
Check (-not (Has "$a\logs-2020-01-01.zip")) 'old log archive deleted'
Check (Has "$a\other-2020-01-01.zip") 'unrelated zip kept'
Expect 'second run same day' (Run $logs '--days 7') 0
End-Case

Start-Case 'logs-failures'
New-Aged "$a\logs-2020-01-01.zip" $old
$env:STUB_FAIL = 'version'; Expect 'tsm version failing' (Run $logs '-d 7') 2
$env:STUB_FAIL = 'config'; Expect 'configuration get failing' (Run $logs '-d 7') 3
Remove-Item Env:STUB_FAIL
$env:STUB_ARCHIVE_DIR = ''; Expect 'empty archive path' (Run $logs '-d 7') 5
$env:STUB_ARCHIVE_DIR = $script:a
$env:STUB_FAIL = 'ziplogs'; Expect 'ziplogs failing' (Run $logs '-d 7') 6
Check (Has "$a\logs-2020-01-01.zip") 'old archive not deleted when ziplogs failed'
End-Case

# cleanup
Start-Case 'cleanup'
Expect 'success' (Run $cleanup '') 0
$env:STUB_FAIL = 'version'; Expect 'tsm version failing' (Run $cleanup '') 2
$env:STUB_FAIL = 'status'; Expect 'tsm status failing' (Run $cleanup '') 3
$env:STUB_FAIL = 'cleanup'; Expect 'cleanup failing' (Run $cleanup '') 9
End-Case

# paths with spaces and forward slashes
Start-Case 'spaces' 'backup dir with spaces'
New-Aged "$b\smoke-2020-01-01.tsbak" $old
New-Aged "$b\smoke-settings-2020-01-01.json" $old
Expect 'run' (Run $backup '-n smoke -d 7') 0
Check (Has "$b\smoke-$today.tsbak") 'backup created in directory with spaces'
Check (Has "$b\smoke-settings-$today.json") 'settings created in directory with spaces'
Check (-not (Has "$b\smoke-2020-01-01.tsbak")) 'old backup deleted in directory with spaces'
Check (-not (Has "$b\smoke-settings-2020-01-01.json")) 'old settings deleted in directory with spaces'
$env:STUB_ARCHIVE_DIR = Join-Path $root 'spaces\log archive dir'
New-Item -ItemType Directory -Force $env:STUB_ARCHIVE_DIR | Out-Null
New-Aged "$env:STUB_ARCHIVE_DIR\logs-2020-01-01.zip" $old
Expect 'log archive run' (Run $logs '-d 7') 0
Check (Has "$env:STUB_ARCHIVE_DIR\logs-$today.zip") 'log archive created in directory with spaces'
Check (-not (Has "$env:STUB_ARCHIVE_DIR\logs-2020-01-01.zip")) 'old log archive deleted in directory with spaces'
End-Case

Start-Case 'forward-slashes' 'fwd'
$env:STUB_BACKUP_DIR = $script:b.Replace('\', '/') + '/'
New-Aged "$b\smoke-2020-01-01.tsbak" $old
Expect 'run with forward slashes and trailing slash' (Run $backup '-n smoke -d 7') 0
Check (Has "$b\smoke-$today.tsbak") 'backup created'
Check (-not (Has "$b\smoke-2020-01-01.tsbak")) 'old backup deleted'
End-Case

Write-Host ''
if ($fails.Count -gt 0) {
  Write-Host "$($fails.Count) FAILED CHECKS:"
  $fails | ForEach-Object { Write-Host "  $_" }
  exit 1
}
Write-Host 'All checks passed'
