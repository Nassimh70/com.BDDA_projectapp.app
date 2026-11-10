SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 200
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF
WHENEVER SQLERROR CONTINUE

PROMPT ===== NETTOYAGE =====
DROP VIEW pb_v;
DROP TABLE pb_op CASCADE CONSTRAINTS PURGE;
DROP TABLE pb_ag_t CASCADE CONSTRAINTS PURGE;
DROP TABLE pb_cpt_t CASCADE CONSTRAINTS PURGE;
DROP TABLE pb_cli_t CASCADE CONSTRAINTS PURGE;
DROP TYPE pb_ag_vor FORCE;
DROP TYPE pb_cpt_nt FORCE;
DROP TYPE pb_cli_nt FORCE;
DROP TYPE pb_ag FORCE;
DROP TYPE pb_cpt FORCE;
DROP TYPE pb_sig_nt FORCE;
DROP TYPE pb_sig FORCE;
DROP TYPE pb_cli FORCE;
DROP TYPE pb_addr FORCE;

PROMPT ===== 1. TYPES =====
BEGIN
  EXECUTE IMMEDIATE 'CREATE TYPE pb_addr AS OBJECT (ville VARCHAR2(30))';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_cli AS OBJECT (id NUMBER, adr pb_addr)';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_sig AS OBJECT (r REF pb_cli, droit CHAR(1))';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_sig_nt AS TABLE OF pb_sig';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_cpt AS OBJECT (num VARCHAR2(10), ref_cli REF pb_cli, solde NUMBER, nb_cb NUMBER, sigs pb_sig_nt)';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_ag AS OBJECT (code VARCHAR2(10), nom VARCHAR2(30))';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_cli_nt AS TABLE OF pb_cli';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_cpt_nt AS TABLE OF pb_cpt';
END;
/

PROMPT ===== 2. TABLES OBJET AVEC OBJECT IDENTIFIER IS PRIMARY KEY =====
CREATE TABLE pb_cli_t OF pb_cli (id PRIMARY KEY) OBJECT IDENTIFIER IS PRIMARY KEY;
CREATE TABLE pb_cpt_t OF pb_cpt (num PRIMARY KEY) OBJECT IDENTIFIER IS PRIMARY KEY
  NESTED TABLE sigs STORE AS pb_sig_st;
CREATE TABLE pb_ag_t OF pb_ag (code PRIMARY KEY) OBJECT IDENTIFIER IS PRIMARY KEY;
ALTER TABLE pb_cpt_t ADD SCOPE FOR (ref_cli) IS pb_cli_t;
ALTER TABLE pb_sig_st ADD CONSTRAINT ck_droit CHECK (droit IN ('X','R','D'));

PROMPT ===== 3. DONNEES =====
INSERT INTO pb_ag_t VALUES (pb_ag('A1','Bejaia'));
INSERT INTO pb_ag_t VALUES (pb_ag('A2','Alger'));
INSERT INTO pb_cli_t VALUES (pb_cli(1, pb_addr('Bejaia')));
INSERT INTO pb_cli_t VALUES (pb_cli(2, pb_addr('Alger')));
INSERT INTO pb_cpt_t VALUES (pb_cpt('C1', NULL, 1000, 0, pb_sig_nt()));
UPDATE pb_cpt_t SET ref_cli = (SELECT REF(c) FROM pb_cli_t c WHERE c.id=1) WHERE num='C1';
INSERT INTO TABLE(SELECT sigs FROM pb_cpt_t WHERE num='C1') SELECT pb_sig(REF(c),'D') FROM pb_cli_t c WHERE c.id=2;

PROMPT ===== 4. MAKE_REF =====
SELECT a.code, MAKE_REF(pb_ag_t, a.code).code AS ref_code FROM pb_ag_t a ORDER BY a.code;

PROMPT ===== 5. VUE OBJET =====
BEGIN
  EXECUTE IMMEDIATE 'CREATE TYPE pb_ag_vor AS OBJECT (
    code VARCHAR2(10), nom VARCHAR2(30), clis pb_cli_nt, cpts pb_cpt_nt)';
