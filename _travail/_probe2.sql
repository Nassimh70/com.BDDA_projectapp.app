SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 200
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF
WHENEVER SQLERROR CONTINUE

PROMPT ===== NETTOYAGE =====
DROP VIEW pb_v;
DROP TABLE pb_cpt_t CASCADE CONSTRAINTS PURGE;
DROP TABLE pb_cli_t CASCADE CONSTRAINTS PURGE;
DROP TABLE pb_ag_t CASCADE CONSTRAINTS PURGE;
DROP TYPE pb_ag FORCE;
DROP TYPE pb_cpt FORCE;
DROP TYPE pb_sig_nt FORCE;
DROP TYPE pb_sig FORCE;
DROP TYPE pb_cli FORCE;
DROP TYPE pb_addr FORCE;

PROMPT ===== 1. TYPES (via EXECUTE IMMEDIATE) =====
BEGIN
  EXECUTE IMMEDIATE 'CREATE TYPE pb_addr AS OBJECT (ville VARCHAR2(30))';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_cli AS OBJECT (id NUMBER, adr pb_addr, parrain REF pb_cli)';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_sig AS OBJECT (r REF pb_cli, droit CHAR(1))';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_sig_nt AS TABLE OF pb_sig';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_cpt AS OBJECT (num VARCHAR2(10), ref_cli REF pb_cli, sigs pb_sig_nt)';
END;
/
SELECT type_name, typecode, attributes FROM user_types WHERE type_name LIKE 'PB_%' ORDER BY type_name;

PROMPT ===== 2. TABLES OBJET + SCOPE + NESTED TABLE =====
CREATE TABLE pb_cli_t OF pb_cli (id PRIMARY KEY);
CREATE TABLE pb_cpt_t OF pb_cpt (
  num PRIMARY KEY,
  CONSTRAINT ck_cpt_cli CHECK (ref_cli IS NOT NULL) DEFERRABLE INITIALLY DEFERRED
) NESTED TABLE sigs STORE AS pb_sig_st;
ALTER TABLE pb_cpt_t ADD SCOPE FOR (ref_cli) IS pb_cli_t;
ALTER TABLE pb_sig_st ADD CONSTRAINT ck_droit CHECK (droit IN ('X','R','D'));

PROMPT ===== 3. INSERTION + REF + NESTED TABLE =====
INSERT INTO pb_cli_t VALUES (pb_cli(1, pb_addr('Bejaia'), NULL));
INSERT INTO pb_cli_t VALUES (pb_cli(2, pb_addr('Alger'), NULL));
INSERT INTO pb_cpt_t VALUES (pb_cpt('C1', NULL, pb_sig_nt()));
UPDATE pb_cpt_t SET ref_cli = (SELECT REF(c) FROM pb_cli_t c WHERE c.id=1) WHERE num='C1';
INSERT INTO TABLE(SELECT sigs FROM pb_cpt_t WHERE num='C1')
  SELECT pb_sig(REF(c),'D') FROM pb_cli_t c WHERE c.id=2;
SELECT c.num AS compte, c.ref_cli.id AS titulaire, c.ref_cli.adr.ville AS ville,
       s.r.id AS signataire, s.droit
  FROM pb_cpt_t c, TABLE(c.sigs) s;
SELECT COUNT(*) AS nb_signataires FROM TABLE(SELECT sigs FROM pb_cpt_t WHERE num='C1');
SELECT MAKE_REF(pb_cli_t, 1).id AS id_make_ref FROM dual;

PROMPT ===== 4. CONTRAINTE NESTED TABLE (attendu ORA-02290) =====
INSERT INTO TABLE(SELECT sigs FROM pb_cpt_t WHERE num='C1')
  SELECT pb_sig(REF(c),'Z') FROM pb_cli_t c WHERE c.id=2;

PROMPT ===== 5. AUTO-REFERENCE : MISE A JOUR PARRAIN =====
UPDATE pb_cli_t p SET p.parrain = (SELECT REF(q) FROM pb_cli_t q WHERE q.id=1) WHERE p.id=2;
SELECT c.id, c.parrain.id AS id_parrain FROM pb_cli_t c ORDER BY c.id;

PROMPT ===== 6. METHODS : ALTER TYPE ADD MEMBER + BODY =====
ALTER TYPE pb_cli ADD MEMBER FUNCTION nbComptes RETURN NUMBER CASCADE;
CREATE OR REPLACE TYPE BODY pb_cli AS
  MEMBER FUNCTION nbComptes RETURN NUMBER IS
    v NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v FROM pb_cpt_t c WHERE c.ref_cli.id = SELF.id;
    RETURN v;
  END;
END;
/
SELECT c.id, c.nbComptes() AS nb FROM pb_cli_t c ORDER BY c.id;
SELECT VALUE(c).nbComptes() AS nb_value FROM pb_cli_t c WHERE c.id = 1;

PROMPT ===== 7. STATIC METHOD =====
ALTER TYPE pb_cpt ADD STATIC PROCEDURE afficheNum CASCADE;
CREATE OR REPLACE TYPE BODY pb_cpt AS
  STATIC PROCEDURE afficheNum IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('STATIC OK');
  END;
END;
/
BEGIN pb_cpt.afficheNum(); END;
/

PROMPT ===== 8. VARRAY + COUNT(*) / COUNT(col) =====
BEGIN
  EXECUTE IMMEDIATE 'CREATE TYPE pb_tel_v AS VARRAY(3) OF VARCHAR2(20)';
END;
/
CREATE TABLE pb_tel_t (id NUMBER, tels pb_tel_v);
INSERT INTO pb_tel_t VALUES (1, pb_tel_v('0661', NULL, NULL));
SELECT COUNT(*) AS total, COUNT(t.column_value) AS renseignes
  FROM pb_tel_t v, TABLE(v.tels) t;

PROMPT ===== 9. HERITAGE + OVERRIDING VIA ALTER TYPE =====
BEGIN
  EXECUTE IMMEDIATE 'CREATE TYPE pb_p AS OBJECT (x NUMBER) NOT FINAL';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_c UNDER pb_p (y NUMBER)';
END;
/
ALTER TYPE pb_p ADD MEMBER FUNCTION f RETURN NUMBER CASCADE;
ALTER TYPE pb_c ADD MEMBER FUNCTION f RETURN NUMBER CASCADE;
CREATE OR REPLACE TYPE BODY pb_p AS
  MEMBER FUNCTION f RETURN NUMBER IS BEGIN RETURN 1; END;
END;
/
CREATE OR REPLACE TYPE BODY pb_c AS
  MEMBER FUNCTION f RETURN NUMBER IS BEGIN RETURN 2; END;
END;
/
CREATE TABLE pb_ct OF pb_c;
INSERT INTO pb_ct VALUES (pb_c(10, 20));
SELECT VALUE(t).f() AS f_dispatch FROM pb_ct t;

PROMPT ===== FIN =====
