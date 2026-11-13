-- =====================================================================
-- partie_E_objet_avance.sql
-- Mini-projet BDDA - M1 ASR - 2026/2027
-- .
-- PARTIE E - Fonctionnalites objet avancees
--   E10 : type recursif (parrainage)
--   E11 : collection multi-niveaux (Releves)
--   E12 : vue objet Agence_VOR + methode mutation
-- .
-- Le script est rejouable : la vue et le type de E12 sont supprimes en
-- debut de partie, les donnees de E11 sont reinserees.
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 250
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF
WHENEVER SQLERROR CONTINUE

PROMPT ============================================================
PROMPT E10. TYPE RECURSIF : PARRAINAGE
PROMPT ============================================================
-- L'attribut ref_parrain REF client_type a ete ajoute en partie A par
-- ALTER TYPE client_type ADD ATTRIBUTE ref_parrain REF client_type CASCADE.
-- La partie A a deja parraine les clients 2 et 3 par le client 1.
-- On ajoute trois liens supplementaires pour obtenir une chaine sur deux
-- niveaux : 5 -> 2 -> 1 et 6 -> 3 -> 1, plus 4 -> 1.

UPDATE client SET ref_parrain = (SELECT REF(p) FROM client p WHERE p.num_client = 1)
 WHERE num_client = 4;
UPDATE client SET ref_parrain = (SELECT REF(p) FROM client p WHERE p.num_client = 2)
 WHERE num_client = 5;
UPDATE client SET ref_parrain = (SELECT REF(p) FROM client p WHERE p.num_client = 3)
 WHERE num_client = 6;
COMMIT;

-- Requete demandee : double notation pointee.
-- c.ref_parrain.nom             -> nom du parrain direct
-- c.ref_parrain.ref_parrain.nom -> nom du parrain du parrain
COLUMN nom FORMAT A15
COLUMN nom_parrain FORMAT A15
COLUMN nom_grand_parrain FORMAT A20
SELECT c.num_client, c.nom,
       c.ref_parrain.nom AS nom_parrain,
       c.ref_parrain.ref_parrain.nom AS nom_grand_parrain
  FROM client c
 WHERE c.ref_parrain IS NOT NULL
 ORDER BY c.num_client;

-- Lecture attendue :
--   2 BENALI   AMRANI  (pas de grand parrain)
--   3 CHERIF   AMRANI  (pas de grand parrain)
--   4 DJEBBAR  AMRANI  (pas de grand parrain)
--   5 HADDAD   BENALI  AMRANI
--   6 ZERROUKI CHERIF  AMRANI

PROMPT ============================================================
PROMPT E11. COLLECTION MULTI-NIVEAUX : RELEVES MENSUELS
PROMPT ============================================================
-- Structure creee en partie A :
--   releves(annee, mois_vry)
--   mois_vry_type         = VARRAY(12) OF mois_elt_vry_type
--   mois_elt_vry_type     = (mois, nb_operations, types)
--   type_stat_nt_type     = TABLE OF type_stat_elt_nt_type
--   type_stat_elt_nt_type = (type_op, nb, montant_total)
-- On insere 4 mois, puis le bloc ajoute le 5e mois.

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

-- Controle du nombre de mois : TABLE() est necessaire car CARDINALITY()
-- ne s'applique pas a un VARRAY dans cette version d'Oracle (ORA-00932).
SELECT r.annee, COUNT(*) AS nb_mois
  FROM releves r, TABLE(r.mois_vry) m
 GROUP BY r.annee;

-- Ajout du mois 5 : extension du VARRAY puis de la nested table.
DECLARE
  v_mois  mois_vry_type;
  v_types type_stat_nt_type;
  v_av    NUMBER;
  v_ap    NUMBER;
BEGIN
  SELECT mois_vry INTO v_mois FROM releves WHERE annee = 2026 FOR UPDATE;

  v_av := v_mois.COUNT;          -- 4 au depart
  v_mois.EXTEND(1);              -- extension du VARRAY
  v_types := type_stat_nt_type(  -- nouvelle nested table
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

-- Requete demandee : total par type d'operation sur l'annee, tri decroissant.
-- Double TABLE() : VARRAY de mois, puis nested table de types.
COLUMN type_op FORMAT A10
SELECT t.type_op,
       SUM(t.nb) AS nb_total,
       SUM(t.montant_total) AS montant_total
  FROM releves r, TABLE(r.mois_vry) m, TABLE(m.types) t
 WHERE r.annee = 2026
 GROUP BY t.type_op
 ORDER BY montant_total DESC;

PROMPT ============================================================
PROMPT E12. VUE OBJET AGENCE_VOR ET METHODE MUTATION
PROMPT ============================================================
-- Nettoyage pour rejeu : la vue depend du type, on la supprime d'abord.
BEGIN EXECUTE IMMEDIATE 'DROP VIEW Agence_VOR'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TYPE agence_vor_type FORCE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- 1) Type objet de la vue.
--    - attributs simples de l'agence
--    - conseillers : nested table des conseillers en poste
--    - comptes     : nested table des comptes courants de l'agence
--    - mutation    : methode demandee
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

