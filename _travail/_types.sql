SET LINESIZE 200
SET PAGESIZE 100
COLUMN type_name FORMAT A35
SELECT type_name, typecode FROM user_types ORDER BY type_name;
EXIT