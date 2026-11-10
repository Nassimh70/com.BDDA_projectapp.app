@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_p11.sql
echo EXITCODE=%ERRORLEVEL%

