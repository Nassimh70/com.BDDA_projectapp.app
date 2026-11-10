@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_probe6.sql > D:\bdda\_probe6.out 2>&1
exit /b %ERRORLEVEL%
