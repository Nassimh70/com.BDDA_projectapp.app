@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\partie_B_manipulations.sql > D:\bdda\_travail\_B.out 2>&1
exit /b %ERRORLEVEL%
