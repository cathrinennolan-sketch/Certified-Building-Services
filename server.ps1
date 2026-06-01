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
        
        # Handle contact form POST submissions
        if ($request.HttpMethod -eq "POST" -and $urlPath -eq "/submit-contact") {
            try {
                $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
                $postData = $reader.ReadToEnd()
                $reader.Close()
                
                # Parse url-encoded form data (e.g. name=John+Doe&email=john%40example.com)
                $params = @{}
                $postData.Split('&') | ForEach-Object {
                    $parts = $_.Split('=')
                    if ($parts.Length -eq 2) {
                        $key = [System.Uri]::UnescapeDataString($parts[0].Replace('+', ' '))
                        $val = [System.Uri]::UnescapeDataString($parts[1].Replace('+', ' '))
                        $params[$key] = $val
                    }
                }
                
                $name = $params["name"]
                $email = $params["email"]
                $phone = $params["phone"]
                $projectType = $params["project-type"]
                $message = $params["message"]

                $subject = "New Contact Form Submission from $name"
                $bodyText = "Name: $name`nEmail: $email`nPhone: $phone`nProject Type: $projectType`n`nMessage:`n$message"

                # Check for SendGrid API Key in local .env file first, then environment
                $sendgridKey = $null
                $envFile = Join-Path (Get-Location) ".env"
                if (Test-Path $envFile) {
                    Get-Content $envFile | ForEach-Object {
                        $line = $_.Trim()
                        if ($line -and -not $line.StartsWith("#")) {
                            $parts = $line.Split('=', 2)
                            if ($parts.Length -eq 2 -and $parts[0].Trim() -eq "SENDGRID_API_KEY") {
                                $sendgridKey = $parts[1].Trim().Trim('"').Trim("'")
                            }
                        }
                    }
                }
                
                if (-not $sendgridKey) {
                    $sendgridKey = [System.Environment]::GetEnvironmentVariable("SENDGRID_API_KEY", "User")
                }
                if (-not $sendgridKey) {
                    $sendgridKey = [System.Environment]::GetEnvironmentVariable("SENDGRID_API_KEY", "Machine")
                }
                
                if ($sendgridKey) {
                    $headers = @{
                        "Authorization" = "Bearer $sendgridKey"
                        "Content-Type" = "application/json"
                    }
                    $payload = @{
                        personalizations = @(
                            @{
                                to = @(
                                    @{ email = "michaelnolan@certifiedbuildingservices.org" }
                                )
                            }
                        )
                        from = @{
                            email = "michaelnolan@certifiedbuildingservices.org" # Must be a verified sender in your SendGrid account
                        }
                        subject = $subject
                        content = @(
                            @{
                                type = "text/plain"
                                value = $bodyText
                            }
                        )
                    } | ConvertTo-Json -Depth 10 -Compress
                    
                    $res = Invoke-RestMethod -Uri "https://api.sendgrid.com/v3/mail/send" -Method Post -Headers $headers -Body $payload
                    Write-Host "Email sent successfully via SendGrid API to michaelnolan@certifiedbuildingservices.org" -ForegroundColor Green
                } else {
                    # Fallback local log if SendGrid is not configured yet
                    $logFile = Join-Path (Get-Location) "form-submissions.log"
                    $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Contact Submission:`n$bodyText`n--------------------`n"
                    [System.IO.File]::AppendAllText($logFile, $logEntry)
                    Write-Host "SendGrid API key not found. Logged submission to $logFile" -ForegroundColor Yellow
                }
                
                # Redirect back to contact page with success parameter
                $response.StatusCode = 302
                $response.RedirectLocation = "/contact.html?status=success"
            } catch {
                Write-Error $_
                $response.StatusCode = 500
                $errorBytes = [System.Text.Encoding]::UTF8.GetBytes("500 Internal Server Error: " + $_.Exception.Message)
                $response.ContentLength64 = $errorBytes.Length
                $response.OutputStream.Write($errorBytes, 0, $errorBytes.Length)
            }
            $response.OutputStream.Close()
            continue
        }

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
