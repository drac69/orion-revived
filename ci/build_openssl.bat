@call "%~dp0legacy_ci_guard.bat" || exit /b 1
setlocal enableextensions
set "OPENSSL_DIR=C:\projects\OpenSSL\%cc%\%platform%"

if exist "%OPENSSL_DIR%" goto :eof

if "%ORION_WINDOWS_OPENSSL_DIR%"=="" (
    echo This legacy helper no longer downloads or builds obsolete OpenSSL releases.
    echo Set ORION_WINDOWS_OPENSSL_DIR to a matching Windows OpenSSL build output directory.
    exit /b 1
)

if not exist "%ORION_WINDOWS_OPENSSL_DIR%" (
    echo ORION_WINDOWS_OPENSSL_DIR does not exist: %ORION_WINDOWS_OPENSSL_DIR%
    exit /b 1
)

if not exist "%ORION_WINDOWS_OPENSSL_DIR%\libssl*.dll" if not exist "%ORION_WINDOWS_OPENSSL_DIR%\ssleay32.dll" (
    echo ORION_WINDOWS_OPENSSL_DIR must contain OpenSSL runtime DLLs for the target Qt build.
    exit /b 1
)

for %%I in ("%OPENSSL_DIR%") do if not exist "%%~dpI" mkdir "%%~dpI"

xcopy "%ORION_WINDOWS_OPENSSL_DIR%\*" "%OPENSSL_DIR%\" /E /I /Y > NUL || exit /b 1
