SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
BEGIN
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL,
          (SELECT REF(c) FROM client c WHERE c.num_client = 5),
          (SELECT REF(cc) FROM cpt_courant cc WHERE cc.num_compte = 'CC5'),
          TRUNC(SYSDATE), -1000, 'RETRAIT', 0);
  DBMS_OUTPUT.PUT_LINE('Inattendu : accepte');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Refus attendu : '||SQLERRM);
END;
/
ROLLBACK;
EXIT