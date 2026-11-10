SET LINESIZE 200
SET PAGESIZE 100
SELECT object_name, object_type, status FROM user_objects WHERE status <> 'VALID' ORDER BY 1;
SELECT object_name, object_type, status FROM user_objects WHERE object_type IN ('PROCEDURE','FUNCTION') ORDER BY 1;
EXIT
