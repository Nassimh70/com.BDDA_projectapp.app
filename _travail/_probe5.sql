SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 200
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF
WHENEVER SQLERROR CONTINUE

PROMPT ===== NETTOYAGE =====
DROP TABLE p5_op CASCADE CONSTRAINTS PURGE;
DROP TABLE p5_cpt_t CASCADE CONSTRAINTS PURGE;
DROP TABLE p5_cli_t CASCADE CONSTRAINTS PURGE;
DROP TABLE p5_ag_t CASCADE CONSTRAINTS PURGE;
DROP TABLE p5_ct CASCADE CONSTRAINTS PURGE;
DROP TYPE p5_c FORCE;
DROP TYPE p5_p FORCE;
DROP TYPE p5_cpt FORCE;
DROP TYPE p5_sig_nt FORCE;
DROP TYPE p5_sig FORCE;
DROP TYPE p5_cli FORCE;
DROP TYPE p5_ag FORCE;
DROP TYPE p5_addr FORCE;

PROMPT ===== 1. TYPES =====
BEGIN
  EXECUTE IMMEDIATE 'CREATE TYPE p5_addr AS OBJECT (ville VARCHAR2(30))';
  EXECUTE IMMEDIATE 'CREATE TYPE p5_cli AS OBJECT (id NUMBER, adr p5_addr, parrain REF p5_cli)';
  EXECUTE IMMEDIATE 'CREATE TYPE p5_sig AS OBJECT (r REF p5_cli, droit CHAR(1))';
  EXECUTE IMMEDIATE 'CREATE TYPE p5_sig_nt AS TABLE OF p5_sig';
  EXECUTE IMMEDIATE 'CREATE TYPE p5_cpt AS OBJECT (num VARCHAR2(10), ref_cli REF p5_cli, solde NUMBER, nb_cb NUMBER, sigs p5_sig_nt)';
  EXECUTE IMMEDIATE 'CREATE TYPE p5_ag AS OBJECT (code VARCHAR2(10), nom VARCHAR2(30))';
END;
/

PROMPT ===== 2. TABLES =====
CREATE TABLE p5_ag_t OF p5_ag (code PRIMARY KEY) OBJECT IDENTIFIER IS PRIMARY KEY;
CREATE TABLE p5_cli_t OF p5_cli (id PRIMARY KEY);
ALTER TABLE p5_cli_t ADD SCOPE FOR (parrain) IS p5_cli_t;
CREATE TABLE p5_cpt_t OF p5_cpt (
  num PRIMARY KEY,
  CONSTRAINT ck_cpt_cli CHECK (ref_cli IS NOT NULL) DEFERRABLE INITIALLY DEFERRED
) NESTED TABLE sigs STORE AS p5_sig_st;
ALTER TABLE p5_cpt_t ADD SCOPE FOR (ref_cli) IS p5_cli_t;
ALTER TABLE p5_sig_st ADD CONSTRAINT ck_droit CHECK (droit IN ('X','R','D'));

PROMPT ===== 3. INSERTION CC SANS CLIENT (CHECK DIFFEREE) PUIS UPDATE =====
INSERT INTO p5_ag_t VALUES (p5_ag('A1','Bejaia'));
INSERT INTO p5_ag_t VALUES (p5_ag('A2','Alger'));
INSERT INTO p5_cli_t VALUES (p5_cli(1, p5_addr('Bejaia'), NULL));
INSERT INTO p5_cli_t VALUES (p5_cli(2, p5_addr('Alger'), NULL));
UPDATE p5_cli_t SET parrain = (SELECT REF(x) FROM p5_cli_t x WHERE x.id = 1) WHERE id = 2;
INSERT INTO p5_cpt_t VALUES (p5_cpt('C1', NULL, 0, 0, p5_sig_nt()));
SELECT COUNT(*) AS comptes_avant_update FROM p5_cpt_t;
UPDATE p5_cpt_t SET ref_cli = (SELECT REF(c) FROM p5_cli_t c WHERE c.id=1) WHERE num='C1';
COMMIT;
SELECT num, ref_cli.id AS titulaire FROM p5_cpt_t;

