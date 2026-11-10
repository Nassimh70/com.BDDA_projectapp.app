@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_travail\_q.sql > D:\bdda\_travail\_q.out 2>&1
exit /b
