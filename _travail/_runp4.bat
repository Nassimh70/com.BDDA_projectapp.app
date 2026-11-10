@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_probe4.sql > D:\bdda\_probe4.out 2>&1
echo EXITCODE=%ERRORLEVEL%

