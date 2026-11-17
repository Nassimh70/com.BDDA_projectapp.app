@echo off
setlocal
cd /d "%~dp0"

if not exist out mkdir out

echo Compilation de BDDA Explorer...
javac -encoding UTF-8 -cp "lib\ojdbc11.jar" -d out src\bdda\explorer\*.java
if errorlevel 1 (
    echo ECHEC de la compilation.
    exit /b 1
)

echo Build OK : classe principale = bdda.explorer.DatabaseExplorerApp
endlocal
