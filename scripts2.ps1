# [1] تهيئة البيئة الاحترافية الشاملة - نسخة الحماية القصوى  
Clear-Host  
$ErrorActionPreference = "Continue" # استمرار التنفيذ حتى عند وجود أخطاء  
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8  
  
Write-Host "===========================================================" -ForegroundColor Gray  
Write-Host "|      🚀 ULTIMATE PARALLEL CONTROL - V140.0 (NON-STOP)   |" -ForegroundColor Magenta  
Write-Host "===========================================================" -ForegroundColor Gray  
  
# --- [2] جلب البيانات من ملف info.txt مع حماية من الفشل ---  
try {  
    $infoFile = "info.txt"  
    if (Test-Path $infoFile) {  
        $creds = Get-Content $info.txt  
        $userEmail = [string]$creds[0]; $userPass = [string]$creds[1]; $secretKey = [string]$creds[2]  
    } else {  
        Write-Host " ❌ Error: info.txt not found!" -ForegroundColor Red  
    }  
} catch {  
    Write-Host " ❌ Failed to load credentials." -ForegroundColor Red  
}  
  
$appsDir = "C:\Users\TOOLBOXLAP\Desktop\Apps"  
$desktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop")  
$wshell = New-Object -ComObject WScript.Shell -ErrorAction SilentlyContinue  
  
