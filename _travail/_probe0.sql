SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK OFF
WHENEVER SQLERROR CONTINUE

PROMPT ===== 1. VERSION / UTILISATEUR =====
SELECT banner FROM v$version WHERE ROWNUM = 1;
SELECT USER AS utilisateur_courant FROM dual;
SELECT username, account_status, default_tablespace FROM user_users;

PROMPT ===== 2. PRIVILEGES SYSTEME =====
SELECT privilege FROM user_sys_privs ORDER BY privilege;

PROMPT ===== 3. QUOTA =====
SELECT tablespace_name, bytes, max_bytes FROM user_ts_quotas;

PROMPT ===== 4. OBJETS EXISTANTS =====
SELECT object_type, COUNT(*) AS nb FROM user_objects GROUP BY object_type ORDER BY object_type;

PROMPT ===== 5. AUTO-REF DANS CREATE TYPE (test) =====
CREATE TYPE probe_a AS OBJECT (x NUMBER, r REF probe_a);

PROMPT ===== 6. ALTER TYPE ADD ATTRIBUTE REF RECURSIF =====
CREATE TYPE probe_b AS OBJECT (x NUMBER);
ALTER TYPE probe_b ADD ATTRIBUTE r REF probe_b CASCADE;
SELECT type_name, attr_name FROM user_type_attrs WHERE type_name = 'PROBE_B' ORDER BY attr_no;

PROMPT ===== 7. ALTER TYPE ADD MEMBER + OVERRIDE =====
CREATE TYPE probe_p AS OBJECT (x NUMBER) NOT FINAL;
CREATE TYPE probe_c UNDER probe_p (y NUMBER);
ALTER TYPE probe_p ADD MEMBER FUNCTION f RETURN NUMBER CASCADE;
ALTER TYPE probe_c ADD MEMBER FUNCTION f RETURN NUMBER CASCADE;

PROMPT ===== 8. REF SUPERTYPE VERS TABLE SOUS-TYPE =====
CREATE TYPE probe_s AS OBJECT (a NUMBER) NOT FINAL;
CREATE TYPE probe_t UNDER probe_s (b NUMBER);
CREATE TABLE probe_st OF probe_s;
CREATE TABLE probe_tt OF probe_t;
CREATE TABLE probe_refs (r REF probe_s);
INSERT INTO probe_refs SELECT REF(t) FROM probe_tt t;
SELECT COUNT(*) AS nb_refs_inserees FROM probe_refs;

PROMPT ===== 9. NETTOYAGE =====
DROP TABLE probe_refs;
DROP TABLE probe_st;
DROP TABLE probe_tt;
DROP TYPE probe_t FORCE;
DROP TYPE probe_s FORCE;
DROP TYPE probe_c FORCE;
DROP TYPE probe_p FORCE;
DROP TYPE probe_b FORCE;
DROP TYPE probe_a FORCE;
PROMPT ===== FIN =====
EXIT
