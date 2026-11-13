SET LINESIZE 200
SET PAGESIZE 100
COLUMN object_name FORMAT A35
SELECT object_name, status FROM user_objects WHERE object_type='TYPE' ORDER BY object_name;
SELECT COUNT(*) AS nb FROM user_objects WHERE object_type='TYPE';
EXIT