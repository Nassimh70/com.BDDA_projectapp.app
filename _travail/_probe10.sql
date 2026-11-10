SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 200
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF
WHENEVER SQLERROR CONTINUE

PROMPT ===== A. TABLE OBJET A OID PRIMAIRE + FK SUR REF =====
BEGIN
  EXECUTE IMMEDIATE 'CREATE TYPE d_ag_type AS OBJECT (code VARCHAR2(5), nom VARCHAR2(20))';
  EXECUTE IMMEDIATE 'CREATE TYPE d_cons_type AS OBJECT (num NUMBER, nom VARCHAR2(20))';
  EXECUTE IMMEDIATE 'CREATE TYPE d_cpt_type AS OBJECT (num VARCHAR2(10), solde NUMBER, ref_ag REF d_ag_type)';
  EXECUTE IMMEDIATE 'CREATE TYPE d_cons_nt_type AS TABLE OF d_cons_type';
  EXECUTE IMMEDIATE 'CREATE TYPE d_cpt_nt_type AS TABLE OF d_cpt_type';
  EXECUTE IMMEDIATE 'CREATE TYPE d_ag_vor_type AS OBJECT (
      code VARCHAR2(5), nom VARCHAR2(20),
      conseillers d_cons_nt_type, comptes d_cpt_nt_type)';
END;
/
CREATE TABLE d_ag OF d_ag_type (code PRIMARY KEY) OBJECT IDENTIFIER IS PRIMARY KEY;
CREATE TABLE d_cons OF d_cons_type;
CREATE TABLE d_cpt OF d_cpt_type;
CREATE TABLE d_aff (id NUMBER PRIMARY KEY, ref_cons REF d_cons_type,
                    ref_ag REF d_ag_type, date_fin DATE);
ALTER TABLE d_aff ADD CONSTRAINT d_fk_ag FOREIGN KEY (ref_ag) REFERENCES d_ag;
SHOW ERRORS
ALTER TABLE d_aff ADD CONSTRAINT d_fk_cons FOREIGN KEY (ref_cons) REFERENCES d_cons;
SHOW ERRORS
ALTER TABLE d_cpt ADD CONSTRAINT d_fk_cpt_ag FOREIGN KEY (ref_ag) REFERENCES d_ag;
SHOW ERRORS

INSERT INTO d_ag VALUES (d_ag_type('A1','Bejaia'));
INSERT INTO d_ag VALUES (d_ag_type('A2','Alger'));
INSERT INTO d_cons VALUES (d_cons_type(1,'Karim'));
INSERT INTO d_cons VALUES (d_cons_type(2,'Sara'));
INSERT INTO d_aff VALUES (1, (SELECT REF(c) FROM d_cons c WHERE c.num=1),
                             (SELECT REF(a) FROM d_ag a WHERE a.code='A1'), NULL);
INSERT INTO d_aff VALUES (2, (SELECT REF(c) FROM d_cons c WHERE c.num=2),
                             (SELECT REF(a) FROM d_ag a WHERE a.code='A2'), NULL);
INSERT INTO d_cpt VALUES (d_cpt_type('CC1', 1000, (SELECT REF(a) FROM d_ag a WHERE a.code='A1')));
INSERT INTO d_cpt VALUES (d_cpt_type('CC2', 2000, (SELECT REF(a) FROM d_ag a WHERE a.code='A1')));

PROMPT ===== B. LA FK SUR REF VERS UNE TABLE A OID PRIMAIRE EST VERIFIEE =====
DELETE FROM d_ag WHERE code = 'A1';

PROMPT ===== C. VUE OBJET AVEC CAST(MULTISET(...)) + MAKE_REF =====
CREATE OR REPLACE VIEW d_ag_vor OF d_ag_vor_type WITH OBJECT IDENTIFIER (code) AS
SELECT a.code,
       a.nom,
       CAST(MULTISET(
         SELECT VALUE(c)
           FROM d_cons c, d_aff f
          WHERE f.ref_cons = REF(c)
            AND f.ref_ag = MAKE_REF(d_ag, a.code)
            AND f.date_fin IS NULL) AS d_cons_nt_type) AS conseillers,
       CAST(MULTISET(
         SELECT VALUE(x)
           FROM d_cpt x
          WHERE x.ref_ag = MAKE_REF(d_ag, a.code)) AS d_cpt_nt_type) AS comptes
  FROM d_ag a;
SHOW ERRORS VIEW d_ag_vor

PROMPT ===== D. LES TROIS REQUETES D'INTERROGATION =====
SELECT v.code, c.num, c.nom
  FROM d_ag_vor v, TABLE(v.conseillers) c
 ORDER BY 1,2;
SELECT v.code, x.num, x.solde
  FROM d_ag_vor v, TABLE(v.comptes) x
 ORDER BY 1,2;
SELECT v.code, v.nom, a.nom AS nom_agence_rel
  FROM d_ag_vor v, d_ag a
 WHERE v.code = a.code
 ORDER BY 1;

PROMPT ===== E. VALEUR D'UN ELEMENT DE COLLECTION =====
DECLARE
  v d_cons_type;
BEGIN
  SELECT VALUE(c) INTO v FROM d_ag_vor x, TABLE(x.conseillers) c WHERE x.code='A1' AND c.num=1;
  DBMS_OUTPUT.PUT_LINE('VALUE = ' || v.num || ' / ' || v.nom);
END;
/

PROMPT ===== F. FIN =====
