@echo off
set NLS_LANG=AMERICAN_AMERICA.AL32UTF8
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_p13.sql
echo EXITCODE=%ERRORLEVEL%

