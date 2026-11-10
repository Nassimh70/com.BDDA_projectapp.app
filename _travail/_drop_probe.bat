@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_travail\_drop_probe.sql > D:\bdda\_travail\_drop_probe.out 2>&1
exit /b
