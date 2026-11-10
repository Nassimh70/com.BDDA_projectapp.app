SET LINESIZE 200
SET PAGESIZE 200
SET DEFINE OFF
SET FEEDBACK ON
DROP TYPE probe_b FORCE;
DROP TYPE probe_p FORCE;
DROP TYPE probe_c FORCE;
DROP TABLE probe_def PURGE;
CREATE TYPE t1 AS OBJECT (x NUMBER);
CREATE TYPE t2 AS OBJECT (x NUMBER) NOT FINAL;
CREATE TYPE t3 UNDER t2 (y NUMBER);
SELECT object_name, object_type, status FROM user_objects WHERE object_name IN ('T1','T2','T3');
SELECT name, type, line, position, text FROM user_errors WHERE name IN ('T1','T2','T3') ORDER BY name, sequence;
EXIT
