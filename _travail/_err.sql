SET PAGESIZE 100
SET LINESIZE 200
SHOW ERRORS PROCEDURE ajout_client
SELECT name, type, line, position, text FROM user_errors WHERE name = 'AJOUT_CLIENT' ORDER BY sequence;
EXIT
