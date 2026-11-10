@echo off
sqlplus MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_p10.sql
echo EXITCODE=%ERRORLEVEL%