END;
/
CREATE OR REPLACE VIEW pb_v OF pb_ag_vor WITH OBJECT IDENTIFIER (code) AS
SELECT a.code,
       a.nom,
       CAST(MULTISET(SELECT VALUE(c) FROM pb_cli_t c) AS pb_cli_nt) AS clis,
       CAST(MULTISET(SELECT VALUE(x) FROM pb_cpt_t x
                     WHERE MAKE_REF(pb_ag_t, a.code).code IS NOT NULL) AS pb_cpt_nt) AS cpts
FROM pb_ag_t a;
SELECT v.code, c.id FROM pb_v v, TABLE(v.clis) c ORDER BY 1,2;
SELECT v.code, x.num, x.solde FROM pb_v v, TABLE(v.cpts) x ORDER BY 1,2;
SELECT v.code, a.nom FROM pb_v v, pb_ag_t a WHERE v.code = a.code ORDER BY 1;

PROMPT ===== 6. METHODE SUR TYPE DE VUE =====
ALTER TYPE pb_ag_vor ADD MEMBER PROCEDURE mutation(nCli NUMBER) CASCADE;
CREATE OR REPLACE TYPE BODY pb_ag_vor AS
  MEMBER PROCEDURE mutation(nCli NUMBER) IS
  BEGIN
    UPDATE pb_cli_t c SET c.adr = pb_addr('M-' || SELF.code) WHERE c.id = nCli;
    DBMS_OUTPUT.PUT_LINE('MUTATION OK ' || SELF.code);
  END;
END;
/
DECLARE
  v pb_ag_vor;
BEGIN
  SELECT VALUE(x) INTO v FROM pb_v x WHERE x.code = 'A1';
  v.mutation(1);
END;
/
SELECT c.id, c.adr.ville FROM pb_cli_t c ORDER BY c.id;

PROMPT ===== 7. TABLE OPERATIONS =====
CREATE TABLE pb_op (
  id NUMBER PRIMARY KEY,
  ref_cpt REF pb_cpt,
  ref_cli REF pb_cli,
  montant NUMBER,
  type_op VARCHAR2(10),
  dt DATE DEFAULT SYSDATE
);

PROMPT ===== 8. TRIGGER BEFORE INSERT AVEC VARIABLE REF =====
CREATE OR REPLACE TRIGGER pb_op_bi
BEFORE INSERT ON pb_op
FOR EACH ROW
DECLARE
  v_ref REF pb_cpt;
  v_num VARCHAR2(10);
BEGIN
  v_ref := :NEW.ref_cpt;
  v_num := v_ref.num;
  IF :NEW.montant < 0 AND v_num = 'C1' THEN
    RAISE_APPLICATION_ERROR(-20001, 'RETRAIT REFUSE (test)');
  END IF;
END;
/
SHOW ERRORS TRIGGER pb_op_bi
INSERT INTO pb_op (id, ref_cpt, ref_cli, montant, type_op)
  SELECT 1, REF(x), REF(c), -10, 'RETRAIT' FROM pb_cpt_t x, pb_cli_t c WHERE x.num='C1' AND c.id=1;
INSERT INTO pb_op (id, ref_cpt, ref_cli, montant, type_op)
  SELECT 2, REF(x), REF(c), 100, 'DEPOT' FROM pb_cpt_t x, pb_cli_t c WHERE x.num='C1' AND c.id=1;

PROMPT ===== 9. COMPOUND TRIGGER PLAFOND =====
CREATE OR REPLACE TRIGGER pb_op_plafond
FOR INSERT ON pb_op
COMPOUND TRIGGER
  TYPE t_tab IS TABLE OF NUMBER INDEX BY VARCHAR2(10);
  g_tot t_tab;
  BEFORE STATEMENT IS
    CURSOR c IS
      SELECT o.ref_cpt.num AS num, SUM(-o.montant) AS total
        FROM pb_op o
       WHERE o.montant < 0 AND o.type_op = 'RETRAIT'
         AND TRUNC(o.dt) = TRUNC(SYSDATE)
       GROUP BY o.ref_cpt.num;
  BEGIN
    FOR r IN c LOOP g_tot(r.num) := r.total; END LOOP;
  END BEFORE STATEMENT;
  BEFORE EACH ROW IS
    v_ref REF pb_cpt;
    v_num VARCHAR2(10);
    v_tot NUMBER;
  BEGIN
    IF :NEW.montant < 0 AND :NEW.type_op = 'RETRAIT' THEN
      v_ref := :NEW.ref_cpt;
      v_num := v_ref.num;
      v_tot := NVL(g_tot(v_num), 0) + (-:NEW.montant);
      IF v_tot > 200000 THEN
        RAISE_APPLICATION_ERROR(-20002, 'PLAFOND DEPASSE : ' || v_tot);
      END IF;
      g_tot(v_num) := v_tot;
    END IF;
  END BEFORE EACH ROW;
