@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\projet_bdda_banque.sql > D:\bdda\_travail\_FULL.out 2>&1
exit /b %ERRORLEVEL%
