@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_travail\_verifA.sql > D:\bdda\_travail\_verifA.out 2>&1
exit /b
