@echo off
setlocal

where gradle >nul 2>nul
if %ERRORLEVEL%==0 (
  gradle %*
  exit /b %ERRORLEVEL%
)

set GRADLE_VERSION=8.7
set BASE_DIR=%USERPROFILE%\.gradle\chatgpt-wrapper
set GRADLE_HOME=%BASE_DIR%\gradle-%GRADLE_VERSION%
set GRADLE_BAT=%GRADLE_HOME%\bin\gradle.bat
set ZIP_FILE=%BASE_DIR%\gradle-%GRADLE_VERSION%-bin.zip

if not exist "%GRADLE_BAT%" (
  echo Gradle %GRADLE_VERSION% not found locally. Trying official and China mirror sources...
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop';" ^
    "$ProgressPreference='SilentlyContinue';" ^
    "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
    "$base='%BASE_DIR%'; $zip='%ZIP_FILE%';" ^
    "$urls=@(" ^
    " 'https://mirrors.aliyun.com/gradle/gradle-%GRADLE_VERSION%-bin.zip'," ^
    " 'https://mirrors.huaweicloud.com/gradle/gradle-%GRADLE_VERSION%-bin.zip'," ^
    " 'https://mirrors.cloud.tencent.com/gradle/gradle-%GRADLE_VERSION%-bin.zip'," ^
    " 'https://services.gradle.org/distributions/gradle-%GRADLE_VERSION%-bin.zip'" ^
    ");" ^
    "New-Item -ItemType Directory -Force -Path $base | Out-Null;" ^
    "if (!(Test-Path $zip)) {" ^
    "  $ok=$false;" ^
    "  foreach($url in $urls) {" ^
    "    Write-Host ('Trying Gradle download: ' + $url);" ^
    "    $tmp=$zip+'.tmp'; Remove-Item -Force -ErrorAction SilentlyContinue $tmp;" ^
    "    try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 120 -Uri $url -OutFile $tmp; if((Test-Path $tmp) -and ((Get-Item $tmp).Length -gt 100MB)) { Move-Item -Force $tmp $zip; $ok=$true; break } else { Write-Host 'Downloaded file is incomplete, trying next source.' } }" ^
    "    catch { Write-Host ('Download failed: ' + $_.Exception.Message) }" ^
    "  }" ^
    "  if(!$ok) { throw 'Could not download Gradle 8.7. Manually download gradle-8.7-bin.zip to: ' + $zip }" ^
    "};" ^
    "if (!(Test-Path '%GRADLE_BAT%')) { Write-Host ('Unpacking ' + $zip); Remove-Item -Recurse -Force -ErrorAction SilentlyContinue '%GRADLE_HOME%'; Expand-Archive -Force -Path $zip -DestinationPath $base }"
  if %ERRORLEVEL% neq 0 (
    echo.
    echo Failed to download or unpack Gradle from all configured sources.
    echo Manual fix:
    echo   1. Download gradle-8.7-bin.zip from one of these URLs:
    echo      https://mirrors.aliyun.com/gradle/gradle-8.7-bin.zip
    echo      https://mirrors.huaweicloud.com/gradle/gradle-8.7-bin.zip
    echo      https://mirrors.cloud.tencent.com/gradle/gradle-8.7-bin.zip
    echo   2. Put it here:
    echo      %ZIP_FILE%
    echo   3. Run again:
    echo      flutter build apk
    exit /b %ERRORLEVEL%
  )
)

call "%GRADLE_BAT%" %*
exit /b %ERRORLEVEL%
