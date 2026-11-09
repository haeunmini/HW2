$ErrorActionPreference = 'Continue'
$log = Join-Path $env:RUNNER_TEMP 'monitor.jsonl'
$rows = @()
if (Test-Path $log) {
  $rows = @(Get-Content $log | ForEach-Object { try { $_ | ConvertFrom-Json } catch { } })
}
$success = @($rows | Where-Object success).Count
$failure = @($rows | Where-Object { -not $_.success }).Count
$versions = @($rows | Where-Object version | Select-Object -ExpandProperty version -Unique) -join ', '
$gaps = @()
for ($i = 1; $i -lt $rows.Count; $i++) {
  $gaps += (([datetime]$rows[$i].start) - ([datetime]$rows[$i-1].end)).TotalSeconds
}
$maxGap = if ($gaps.Count) { [math]::Round(($gaps | Measure-Object -Maximum).Maximum, 2) } else { 'n/a' }
$summary = @(
  '## Local deployment verification'
  '- Address: http://127.0.0.1:8000/api/health'
  '- Monitor: /api/analyze with fixed image; nominal interval: 1 second'
  "- Requests: $($rows.Count); success: $success; failure: $failure"
  "- Observed versions: $versions"
  "- Maximum unobserved gap: $maxGap seconds (gaps are unverified intervals)"
  '- Logs: UTF-8 JSONL artifact deployment-monitor-log'
)
$summary | Add-Content -Encoding utf8 $env:GITHUB_STEP_SUMMARY
if (Test-Path $log) { Copy-Item $log (Join-Path $env:GITHUB_WORKSPACE 'deployment-monitor.jsonl') -Force }
