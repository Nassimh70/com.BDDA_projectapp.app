SPOOL D:\bdda\_probe1.out
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 200
SET DEFINE OFF
SET FEEDBACK ON
WHENEVER SQLERROR CONTINUE

PROMPT ### 0 CLEANUP
DROP TYPE probe_a FORCE;
DROP TYPE probe_x FORCE;

PROMPT ### 1 ALTER TYPE ADD ATTRIBUTE CASCADE
CREATE TYPE probe_b AS OBJECT (x NUMBER);
ALTER TYPE probe_b ADD ATTRIBUTE r REF probe_b CASCADE;
SELECT type_name, attr_name FROM user_type_attrs WHERE type_name='PROBE_B' ORDER BY attr_no;

PROMPT ### 2 ALTER TYPE ADD MEMBER + OVERRIDE
CREATE TYPE probe_p AS OBJECT (x NUMBER) NOT FINAL;
CREATE TYPE probe_c UNDER probe_p (y NUMBER);
ALTER TYPE probe_p ADD MEMBER FUNCTION f RETURN NUMBER CASCADE;
ALTER TYPE probe_c ADD MEMBER FUNCTION f RETURN NUMBER CASCADE;
CREATE OR REPLACE TYPE BODY probe_p AS
  MEMBER FUNCTION f RETURN NUMBER IS BEGIN RETURN 1; END;
END;
/
CREATE OR REPLACE TYPE BODY probe_c AS
  MEMBER FUNCTION f RETURN NUMBER IS BEGIN RETURN 2; END;
END;
/
CREATE TABLE probe_ct OF probe_c;
INSERT INTO probe_ct VALUES (probe_c(1,2));
SELECT VALUE(t).f() AS f_value FROM probe_ct t;
SELECT t.f() AS f_direct FROM probe_ct t;

PROMPT ### 3 CHECK DEFERRABLE
CREATE TABLE probe_def (a NUMBER, b NUMBER, CONSTRAINT ck_b CHECK (b IS NOT NULL) DEFERRABLE INITIALLY DEFERRED);
INSERT INTO probe_def VALUES (1, NULL);
SELECT COUNT(*) AS avant_update FROM probe_def;
UPDATE probe_def SET b = 5;
COMMIT;
SELECT COUNT(*) AS apres_commit FROM probe_def;

PROMPT ### 4 OBJECT TABLE + SCOPE + NESTED TABLE + MAKE_REF
CREATE TYPE probe_addr AS OBJECT (ville VARCHAR2(20));
CREATE TYPE probe_cli AS OBJECT (id NUMBER, adr probe_addr);
CREATE TYPE probe_sig AS OBJECT (r REF probe_cli, droit CHAR(1));
CREATE TYPE probe_sig_nt AS TABLE OF probe_sig;
CREATE TYPE probe_cpt AS OBJECT (num VARCHAR2(10), ref_cli REF probe_cli, sigs probe_sig_nt);
CREATE TABLE probe_cli_t OF probe_cli (id PRIMARY KEY);
CREATE TABLE probe_cpt_t OF probe_cpt (num PRIMARY KEY, ref_cli NOT NULL)
  NESTED TABLE sigs STORE AS probe_sig_st;
ALTER TABLE probe_cpt_t ADD SCOPE FOR (ref_cli) IS probe_cli_t;
ALTER TABLE probe_sig_st ADD CONSTRAINT ck_droit CHECK (droit IN ('X','R','D'));
INSERT INTO probe_cli_t VALUES (probe_cli(1, probe_addr('Bejaia')));
INSERT INTO probe_cpt_t VALUES (probe_cpt('C1', NULL, probe_sig_nt()));
UPDATE probe_cpt_t SET ref_cli = (SELECT REF(c) FROM probe_cli_t c WHERE c.id=1) WHERE num='C1';
INSERT INTO TABLE(SELECT sigs FROM probe_cpt_t WHERE num='C1') SELECT probe_sig(REF(c),'D') FROM probe_cli_t c WHERE c.id=1;
SELECT c.num, c.ref_cli.id AS id_cli, c.ref_cli.adr.ville AS ville, s.r.id AS id_sig, s.droit
  FROM probe_cpt_t c, TABLE(c.sigs) s;
SELECT COUNT(*) AS nb_sig FROM TABLE(SELECT sigs FROM probe_cpt_t WHERE num='C1');
SELECT MAKE_REF(probe_cli_t, 1).id AS id_make_ref FROM dual;

PROMPT ### 5 VIOLATION CONTRAINTE NESTED TABLE (attendu ORA-02290)
INSERT INTO TABLE(SELECT sigs FROM probe_cpt_t WHERE num='C1') SELECT probe_sig(REF(c),'Z') FROM probe_cli_t c WHERE c.id=1;

PROMPT ### 6 VARRAY + COUNT(*) / COUNT(col)
CREATE TYPE probe_v AS VARRAY(3) OF VARCHAR2(10);
CREATE TABLE probe_vt (id NUMBER, tels probe_v);
INSERT INTO probe_vt VALUES (1, probe_v('a', NULL, NULL));
SELECT COUNT(*) AS total, COUNT(t.column_value) AS renseignes FROM probe_vt v, TABLE(v.tels) t;

PROMPT ### 7 CLEANUP
DROP TABLE probe_vt;
DROP TYPE probe_v FORCE;
DROP TABLE probe_cpt_t;
DROP TABLE probe_cli_t;
DROP TYPE probe_cpt FORCE;
DROP TYPE probe_sig_nt FORCE;
DROP TYPE probe_sig FORCE;
DROP TYPE probe_cli FORCE;
DROP TYPE probe_addr FORCE;
DROP TABLE probe_ct;
DROP TYPE probe_c FORCE;
DROP TYPE probe_p FORCE;
DROP TABLE probe_def;
DROP TYPE probe_b FORCE;
SPOOL OFF
EXIT
