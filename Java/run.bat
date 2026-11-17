@echo off
setlocal
cd /d "%~dp0"

call build.bat
if errorlevel 1 exit /b 1

echo Lancement de BDDA Explorer...
java -cp "out;lib\ojdbc11.jar" bdda.explorer.DatabaseExplorerApp
endlocal
