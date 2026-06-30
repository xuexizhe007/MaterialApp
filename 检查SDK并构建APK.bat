@echo off
setlocal
cd /d "%~dp0"

echo ===== 当前项目目录 =====
cd

echo.
echo ===== 检查 Android SDK 路径 =====
if exist android\local.properties (
  type android\local.properties | findstr /i "sdk.dir flutter.sdk"
)

set SDK_PATH=
if defined ANDROID_HOME set SDK_PATH=%ANDROID_HOME%
if not defined SDK_PATH if defined ANDROID_SDK_ROOT set SDK_PATH=%ANDROID_SDK_ROOT%
if not defined SDK_PATH if exist D:\AndroidSDK set SDK_PATH=D:\AndroidSDK

echo.
echo 推测 SDK_PATH=%SDK_PATH%

echo.
echo ===== 已安装 Build-Tools 版本 =====
if defined SDK_PATH (
  if exist "%SDK_PATH%\build-tools" (
    dir /b "%SDK_PATH%\build-tools"
  ) else (
    echo 未找到 "%SDK_PATH%\build-tools"
  )
) else (
  echo 未能从环境变量或 D:\AndroidSDK 推测 SDK 路径。
)

echo.
echo ===== 开始构建 APK =====
flutter clean
flutter pub get
flutter build apk

pause
