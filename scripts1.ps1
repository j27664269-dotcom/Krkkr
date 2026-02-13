using namespace System.Text
using namespace System.IO
[Console]::OutputEncoding = [Encoding]::UTF8
[Console]::InputEncoding = [Encoding]::UTF8
Clear-Host
$hostName = $Host.Name
$hostVersion = $Host.Version
$isPS7 = $PSVersionTable.PSVersion.Major -ge 7
Write-Host "🔧 Host Environment Info:" -ForegroundColor Yellow
Write-Host "  - Host: $hostName" -ForegroundColor Gray
Write-Host "  - Version: $hostVersion" -ForegroundColor Gray
Write-Host "  - Is PowerShell 7+?: $(if($isPS7){"Yes"}else{"No"})" -ForegroundColor Gray
Write-Host ""
if ($hostName -eq "ConsoleHost") {
    Write-Host "⚠️  You are using 'Console Host' (Default PowerShell)" -ForegroundColor Red
    Write-Host "   - To set font Cairo or RTL-supporting font: Click console icon top-left > Properties > Font" -ForegroundColor Gray
    Write-Host "   - Choose 'Consolas', 'Cascadia Code', or 'Simplified Arabic' (Not Cairo alone)" -ForegroundColor Gray
    Write-Host "   - Or better: Use 'Windows Terminal' from Microsoft Store." -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "💡 Using another environment (like ISE or Terminal) — Adjust font manually." -ForegroundColor Cyan
    Write-Host ""
}
function Get-RandomID {
    $chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return -join ((1..8) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}
Set-StrictMode -Off
$ErrorActionPreference = "SilentlyContinue"
$scriptDir = $PSScriptRoot
$saveFile = Join-Path $scriptDir "save.txt"
if (!(Test-Path $saveFile)) {
    Write-Host "❌ Error: save.txt not found in script directory!" -ForegroundColor Red
    Write-Host "📁 Expected path: $saveFile" -ForegroundColor Yellow
    exit 1
}
$myToken = Get-Content $saveFile -Raw
$configPath = Join-Path $env:APPDATA "rclone\rclone.conf"
$configContent = "[MyDrive]`ntype = drive`nscope = drive`ntoken = $myToken"
if (!(Test-Path (Split-Path $configPath))) {
    New-Item -ItemType Directory -Path (Split-Path $configPath) -Force | Out-Null
}
Set-Content -Path $configPath -Value $configContent -Encoding UTF8NoBOM
Write-Host "─" * 60 -ForegroundColor Gray
Write-Host "🚀 Smart Backup & Upload System v22.0" -ForegroundColor Magenta
Write-Host "──────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host "Status: Ready to backup and clean project" -ForegroundColor Cyan
Write-Host "─" * 60 -ForegroundColor Gray
$desktop = [Environment]::GetFolderPath("Desktop")
$projectDir = Join-Path $desktop "Project"$stats = @{
    Files = 0
    LinesRemoved_Total = 0
    LinesRemoved_Empty = 0
    LinesRemoved_Comments = 0
    OriginalLines = 0
    ExcludedCount = 0
    LingmaIncluded = 0
}
$Regex_Comments = @'
(?ms)
/\*.*?\*/              |  
//.*?$                 |  
#.*?$                  |  
<!--.*?-->             |  
<!--.*?$               |  
REM\s+.*?$             |  
--\s+.*?$              |  
'''.*?'''              |  
""".*?"""              
'@ -replace "`n", ""
$Regex_EmptyLines = '(?m)^\s*[\r\n]+$'
$binaryExts = @(
    '.exe', '.bin', '.zip', '.rar', '.7z', '.iso', '.img',
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.ico',
    '.mp3', '.mp4', '.avi', '.mov', '.mkv',
    '.pdf', '.docx', '.xlsx', '.pptx', '.epub', '.mobi',
    '.svg', '.ttf', '.otf', '.woff', '.woff2'
)
$folders = Get-ChildItem -Path $projectDir -Directory | Where-Object {
    $_.Name -like "rfcity-*" -and
    $_.Name -notlike "*-backup" -and
    $_.Name -notlike "rfcityCopy-*"
}
foreach ($folder in $folders) {
    $uniqueID = Get-RandomID
    $copyPath = Join-Path $env:LOCALAPPDATA "rfcityCopy-$uniqueID"
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $zipPath = Join-Path $env:LOCALAPPDATA "rfcity-$uniqueID-$timestamp.zip"
    Write-Host "📂 Creating isolated copy with ID: [$uniqueID]" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $copyPath -Force | Out-Null
    $allItems = Get-ChildItem -Path $folder.FullName -Recurse
    foreach ($item in $allItems) {
        $destPath = $item.FullName.Replace($folder.FullName, $copyPath)
        if ($item.Extension -in @('.exe', '.ps1')) {
            $stats.ExcludedCount++
            continue
        }
        if ($item.FullName -like "*node_modules*") {
            $stats.ExcludedCount++            continue
        }
        if ($item.PSIsContainer) {
            if (!(Test-Path $destPath)) { New-Item -ItemType Directory -Path $destPath -Force | Out-Null }
        } else {
            Copy-Item -Path $item.FullName -Destination $destPath -Force
            if ($item.FullName -like "*.lingma*") { $stats.LingmaIncluded++ }
        }
    }
    $files = Get-ChildItem -Path $copyPath -Recurse -File | Where-Object {
        $_.Extension -notin $binaryExts -and
        $_.Extension -ne '.txt'
    }
    foreach ($file in $files) {
        $stats.Files++
        try {
            $content = [File]::ReadAllText($file.FullName, [Encoding]::UTF8)
            $oldLines = ($content -split "`n").Count
            $stats.OriginalLines += $oldLines
            $commentsBefore = [regex]::Matches($content, $Regex_Comments, [System.Text.RegularExpressions.RegexOptions]::MultiLine).Count
            $emptyBefore = [regex]::Matches($content, $Regex_EmptyLines).Count
            $cleanContent = [regex]::Replace($content, $Regex_Comments, "", [System.Text.RegularExpressions.RegexOptions]::MultiLine)
            $cleanContent = [regex]::Replace($cleanContent, $Regex_EmptyLines, "")
            $newLines = ($cleanContent.Trim() -split "`n").Count
            $linesRemoved_Total = $oldLines - $newLines
            $stats.LinesRemoved_Total += $linesRemoved_Total
            $stats.LinesRemoved_Comments += $commentsBefore
            $stats.LinesRemoved_Empty += $emptyBefore
            [File]::WriteAllText($file.FullName, $cleanContent.Trim(), [Encoding]::UTF8)
        } catch {}
    }
    Compress-Archive -Path "$copyPath\*" -DestinationPath $zipPath -Force
    rclone copy "$zipPath" "MyDrive:/RDP_BACKUPS/rfcity-$uniqueID-$timestamp.zip" -P
    Write-Host "─" * 60 -ForegroundColor Gray
    Write-Host "📊 Final Operation Summary" -ForegroundColor Magenta
    Write-Host "─" * 60 -ForegroundColor Gray
    Write-Host "🆔 Unique Copy ID: $uniqueID" -ForegroundColor Cyan
    Write-Host "⚙️ Lingma Files Secured: [$($stats.LingmaIncluded)]" -ForegroundColor White
    Write-Host "🚫 Files/Folders Excluded: [$($stats.ExcludedCount)]" -ForegroundColor Red
    Write-Host "🧹 Empty Lines Removed: [$($stats.LinesRemoved_Empty)]" -ForegroundColor DarkGray
    Write-Host "💬 Comments Removed: [$($stats.LinesRemoved_Comments)]" -ForegroundColor Yellow
    Write-Host "🔢 Total Lines Cleaned: [$($stats.LinesRemoved_Total)]" -ForegroundColor Green
    $saveSpace = if($stats.OriginalLines -gt 0){[Math]::Round(($stats.LinesRemoved_Total / $stats.OriginalLines)*100)}else{0}
    Write-Host "📈 Code Improvement Ratio: [$saveSpace %]" -ForegroundColor Green
    Write-Host "📁 Uploaded File Name: rfcity-$uniqueID-$timestamp.zip" -ForegroundColor Cyan
    Write-Host "─" * 60 -ForegroundColor Gray
    Write-Host "✅ Operation Completed Successfully" -ForegroundColor White
    Write-Host "─" * 60 -ForegroundColor Gray
    Remove-Item $zipPath -Force
    Remove-Item $copyPath -Recurse -Force}