END;
/
SHOW ERRORS TRIGGER pb_op_plafond
INSERT INTO pb_op (id, ref_cpt, ref_cli, montant, type_op)
  SELECT 3, REF(x), REF(c), -150000, 'RETRAIT' FROM pb_cpt_t x, pb_cli_t c WHERE x.num='C1' AND c.id=1;
INSERT INTO pb_op (id, ref_cpt, ref_cli, montant, type_op)
  SELECT 4, REF(x), REF(c), -60000, 'RETRAIT' FROM pb_cpt_t x, pb_cli_t c WHERE x.num='C1' AND c.id=1;
SELECT id, montant FROM pb_op ORDER BY id;

PROMPT ===== 10. TRIGGER AFTER INSERT : MAJ SOLDE + COMPTEUR CB =====
CREATE OR REPLACE TRIGGER pb_op_ai
AFTER INSERT ON pb_op
FOR EACH ROW
BEGIN
  UPDATE pb_cpt_t x
     SET x.solde = x.solde + :NEW.montant,
         x.nb_cb = x.nb_cb + CASE WHEN :NEW.type_op = 'CB' THEN 1 ELSE 0 END
   WHERE x.num = :NEW.ref_cpt.num;
END;
/
SHOW ERRORS TRIGGER pb_op_ai
INSERT INTO pb_op (id, ref_cpt, ref_cli, montant, type_op)
  SELECT 5, REF(x), REF(c), 1000, 'CB' FROM pb_cpt_t x, pb_cli_t c WHERE x.num='C1' AND c.id=1;
SELECT num, solde, nb_cb FROM pb_cpt_t;

PROMPT ===== 11. AUDIT =====
CREATE TABLE pb_audit (id NUMBER GENERATED BY DEFAULT AS IDENTITY, obj VARCHAR2(30), anc NUMBER, nouv NUMBER, dt DATE, utilisateur VARCHAR2(30));
CREATE OR REPLACE TRIGGER pb_cpt_au
AFTER UPDATE OF solde ON pb_cpt_t
FOR EACH ROW
BEGIN
  IF :OLD.solde <> :NEW.solde THEN
    INSERT INTO pb_audit (obj, anc, nouv, dt, utilisateur)
      VALUES ('SOLDE', :OLD.solde, :NEW.solde, SYSDATE, USER);
  END IF;
END;
/
SHOW ERRORS TRIGGER pb_cpt_au
UPDATE pb_cpt_t SET solde = solde + 5 WHERE num = 'C1';
SELECT obj, anc, nouv, utilisateur FROM pb_audit;

PROMPT ===== 12. PRAGMA EXCEPTION_INIT =====
DECLARE
  e_notnull EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_notnull, -1400);
BEGIN
  INSERT INTO pb_op (id, ref_cpt, ref_cli, montant) VALUES (99, NULL, NULL, 10);
EXCEPTION
  WHEN e_notnull THEN DBMS_OUTPUT.PUT_LINE('ORA-01400 INTERCEPTEE');
END;
/

PROMPT ===== 13. DISPATCH POLYMORPHE AVEC OVERRIDING A LA CREATION =====
BEGIN
  EXECUTE IMMEDIATE 'CREATE TYPE pb_p AS OBJECT (x NUMBER, MEMBER FUNCTION f RETURN NUMBER) NOT FINAL';
  EXECUTE IMMEDIATE 'CREATE TYPE pb_c UNDER pb_p (y NUMBER, OVERRIDING MEMBER FUNCTION f RETURN NUMBER)';
END;
/
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
DECLARE
  v pb_p;
BEGIN
  SELECT VALUE(t) INTO v FROM pb_ct t;
  DBMS_OUTPUT.PUT_LINE('DISPATCH DYNAMIQUE = ' || v.f());
END;
/

PROMPT ===== FIN =====
