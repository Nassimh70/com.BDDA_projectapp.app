SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 250
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF

PROMPT *** corps complet de agence_vor_type ***
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
       SET date_fin = SYSDATE
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

PROMPT *** etat initial de la vue ***
SELECT code, CARDINALITY(conseillers) AS nb_conseillers,
       CARDINALITY(comptes) AS nb_comptes
  FROM Agence_VOR ORDER BY code;

PROMPT *** mutation 4 : A2 -> A3 (non responsable) ***
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A2';
  v_ag.mutation(4, 'A3');
  COMMIT;
END;
/
SELECT code, CARDINALITY(conseillers) AS nb_conseillers
  FROM Agence_VOR ORDER BY code;

PROMPT *** mutation 1 : A1 -> A2 (responsable A1) ***
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A1';
  v_ag.mutation(1, 'A2');
  COMMIT;
END;
/
SELECT code, CARDINALITY(conseillers) AS nb_conseillers
  FROM Agence_VOR ORDER BY code;

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
SELECT code, CARDINALITY(conseillers) AS nb_conseillers
  FROM Agence_VOR ORDER BY code;

PROMPT *** erreur : conseiller hors agence ***
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A3';
  v_ag.mutation(1, 'A3');
END;
/

PROMPT *** E11 : insertion de 4 mois ***
DELETE FROM releves;
INSERT INTO releves (annee, mois_vry)
VALUES (2026, mois_vry_type(
  mois_elt_vry_type(1, 10, type_stat_nt_type(
    type_stat_elt_nt_type('RETRAIT', 6, 120000),
    type_stat_elt_nt_type('DEPOT',   3, 200000),
    type_stat_elt_nt_type('CB',      1,  15000))),
  mois_elt_vry_type(2, 8, type_stat_nt_type(
    type_stat_elt_nt_type('RETRAIT', 5,  90000),
    type_stat_elt_nt_type('DEPOT',   2, 150000),
    type_stat_elt_nt_type('VIREMENT',1,  50000))),
  mois_elt_vry_type(3, 12, type_stat_nt_type(
    type_stat_elt_nt_type('RETRAIT', 7, 140000),
    type_stat_elt_nt_type('DEPOT',   4, 250000),
    type_stat_elt_nt_type('CB',      1,  20000))),
  mois_elt_vry_type(4, 9, type_stat_nt_type(
    type_stat_elt_nt_type('RETRAIT', 6, 110000),
    type_stat_elt_nt_type('DEPOT',   2, 180000),
    type_stat_elt_nt_type('VIREMENT',1,  30000)))
));
COMMIT;
SELECT annee, CARDINALITY(mois_vry) AS nb_mois FROM releves;

PROMPT *** E11 : ajout du mois 5 ***
DECLARE
  v_mois  mois_vry_type;
  v_types type_stat_nt_type;
  v_av    NUMBER;
  v_ap    NUMBER;
BEGIN
  SELECT mois_vry INTO v_mois FROM releves WHERE annee = 2026 FOR UPDATE;
  v_av := v_mois.COUNT;
  v_mois.EXTEND(1);
  v_types := type_stat_nt_type(
    type_stat_elt_nt_type('RETRAIT', 8, 160000),
    type_stat_elt_nt_type('DEPOT',   2, 100000),
    type_stat_elt_nt_type('VIREMENT',1,  50000));
  v_mois(v_mois.LAST) := mois_elt_vry_type(5, 11, v_types);
  UPDATE releves SET mois_vry = v_mois WHERE annee = 2026;
  v_types := v_mois(v_mois.LAST).types;
  v_ap := v_mois.COUNT;
  DBMS_OUTPUT.PUT_LINE('VARRAY : '||v_av||' -> '||v_ap||' mois');
  DBMS_OUTPUT.PUT_LINE('Nested table du mois '||v_mois(v_mois.LAST).mois
    ||' : '||v_types.COUNT||' types');
  COMMIT;
END;
/
SELECT annee, CARDINALITY(mois_vry) AS nb_mois FROM releves;

PROMPT *** E11 : totaux par type sur l annee ***
SELECT t.type_op,
       SUM(t.nb) AS nb_total,
       SUM(t.montant_total) AS montant_total
  FROM releves r, TABLE(r.mois_vry) m, TABLE(m.types) t
 WHERE r.annee = 2026
 GROUP BY t.type_op
 ORDER BY montant_total DESC;

PROMPT *** E10 : mise a jour des parrains ***
UPDATE client SET ref_parrain = (SELECT REF(p) FROM client p WHERE p.num_client = 1)
 WHERE num_client = 4;
UPDATE client SET ref_parrain = (SELECT REF(p) FROM client p WHERE p.num_client = 2)
 WHERE num_client = 5;
UPDATE client SET ref_parrain = (SELECT REF(p) FROM client p WHERE p.num_client = 3)
 WHERE num_client = 6;
COMMIT;

SELECT c.num_client, c.nom,
       c.ref_parrain.nom AS nom_parrain,
       c.ref_parrain.ref_parrain.nom AS nom_grand_parrain
  FROM client c
 WHERE c.ref_parrain IS NOT NULL
 ORDER BY c.num_client;
