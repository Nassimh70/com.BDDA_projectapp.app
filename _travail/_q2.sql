SET LINESIZE 200
SET PAGESIZE 100
COLUMN object_name FORMAT A30
SELECT object_name, object_type, status, created, last_ddl_time FROM user_objects WHERE object_name LIKE '%PROBE%' OR status <> 'VALID' ORDER BY object_type;
SELECT type_name, typecode, attributes FROM user_types WHERE type_name LIKE '%PROBE%';
EXIT
