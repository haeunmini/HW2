param([string]$ImagePath, [string]$LogPath, [int]$DurationSeconds = 180)
$ErrorActionPreference = 'Continue'
$end = (Get-Date).ToUniversalTime().AddSeconds($DurationSeconds)
while ((Get-Date).ToUniversalTime() -lt $end) {
  $start = (Get-Date).ToUniversalTime()
  $status = 0; $ok = $false; $version = ''; $body = ''
  $responseFile = Join-Path ([IO.Path]::GetTempPath()) ("waste-monitor-{0}.json" -f [guid]::NewGuid())
  try {
    $statusText = curl.exe -sS -o $responseFile -w "%{http_code}" -X POST -F "file=@$ImagePath" http://127.0.0.1:8000/api/analyze 2>$null
    $status = [int](($statusText -join '').Trim())
    if (Test-Path $responseFile) { $body = [string](Get-Content -LiteralPath $responseFile -Raw -Encoding utf8) }
    $parsed = ConvertFrom-Json -InputObject $body
    $version = [string]$parsed.version
    $ok = $status -eq 200 -and [bool]$parsed.category_id
  } catch { $body = $_.Exception.Message }
  finally { Remove-Item -LiteralPath $responseFile -Force -ErrorAction SilentlyContinue }
  $finish = (Get-Date).ToUniversalTime()
  [pscustomobject]@{ start=$start.ToString('o'); end=$finish.ToString('o'); latency_ms=[math]::Round(($finish-$start).TotalMilliseconds,2); status=$status; success=$ok; version=$version; response=$body } | ConvertTo-Json -Compress | Add-Content -Encoding utf8 $LogPath
  Start-Sleep -Seconds 1
}
