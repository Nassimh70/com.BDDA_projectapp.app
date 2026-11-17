-- =====================================================================
-- DEMO_SOUTENANCE.SQL
-- Demonstration de 10 minutes, rejouable sans modifier l'etat final.
-- Tous les mouvements sont annules par ROLLBACK.
-- Connexion : sqlplus MASTER1/system@localhost:1521/XEPDB1
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK ON
SET VERIFY OFF

PROMPT ############################################################
PROMPT 0. ENVIRONNEMENT ET CONTROLE
PROMPT ############################################################
SELECT USER AS utilisateur FROM dual;

SELECT COUNT(*) AS objets_invalides
  FROM user_objects
 WHERE status <> 'VALID';

SELECT object_type, COUNT(*) AS nb
  FROM user_objects
 GROUP BY object_type
 ORDER BY object_type;

PROMPT ############################################################
PROMPT 1. PARTIE A : TYPES, TABLES, DONNEES
PROMPT ############################################################
SELECT COUNT(*) AS nb_types_metier FROM user_types;

SELECT COUNT(*) AS nb_clients FROM client;
SELECT COUNT(*) AS nb_cc FROM cpt_courant;
SELECT COUNT(*) AS nb_ce FROM cpt_epargne;
SELECT COUNT(*) AS nb_ct FROM cpt_terme;

PROMPT ############################################################
PROMPT 2. PARTIE C : DEUX REQUETES PHARES
PROMPT ############################################################
PROMPT *** 6.10 : compte courant a solde negatif ***
SELECT cc.num_compte, cc.solde, c.nom AS titulaire, k.nom AS conseiller
  FROM cpt_courant cc, client c, conseiller k
 WHERE cc.ref_client = REF(c)
   AND c.ref_conseiller = REF(k)
   AND cc.solde < 0;

PROMPT *** 6.20 : signataires de CC7 avec adresse ***
SELECT c.num_client, c.nom,
       c.adresse.num_rue||' '||c.adresse.rue||', '||c.adresse.ville AS adresse,
       s.droit
  FROM cpt_courant cc, TABLE(cc.signataires) s, client c
 WHERE cc.num_compte = 'CC7'
   AND s.ref_client = REF(c)
 ORDER BY c.num_client;

PROMPT ############################################################
PROMPT 3. PARTIE D : METHODES
PROMPT ############################################################
PROMPT *** nbCepargne et soldeTotal (etat final, apres fermeture de CE4) ***
SELECT c.num_client, c.nom, c.nbCepargne() AS nb_epargne,
       c.soldeTotal() AS solde_total
  FROM client c
 ORDER BY c.num_client;

PROMPT *** calculeInterets et sortieAnticipee des comptes d epargne ***
SELECT ce.num_compte, ce.solde, ce.calculeInterets() AS a_l_echeance,
       ce.sortieAnticipee() AS sortie_anticipee
  FROM cpt_epargne ce
 ORDER BY ce.num_compte;

PROMPT *** passeMvt : +10 000 sur CC7 par le titulaire (client 4), puis ROLLBACK ***
DECLARE
  v_cc    cptCourant_type;
  v_avant NUMBER;
  v_apres NUMBER;
BEGIN
  SELECT solde INTO v_avant FROM cpt_courant WHERE num_compte = 'CC7';
  SELECT VALUE(cc) INTO v_cc FROM cpt_courant cc WHERE cc.num_compte = 'CC7';
  v_cc.passeMvt(4, 10000);
  SELECT solde INTO v_apres FROM cpt_courant WHERE num_compte = 'CC7';
  DBMS_OUTPUT.PUT_LINE('CC7 : '||v_avant||' -> '||v_apres);
  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('ROLLBACK : CC7 revient a 185000.');
END;
/

PROMPT ############################################################
PROMPT 4. PARTIE D : TRIGGERS DE SECURITE
PROMPT ############################################################
PROMPT *** Refus 1 : compte CC5 BLOQUE ***
BEGIN
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL,
          (SELECT REF(c) FROM client c WHERE c.num_client = 5),
          (SELECT REF(cc) FROM cpt_courant cc WHERE cc.num_compte = 'CC5'),
          TRUNC(SYSDATE), -1000, 'RETRAIT', 0);
  DBMS_OUTPUT.PUT_LINE('Inattendu : operation acceptee.');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Refus attendu : '||SQLERRM);
END;
/

PROMPT *** Refus 2 : plafond journalier de 200 000 DA sur CC4 ***
BEGIN
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL,
          (SELECT REF(c) FROM client c WHERE c.num_client = 3),
          (SELECT REF(cc) FROM cpt_courant cc WHERE cc.num_compte = 'CC4'),
          TRUNC(SYSDATE), -210000, 'RETRAIT', 0);
  DBMS_OUTPUT.PUT_LINE('Inattendu : operation acceptee.');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Refus attendu : '||SQLERRM);
END;
/

PROMPT *** Succes : depot de 10 000 sur CC6, puis ROLLBACK ***
DECLARE
  v_avant NUMBER;
  v_apres NUMBER;
