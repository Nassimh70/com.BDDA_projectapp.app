SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 250
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF

PROMPT *** nettoyage ***
BEGIN EXECUTE IMMEDIATE 'DROP VIEW Agence_VOR'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE agence_vor_type FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

PROMPT *** creation type ***
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE agence_vor_type AS OBJECT (
      code            VARCHAR2(6),
      nom             VARCHAR2(40),
      ville           VARCHAR2(40),
      ref_responsable REF conseiller_type,
      conseillers     conseiller_nt_type,
      comptes         cptCourant_nt_type,
      MEMBER PROCEDURE mutation(nConseiller NUMBER, nAgenceCible VARCHAR2)
    )]';
END;
/
SHOW ERRORS TYPE agence_vor_type

CREATE OR REPLACE TYPE BODY agence_vor_type AS
  MEMBER PROCEDURE mutation(nConseiller NUMBER, nAgenceCible VARCHAR2) IS
  BEGIN
    NULL;
  END;
END;
/
SHOW ERRORS TYPE BODY agence_vor_type

PROMPT *** creation vue ***
CREATE OR REPLACE VIEW Agence_VOR OF agence_vor_type
WITH OBJECT IDENTIFIER (code) AS
SELECT a.code, a.nom, a.ville, a.ref_responsable,
       CAST(MULTISET(
         SELECT VALUE(c)
           FROM conseiller c, affectation af
          WHERE af.ref_conseiller = REF(c)
            AND af.ref_agence = MAKE_REF(agence, a.code)
            AND af.date_fin IS NULL
       ) AS conseiller_nt_type) AS conseillers,
       CAST(MULTISET(
         SELECT VALUE(cc)
           FROM cpt_courant cc
          WHERE cc.ref_agence = MAKE_REF(agence, a.code)
       ) AS cptCourant_nt_type) AS comptes
  FROM agence a;
SHOW ERRORS VIEW Agence_VOR

PROMPT *** test 1 cardinalites ***
SELECT code, nom, ville, CARDINALITY(conseillers) AS nb_conseillers,
       CARDINALITY(comptes) AS nb_comptes
  FROM Agence_VOR
 ORDER BY code;

PROMPT *** test 2 TABLE conseillers ***
SELECT a.code AS agence, c.num_conseiller, c.nom, c.prenom
  FROM Agence_VOR a, TABLE(a.conseillers) c
 ORDER BY a.code, c.num_conseiller;

PROMPT *** test 3 TABLE comptes ***
SELECT a.code AS agence, cc.num_compte, cc.solde, cc.statut
  FROM Agence_VOR a, TABLE(a.comptes) cc
 ORDER BY a.code, cc.num_compte;

PROMPT *** test 4 jointure relationnelle ***
SELECT a.code AS agence, c.nom AS conseiller, af.date_debut
  FROM Agence_VOR a, TABLE(a.conseillers) c, affectation af
 WHERE af.ref_conseiller.num_conseiller = c.num_conseiller
   AND af.ref_agence.code = a.code
   AND af.date_fin IS NULL
 ORDER BY a.code, c.nom;

PROMPT *** test 5 notation pointee double ***
SELECT c.num_client, c.nom,
       c.ref_parrain.nom AS nom_parrain,
       c.ref_parrain.ref_parrain.nom AS nom_grand_parrain
  FROM client c
 WHERE c.ref_parrain IS NOT NULL
 ORDER BY c.num_client;

PROMPT *** test 6 valeur objet ***
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A1';
  DBMS_OUTPUT.PUT_LINE('Agence '||v_ag.code||' - '||v_ag.nom
    ||' - conseillers='||v_ag.conseillers.COUNT
    ||' comptes='||v_ag.comptes.COUNT);
END;
/
