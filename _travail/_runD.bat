@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\partie_D_programmation.sql > D:\bdda\_travail\_D.out 2>&1
exit /b %ERRORLEVEL%