PROMPT ===== 4. NESTED TABLE + REF (client en OID systeme) =====
INSERT INTO TABLE(SELECT sigs FROM p5_cpt_t WHERE num='C1')
  SELECT p5_sig(REF(c),'D') FROM p5_cli_t c WHERE c.id=2;
SELECT COUNT(*) AS nb_sig FROM TABLE(SELECT sigs FROM p5_cpt_t WHERE num='C1');

PROMPT ===== 5. TABLE OPERATIONS =====
CREATE TABLE p5_op (
  id NUMBER PRIMARY KEY,
  ref_cpt REF p5_cpt,
  ref_cli REF p5_cli,
  montant NUMBER,
  type_op VARCHAR2(10),
  dt DATE DEFAULT SYSDATE
);

PROMPT ===== 6. TRIGGER BEFORE INSERT (droits/statut) =====
CREATE OR REPLACE TRIGGER p5_op_bi
BEFORE INSERT ON p5_op
FOR EACH ROW
DECLARE
  v_num VARCHAR2(10);
BEGIN
  SELECT x.num INTO v_num FROM p5_cpt_t x WHERE REF(x) = :NEW.ref_cpt;
  IF :NEW.montant < 0 AND v_num = 'C1' AND :NEW.type_op = 'RETRAIT' AND :NEW.montant < -200000 THEN
    RAISE_APPLICATION_ERROR(-20001, 'MONTANT RETRAIT TROP ELEVE');
  END IF;
END;
/
SHOW ERRORS TRIGGER p5_op_bi

PROMPT ===== 7. COMPOUND TRIGGER PLAFOND =====
CREATE OR REPLACE TRIGGER p5_op_plafond
FOR INSERT ON p5_op
COMPOUND TRIGGER
  TYPE t_tab IS TABLE OF NUMBER INDEX BY VARCHAR2(10);
  g_tot t_tab;
  BEFORE STATEMENT IS
    CURSOR c IS
      SELECT o.ref_cpt.num AS num, SUM(-o.montant) AS total
        FROM p5_op o
       WHERE o.montant < 0 AND o.type_op = 'RETRAIT'
         AND TRUNC(o.dt) = TRUNC(SYSDATE)
       GROUP BY o.ref_cpt.num;
  BEGIN
    FOR r IN c LOOP g_tot(r.num) := r.total; END LOOP;
  END BEFORE STATEMENT;
  BEFORE EACH ROW IS
    v_num VARCHAR2(10);
    v_tot NUMBER;
  BEGIN
    IF :NEW.montant < 0 AND :NEW.type_op = 'RETRAIT' THEN
      SELECT x.num INTO v_num FROM p5_cpt_t x WHERE REF(x) = :NEW.ref_cpt;
      v_tot := NVL(g_tot(v_num), 0) + (-:NEW.montant);
      IF v_tot > 200000 THEN
        RAISE_APPLICATION_ERROR(-20002, 'PLAFOND DEPASSE : ' || v_tot);
      END IF;
      g_tot(v_num) := v_tot;
    END IF;
  END BEFORE EACH ROW;
END;
/
SHOW ERRORS TRIGGER p5_op_plafond

PROMPT ===== 8. TRIGGER AFTER INSERT : SOLDE + CB =====
CREATE OR REPLACE TRIGGER p5_op_ai
AFTER INSERT ON p5_op
FOR EACH ROW
DECLARE
  v_num VARCHAR2(10);
BEGIN
  SELECT x.num INTO v_num FROM p5_cpt_t x WHERE REF(x) = :NEW.ref_cpt;
  UPDATE p5_cpt_t x
     SET x.solde = x.solde + :NEW.montant,
         x.nb_cb = x.nb_cb + CASE WHEN :NEW.type_op = 'CB' THEN 1 ELSE 0 END
   WHERE x.num = v_num;
END;
/
SHOW ERRORS TRIGGER p5_op_ai

