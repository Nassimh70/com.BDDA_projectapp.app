SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 200
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF
WHENEVER SQLERROR CONTINUE

PROMPT ===== A. REF RECURSIF AJOUTE PAR ALTER TYPE ... CASCADE =====
BEGIN
  EXECUTE IMMEDIATE 'CREATE TYPE r_cli_type AS OBJECT (id NUMBER, nom VARCHAR2(30)) NOT FINAL';
END;
/
CREATE TABLE r_cli OF r_cli_type;
INSERT INTO r_cli VALUES (1,'A');
INSERT INTO r_cli VALUES (2,'B');
ALTER TYPE r_cli_type ADD ATTRIBUTE ref_parrain REF r_cli_type CASCADE;
SHOW ERRORS TYPE r_cli_type
UPDATE r_cli c SET c.ref_parrain = (SELECT REF(p) FROM r_cli p WHERE p.id = 1) WHERE c.id = 2;
COMMIT;
SELECT c.id, c.nom, c.ref_parrain.id AS id_parrain FROM r_cli c ORDER BY c.id;
SELECT c.id, c.ref_parrain.nom AS parrain, c.ref_parrain.ref_parrain.nom AS grand_parrain
  FROM r_cli c WHERE c.id = 2;

PROMPT ===== B. CONTRAINTE FK SUR UNE COLONNE REF =====
BEGIN
  EXECUTE IMMEDIATE 'CREATE TYPE b_cli_type AS OBJECT (id NUMBER, nom VARCHAR2(20))';
END;
/
CREATE TABLE b_cli OF b_cli_type;
INSERT INTO b_cli VALUES (1,'X');
CREATE TABLE b_use (id NUMBER PRIMARY KEY, r REF b_cli_type);
ALTER TABLE b_use ADD CONSTRAINT b_fk_ref FOREIGN KEY (r) REFERENCES b_cli;
SHOW ERRORS
INSERT INTO b_use VALUES (1, (SELECT REF(c) FROM b_cli c WHERE c.id = 1));
SELECT id, DEREF(r).nom AS nom FROM b_use;

PROMPT ===== C. LA FK SUR REF EST-ELLE REELLEMENT VERIFIEE ? =====
DELETE FROM b_cli WHERE id = 1;
SELECT COUNT(*) AS restant_dans_b_cli FROM b_cli;
SELECT COUNT(*) AS restant_dans_b_use FROM b_use;

PROMPT ===== D. SCOPE IS SUR UNE COLONNE REF =====
CREATE TABLE b_use2 (id NUMBER, r REF b_cli_type SCOPE IS b_cli);
SHOW ERRORS
INSERT INTO b_use2 VALUES (1, (SELECT REF(c) FROM b_cli c WHERE c.id = 1));

PROMPT ===== E. FK SUR REF DANS LE STOCKAGE D'UNE NESTED TABLE =====
BEGIN
  EXECUTE IMMEDIATE 'CREATE TYPE b_sig_type AS OBJECT (r REF b_cli_type, droit CHAR(1))';
  EXECUTE IMMEDIATE 'CREATE TYPE b_sig_nt_type AS TABLE OF b_sig_type';
END;
/
CREATE TABLE b_nt (id NUMBER PRIMARY KEY, sig b_sig_nt_type)
  NESTED TABLE sig STORE AS b_sig_st;
ALTER TABLE b_sig_st ADD CONSTRAINT b_fk_nt_ref FOREIGN KEY (r) REFERENCES b_cli;
SHOW ERRORS
INSERT INTO b_nt VALUES (1, b_sig_nt_type(b_sig_type((SELECT REF(c) FROM b_cli c WHERE c.id = 1), 'D')));
SELECT n.id, s.r.id AS id_client, s.droit FROM b_nt n, TABLE(n.sig) s;

PROMPT ===== F. FIN =====
