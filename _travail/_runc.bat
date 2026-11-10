@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\partie_C_requetes.sql > D:\bdda\_travail\_C.out 2>&1
exit /b %ERRORLEVEL%
