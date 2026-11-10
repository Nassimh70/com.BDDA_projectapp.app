@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_probe2.sql > D:\bdda\_probe2.out 2>&1
echo EXITCODE=%ERRORLEVEL%

