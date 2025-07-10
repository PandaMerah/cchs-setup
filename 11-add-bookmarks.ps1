# Define bookmark info
$bookmarkName = "CCHS-Internaly"
$bookmarkURL = "http://192.168.1.81"
# Locate Chrome Bookmarks file (Default profile)
$chromeBookmarksPath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Bookmarks"
# Check if Chrome bookmarks file exists, if not, launch Chrome to create it
if (-Not (Test-Path $chromeBookmarksPath)) {
    Write-Host "Chrome bookmarks file not found. Launching Chrome to initialize profile..." -ForegroundColor Yellow
    
    # Try to find Chrome executable
    $chromeExe = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if (-not $chromeExe) {
        Write-Warning "Chrome executable not found. Please install Chrome first."
        exit 1
    }
    
    # Launch Chrome and wait for it to create the profile
    Start-Process -FilePath $chromeExe -ArgumentList "--no-first-run" -WindowStyle Minimized
    
    # Wait for bookmarks file to be created (max 30 seconds)
    $timeout = 30
    $elapsed = 0
    while (-Not (Test-Path $chromeBookmarksPath) -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 1
        $elapsed++
    }
    
    if (-Not (Test-Path $chromeBookmarksPath)) {
        Write-Warning "Chrome bookmarks file still not found after launching Chrome."
        exit 1
    }
    
    # Close Chrome process
    Get-Process -Name "chrome" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}
# Read and parse the JSON
$bookmarksJson = Get-Content $chromeBookmarksPath -Raw | ConvertFrom-Json
# Ensure children exists
if (-not $bookmarksJson.roots.bookmark_bar.children) {
    $bookmarksJson.roots.bookmark_bar.children = @()
}
# Check for existing bookmark
$exists = $bookmarksJson.roots.bookmark_bar.children | Where-Object {
    $_.name -eq $bookmarkName -and $_.url -eq $bookmarkURL
}
if (-not $exists) {
    # Generate unique ID (find max and increment)
    $existingIDs = $bookmarksJson.roots.bookmark_bar.children | ForEach-Object { [int]$_.id }
    $nextID = ($existingIDs | Measure-Object -Maximum).Maximum + 1
    if (-not $nextID) { $nextID = 1 }
    # Create new bookmark
    $newBookmark = [PSCustomObject]@{
        date_added = ([string][math]::Round(((Get-Date).ToUniversalTime() - [datetime]'1601-01-01').TotalMilliseconds * 10)) + "00"
        id         = "$nextID"
        name       = $bookmarkName
        type       = "url"
        url        = $bookmarkURL
    }
    # Append to the children array
    $bookmarksJson.roots.bookmark_bar.children += $newBookmark
    # Write back to file
    $bookmarksJson | ConvertTo-Json -Depth 10 | Set-Content -Path $chromeBookmarksPath -Encoding UTF8
    Write-Host "✅ Bookmark '$bookmarkName' added. Restart Chrome to see the change." -ForegroundColor Green
} else {
    Write-Host "⚠️ Bookmark already exists. No action taken." -ForegroundColor Yellow
}
# Write-Host "Press any key to exit..."
# $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")