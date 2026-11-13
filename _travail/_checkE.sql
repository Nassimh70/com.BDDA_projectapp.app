SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
COLUMN object_name FORMAT A35
COLUMN object_type FORMAT A20
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status <> 'VALID'
 ORDER BY object_type, object_name;
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('AGENCE_VOR','AGENCE_VOR_TYPE')
 ORDER BY object_type, object_name;
EXIT