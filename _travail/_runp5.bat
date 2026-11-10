@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_probe5.sql > D:\bdda\_probe5.out 2>&1
echo EXITCODE=%ERRORLEVEL%

