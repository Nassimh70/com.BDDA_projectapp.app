@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\purge_donnees.sql > D:\bdda\_travail\_P.out 2>&1
exit /b
