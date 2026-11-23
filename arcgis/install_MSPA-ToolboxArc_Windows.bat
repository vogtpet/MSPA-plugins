@echo off
rem ---------------------------------------------------------------------------
rem Install the MSPA toolbox for ArcGIS Desktop 10.3 - 10.9 and ArcGIS Pro.
rem Run this script from the extracted MSPA-ArcGIS folder.
rem ---------------------------------------------------------------------------
setlocal enabledelayedexpansion
cd /d "%~dp0"

set "_num=0"

for %%V in (10.3 10.4 10.5 10.6 10.7 10.8 10.9) do (
  if exist "%APPDATA%\ESRI\Desktop%%V" (
    call :install "%%V" "%APPDATA%\ESRI\Desktop%%V\ArcToolbox\My Toolboxes"
  )
)

if exist "%ProgramFiles%\ArcGIS\Pro\bin\ArcGISPro.exe" (
  call :install "Pro" "%LOCALAPPDATA%\ESRI\ArcGISPro\Toolboxes"
)

if "!_num!"=="0" (
  echo.
  echo ArcGIS ^>= 10.3 or ArcGIS Pro was not found on your system.
  echo Please install a supported ArcGIS version and run this script again.
  echo.
)

pause
exit /b 0

:install
echo Installing for ArcGIS %~1
if not exist "%~2" md "%~2"
xcopy "mspa" "%~2\mspa" /Y /E /R /Q
xcopy "MSPA_Guide.pdf" "%~2\" /Y /R /Q
xcopy "README.md" "%~2\" /Y /R /Q
set /a _num+=1
exit /b 0
