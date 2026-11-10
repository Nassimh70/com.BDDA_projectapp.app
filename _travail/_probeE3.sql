SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 250
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF

PROMPT *** corps corrige : date_fin strictement superieure a date_debut ***
CREATE OR REPLACE TYPE BODY agence_vor_type AS
  MEMBER PROCEDURE mutation(nConseiller NUMBER, nAgenceCible VARCHAR2) IS
    v_ref_cons    REF conseiller_type;
    v_ref_ag_cur  REF agence_type;
    v_ref_ag_cib  REF agence_type;
    v_resp        NUMBER := 0;
    v_nb          NUMBER := 0;
  BEGIN
    SELECT REF(c) INTO v_ref_cons
      FROM conseiller c WHERE c.num_conseiller = nConseiller;

    SELECT REF(a) INTO v_ref_ag_cur
      FROM agence a WHERE a.code = SELF.code;

    SELECT REF(a) INTO v_ref_ag_cib
      FROM agence a WHERE a.code = nAgenceCible;

    SELECT COUNT(*) INTO v_nb
      FROM affectation af
     WHERE af.ref_conseiller = v_ref_cons
       AND af.ref_agence = v_ref_ag_cur
       AND af.date_fin IS NULL;

    IF v_nb = 0 THEN
      RAISE_APPLICATION_ERROR(-20010,
        'Le conseiller '||nConseiller||' n''est pas en poste dans l''agence '||SELF.code);
    END IF;

    SELECT COUNT(*) INTO v_resp
      FROM agence a
     WHERE a.code = SELF.code
       AND a.ref_responsable = v_ref_cons;

    IF v_resp > 0 THEN
      DBMS_OUTPUT.PUT_LINE('ALERTE : le conseiller '||nConseiller
        ||' est responsable de l''agence '||SELF.code||' qu''il quitte.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('Information : le conseiller '||nConseiller
        ||' n''est pas responsable de l''agence '||SELF.code||'.');
    END IF;

    UPDATE affectation
       SET date_fin = GREATEST(SYSDATE, date_debut) + 1/86400
     WHERE ref_conseiller = v_ref_cons
       AND ref_agence = v_ref_ag_cur
       AND date_fin IS NULL;

    INSERT INTO affectation (id_affectation, ref_conseiller, ref_agence,
                             date_debut, date_fin)
    VALUES (seq_affectation.NEXTVAL, v_ref_cons, v_ref_ag_cib, SYSDATE, NULL);

    DBMS_OUTPUT.PUT_LINE('Mutation effectuee : conseiller '||nConseiller
      ||' de '||SELF.code||' vers '||nAgenceCible||'.');
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20011, 'Conseiller ou agence introuvable.');
  END;
END;
/
SHOW ERRORS TYPE BODY agence_vor_type

PROMPT *** restauration 1 : A2 -> A1 ***
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A2';
  v_ag.mutation(1, 'A1');
  COMMIT;
END;
/

PROMPT *** restauration 4 : A3 -> A2 ***
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A3';
  v_ag.mutation(4, 'A2');
  COMMIT;
END;
/

PROMPT *** etat de la vue apres restauration ***
SELECT code, CARDINALITY(conseillers) AS nb_conseillers,
       CARDINALITY(comptes) AS nb_comptes
  FROM Agence_VOR ORDER BY code;

PROMPT *** E11 : comptage des mois par TABLE ***
SELECT r.annee, COUNT(*) AS nb_mois
  FROM releves r, TABLE(r.mois_vry) m
 GROUP BY r.annee;

PROMPT *** erreur : conseiller inexistant ***
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A1';
  v_ag.mutation(99, 'A2');
END;
/

PROMPT *** erreur : agence cible inexistante ***
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A1';
  v_ag.mutation(1, 'A9');
END;
/
