@echo off
if "%ORION_ALLOW_LEGACY_CI%"=="1" exit /b 0
echo This is a legacy upstream Travis/AppVeyor helper and is not part of the maintained GitHub Actions CI for this fork.
echo Use the README source build steps or .github\workflows\ci.yml for supported automation.
echo To run this legacy helper intentionally, set ORION_ALLOW_LEGACY_CI=1.
exit /b 1
