@echo off
echo --- SYSTEMP
sqlplus -S -L MASTER1/SYSTEMP@localhost:1521/XEPDB1 @D:\bdda\_t.sql
echo --- system
sqlplus -S -L MASTER1/system@localhost:1521/XEPDB1 @D:\bdda\_t.sql
echo --- Master1
sqlplus -S -L MASTER1/Master1@localhost:1521/XEPDB1 @D:\bdda\_t.sql
