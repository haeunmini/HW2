param([string]$ImagePath, [string]$LogPath, [int]$DurationSeconds = 180)
$ErrorActionPreference = 'Continue'
$end = (Get-Date).ToUniversalTime().AddSeconds($DurationSeconds)
while ((Get-Date).ToUniversalTime() -lt $end) {
  $start = (Get-Date).ToUniversalTime()
  $status = 0; $ok = $false; $version = ''; $body = ''
  try {
    $result = curl.exe -sS -w "`nHTTP_STATUS:%{http_code}" -X POST -F "file=@$ImagePath" http://127.0.0.1:8000/api/analyze 2>&1
    $text = ($result -join "`n")
    $marker = 'HTTP_STATUS:'; $pos = $text.LastIndexOf($marker)
    if ($pos -ge 0) { $status = [int]$text.Substring($pos + $marker.Length).Trim(); $body = $text.Substring(0, $pos).Trim() }
    $parsed = $body | ConvertFrom-Json
    $version = [string]$parsed.version
    $ok = $status -eq 200 -and [bool]$parsed.category_id
  } catch { $body = $_.Exception.Message }
  $finish = (Get-Date).ToUniversalTime()
  [pscustomobject]@{ start=$start.ToString('o'); end=$finish.ToString('o'); latency_ms=[math]::Round(($finish-$start).TotalMilliseconds,2); status=$status; success=$ok; version=$version; response=$body } | ConvertTo-Json -Compress | Add-Content -Encoding utf8 $LogPath
  Start-Sleep -Seconds 1
}
