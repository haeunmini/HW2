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
$start = if (Test-Path (Join-Path $env:RUNNER_TEMP 'monitor-start.txt')) { [datetime](Get-Content (Join-Path $env:RUNNER_TEMP 'monitor-start.txt')) } else { [datetime]::MinValue }
$deployStart = if (Test-Path (Join-Path $env:RUNNER_TEMP 'deploy-start.txt')) { [datetime](Get-Content (Join-Path $env:RUNNER_TEMP 'deploy-start.txt')) } else { [datetime]::MaxValue }
$deployEnd = if (Test-Path (Join-Path $env:RUNNER_TEMP 'deploy-end.txt')) { [datetime](Get-Content (Join-Path $env:RUNNER_TEMP 'deploy-end.txt')) } else { [datetime]::MinValue }
$phaseRows = foreach ($phase in 'pre','during','post') {
  $phaseSet = @($rows | Where-Object { $t = [datetime]$_.start; ($phase -eq 'pre' -and $t -lt $deployStart) -or ($phase -eq 'during' -and $t -ge $deployStart -and $t -le $deployEnd) -or ($phase -eq 'post' -and $t -gt $deployEnd) })
  [pscustomobject]@{ phase=$phase; requests=$phaseSet.Count; successful=@($phaseSet | Where-Object success).Count; representative=if ($phaseSet.Count) { $phaseSet[0].version } else { 'unobserved' } }
}
$summary = @(
  '## Local deployment verification'
  '- Address: http://127.0.0.1:8000/api/health'
  '- Monitor: /api/analyze with fixed image; nominal interval: 1 second'
  "- Requests: $($rows.Count); success: $success; failure: $failure"
  "- Observed versions: $versions"
  "- Maximum unobserved gap: $maxGap seconds (gaps are unverified intervals)"
  ''
  '| Phase | Requests | Successful | Representative version |'
  '| --- | ---: | ---: | --- |'
  $(foreach ($p in $phaseRows) { "| $($p.phase) | $($p.requests) | $($p.successful) | $($p.representative) |" })
  "- Version transition observed: $versions"
  '- Logs: UTF-8 JSONL artifact deployment-monitor-log'
)
$summary | Add-Content -Encoding utf8 $env:GITHUB_STEP_SUMMARY
if (Test-Path $log) { Copy-Item $log (Join-Path $env:GITHUB_WORKSPACE 'deployment-monitor.jsonl') -Force }
if ($rows.Count -eq 0 -or $success -eq 0) {
  Write-Error "Monitoring recorded no successful /api/analyze requests. Deployment validation failed."
  exit 1
}
