@echo off
title Execution script final BDDA
echo.
echo ============================================================
echo  LANCEMENT DU SCRIPT FINAL : projet_bdda_banque.sql
echo ============================================================
echo.
powershell -NoProfile -Command "& 'D:\Oracle\dbhomeXE\binj\sqlplus.exe' -L MASTER1/system@localhost:1521/XEPDB1 '@D:\bdda\projet_bdda_banque.sql' 2>&1 | Tee-Object -FilePath 'D:\bdda\execution_finale.log'"
echo.
echo ============================================================
echo  TERMINE. Log : D:\bdda\execution_finale.log
echo ============================================================
echo.
pause
