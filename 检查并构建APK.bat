@echo off
setlocal
cd /d "%~dp0"

echo ===== 当前目录 =====
cd

echo.
echo ===== 已安装 Android Build-Tools =====
if exist "%ANDROID_HOME%\build-tools" (
  dir /b "%ANDROID_HOME%\build-tools"
) else if exist "%ANDROID_SDK_ROOT%\build-tools" (
  dir /b "%ANDROID_SDK_ROOT%\build-tools"
) else if exist "D:\AndroidSDK\build-tools" (
  dir /b "D:\AndroidSDK\build-tools"
) else (
  echo 未检测到 build-tools 目录。请在 Android Studio 的 SDK Manager 中安装 Android SDK Build-Tools。
)

echo.
echo ===== 开始构建 APK =====
flutter clean
flutter pub get
flutter build apk

pause