# --- [3] محرك TOTP للمصادقة الثنائية ---  
function Get-SyncCodes {  
    param([string]$secret)  
    try {  
        $codeScript = @"  
        using System;  
        using System.Security.Cryptography;  
        public class TOTP {  
            public static string[] GenerateTrio(string secret) {  
                byte[] key = Base32Decode(secret.Replace(" ", "").ToUpper());  
                long step = (long)(DateTime.UtcNow - new DateTime(1970, 1, 1)).TotalSeconds / 30;  
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
  
# --- [4] وظيفة إنشاء الاختصارات (Shortcuts) ---  
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
  
# --- [5] وظيفة المسح الشامل قبل البدء ---  
function Invoke-Force-Wipe {  
    try {  
        Write-Host "`n [!] Stage: Killing processes and wiping old data..." -ForegroundColor Red  
        Stop-Process -Name "lingma*", "gcloud*", "python*", "node*", "cmd", "Discord*" -Force 2>$null  
        Start-Sleep -Seconds 2  
        rmdir -s -q "$env:APPDATA\Lingma" 2>$null  
        rmdir -s -q "$env:LOCALAPPDATA\Programs\Lingma" 2>$null  
        rmdir -s -q "$env:APPDATA\gcloud" 2>$null  
        rmdir -s -q "$env:LOCALAPPDATA\Google\Cloud SDK" 2>$null  
        rmdir -s -q "$env:LOCALAPPDATA\Discord", "$env:APPDATA\Discord" 2>$null  
        Write-Host " ✅ Environment Cleaned." -ForegroundColor Green  
    } catch { Write-Host " [!] Wipe incomplete, continuing anyway..." -ForegroundColor Yellow }  
}  
  
# --- [6] إنشاء ملف mcp.json ديناميكيًا ---  
function Set-LingmaMCPConfig {  
    try {  
        Write-Host "`n [*] Stage: Creating mcp.json for Stitch-MCP..." -ForegroundColor Cyan  
        $mcpDir = Join-Path $env:APPDATA "Lingma\SharedClientCache"          $mcpPath = Join-Path $mcpDir "mcp.json"  
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
  
# --- [7] التثبيت المتوازي الفوري والكتابة حرف بحرف ---  
function Start-Immediate-Parallel-Install {  
    try {  
        Write-Host "`n [*] Stage: Launching Lingma & GCloud SIMULTANEOUSLY..." -ForegroundColor Cyan  
        $lingmaData = Join-Path $env:APPDATA "Lingma\User"  
        if (!(Test-Path $lingmaData)) { New-Item -Path $lingmaData -ItemType Directory -Force | Out-Null }  
        $fullJsonSettings = '{"workbench.startupEditor":"none","lingma.showWelcomePage":false,"workbench.colorTheme":"Lingma Dark"}'  
        $fullJsonSettings | Out-File (Join-Path $lingmaData "settings.json") -Encoding UTF8 -Force  
  
        $lingmaSetup = Get-ChildItem -Path $appsDir -Filter "*Lingma*" | Select-Object -First 1  
        $gcloudSetup = Get-ChildItem -Path $appsDir -Filter "*GoogleCloud*" | Select-Object -First 1  
  
        if ($lingmaSetup) { Start-Process $lingmaSetup.FullName -ArgumentList "/S /VERYSILENT" }  
        if ($gcloudSetup) { Start-Process $gcloudSetup.FullName -ArgumentList "/S /allusers" }  
  
        while (Get-Process -Name "*GoogleCloud*" -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 2 }  
          
        Create-Shortcuts  
        Stop-Process -Name "cmd" -Force 2>$null  
        Start-Sleep -Seconds 2  
        Start-Process "cmd.exe"  
        Start-Sleep -Seconds 4  
  
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")  
  
        if ($wshell -and $wshell.AppActivate("cmd.exe")) {  
            $cmd1 = "gcloud auth application-default login"  
            $cmd1.ToCharArray() | % { $wshell.SendKeys($_); Start-Sleep -m 30 }  
            $wshell.SendKeys("{ENTER}")  
        }  
  
        $credPath = Join-Path $env:APPDATA "gcloud\application_default_credentials.json"  
        while (!(Test-Path $credPath)) { Start-Sleep -Seconds 5 }    
        if ($wshell -and $wshell.AppActivate("cmd.exe")) {  
            $cmd2 = "gcloud config set project my-stitch-app-2026"  
            $cmd2.ToCharArray() | % { $wshell.SendKeys($_); Start-Sleep -m 30 }  
            $wshell.SendKeys("{ENTER}")  
        }  
  
        Start-Process "lingma.exe" 2>$null  
        Set-LingmaMCPConfig  
    } catch { Write-Host " [!] Parallel install encountered an issue." -ForegroundColor Yellow }  
}  
  
# --- [8] وظيفة دخول ديسكورد ---  
function Run-Discord-Full {  
    try {  
        Write-Host "`n [*] Action: Opening Discord..." -ForegroundColor Cyan  
        $updateExe = Join-Path $env:LOCALAPPDATA "Discord\Update.exe"  
        if (Test-Path $updateExe) {  
            Start-Process $updateExe -ArgumentList "--processStart Discord.exe"  
            for ($i = 0; $i -lt 60; $i++) {  
                if ($wshell -and $wshell.AppActivate("Discord")) {  
                    Start-Sleep -Seconds 15  
                    $userEmail.ToCharArray() | % { $wshell.SendKeys($_); Start-Sleep -m 40 }  
                    $wshell.SendKeys("{TAB}"); Start-Sleep -m 500  
                    $userPass.ToCharArray() | % { $wshell.SendKeys($_); Start-Sleep -m 40 }  
                    $wshell.SendKeys("{ENTER}")  
                    while($true) {  
                        Write-Host "`n [?] Press Y after Captcha for 2FA" -ForegroundColor Yellow  
                        if ((Read-Host) -eq "y") {  
                            if ($wshell.AppActivate("Discord")) {  
                                $codes = Get-SyncCodes -secret $secretKey  
                                foreach ($c in $codes) {  
                                    $wshell.SendKeys("^a{BACKSPACE}")  
                                    $c.ToCharArray() | % { $wshell.SendKeys($_); Start-Sleep -m 40 }  
                                    $wshell.SendKeys("{ENTER}"); Start-Sleep -Seconds 2  
                                }  
                                break  
                            }  
                        }  
                    }  
                    return $true  
                }  
                Start-Sleep -Seconds 1  
            }  
        }  
    } catch { Write-Host " [!] Discord injection failed." -ForegroundColor Yellow }  
}  
  
# --- [9] قائمة الخيارات ---  
Write-Host "`n [?] Select Operation Mode:" -ForegroundColor Yellow  Write-Host "  [Y]  Full Wipe & Parallel Install" -ForegroundColor White  
Write-Host "  [LG] Fast Parallel Re-setup" -ForegroundColor Green  
Write-Host "  [N]  System Wipe" -ForegroundColor Red  
Write-Host "  [X]  Stay Open" -ForegroundColor White  
  
$mode = (Read-Host "`n -> Your Choice").ToUpper()  
  
try {  
    if ($mode -eq "N") { Invoke-Force-Wipe }  
    elseif ($mode -eq "LG") { Invoke-Force-Wipe; Start-Immediate-Parallel-Install }  
    elseif ($mode -eq "Y") { Invoke-Force-Wipe; Start-Immediate-Parallel-Install; Run-Discord-Full }  
} catch { Write-Host " [!] Execution Error, but I am staying open." -ForegroundColor Red }  
  
Write-Host "`n===========================================================" -ForegroundColor Gray  
Write-Host " ✅ PROCESS FINISHED. STAYING OPEN FOREVER... " -ForegroundColor Green  
Write-Host "===========================================================" -ForegroundColor Gray  
  
# --- [10] الحلقة اللانهائية المطلقة لحماية النافذة ---  
while ($true) {  
    Start-Sleep -Seconds 10  
}
