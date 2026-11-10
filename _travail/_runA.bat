@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\partie_A_schema.sql > D:\bdda\_travail\_A.out 2>&1
exit /b %ERRORLEVEL%
