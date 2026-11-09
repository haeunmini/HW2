param([string]$ImagePath, [string]$LogPath, [string]$StopFile, [int]$MaxRuntimeSeconds = 3600)
$ErrorActionPreference = 'Continue'
$null = Add-Type -AssemblyName System.Net.Http
$end = (Get-Date).ToUniversalTime().AddSeconds($MaxRuntimeSeconds)
$client = New-Object System.Net.Http.HttpClient
try { while (-not (Test-Path -LiteralPath $StopFile) -and (Get-Date).ToUniversalTime() -lt $end) {
  $start = (Get-Date).ToUniversalTime()
  $status = 0; $ok = $false; $version = ''; $body = ''
  $responseFile = Join-Path ([IO.Path]::GetTempPath()) ("waste-monitor-{0}.json" -f [guid]::NewGuid())
  try {
    $multipart = New-Object System.Net.Http.MultipartFormDataContent
    $stream = [IO.File]::OpenRead($ImagePath)
    $fileContent = New-Object System.Net.Http.StreamContent($stream)
    $fileContent.Headers.ContentType = New-Object System.Net.Http.Headers.MediaTypeHeaderValue('image/png')
    $multipart.Add($fileContent, 'file', [IO.Path]::GetFileName($ImagePath))
    $reply = $client.PostAsync('http://127.0.0.1:8000/api/analyze', $multipart).GetAwaiter().GetResult()
    $status = [int]$reply.StatusCode
    $body = $reply.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    $parsed = ConvertFrom-Json -InputObject $body
    $version = [string]$parsed.version
    $ok = $status -eq 200 -and [bool]$parsed.category_id
  } catch { $body = $_.Exception.Message }
  finally {
    if ($stream) { $stream.Dispose() }
    if ($fileContent) { $fileContent.Dispose() }
    if ($multipart) { $multipart.Dispose() }
    Remove-Item -LiteralPath $responseFile -Force -ErrorAction SilentlyContinue
  }
  $finish = (Get-Date).ToUniversalTime()
  [pscustomobject]@{ start=$start.ToString('o'); end=$finish.ToString('o'); latency_ms=[math]::Round(($finish-$start).TotalMilliseconds,2); status=$status; success=$ok; version=$version; response=$body } | ConvertTo-Json -Compress | Add-Content -Encoding utf8 $LogPath
  Start-Sleep -Seconds 1
} } finally { if ($client) { $client.Dispose() } }