PROMPT ===== 9. JEU DE TEST TRIGGERS =====
INSERT INTO p5_op (id, ref_cpt, ref_cli, montant, type_op)
  SELECT 1, REF(x), REF(c), 100000, 'DEPOT' FROM p5_cpt_t x, p5_cli_t c WHERE x.num='C1' AND c.id=1;
INSERT INTO p5_op (id, ref_cpt, ref_cli, montant, type_op)
  SELECT 2, REF(x), REF(c), -150000, 'RETRAIT' FROM p5_cpt_t x, p5_cli_t c WHERE x.num='C1' AND c.id=1;
INSERT INTO p5_op (id, ref_cpt, ref_cli, montant, type_op)
  SELECT 3, REF(x), REF(c), -60000, 'RETRAIT' FROM p5_cpt_t x, p5_cli_t c WHERE x.num='C1' AND c.id=1;
INSERT INTO p5_op (id, ref_cpt, ref_cli, montant, type_op)
  SELECT 4, REF(x), REF(c), 500, 'CB' FROM p5_cpt_t x, p5_cli_t c WHERE x.num='C1' AND c.id=1;
SELECT num, solde, nb_cb FROM p5_cpt_t;
SELECT id, montant, type_op FROM p5_op ORDER BY id;

PROMPT ===== 10. ALERTE > 1 000 000 =====
CREATE TABLE p5_alerte (id NUMBER GENERATED BY DEFAULT AS IDENTITY, msg VARCHAR2(100), dt DATE DEFAULT SYSDATE);
CREATE OR REPLACE TRIGGER p5_op_alerte
AFTER INSERT ON p5_op
FOR EACH ROW
BEGIN
  IF ABS(:NEW.montant) > 1000000 THEN
    INSERT INTO p5_alerte (msg) VALUES ('OPERATION SUSPECTE : ' || :NEW.montant);
  END IF;
END;
/
INSERT INTO p5_op (id, ref_cpt, ref_cli, montant, type_op)
  SELECT 5, REF(x), REF(c), 1500000, 'DEPOT' FROM p5_cpt_t x, p5_cli_t c WHERE x.num='C1' AND c.id=1;
SELECT msg FROM p5_alerte;

PROMPT ===== 11. PRAGMA EXCEPTION_INIT =====
DECLARE
  e_notnull EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_notnull, -1400);
BEGIN
  INSERT INTO p5_op (id, ref_cpt, ref_cli, montant) VALUES (99, NULL, NULL, 10);
EXCEPTION
  WHEN e_notnull THEN DBMS_OUTPUT.PUT_LINE('ORA-01400 INTERCEPTEE');
END;
/

PROMPT ===== 12. DISPATCH POLYMORPHE =====
BEGIN
  EXECUTE IMMEDIATE 'CREATE TYPE p5_p AS OBJECT (x NUMBER, MEMBER FUNCTION f RETURN NUMBER) NOT FINAL';
  EXECUTE IMMEDIATE 'CREATE TYPE p5_c UNDER p5_p (y NUMBER, OVERRIDING MEMBER FUNCTION f RETURN NUMBER)';
END;
/
CREATE OR REPLACE TYPE BODY p5_p AS
  MEMBER FUNCTION f RETURN NUMBER IS BEGIN RETURN 1; END;
END;
/
CREATE OR REPLACE TYPE BODY p5_c AS
  MEMBER FUNCTION f RETURN NUMBER IS BEGIN RETURN 2; END;
END;
/
CREATE TABLE p5_ct OF p5_c;
INSERT INTO p5_ct VALUES (p5_c(10, 20));
SELECT VALUE(t).f() AS f_dispatch FROM p5_ct t;
DECLARE
  v p5_p;
BEGIN
  SELECT VALUE(t) INTO v FROM p5_ct t WHERE t.x = 10;
  DBMS_OUTPUT.PUT_LINE('DISPATCH DYNAMIQUE = ' || v.f());
END;
/

PROMPT ===== FIN =====
