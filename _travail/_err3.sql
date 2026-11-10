SET PAGESIZE 100
SET LINESIZE 200
ALTER PROCEDURE ajout_client COMPILE;
SHOW ERRORS PROCEDURE ajout_client
SELECT object_name, object_type, status FROM user_objects WHERE object_name = 'AJOUT_CLIENT';
EXIT
