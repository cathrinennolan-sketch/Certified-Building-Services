$port = 8000
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")

# Set up Ctrl+C or process exit handler to stop listener
[System.Console]::TreatControlCAsInput = $false

Write-Host "Starting server on http://localhost:$port/ ..."
try {
    $listener.Start()
    Write-Host "Server successfully started. Press Ctrl+C in terminal (or stop the background command) to quit."
    Write-Host "Serving files from: $(Get-Location)"
    
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $urlPath = $request.Url.LocalPath
        if ($urlPath -eq "/") {
            $urlPath = "/index.html"
        }

        # Resolve path safely and check if it's within the current directory
        $cleanPath = $urlPath.Replace("/", "\").TrimStart("\")
        $filePath = Join-Path (Get-Location) $cleanPath
        
        # Security check: ensure path is within current directory to prevent traversal
        $currentDir = (Get-Location).Path
        $fullPath = [System.IO.Path]::GetFullPath($filePath)
        
        if (-not $fullPath.StartsWith($currentDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            $response.StatusCode = 403
            $errorBytes = [System.Text.Encoding]::UTF8.GetBytes("403 Forbidden")
            $response.ContentLength64 = $errorBytes.Length
            $response.OutputStream.Write($errorBytes, 0, $errorBytes.Length)
            $response.OutputStream.Close()
            continue
        }

        if (Test-Path $fullPath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($fullPath).ToLower()
            $contentType = switch ($ext) {
                ".html" { "text/html; charset=utf-8" }
                ".htm"  { "text/html; charset=utf-8" }
                ".css"  { "text/css; charset=utf-8" }
                ".js"   { "application/javascript; charset=utf-8" }
                ".png"  { "image/png" }
                ".jpg"  { "image/jpeg" }
                ".jpeg" { "image/jpeg" }
                ".gif"  { "image/gif" }
                ".svg"  { "image/svg+xml" }
                ".ico"  { "image/x-icon" }
                ".json" { "application/json; charset=utf-8" }
                default { "application/octet-stream" }
            }

            $response.ContentType = $contentType
            $bytes = [System.IO.File]::ReadAllBytes($fullPath)
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.StatusCode = 200
        } else {
            $response.StatusCode = 404
            $errorBytes = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $response.ContentLength64 = $errorBytes.Length
            $response.OutputStream.Write($errorBytes, 0, $errorBytes.Length)
        }
        $response.OutputStream.Close()
    }
} catch {
    Write-Error $_
} finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
    Write-Host "Server stopped."
}