-- 2) Corps du type : methode mutation.
--    SELF.code est l'agence courante de l'objet.
--    La methode :
--      - verifie que le conseiller est bien en poste dans SELF.code ;
--      - signale s'il est responsable de cette agence ;
--      - cloture l'affectation courante ;
--      - cree la nouvelle affectation vers nAgenceCible.
--    La date de fin est forcee a etre strictement superieure a la date de
--    debut (contrainte ck_aff_dates), meme pour une mutation le meme jour.
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

-- 3) Vue objet.
--    MAKE_REF(agence, a.code) est possible car la table agence a un OID
--    primaire (OBJECT IDENTIFIER IS PRIMARY KEY).
--    CAST(MULTISET(...)) construit les deux collections.
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

-- 4) Trois requetes d'interrogation avec TABLE.
-- 4.1 Conseillers en poste par agence.
COLUMN agence FORMAT A6
COLUMN conseiller FORMAT A20
SELECT a.code AS agence, c.num_conseiller, c.nom AS conseiller, c.prenom
  FROM Agence_VOR a, TABLE(a.conseillers) c
 ORDER BY a.code, c.num_conseiller;

-- 4.2 Comptes courants par agence.
SELECT a.code AS agence, cc.num_compte, cc.solde, cc.statut
  FROM Agence_VOR a, TABLE(a.comptes) cc
 ORDER BY a.code, cc.num_compte;

-- 4.3 Jointure traditionnelle avec la table relationnelle affectation.
SELECT a.code AS agence, c.nom AS conseiller, af.date_debut
  FROM Agence_VOR a, TABLE(a.conseillers) c, affectation af
 WHERE af.ref_conseiller.num_conseiller = c.num_conseiller
   AND af.ref_agence.code = a.code
   AND af.date_fin IS NULL
 ORDER BY a.code, c.nom;

-- 4.4 Bonus : cardinalites des collections.
SELECT a.code, a.nom,
       CARDINALITY(a.conseillers) AS nb_conseillers,
       CARDINALITY(a.comptes) AS nb_comptes
  FROM Agence_VOR a
 ORDER BY a.code;

-- 5) Tests de la methode mutation.
-- 5.1 Etat initial.
SELECT a.code, CARDINALITY(a.conseillers) AS nb_conseillers
  FROM Agence_VOR a ORDER BY a.code;

-- 5.2 Mutation d'un conseiller NON responsable : KACI (4), A2 -> A3.
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A2';
  v_ag.mutation(4, 'A3');
  COMMIT;
END;
/
SELECT a.code, CARDINALITY(a.conseillers) AS nb_conseillers
  FROM Agence_VOR a ORDER BY a.code;

-- 5.3 Mutation d'un conseiller RESPONSABLE : BENALI (1), A1 -> A2.
--     La methode signale qu'il quitte l'agence dont il est responsable.
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A1';
  v_ag.mutation(1, 'A2');
  COMMIT;
END;
/
SELECT a.code, CARDINALITY(a.conseillers) AS nb_conseillers
  FROM Agence_VOR a ORDER BY a.code;

-- 5.4 Restauration : 1 revient en A1, 4 revient en A2.
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A2';
  v_ag.mutation(1, 'A1');
  COMMIT;
END;
/
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A3';
  v_ag.mutation(4, 'A2');
  COMMIT;
END;
/
SELECT a.code, CARDINALITY(a.conseillers) AS nb_conseillers
  FROM Agence_VOR a ORDER BY a.code;

-- 5.5 Erreur attendue : conseiller 1 absent de l'agence A3.
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A3';
  v_ag.mutation(1, 'A2');
END;
/

-- 5.6 Erreur attendue : conseiller inexistant.
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A1';
  v_ag.mutation(99, 'A2');
END;
/

-- 5.7 Erreur attendue : agence cible inexistante.
DECLARE
  v_ag agence_vor_type;
BEGIN
  SELECT VALUE(a) INTO v_ag FROM Agence_VOR a WHERE a.code = 'A1';
  v_ag.mutation(1, 'A9');
END;
/
