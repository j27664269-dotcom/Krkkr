Clear-Host  
$ErrorActionPreference = "Continue"  
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8  
  
Write-Host "===========================================================" -ForegroundColor Gray  
Write-Host "|      🚀 ULTIMATE PARALLEL CONTROL - V140.0 (NON-STOP)   |" -ForegroundColor Magenta  
Write-Host "===========================================================" -ForegroundColor Gray  
  
$infoFile = "C:\Users\Public\info.txt"  
$userEmail = $null; $userPass = $null; $secretKey = $null  

if (Test-Path $infoFile) {
    $creds = Get-Content $infoFile
    if ($creds.Count -ge 3) {
        $userEmail = [string]$creds[0].Trim()
        $userPass = [string]$creds[1].Trim()
        $secretKey = [string]$creds[2].Trim()
    } else {
        Write-Host " ❌ Error: info.txt exists but has less than 3 lines." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "`n⚠️  info.txt not found. Please enter credentials manually:" -ForegroundColor Yellow
    $userEmail = Read-Host "  1. What is the email?"
    $userPass = Read-Host "  2. What is the password?"
    $secretKey = Read-Host "  3. What is the secret key?"
    
    if (-not $userEmail -or -not $userPass -or -not $secretKey) {
        Write-Host " ❌ All fields are required. Exiting." -ForegroundColor Red
        exit 1
    }
    
    $infoContent = "$userEmail`r`n$userPass`r`n$secretKey"
    $infoContent | Out-File $infoFile -Encoding UTF8NoBOM -Force
    Write-Host " ✅ info.txt saved to: $infoFile" -ForegroundColor Green
}

$appsDir = "C:\Users\Public\Desktop\Apps"  
$desktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop")  
$wshell = New-Object -ComObject WScript.Shell -ErrorAction SilentlyContinue  

function Get-SyncCodes {  
    param([string]$secret)  
    try {  
        $codeScript = @"  
        using System;  
        using System.Security.Cryptography;  
        public class TOTP {  
            public static string[] GenerateTrio(string secret) {  
                byte[] key = Base32Decode(secret.Replace(" ", "").ToUpper());                  long step = (long)(DateTime.UtcNow - new DateTime(1970, 1, 1)).TotalSeconds / 30;  
                return new string[] { Compute(key, step), Compute(key, step - 1), Compute(key, step + 1) };  
            }  
            private static string Compute(byte[] key, long step) {  
                byte[] bytes = BitConverter.GetBytes(step);  
                if (BitConverter.IsLittleEndian) Array.Reverse(bytes);  
                HMACSHA1 hmac = new HMACSHA1(key);  
                byte[] hash = hmac.ComputeHash(bytes);  
                int offset = hash[hash.Length - 1] & 0xf;  
                int binary = ((hash[offset] & 0x7f) << 24) | ((hash[offset + 1] & 0xff) << 16) | ((hash[offset + 2] & 0xff) << 8) | (hash[offset + 3] & 0xff);  
                return (binary % 1000000).ToString("D6");  
            }  
            private static byte[] Base32Decode(string b32) {  
                string alpha = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"; b32 = b32.TrimEnd('=');                  byte[] res = new byte[b32.Length * 5 / 8]; int bIdx = 0, bitAcc = 0, valAcc = 0;  
                foreach (char c in b32) { valAcc = (valAcc << 5) | alpha.IndexOf(c); bitAcc += 5; if (bitAcc >= 8) { res[bIdx++] = (byte)(valAcc >> (bitAcc - 8)); bitAcc -= 8; } }  
                return res;  
            }    }  
"@  
        Add-Type -TypeDefinition $codeScript -ErrorAction SilentlyContinue  
        return [TOTP]::GenerateTrio($secret)  
    } catch { return @("000000") }  
}  

function Create-Shortcuts {  
    try {  
        Write-Host " [*] Creating Shortcuts on Desktop..." -ForegroundColor Cyan  
        $gcloudExe = "$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin\gcloud.cmd"  
        if (Test-Path $gcloudExe) {  
            $s1 = $wshell.CreateShortcut("$desktopPath\Google Cloud SDK.lnk")  
            $s1.TargetPath = "cmd.exe"  
            $s1.Arguments = "/k `"$gcloudExe`""  
            $s1.Save()  
        }  
        $lingmaExe = "$env:LOCALAPPDATA\Programs\Lingma\Lingma.exe"  
        if (Test-Path $lingmaExe) {  
            $s2 = $wshell.CreateShortcut("$desktopPath\Lingma IDE.lnk")  
            $s2.TargetPath = $lingmaExe  
            $s2.Save()  
        }  
    } catch { Write-Host " [!] Shortcut creation skipped." -ForegroundColor Yellow }  
}  

function Invoke-Force-Wipe {  
    try {  
        Write-Host "`n [!] Stage: Killing processes and wiping old data..." -ForegroundColor Red  
        Stop-Process -Name "lingma*", "gcloud*", "python*", "node*", "cmd", "Discord*" -Force -ErrorAction SilentlyContinue  
        Start-Sleep -Seconds 2  
        Remove-Item -Path "$env:APPDATA\Lingma" -Recurse -Force -ErrorAction SilentlyContinue  
        Remove-Item -Path "$env:LOCALAPPDATA\Programs\Lingma" -Recurse -Force -ErrorAction SilentlyContinue  
        Remove-Item -Path "$env:APPDATA\gcloud" -Recurse -Force -ErrorAction SilentlyContinue          Remove-Item -Path "$env:LOCALAPPDATA\Google\Cloud SDK" -Recurse -Force -ErrorAction SilentlyContinue  
        Remove-Item -Path "$env:LOCALAPPDATA\Discord", "$env:APPDATA\Discord" -Recurse -Force -ErrorAction SilentlyContinue  
        Write-Host " ✅ Environment Cleaned." -ForegroundColor Green  
    } catch { Write-Host " [!] Wipe incomplete, continuing anyway..." -ForegroundColor Yellow }  
}  

function Set-LingmaMCPConfig {  
    try {  
        Write-Host "`n [*] Stage: Creating mcp.json for Stitch-MCP..." -ForegroundColor Cyan  
        $mcpDir = Join-Path $env:APPDATA "Lingma\SharedClientCache"
        $mcpPath = Join-Path $mcpDir "mcp.json"  
        if (!(Test-Path $mcpDir)) { New-Item -Path $mcpDir -ItemType Directory -Force | Out-Null }  
        $credPath = Join-Path $env:APPDATA "gcloud\application_default_credentials.json"  
        $mcpContent = @{  
            mcpServers = @{  
                "stitch-official" = @{                  
                    command = "C:\\npm\\prefix\\stitch-mcp.cmd"  
                    args    = @("proxy")  
                    env     = @{ GOOGLE_APPLICATION_CREDENTIALS = $credPath; CLOUDSDK_CONFIG = Join-Path $env:APPDATA "gcloud" }  
                }  
            }  
        } | ConvertTo-Json -Depth 5  
        $mcpContent | Out-File -FilePath $mcpPath -Encoding UTF8 -Force  
        Write-Host " ✅ mcp.json ready." -ForegroundColor Green  
    } catch { Write-Host " [!] MCP Config failed." -ForegroundColor Yellow }  
}  

function Install-Discord-And-Login {  
    try {  
        Write-Host "`n [*] Stage: Installing & Logging into Discord..." -ForegroundColor Cyan  
        $discordSetup = Get-ChildItem -Path $appsDir -Filter "*Discord*" | Select-Object -First 1
        if ($discordSetup -and (Test-Path $discordSetup.FullName)) {
            Write-Host "   Installing Discord..." -ForegroundColor Gray
            Start-Process $discordSetup.FullName -ArgumentList "/S" -Wait
        }
        
        $updateExe = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"  
        if (Test-Path $updateExe) {  
            Start-Process $updateExe -ArgumentList "--processStart Discord.exe"  
            for ($i = 0; $i -lt 120; $i++) {  
                if ($wshell -and $wshell.AppActivate("Discord")) {  
                    Start-Sleep -Seconds 15  
                    $userEmail.ToCharArray() | % { $wshell.SendKeys($_); Start-Sleep -m 40 }  
                    $wshell.SendKeys("{TAB}"); Start-Sleep -m 500  
                    $userPass.ToCharArray() | % { $wshell.SendKeys($_); Start-Sleep -m 40 }  
                    $wshell.SendKeys("{ENTER}")  
                    Start-Sleep -Seconds 8
                    
                    Write-Host "`n [?] CAPTCHA: Solve captcha manually, then press Y to proceed with 2FA" -ForegroundColor Yellow -BackgroundColor Black
                    while ((Read-Host "   Ready for 2FA? (Y/N)").ToUpper() -ne "Y") { Start-Sleep -Seconds 1 }                    
                    if ($wshell.AppActivate("Discord")) {  
                        $codes = Get-SyncCodes -secret $secretKey  
                        Write-Host "   Sending TOTP codes (prev/current/next)..." -ForegroundColor Gray
                        foreach ($c in $codes) {  
                            $wshell.SendKeys("^a{BACKSPACE}")  
                            $c.ToCharArray() | % { $wshell.SendKeys($_); Start-Sleep -m 40 }  
                            $wshell.SendKeys("{ENTER}"); Start-Sleep -Seconds 3  
                        }  
                        Start-Sleep -Seconds 5
                        if ($wshell.AppActivate("Discord")) {
                            Write-Host " ✅ Discord login successful." -ForegroundColor Green
                            return $true
                        }
                    }  
                }  
                Start-Sleep -Seconds 1  
            }  
        }  
        Write-Host " ⚠️ Discord login incomplete, continuing anyway..." -ForegroundColor Yellow
        return $false
    } catch { Write-Host " [!] Discord login failed, continuing anyway." -ForegroundColor Yellow; return $false }  
}  

function Start-Immediate-Parallel-Install {  
    try {  
        Write-Host "`n [*] Stage 1: Preparing Lingma User Directory..." -ForegroundColor Cyan  
        $lingmaData = "$env:APPDATA\Lingma\User"
        if (!(Test-Path $lingmaData)) { 
            New-Item -Path $lingmaData -ItemType Directory -Force | Out-Null 
            Write-Host " ✅ Lingma\User directory created." -ForegroundColor Green
        }
        
        Write-Host "`n [*] Stage 2: Creating settings.json..." -ForegroundColor Cyan  
        $fullJsonSettings = @'
{
    "workbench.startupEditor": "none",
    "lingma.showWelcomePage": false,
    "app": {
        "configGeneralDisplayLanguage": "en-us",
        "configGeneralAiResponseLanguage": "en-us",
        "configGeneralImprovementPlan": "agree",
        "configGeneralImportSettings": "VS Code",
        "configCompletionEnableNES": true,
        "configCompletionDisabledLanguages": [],
        "configCompletionTriggerInComment": true,
        "configCompletionAutoImport": true,
        "configChatWebToolsMode": "Ask every time",
        "configChatAskModeUseTools": true,
        "configChatEditFileTool": false,        "configChatTerminalRunMode": "askEveryTime",
        "configChatCommandDenyList": "rm,mv,sudo,wget,curl,chown",
        "configChatCommandAllowlist": "",
        "configChatAutoRunMcpTools": true,
        "configChatMethodQuickOperation": false,
        "configChatShowSelectionToolbar": true,
        "configQuestDefaultLayout": false,
        "configMemoryAutoGenerate": true,
        "configIntegrationsBrowserRunMode": "Ask every time",
        "configIntegrationsBrowserToolsRunMode": "Auto-run",
        "configIntegrationsPlanModeRunConfig": "Ask every time",
        "configAdvancedAutoUpdate": true,
        "configAdvancedProxyMode": "system",
        "configAdvancedProxyURL": ""
    },
    "workbench.colorTheme": "Lingma Dark",
    "security.workspace.trust.untrustedFiles": "open"
}
'@
        $fullJsonSettings | Out-File (Join-Path $lingmaData "settings.json") -Encoding UTF8 -Force  
        Write-Host " ✅ settings.json created with advanced configuration." -ForegroundColor Green
        
        Write-Host "`n [*] Stage 3: Launching Lingma Setup..." -ForegroundColor Cyan  
        $lingmaSetup = Get-ChildItem -Path $appsDir -Filter "*Lingma*" | Select-Object -First 1  
        if ($lingmaSetup) { 
            Start-Process $lingmaSetup.FullName -ArgumentList "/S /VERYSILENT" 
            Write-Host " ✅ Lingma installation started." -ForegroundColor Green
        }
        
        Write-Host "`n [*] Stage 4: Launching GCloud Setup (Parallel)..." -ForegroundColor Cyan  
        $gcloudSetup = Get-ChildItem -Path $appsDir -Filter "*GoogleCloud*" | Select-Object -First 1  
        if ($gcloudSetup) { 
            Start-Process $gcloudSetup.FullName -ArgumentList "/S /allusers" 
            Write-Host " ✅ Google Cloud SDK installation started." -ForegroundColor Green
        }
        
        while (Get-Process -Name "*GoogleCloud*" -ErrorAction SilentlyContinue) { 
            Start-Sleep -Seconds 2 
        }
        
        Write-Host "`n [*] Stage 5: Creating mcp.json after installation..." -ForegroundColor Cyan  
        Set-LingmaMCPConfig  
        
        Create-Shortcuts  
        
        $projectBase = "C:\Users\Public\Desktop\Project"
        $rfcityFolder = Get-ChildItem -Path $projectBase -Directory | Where-Object { $_.Name -like "rfcity-*" } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        Write-Host "`n [*] Stage 6: Launching Lingma IDE with project..." -ForegroundColor Cyan  
        $lingmaExe = "$env:LOCALAPPDATA\Programs\Lingma\Lingma.exe"        $waitCount = 0
        while (-not (Test-Path $lingmaExe) -and $waitCount -lt 30) {
            Start-Sleep -Seconds 2
            $waitCount++
        }
        
        if (Test-Path $lingmaExe) {
            if ($rfcityFolder) {
                Start-Process $lingmaExe -ArgumentList "--folder `"$($rfcityFolder.FullName)`""
                Write-Host " ✅ Lingma IDE launched with project folder." -ForegroundColor Green
                
                if (Test-Path (Join-Path $rfcityFolder.FullName "package.json")) {
                    Write-Host "`n [*] Installing npm dependencies in background..." -ForegroundColor Cyan
                    Start-Process "cmd.exe" -ArgumentList "/c cd /d `"$($rfcityFolder.FullName)`" && npm install && echo Dependencies installed! && pause" -WindowStyle Minimized
                }
            } else {
                Start-Process $lingmaExe
                Write-Host " ✅ Lingma IDE launched (no project found)." -ForegroundColor Yellow
            }
        } else {
            Write-Host " ⚠️ Lingma executable not found after install." -ForegroundColor Yellow
        }
        
        Write-Host "`n [*] Configuring Google Cloud SDK in new window..." -ForegroundColor Cyan
        Stop-Process -Name "cmd" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        $newCmd = Start-Process "cmd.exe" -PassThru
        Start-Sleep -Seconds 3
        
        if ($wshell.AppActivate($newCmd.Id)) {
            $loginCmd = "gcloud auth application-default login"
            $loginCmd.ToCharArray() | % { $wshell.SendKeys($_); Start-Sleep -m 30 }
            $wshell.SendKeys("{ENTER}")
            
            $credPath = Join-Path $env:APPDATA "gcloud\application_default_credentials.json"
            $wait = 0
            while (!(Test-Path $credPath) -and $wait -lt 180) {
                Start-Sleep -Seconds 5
                $wait++
            }
            
            if (Test-Path $credPath) {
                Write-Host " ✅ GCloud login successful." -ForegroundColor Green
                Start-Sleep -Seconds 3
                
                $setProject = "gcloud config set project my-stitch-app-2026"
                $setProject.ToCharArray() | % { $wshell.SendKeys($_); Start-Sleep -m 30 }
                $wshell.SendKeys("{ENTER}")
                Start-Sleep -Seconds 5                Write-Host " ✅ Project 'my-stitch-app-2026' selected." -ForegroundColor Green
            } else {
                Write-Host " ⚠️ GCloud login timed out, manual login required." -ForegroundColor Yellow
            }
        }
    } catch { Write-Host " [!] Parallel install encountered an issue." -ForegroundColor Yellow }  
}  

Write-Host "`n [?] Select Operation Mode:" -ForegroundColor Yellow  
Write-Host "  [Y]  Full Wipe → Discord Login → Parallel Install" -ForegroundColor White  
Write-Host "  [LG] Fast Parallel Re-setup (No Discord)" -ForegroundColor Green  
Write-Host "  [N]  System Wipe Only" -ForegroundColor Red  
Write-Host "  [X]  Stay Open" -ForegroundColor White  

$mode = (Read-Host "`n -> Your Choice").ToUpper()  

try {  
    if ($mode -eq "N") { 
        Invoke-Force-Wipe 
    }  
    elseif ($mode -eq "LG") { 
        Invoke-Force-Wipe
        Start-Immediate-Parallel-Install 
    }  
    elseif ($mode -eq "Y") { 
        Invoke-Force-Wipe
        $discordSuccess = Install-Discord-And-Login
        if ($discordSuccess) {
            Write-Host "`n ✅ Discord login completed successfully." -ForegroundColor Green
        } else {
            Write-Host "`n ⚠️ Discord login skipped or failed, continuing with setup..." -ForegroundColor Yellow
        }
        Start-Immediate-Parallel-Install 
    }
} catch { 
    Write-Host " [!] Execution Error, but I am staying open." -ForegroundColor Red 
}  

Write-Host "`n===========================================================" -ForegroundColor Gray  
Write-Host " ✅ PROCESS FINISHED. STAYING OPEN FOREVER... " -ForegroundColor Green  
Write-Host "===========================================================" -ForegroundColor Gray  

while ($true) {  
    Start-Sleep -Seconds 10  
}
