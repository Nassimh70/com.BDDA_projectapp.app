@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_travail\_q2.sql > D:\bdda\_travail\_q2.out 2>&1
exit /b
