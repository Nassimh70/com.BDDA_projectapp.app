@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_probe7.sql > D:\bdda\_probe7.out 2>&1
exit /b %ERRORLEVEL%