BEGIN
  SELECT solde INTO v_avant FROM cpt_courant WHERE num_compte = 'CC6';
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL,
          (SELECT REF(c) FROM client c WHERE c.num_client = 6),
          (SELECT REF(cc) FROM cpt_courant cc WHERE cc.num_compte = 'CC6'),
          TRUNC(SYSDATE), 10000, 'DEPOT', 0);
  SELECT solde INTO v_apres FROM cpt_courant WHERE num_compte = 'CC6';
  DBMS_OUTPUT.PUT_LINE('CC6 : '||v_avant||' -> '||v_apres);
  ROLLBACK;
  DBMS_OUTPUT.PUT_LINE('ROLLBACK : CC6 revient a 40000.');
END;
/

PROMPT ############################################################
PROMPT 5. PARTIE D : VIREMENTS
PROMPT ############################################################
PROMPT *** Virement same-agence CC4 -> CC7 de 1000 DA, puis ROLLBACK ***
DECLARE
  v_cc4 NUMBER;
  v_cc7 NUMBER;
BEGIN
  SELECT solde INTO v_cc4 FROM cpt_courant WHERE num_compte = 'CC4';
  SELECT solde INTO v_cc7 FROM cpt_courant WHERE num_compte = 'CC7';
  DBMS_OUTPUT.PUT_LINE('Avant : CC4='||v_cc4||' CC7='||v_cc7);

  virement('CC4', 'CC7', 1000, 4);

  SELECT solde INTO v_cc4 FROM cpt_courant WHERE num_compte = 'CC4';
  SELECT solde INTO v_cc7 FROM cpt_courant WHERE num_compte = 'CC7';
  DBMS_OUTPUT.PUT_LINE('Apres : CC4='||v_cc4||' CC7='||v_cc7||' (commission 0)');
  ROLLBACK;
END;
/

PROMPT *** Virement inter-agences CC4 (A1) -> CC3 (A3) de 1000 DA, puis ROLLBACK ***
DECLARE
  v_cc4 NUMBER;
  v_cc3 NUMBER;
BEGIN
  SELECT solde INTO v_cc4 FROM cpt_courant WHERE num_compte = 'CC4';
  SELECT solde INTO v_cc3 FROM cpt_courant WHERE num_compte = 'CC3';
  DBMS_OUTPUT.PUT_LINE('Avant : CC4='||v_cc4||' CC3='||v_cc3);

  virement('CC4', 'CC3', 1000, 3);

  SELECT solde INTO v_cc4 FROM cpt_courant WHERE num_compte = 'CC4';
  SELECT solde INTO v_cc3 FROM cpt_courant WHERE num_compte = 'CC3';
  DBMS_OUTPUT.PUT_LINE('Apres : CC4='||v_cc4||' CC3='||v_cc3||' (commission 100)');
  ROLLBACK;
END;
/

PROMPT *** Virement atomique refuse CC3 -> CC4 de 60 000 DA ***
DECLARE
  v_cc4_avant NUMBER;
  v_cc4_apres NUMBER;
BEGIN
  SELECT solde INTO v_cc4_avant FROM cpt_courant WHERE num_compte = 'CC4';
  DBMS_OUTPUT.PUT_LINE('CC4 avant = '||v_cc4_avant);

  virement('CC3', 'CC4', 60000, 3);

  SELECT solde INTO v_cc4_apres FROM cpt_courant WHERE num_compte = 'CC4';
  DBMS_OUTPUT.PUT_LINE('CC4 apres = '||v_cc4_apres||' (doit rester 325000)');
  ROLLBACK;
END;
/

PROMPT ############################################################
PROMPT 6. PARTIE E : VUE OBJET AGENCE_VOR
PROMPT ############################################################
SELECT code, nom, ville FROM Agence_VOR ORDER BY code;

PROMPT *** Conseillers par agence ***
SELECT v.code AS agence, k.num_conseiller, k.nom, k.prenom
  FROM Agence_VOR v, TABLE(v.conseillers) k
 ORDER BY v.code, k.num_conseiller;

PROMPT *** Comptes courants par agence ***
SELECT v.code AS agence, c.num_compte, c.solde, c.statut
  FROM Agence_VOR v, TABLE(v.comptes) c
 ORDER BY v.code, c.num_compte;

PROMPT *** Parrain et grand-parrain (type recursif) ***
SELECT c.num_client, c.nom,
       c.ref_parrain.nom AS parrain,
       c.ref_parrain.ref_parrain.nom AS grand_parrain
  FROM client c
 ORDER BY c.num_client;

PROMPT ############################################################
PROMPT 7. CONTROLE FINAL : ETAT INCHANGE
PROMPT ############################################################
SELECT COUNT(*) AS objets_invalides
  FROM user_objects
 WHERE status <> 'VALID';

SELECT 'CLIENTS' AS objet, COUNT(*) AS nb FROM client
UNION ALL SELECT 'CC', COUNT(*) FROM cpt_courant
UNION ALL SELECT 'CE', COUNT(*) FROM cpt_epargne
UNION ALL SELECT 'CT', COUNT(*) FROM cpt_terme
UNION ALL SELECT 'OPERATIONS', COUNT(*) FROM operation
UNION ALL SELECT 'SIGNATAIRES', COUNT(*)
           FROM cpt_courant cc, TABLE(cc.signataires) s
UNION ALL SELECT 'ALERTES', COUNT(*) FROM alerte
UNION ALL SELECT 'AFFECTATIONS', COUNT(*) FROM affectation
ORDER BY 1;

PROMPT ============================================================
PROMPT FIN DE LA DEMONSTRATION
PROMPT ============================================================
