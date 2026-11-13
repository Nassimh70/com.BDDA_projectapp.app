@echo off
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\partie_E_objet_avance.sql > D:\bdda\_travail\_E.out 2>&1
exit /b %ERRORLEVEL%
