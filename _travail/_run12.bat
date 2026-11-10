@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_p12.sql
echo EXITCODE=%ERRORLEVEL%

