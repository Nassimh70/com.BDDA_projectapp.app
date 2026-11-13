-- =====================================================================
-- projet_bdda_banque.sql
-- Mini-projet BDDA - M1 ASR - 2026/2027
-- Banque de gestion des comptes et des clients
-- .
-- SCRIPT UNIQUE ET REJOUABLE : parties A a E
--   Partie A : schema objet-relationnel + donnees de test
--   Partie B : manipulations de donnees (B5a-B5f)
--   Partie C : requetes SQL (6.1-6.25)
--   Partie D : programmation PL/SQL (7, 8, 9)
--   Partie E : fonctionnalites objet avancees (10, 11, 12)
-- .
-- Connexion :
--   sqlplus MASTER1/system@localhost:1521/XEPDB1
--   SQL> @projet_bdda_banque.sql
-- .
-- Le script supprime d'abord les objets existants (section 0 de la
-- partie A), puis les recree dans l'ordre. Il peut donc etre rejoue.
-- Les erreurs attendues des tests d'exception sont signalees par un
-- commentaire "Erreur attendue" et n'arretent pas le script.
-- =====================================================================

PROMPT ############################################################
PROMPT # PARTIE_A_SCHEMA.SQL
PROMPT ############################################################
-- =====================================================================
-- partie_A_schema.sql
-- Mini-projet BDDA - M1 ASR - 2026/2027
-- .
-- PARTIE A
--   A1 : diagramme de classes -> dossier uml/
--   A2 : creation de l'utilisateur -> 00_creation_utilisateur.sql
--   A3 : types objet, VARRAY, nested tables, tables objet, contraintes,
--        script de regeneration (DROP) et purge des donnees (DELETE)
--   A4 : jeu de donnees de test
-- .
-- Le script est rejouable : il supprime d'abord les objets existants.
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF

PROMPT ============================================================
PROMPT 0. REGENERATION - SUPPRESSION DES OBJETS EXISTANTS
PROMPT ============================================================
-- ORDRE DE REGENERATION (equivalent explicite, pour le rapport) :
--   DROP VIEW Agence_VOR;                 -- vue objet de E12
--   DROP TABLE releves, "AUDIT", alerte, operation, cpt_terme, cpt_epargne,
--              cpt_courant, client, affectation, agence, conseiller;
--   DROP SEQUENCE seq_operation, seq_alerte, seq_audit, seq_affectation;
--   DROP TYPE agence_vor_type, mois_vry_type, mois_elt_vry_type,
--             type_stat_nt_type, type_stat_elt_nt_type, cptCourant_nt_type,
--             conseiller_nt_type, operation_type, cptTerme_type,
--             cptEpargne_type, cptCourant_type, compte_type,
--             signataire_nt_type, signataire_elt_nt_type, client_type,
--             agence_type, conseiller_type, tel_vry_type, adresse_type;
--
-- Bloc idempotent : au premier passage les objets n'existent pas, on
-- ignore donc les erreurs de suppression (aucune sortie parasite).

-- La vue objet de E12 depend de la table agence et du type agence_vor_type :
-- on la supprime en premier pour rendre le script complet rejouable.
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW Agence_VOR';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

DECLARE
  TYPE t_liste IS TABLE OF VARCHAR2(30);
  v_tables t_liste := t_liste(
    'RELEVES','AUDIT','ALERTE','OPERATION','CPT_TERME','CPT_EPARGNE',
    'CPT_COURANT','CLIENT','AFFECTATION','AGENCE','CONSEILLER');
  v_sequences t_liste := t_liste(
    'SEQ_OPERATION','SEQ_ALERTE','SEQ_AUDIT','SEQ_AFFECTATION');
  v_types t_liste := t_liste(
    'AGENCE_VOR_TYPE','MOIS_VRY_TYPE','MOIS_ELT_VRY_TYPE',
    'TYPE_STAT_NT_TYPE','TYPE_STAT_ELT_NT_TYPE','CPTCOURANT_NT_TYPE',
    'CONSEILLER_NT_TYPE','OPERATION_TYPE','CPTTERME_TYPE','CPTEPARGNE_TYPE',
    'CPTCOURANT_TYPE','COMPTE_TYPE','SIGNATAIRE_NT_TYPE',
    'SIGNATAIRE_ELT_NT_TYPE','CLIENT_TYPE','AGENCE_TYPE','CONSEILLER_TYPE',
    'TEL_VRY_TYPE','ADRESSE_TYPE');
BEGIN
  FOR i IN 1..v_tables.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE "'||v_tables(i)||'" CASCADE CONSTRAINTS PURGE';
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
  FOR i IN 1..v_sequences.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP SEQUENCE "'||v_sequences(i)||'"';
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
  FOR i IN 1..v_types.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TYPE "'||v_types(i)||'" FORCE';
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Regeneration : objets existants supprimes.');
END;
/
WHENEVER SQLERROR CONTINUE

PROMPT ============================================================
PROMPT 1. CREATION DES TYPES OBJET
PROMPT ============================================================
-- CREATE TYPE direct ferme silencieusement la session SQL*Plus sur cette
-- installation : on passe par EXECUTE IMMEDIATE (comportement verifie).

-- 1.1 Adresse (type objet dedie)
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE adresse_type AS OBJECT (
      num_rue NUMBER,
      rue     VARCHAR2(80),
      ville   VARCHAR2(40),
      cp      VARCHAR2(10)
    )]';
END;
/
SHOW ERRORS TYPE adresse_type

-- 1.2 Telephones : VARRAY de 3 elements scalaires (domicile, portable 1, portable 2)
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE tel_vry_type AS VARRAY(3) OF VARCHAR2(20)]';
END;
/
SHOW ERRORS TYPE tel_vry_type

-- 1.3 Conseiller
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE conseiller_type AS OBJECT (
      num_conseiller NUMBER,
      nom            VARCHAR2(30),
      prenom         VARCHAR2(30),
      specialite     VARCHAR2(40),
      date_embauche  DATE,
      salaire        NUMBER(10,2)
    )]';
END;
/
SHOW ERRORS TYPE conseiller_type

-- 1.4 Agence : le responsable est un REF vers un conseiller
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE agence_type AS OBJECT (
      code            VARCHAR2(6),
      nom             VARCHAR2(40),
      ville           VARCHAR2(40),
      ref_responsable REF conseiller_type
    )]';
END;
/
SHOW ERRORS TYPE agence_type

-- 1.5 Client (sans le parrain : il sera ajoute par ALTER TYPE, cf. E10)
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE client_type AS OBJECT (
      num_client     NUMBER,
      nom            VARCHAR2(30),
      prenom         VARCHAR2(30),
      date_naissance DATE,
      num_secu       VARCHAR2(20),
      adresse        adresse_type,
      telephones     tel_vry_type,
      email          VARCHAR2(60),
      date_entree    DATE,
      ref_conseiller REF conseiller_type
    )]';
END;
/
SHOW ERRORS TYPE client_type

-- 1.6 Association recursive de parrainage (question E10, rendue possible
--     des la partie A pour pouvoir inserer les 2 clients parraines de A4)
ALTER TYPE client_type ADD ATTRIBUTE ref_parrain REF client_type CASCADE;
SHOW ERRORS TYPE client_type

-- 1.7 Signataires : nested table d'objets (client + droit)
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE signataire_elt_nt_type AS OBJECT (
      ref_client REF client_type,
      droit      CHAR(1)
    )]';
END;
/
SHOW ERRORS TYPE signataire_elt_nt_type

BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE signataire_nt_type AS TABLE OF signataire_elt_nt_type]';
END;
/
SHOW ERRORS TYPE signataire_nt_type

-- 1.8 Compte : racine NOT FINAL NOT INSTANTIABLE
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE compte_type AS OBJECT (
      num_compte     VARCHAR2(10),
      solde          NUMBER(12,2),
      date_ouverture DATE,
      statut         VARCHAR2(10),
      ref_client     REF client_type,
      ref_agence     REF agence_type,
      MEMBER FUNCTION fraisTenue RETURN NUMBER
    ) NOT FINAL NOT INSTANTIABLE]';
END;
/
SHOW ERRORS TYPE compte_type

-- 1.9 Compte courant
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE cptCourant_type UNDER compte_type (
      decouvert   NUMBER(12,2),
      nb_op_cb    NUMBER,
      signataires signataire_nt_type,
      OVERRIDING MEMBER FUNCTION fraisTenue RETURN NUMBER
    )]';
END;
/
SHOW ERRORS TYPE cptCourant_type

-- 1.10 Compte d'epargne
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE cptEpargne_type UNDER compte_type (
      taux_interet  NUMBER(5,2),
      plafond_depot NUMBER(12,2),
      OVERRIDING MEMBER FUNCTION fraisTenue RETURN NUMBER
    )]';
END;
/
SHOW ERRORS TYPE cptEpargne_type

-- 1.11 Compte a terme
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE cptTerme_type UNDER compte_type (
      montant_bloque NUMBER(12,2),
      duree_mois     NUMBER,
      date_echeance  DATE,
      taux_garanti   NUMBER(5,2),
      OVERRIDING MEMBER FUNCTION fraisTenue RETURN NUMBER
    )]';
END;
/
SHOW ERRORS TYPE cptTerme_type

-- 1.12 Operation (uniquement sur compte courant : typage structurel)
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE operation_type AS OBJECT (
      id_op      NUMBER,
      ref_client REF client_type,
      ref_compte REF cptCourant_type,
      date_op    DATE,
      montant    NUMBER(12,2),
      type_op    VARCHAR2(10),
      commission NUMBER(12,2)
    )]';
END;
/
SHOW ERRORS TYPE operation_type

-- 1.13 Collections pour la vue objet de E12
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE conseiller_nt_type AS TABLE OF conseiller_type]';
END;
/
SHOW ERRORS TYPE conseiller_nt_type

BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE cptCourant_nt_type AS TABLE OF cptCourant_type]';
END;
/
SHOW ERRORS TYPE cptCourant_nt_type

-- 1.14 Collections multi-niveaux de E11
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE type_stat_elt_nt_type AS OBJECT (
      type_op       VARCHAR2(10),
      nb            NUMBER,
      montant_total NUMBER(14,2)
    )]';
END;
/
SHOW ERRORS TYPE type_stat_elt_nt_type

BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE type_stat_nt_type AS TABLE OF type_stat_elt_nt_type]';
END;
/
SHOW ERRORS TYPE type_stat_nt_type

BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE mois_elt_vry_type AS OBJECT (
      mois          NUMBER,
      nb_operations NUMBER,
      types         type_stat_nt_type
    )]';
END;
/
SHOW ERRORS TYPE mois_elt_vry_type

BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE mois_vry_type AS VARRAY(12) OF mois_elt_vry_type]';
END;
/
SHOW ERRORS TYPE mois_vry_type

PROMPT ============================================================
PROMPT 2. CORPS DES TYPES (POLYMORPHISME DE fraisTenue)
PROMPT ============================================================
-- fraisTenue est declaree des la creation : Oracle interdit d'ajouter
-- ensuite une methode qui REDEFINIT une methode existante (ORA-22324).

CREATE OR REPLACE TYPE BODY compte_type AS
  MEMBER FUNCTION fraisTenue RETURN NUMBER IS
  BEGIN
    RETURN 500;   -- valeur de la racine (jamais instanciee)
  END;
END;
/
SHOW ERRORS TYPE BODY compte_type

CREATE OR REPLACE TYPE BODY cptCourant_type AS
  OVERRIDING MEMBER FUNCTION fraisTenue RETURN NUMBER IS
  BEGIN
    RETURN 1200;
  END;
END;
/
SHOW ERRORS TYPE BODY cptCourant_type

CREATE OR REPLACE TYPE BODY cptEpargne_type AS
  OVERRIDING MEMBER FUNCTION fraisTenue RETURN NUMBER IS
  BEGIN
    RETURN 0;
  END;
END;
/
SHOW ERRORS TYPE BODY cptEpargne_type

CREATE OR REPLACE TYPE BODY cptTerme_type AS
  OVERRIDING MEMBER FUNCTION fraisTenue RETURN NUMBER IS
  BEGIN
    RETURN 0;
  END;
END;
/
SHOW ERRORS TYPE BODY cptTerme_type

PROMPT ============================================================
PROMPT 3. CREATION DES TABLES ET DES CONTRAINTES
PROMPT ============================================================

-- 3.1 Conseiller
CREATE TABLE conseiller OF conseiller_type (
  num_conseiller PRIMARY KEY,
  CONSTRAINT ck_cons_salaire CHECK (salaire >= 0)
);

-- 3.2 Agence : OID primaire, indispensable a MAKE_REF dans la vue objet
CREATE TABLE agence OF agence_type (
  code PRIMARY KEY,
  CONSTRAINT ck_ag_responsable CHECK (ref_responsable IS NOT NULL)
) OBJECT IDENTIFIER IS PRIMARY KEY;

-- 3.3 Historique des affectations conseiller <-> agence
CREATE TABLE affectation (
  id_affectation NUMBER PRIMARY KEY,
  ref_conseiller REF conseiller_type,
  ref_agence     REF agence_type,
  date_debut     DATE DEFAULT SYSDATE,
  date_fin       DATE,
  CONSTRAINT ck_aff_conseiller CHECK (ref_conseiller IS NOT NULL),
  CONSTRAINT ck_aff_agence     CHECK (ref_agence IS NOT NULL),
  CONSTRAINT ck_aff_dates      CHECK (date_fin IS NULL OR date_fin > date_debut)
);

-- 3.4 Client : OID systeme (un REF d'OID primaire ne peut pas entrer
--     dans la nested table des signataires : ORA-22979)
CREATE TABLE client OF client_type (
  num_client PRIMARY KEY,
  num_secu   UNIQUE,
  CONSTRAINT ck_cli_conseiller CHECK (ref_conseiller IS NOT NULL)
);

-- 3.5 Comptes courants + nested table des signataires
CREATE TABLE cpt_courant OF cptCourant_type (
  num_compte PRIMARY KEY,
  -- B5b impose d'inserer CC99 sans titulaire puis de l'associer :
  -- la contrainte est donc differee au COMMIT.
  CONSTRAINT ck_cc_client    CHECK (ref_client IS NOT NULL)
                             DEFERRABLE INITIALLY DEFERRED,
  CONSTRAINT ck_cc_agence    CHECK (ref_agence IS NOT NULL),
  CONSTRAINT ck_cc_statut    CHECK (statut IN ('ACTIF','BLOQUE','DORMANT')),
  CONSTRAINT ck_cc_decouvert CHECK (decouvert >= 0),
  CONSTRAINT ck_cc_nbcb      CHECK (nb_op_cb >= 0)
)
NESTED TABLE signataires STORE AS signataire_nt_st;

-- Contraintes de domaine ajoutees sur la nested table par ALTER TABLE
ALTER TABLE signataire_nt_st
  ADD CONSTRAINT ck_sig_droit CHECK (droit IN ('X','R','D'));
ALTER TABLE signataire_nt_st
  ADD CONSTRAINT ck_sig_droit_nn CHECK (droit IS NOT NULL);

-- 3.6 Comptes d'epargne
CREATE TABLE cpt_epargne OF cptEpargne_type (
  num_compte PRIMARY KEY,
  CONSTRAINT ck_ce_client  CHECK (ref_client IS NOT NULL),
  CONSTRAINT ck_ce_agence  CHECK (ref_agence IS NOT NULL),
  CONSTRAINT ck_ce_statut  CHECK (statut IN ('ACTIF','BLOQUE','DORMANT')),
  CONSTRAINT ck_ce_taux    CHECK (taux_interet >= 0 AND taux_interet < 3.5),
  CONSTRAINT ck_ce_plafond CHECK (plafond_depot >= 0)
);

-- 3.7 Comptes a terme
CREATE TABLE cpt_terme OF cptTerme_type (
  num_compte PRIMARY KEY,
  CONSTRAINT ck_ct_client  CHECK (ref_client IS NOT NULL),
  CONSTRAINT ck_ct_agence  CHECK (ref_agence IS NOT NULL),
  CONSTRAINT ck_ct_statut  CHECK (statut IN ('ACTIF','BLOQUE','DORMANT')),
  CONSTRAINT ck_ct_duree   CHECK (duree_mois IN (6,12,24,36)),
  CONSTRAINT ck_ct_montant CHECK (montant_bloque >= 0),
  CONSTRAINT ck_ct_taux    CHECK (taux_garanti >= 0)
);

-- 3.8 Operations
CREATE TABLE operation OF operation_type (
  id_op PRIMARY KEY,
  CONSTRAINT ck_op_client     CHECK (ref_client IS NOT NULL),
  CONSTRAINT ck_op_compte     CHECK (ref_compte IS NOT NULL),
  CONSTRAINT ck_op_type       CHECK (type_op IN ('DEPOT','RETRAIT','VIREMENT','CB')),
  CONSTRAINT ck_op_commission CHECK (commission >= 0),
  CONSTRAINT ck_op_montant    CHECK (montant <> 0)
);

-- 3.9 Alertes
CREATE TABLE alerte (
  id_alerte   NUMBER PRIMARY KEY,
  type_alerte VARCHAR2(30) NOT NULL,
  num_compte  VARCHAR2(10),
  message     VARCHAR2(200),
  date_alerte DATE DEFAULT SYSDATE,
  traitee     CHAR(1) DEFAULT 'N',
  CONSTRAINT ck_al_type    CHECK (type_alerte IN
    ('ECHEANCE_PROCHE','ECHEANCE_DEPASSEE','SOLDE_NEGATIF','OPERATION_SUSPECTE')),
  CONSTRAINT ck_al_traitee CHECK (traitee IN ('O','N'))
);

-- 3.10 Audit
CREATE TABLE "AUDIT" (
  id_audit        NUMBER PRIMARY KEY,
  nom_table       VARCHAR2(30),
  nom_colonne     VARCHAR2(30),
  num_compte      VARCHAR2(10),
  ancienne_valeur NUMBER,
  nouvelle_valeur NUMBER,
  date_modif      DATE DEFAULT SYSDATE,
  utilisateur     VARCHAR2(30) DEFAULT USER
);

-- 3.11 Releves mensuels multi-niveaux (E11)
CREATE TABLE releves (
  annee    NUMBER PRIMARY KEY,
  mois_vry mois_vry_type
);

PROMPT *** Valeurs par defaut exigees par le sujet ***
ALTER TABLE cpt_courant MODIFY (statut  DEFAULT 'ACTIF');
ALTER TABLE cpt_courant MODIFY (nb_op_cb DEFAULT 0);
ALTER TABLE cpt_epargne MODIFY (statut  DEFAULT 'ACTIF');
ALTER TABLE cpt_terme   MODIFY (statut  DEFAULT 'ACTIF');
ALTER TABLE operation   MODIFY (date_op    DEFAULT SYSDATE);
ALTER TABLE operation   MODIFY (commission DEFAULT 0);

PROMPT *** Integrite referentielle sur les REF ***
ALTER TABLE agence      ADD CONSTRAINT fk_ag_responsable
  FOREIGN KEY (ref_responsable) REFERENCES conseiller;
ALTER TABLE affectation ADD CONSTRAINT fk_aff_conseiller
  FOREIGN KEY (ref_conseiller) REFERENCES conseiller;
ALTER TABLE affectation ADD CONSTRAINT fk_aff_agence
  FOREIGN KEY (ref_agence) REFERENCES agence;
ALTER TABLE client      ADD CONSTRAINT fk_cli_conseiller
  FOREIGN KEY (ref_conseiller) REFERENCES conseiller;
ALTER TABLE client      ADD CONSTRAINT fk_cli_parrain
  FOREIGN KEY (ref_parrain) REFERENCES client;
ALTER TABLE cpt_courant ADD CONSTRAINT fk_cc_client
  FOREIGN KEY (ref_client) REFERENCES client;
ALTER TABLE cpt_courant ADD CONSTRAINT fk_cc_agence
  FOREIGN KEY (ref_agence) REFERENCES agence;
ALTER TABLE cpt_epargne ADD CONSTRAINT fk_ce_client
  FOREIGN KEY (ref_client) REFERENCES client;
ALTER TABLE cpt_epargne ADD CONSTRAINT fk_ce_agence
  FOREIGN KEY (ref_agence) REFERENCES agence;
ALTER TABLE cpt_terme   ADD CONSTRAINT fk_ct_client
  FOREIGN KEY (ref_client) REFERENCES client;
ALTER TABLE cpt_terme   ADD CONSTRAINT fk_ct_agence
  FOREIGN KEY (ref_agence) REFERENCES agence;
ALTER TABLE operation   ADD CONSTRAINT fk_op_client
  FOREIGN KEY (ref_client) REFERENCES client;
ALTER TABLE operation   ADD CONSTRAINT fk_op_compte
  FOREIGN KEY (ref_compte) REFERENCES cpt_courant;

PROMPT ============================================================
PROMPT 4. SEQUENCES
PROMPT ============================================================
CREATE SEQUENCE seq_operation   START WITH 100;
CREATE SEQUENCE seq_alerte      START WITH 1;
CREATE SEQUENCE seq_audit       START WITH 1;
CREATE SEQUENCE seq_affectation START WITH 100;

PROMPT ============================================================
PROMPT 5. DONNEES DE TEST (A4)
PROMPT ============================================================

-- 5.1 Conseillers (4)
INSERT INTO conseiller VALUES (conseiller_type(1,'BENALI','Karim','Particuliers',
                                               DATE '2015-03-01', 85000));
INSERT INTO conseiller VALUES (conseiller_type(2,'HAMDI','Sara','Entreprises',
                                               DATE '2018-09-15', 92000));
INSERT INTO conseiller VALUES (conseiller_type(3,'TOUATI','Yacine','Particuliers',
                                               DATE '2020-01-10', 78000));
INSERT INTO conseiller VALUES (conseiller_type(4,'KACI','Nadia','Epargne',
                                               DATE '2021-06-01', 81000));

-- 5.2 Agences (3), un responsable par agence
INSERT INTO agence (code, nom, ville, ref_responsable)
VALUES ('A1','Agence Bejaia Centre','Bejaia',
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 1));
INSERT INTO agence (code, nom, ville, ref_responsable)
VALUES ('A2','Agence Alger Grande Poste','Alger',
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 2));
INSERT INTO agence (code, nom, ville, ref_responsable)
VALUES ('A3','Agence Oran Front de Mer','Oran',
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 3));

-- 5.3 Historique des affectations (mutation du conseiller 4)
INSERT INTO affectation (id_affectation, ref_conseiller, ref_agence, date_debut, date_fin)
VALUES (1,(SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 1),
          (SELECT REF(a) FROM agence a WHERE a.code = 'A1'),
          DATE '2015-03-01', NULL);
INSERT INTO affectation (id_affectation, ref_conseiller, ref_agence, date_debut, date_fin)
VALUES (2,(SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 2),
          (SELECT REF(a) FROM agence a WHERE a.code = 'A2'),
          DATE '2018-09-15', NULL);
INSERT INTO affectation (id_affectation, ref_conseiller, ref_agence, date_debut, date_fin)
VALUES (3,(SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 3),
          (SELECT REF(a) FROM agence a WHERE a.code = 'A3'),
          DATE '2020-01-10', NULL);
INSERT INTO affectation (id_affectation, ref_conseiller, ref_agence, date_debut, date_fin)
VALUES (4,(SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 4),
          (SELECT REF(a) FROM agence a WHERE a.code = 'A1'),
          DATE '2021-06-01', DATE '2023-12-31');
INSERT INTO affectation (id_affectation, ref_conseiller, ref_agence, date_debut, date_fin)
VALUES (5,(SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 4),
          (SELECT REF(a) FROM agence a WHERE a.code = 'A2'),
          DATE '2024-01-01', NULL);

-- 5.4 Clients (6) - VARRAY varies : NULL, partiel, complet
INSERT INTO client (num_client, nom, prenom, date_naissance, num_secu, adresse,
                    telephones, email, date_entree, ref_conseiller, ref_parrain)
VALUES (1,'AMRANI','Ali',DATE '1980-05-12','800512001',
        adresse_type(12,'Rue des Oliviers','Bejaia','06000'),
        tel_vry_type('034-12-34-56','0661-11-22-33',NULL),
        'ali.amrani@mail.dz', DATE '2015-04-01',
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 1), NULL);

INSERT INTO client (num_client, nom, prenom, date_naissance, num_secu, adresse,
                    telephones, email, date_entree, ref_conseiller, ref_parrain)
VALUES (2,'BENALI','Samia',DATE '1990-02-20','900220002',
        adresse_type(5,'Rue Didouche Mourad','Alger','16000'),
        tel_vry_type('021-45-67-89',NULL,'0770-44-55-66'),
        'samia.benali@mail.dz', DATE '2016-06-15',
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 2), NULL);

INSERT INTO client (num_client, nom, prenom, date_naissance, num_secu, adresse,
                    telephones, email, date_entree, ref_conseiller, ref_parrain)
VALUES (3,'CHERIF','Mohamed',DATE '1975-11-03','751103003',
        adresse_type(8,'Boulevard de l ALN','Oran','31000'),
        tel_vry_type(NULL,'0555-77-88-99',NULL),
        'mohamed.cherif@mail.dz', DATE '2017-01-20',
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 3), NULL);

INSERT INTO client (num_client, nom, prenom, date_naissance, num_secu, adresse,
                    telephones, email, date_entree, ref_conseiller, ref_parrain)
VALUES (4,'DJEBBAR','Lina',DATE '1995-07-08','950708004',
        adresse_type(3,'Rue des Freres Amirouche','Bejaia','06000'),
        tel_vry_type('034-98-76-54','0662-33-44-55','0771-22-33-44'),
        'lina.djebbar@mail.dz', DATE '2019-03-10',
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 1), NULL);

INSERT INTO client (num_client, nom, prenom, date_naissance, num_secu, adresse,
                    telephones, email, date_entree, ref_conseiller, ref_parrain)
VALUES (5,'HADDAD','Omar',DATE '1988-09-30','880930005',
        adresse_type(22,'Rue de la Gare','Alger','16000'),
        tel_vry_type('021-11-22-33',NULL,NULL),
        'omar.haddad@mail.dz', DATE '2020-11-05',
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 2), NULL);

INSERT INTO client (num_client, nom, prenom, date_naissance, num_secu, adresse,
                    telephones, email, date_entree, ref_conseiller, ref_parrain)
VALUES (6,'ZERROUKI','Nour',DATE '2000-01-25','000125006',
        adresse_type(7,'Cite 200 logements','Oran','31000'),
        tel_vry_type(NULL,'0663-55-66-77',NULL),
        'nour.zerrouki@mail.dz', DATE '2022-02-14',
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 3), NULL);

-- Association recursive : clients 2 et 3 parraines par le client 1
UPDATE client
   SET ref_parrain = (SELECT REF(p) FROM client p WHERE p.num_client = 1)
 WHERE num_client IN (2,3);

-- 5.5 Comptes courants (7) : nested table vide a la creation
INSERT INTO cpt_courant (num_compte, solde, date_ouverture, ref_client, ref_agence,
                         decouvert, signataires)
VALUES ('CC1',0,DATE '2015-04-10',
        (SELECT REF(c) FROM client c WHERE c.num_client = 1),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A1'),
        50000, signataire_nt_type());
INSERT INTO cpt_courant (num_compte, solde, date_ouverture, ref_client, ref_agence,
                         decouvert, signataires)
VALUES ('CC2',0,DATE '2016-07-01',
        (SELECT REF(c) FROM client c WHERE c.num_client = 2),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A2'),
        50000, signataire_nt_type());
INSERT INTO cpt_courant (num_compte, solde, date_ouverture, ref_client, ref_agence,
                         decouvert, signataires)
VALUES ('CC3',0,DATE '2017-02-01',
        (SELECT REF(c) FROM client c WHERE c.num_client = 3),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A3'),
        20000, signataire_nt_type());
INSERT INTO cpt_courant (num_compte, solde, date_ouverture, ref_client, ref_agence,
                         decouvert, signataires)
VALUES ('CC4',0,DATE '2019-04-01',
        (SELECT REF(c) FROM client c WHERE c.num_client = 4),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A1'),
        100000, signataire_nt_type());
INSERT INTO cpt_courant (num_compte, solde, date_ouverture, ref_client, ref_agence,
                         decouvert, signataires, statut)
VALUES ('CC5',0,DATE '2020-12-01',
        (SELECT REF(c) FROM client c WHERE c.num_client = 5),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A2'),
        0, signataire_nt_type(), 'BLOQUE');
INSERT INTO cpt_courant (num_compte, solde, date_ouverture, ref_client, ref_agence,
                         decouvert, signataires)
VALUES ('CC6',0,DATE '2022-03-01',
        (SELECT REF(c) FROM client c WHERE c.num_client = 6),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A3'),
        30000, signataire_nt_type());
INSERT INTO cpt_courant (num_compte, solde, date_ouverture, ref_client, ref_agence,
                         decouvert, signataires)
VALUES ('CC7',0,DATE '2023-05-01',
        (SELECT REF(c) FROM client c WHERE c.num_client = 4),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A1'),
        75000, signataire_nt_type());

-- 5.6 Remplissage des signataires (5 comptes, les trois droits X, R et D)
INSERT INTO TABLE (SELECT signataires FROM cpt_courant WHERE num_compte = 'CC1')
SELECT signataire_elt_nt_type(REF(c),'X') FROM client c WHERE c.num_client = 4;

INSERT INTO TABLE (SELECT signataires FROM cpt_courant WHERE num_compte = 'CC2')
SELECT signataire_elt_nt_type(REF(c),'R') FROM client c WHERE c.num_client = 5;

INSERT INTO TABLE (SELECT signataires FROM cpt_courant WHERE num_compte = 'CC3')
SELECT signataire_elt_nt_type(REF(c),'D') FROM client c WHERE c.num_client = 1;
INSERT INTO TABLE (SELECT signataires FROM cpt_courant WHERE num_compte = 'CC3')
SELECT signataire_elt_nt_type(REF(c),'R') FROM client c WHERE c.num_client = 6;

INSERT INTO TABLE (SELECT signataires FROM cpt_courant WHERE num_compte = 'CC4')
SELECT signataire_elt_nt_type(REF(c),'D') FROM client c WHERE c.num_client = 2;
INSERT INTO TABLE (SELECT signataires FROM cpt_courant WHERE num_compte = 'CC4')
SELECT signataire_elt_nt_type(REF(c),'X') FROM client c WHERE c.num_client = 3;
INSERT INTO TABLE (SELECT signataires FROM cpt_courant WHERE num_compte = 'CC4')
SELECT signataire_elt_nt_type(REF(c),'R') FROM client c WHERE c.num_client = 5;

INSERT INTO TABLE (SELECT signataires FROM cpt_courant WHERE num_compte = 'CC7')
SELECT signataire_elt_nt_type(REF(c),'D') FROM client c WHERE c.num_client = 2;
INSERT INTO TABLE (SELECT signataires FROM cpt_courant WHERE num_compte = 'CC7')
SELECT signataire_elt_nt_type(REF(c),'X') FROM client c WHERE c.num_client = 3;
INSERT INTO TABLE (SELECT signataires FROM cpt_courant WHERE num_compte = 'CC7')
SELECT signataire_elt_nt_type(REF(c),'R') FROM client c WHERE c.num_client = 5;

-- 5.7 Comptes d'epargne (5), dont CE2 a 3.49 % (limite < 3.5)
INSERT INTO cpt_epargne (num_compte, solde, date_ouverture, ref_client, ref_agence,
                         taux_interet, plafond_depot)
VALUES ('CE1',150000,DATE '2016-01-15',
        (SELECT REF(c) FROM client c WHERE c.num_client = 1),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A1'), 2.50, 500000);
INSERT INTO cpt_epargne (num_compte, solde, date_ouverture, ref_client, ref_agence,
                         taux_interet, plafond_depot)
VALUES ('CE2',250000,DATE '2017-03-01',
        (SELECT REF(c) FROM client c WHERE c.num_client = 2),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A2'), 3.49, 1000000);
INSERT INTO cpt_epargne (num_compte, solde, date_ouverture, ref_client, ref_agence,
                         taux_interet, plafond_depot)
VALUES ('CE3',80000,DATE '2018-05-01',
        (SELECT REF(c) FROM client c WHERE c.num_client = 3),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A3'), 1.75, 300000);
INSERT INTO cpt_epargne (num_compte, solde, date_ouverture, ref_client, ref_agence,
                         taux_interet, plafond_depot)
VALUES ('CE4',320000,DATE '2019-06-01',
        (SELECT REF(c) FROM client c WHERE c.num_client = 4),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A1'), 2.00, 750000);
INSERT INTO cpt_epargne (num_compte, solde, date_ouverture, ref_client, ref_agence,
                         taux_interet, plafond_depot)
VALUES ('CE5',500000,DATE '2021-09-01',
        (SELECT REF(c) FROM client c WHERE c.num_client = 1),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A2'), 3.00, 2000000);

-- 5.8 Comptes a terme (4)
--     CT1 : echeance dans 20 jours
--     CT2 : echeance dans 5 jours  (< 8 jours -> alerte)
--     CT3 : echeance depassee de 20 jours
--     CT4 : echeance depassee de 400 jours et montant bloque nul (C6.25)
INSERT INTO cpt_terme (num_compte, solde, date_ouverture, ref_client, ref_agence,
                       montant_bloque, duree_mois, date_echeance, taux_garanti)
VALUES ('CT1',200000,ADD_MONTHS(TRUNC(SYSDATE)+20,-12),
        (SELECT REF(c) FROM client c WHERE c.num_client = 1),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A1'),
        200000, 12, TRUNC(SYSDATE)+20, 3.20);
INSERT INTO cpt_terme (num_compte, solde, date_ouverture, ref_client, ref_agence,
                       montant_bloque, duree_mois, date_echeance, taux_garanti)
VALUES ('CT2',100000,ADD_MONTHS(TRUNC(SYSDATE)+5,-6),
        (SELECT REF(c) FROM client c WHERE c.num_client = 2),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A2'),
        100000, 6, TRUNC(SYSDATE)+5, 2.80);
INSERT INTO cpt_terme (num_compte, solde, date_ouverture, ref_client, ref_agence,
                       montant_bloque, duree_mois, date_echeance, taux_garanti)
VALUES ('CT3',50000,ADD_MONTHS(TRUNC(SYSDATE)-20,-12),
        (SELECT REF(c) FROM client c WHERE c.num_client = 3),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A3'),
        50000, 12, TRUNC(SYSDATE)-20, 3.00);
INSERT INTO cpt_terme (num_compte, solde, date_ouverture, ref_client, ref_agence,
                       montant_bloque, duree_mois, date_echeance, taux_garanti)
VALUES ('CT4',0,ADD_MONTHS(TRUNC(SYSDATE)-400,-36),
        (SELECT REF(c) FROM client c WHERE c.num_client = 6),
        (SELECT REF(a) FROM agence a WHERE a.code = 'A3'),
        0, 36, TRUNC(SYSDATE)-400, 1.50);

-- 5.9 Operations (20), dates construites avec SYSDATE et des decalages
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (1,(SELECT REF(c) FROM client c WHERE c.num_client = 1),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC1'),
          TRUNC(SYSDATE)-30,  200000, 'DEPOT', 0);
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (2,(SELECT REF(c) FROM client c WHERE c.num_client = 1),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC1'),
          TRUNC(SYSDATE)-20,  -50000, 'RETRAIT', 0);
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (3,(SELECT REF(c) FROM client c WHERE c.num_client = 1),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC1'),
          TRUNC(SYSDATE)-10, 1000000, 'DEPOT', 0);
-- Virement CC1 (A1) -> CC2 (A2) : commission 1 % = 1500 DA
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (4,(SELECT REF(c) FROM client c WHERE c.num_client = 1),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC1'),
          TRUNC(SYSDATE)-5,  -150000, 'VIREMENT', 1500);
-- Operation > 1 000 000 DA : doit etre signalee
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (5,(SELECT REF(c) FROM client c WHERE c.num_client = 1),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC1'),
          TRUNC(SYSDATE)-2,  1500000, 'DEPOT', 0);
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (6,(SELECT REF(c) FROM client c WHERE c.num_client = 2),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC2'),
          TRUNC(SYSDATE)-5,   150000, 'VIREMENT', 0);
-- Retrait qui amene CC2 exactement a -50 000 (decouvert autorise)
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (7,(SELECT REF(c) FROM client c WHERE c.num_client = 2),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC2'),
          TRUNC(SYSDATE)-1,  -200000, 'RETRAIT', 0);
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (8,(SELECT REF(c) FROM client c WHERE c.num_client = 3),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC3'),
          TRUNC(SYSDATE)-60,   80000, 'DEPOT', 0);
-- Operation faite par un signataire de droit D (client 1 sur CC3)
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (9,(SELECT REF(c) FROM client c WHERE c.num_client = 1),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC3'),
          TRUNC(SYSDATE)-45,  -30000, 'RETRAIT', 0);
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (10,(SELECT REF(c) FROM client c WHERE c.num_client = 3),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC3'),
          TRUNC(SYSDATE)-40,  -12000, 'CB', 0);
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (11,(SELECT REF(c) FROM client c WHERE c.num_client = 4),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC4'),
          TRUNC(SYSDATE)-90,  500000, 'DEPOT', 0);
-- Signataire de droit D (client 2 sur CC4)
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (12,(SELECT REF(c) FROM client c WHERE c.num_client = 2),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC4'),
          TRUNC(SYSDATE)-80,  -100000, 'RETRAIT', 0);
-- Signataire de droit X (client 3 sur CC4)
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (13,(SELECT REF(c) FROM client c WHERE c.num_client = 3),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC4'),
          TRUNC(SYSDATE)-70,  -50000, 'RETRAIT', 0);
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (14,(SELECT REF(c) FROM client c WHERE c.num_client = 4),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC4'),
          TRUNC(SYSDATE)-60,  -25000, 'CB', 0);
-- CC6 : derniere operation il y a 400 jours (futur compte DORMANT)
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (15,(SELECT REF(c) FROM client c WHERE c.num_client = 6),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC6'),
          TRUNC(SYSDATE)-400,   60000, 'DEPOT', 0);
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (16,(SELECT REF(c) FROM client c WHERE c.num_client = 6),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC6'),
          TRUNC(SYSDATE)-400,  -20000, 'RETRAIT', 0);
-- CC7 : operations du titulaire (client 4) et de non-proprietaires
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (17,(SELECT REF(c) FROM client c WHERE c.num_client = 4),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC7'),
          TRUNC(SYSDATE)-50,  300000, 'DEPOT', 0);
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (18,(SELECT REF(c) FROM client c WHERE c.num_client = 2),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC7'),
          TRUNC(SYSDATE)-40,  -40000, 'RETRAIT', 0);
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (19,(SELECT REF(c) FROM client c WHERE c.num_client = 3),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC7'),
          TRUNC(SYSDATE)-30,  -60000, 'RETRAIT', 0);
INSERT INTO operation (id_op, ref_client, ref_compte, date_op, montant, type_op, commission)
VALUES (20,(SELECT REF(c) FROM client c WHERE c.num_client = 3),
          (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC7'),
          TRUNC(SYSDATE)-20,  -15000, 'CB', 0);

-- 5.10 Synchronisation des soldes avec l'historique.
--      Les triggers de la partie D n'existent pas encore : on calcule
--      ici le solde une fois pour toutes a partir des operations.
UPDATE cpt_courant c
   SET c.solde = (SELECT NVL(SUM(o.montant - o.commission),0)
                    FROM operation o
                   WHERE o.ref_compte = REF(c));
UPDATE cpt_courant c
   SET c.nb_op_cb = (SELECT COUNT(*) FROM operation o
                      WHERE o.ref_compte = REF(c) AND o.type_op = 'CB');

COMMIT;

PROMPT ============================================================
PROMPT 6. VERIFICATIONS
PROMPT ============================================================
SELECT num_compte, solde, nb_op_cb, statut
  FROM cpt_courant
 ORDER BY num_compte;

SELECT num_compte, solde, taux_interet
  FROM cpt_epargne
 ORDER BY num_compte;

SELECT num_compte, montant_bloque, duree_mois,
       TO_CHAR(date_echeance,'DD/MM/YYYY') AS echeance
  FROM cpt_terme
 ORDER BY num_compte;

SELECT 'CLIENTS' AS objet, COUNT(*) AS nb FROM client
UNION ALL SELECT 'CONSEILLERS', COUNT(*) FROM conseiller
UNION ALL SELECT 'AGENCES',     COUNT(*) FROM agence
UNION ALL SELECT 'AFFECTATIONS',COUNT(*) FROM affectation
UNION ALL SELECT 'CC',          COUNT(*) FROM cpt_courant
UNION ALL SELECT 'CE',          COUNT(*) FROM cpt_epargne
UNION ALL SELECT 'CT',          COUNT(*) FROM cpt_terme
UNION ALL SELECT 'OPERATIONS',  COUNT(*) FROM operation
UNION ALL SELECT 'SIGNATAIRES', COUNT(*) FROM cpt_courant c, TABLE(c.signataires) s;

PROMPT *** Objets invalides eventuels ***
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status <> 'VALID'
 ORDER BY object_type, object_name;

PROMPT ============================================================
PROMPT FIN PARTIE A
PROMPT ============================================================

PROMPT ############################################################
PROMPT # PARTIE_B_MANIPULATIONS.SQL
PROMPT ############################################################
-- =====================================================================
-- partie_B_manipulations.sql
-- Mini-projet BDDA - M1 ASR - 2026/2027
--
-- PARTIE B - Manipulation de la base (question 5)
--   B5a : ajout du client 99 (VARRAY a un seul element)
--   B5b : ajout de CC99 sans titulaire, puis UPDATE (contrainte differee)
--   B5c : operation sans date -> valeur par defaut SYSDATE
--   B5d : ajout d'un signataire de droit D dans la nested table
--   B5e : procedure change_Portable (avant / apres)
--   B5f : procedure drop_client(99) (avant / apres)
--
-- A executer APRES la partie A. Le script est rejouable : il commence par
-- supprimer un eventuel client 99 reste d'une execution precedente.
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF

PROMPT ============================================================
PROMPT 0. PROCEDURES CATALOGUEES UTILISEES EN PARTIE B
PROMPT ============================================================

-- ---------------------------------------------------------------------
-- change_Portable (element 4 des "Elements a programmer")
-- Affecte un nouveau numero de portable (2e element du VARRAY).
--   - VARRAY NULL          -> creation d'un tableau de 2 elements
--   - 1 seul element       -> EXTEND puis affectation
--   - 2 ou 3 elements      -> remplacement de l'element 2
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE change_Portable (
  paramcli IN NUMBER,
  paramtel IN VARCHAR2
) IS
  v_tel tel_vry_type;
BEGIN
  SELECT telephones INTO v_tel
    FROM client
   WHERE num_client = paramcli;

  IF v_tel IS NULL THEN
    v_tel := tel_vry_type(NULL, paramtel);        -- tableau non initialise
  ELSIF v_tel.COUNT = 0 THEN
    v_tel := tel_vry_type(NULL, paramtel);        -- tableau vide
  ELSIF v_tel.COUNT = 1 THEN
    v_tel.EXTEND(1);                              -- extension dynamique
    v_tel(2) := paramtel;
  ELSE
    v_tel(2) := paramtel;                         -- remplacement simple
  END IF;

  UPDATE client SET telephones = v_tel WHERE num_client = paramcli;
  COMMIT;

  DBMS_OUTPUT.PUT_LINE('change_Portable : client '||paramcli
                       ||' -> '||paramtel||'  (COUNT='||v_tel.COUNT||')');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('change_Portable : client '||paramcli||' inexistant.');
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('change_Portable : echec, ROLLBACK ('||SQLERRM||')');
    RAISE;
END;
/
SHOW ERRORS PROCEDURE change_Portable

-- ---------------------------------------------------------------------
-- drop_client (element 3 des "Elements a programmer")
-- Detruit un client, ses comptes et leurs operations, le retire des
-- listes de signataires des autres comptes et remet a NULL le parrain
-- de ses filleuls. Transaction : COMMIT si tout passe, ROLLBACK sinon.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE drop_client (paramcli IN NUMBER) IS
  v_ref REF client_type;
BEGIN
  SELECT REF(c) INTO v_ref FROM client c WHERE c.num_client = paramcli;

  -- 1. Operations faites par ce client et operations de ses comptes
  DELETE FROM operation
   WHERE ref_client = v_ref
      OR ref_compte IN (SELECT REF(x) FROM cpt_courant x
                         WHERE x.ref_client = v_ref);

  -- 2. Retirer le client des listes de signataires des autres comptes
  FOR r IN (SELECT c.num_compte
              FROM cpt_courant c
             WHERE EXISTS (SELECT 1 FROM TABLE(c.signataires) s
                            WHERE s.ref_client = v_ref)) LOOP
    DELETE FROM TABLE (SELECT signataires FROM cpt_courant
                        WHERE num_compte = r.num_compte)
     WHERE ref_client = v_ref;
  END LOOP;

  -- 3. Filleuls : la reference de parrain repasse a NULL
  UPDATE client SET ref_parrain = NULL WHERE ref_parrain = v_ref;

  -- 4. Comptes du client (terme, epargne, courant)
  DELETE FROM cpt_terme   WHERE ref_client = v_ref;
  DELETE FROM cpt_epargne WHERE ref_client = v_ref;
  DELETE FROM cpt_courant WHERE ref_client = v_ref;

  -- 5. Le client lui-meme
  DELETE FROM client WHERE num_client = paramcli;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('drop_client : client '||paramcli
                       ||' supprime, COMMIT effectue.');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('drop_client : client '||paramcli||' inexistant.');
  WHEN OTHERS THEN
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('drop_client : echec, ROLLBACK ('||SQLERRM||')');
    RAISE;
END;
/
SHOW ERRORS PROCEDURE drop_client

-- Nettoyage d'une execution precedente (rejouabilite du script)
DECLARE
  v_nb NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_nb FROM client WHERE num_client = 99;
  IF v_nb > 0 THEN
    DBMS_OUTPUT.PUT_LINE('Nettoyage : client 99 deja present, suppression.');
    drop_client(99);
  END IF;
END;
/

PROMPT ============================================================
PROMPT 1. B5a - AJOUT DU CLIENT 99
PROMPT ============================================================
-- Valeurs non precisees par le sujet : prenom, date de naissance,
-- numero de securite sociale et e-mail sont choisis de facon coherente.
INSERT INTO client (num_client, nom, prenom, date_naissance, num_secu,
                    adresse, telephones, email, date_entree,
                    ref_conseiller, ref_parrain)
VALUES (99, 'OUKACI', 'Ahmed', DATE '1999-01-01', '990101099',
        adresse_type(10, 'Rue de la Poste', 'Bejaia', '06000'),
        tel_vry_type('0661-00-00-01'),
        'ahmed.oukaci@mail.dz', TRUNC(SYSDATE),
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 1), NULL);
COMMIT;

SELECT c.num_client, c.nom, c.prenom, c.adresse.ville AS ville
  FROM client c
 WHERE c.num_client = 99;

-- Un seul element dans le VARRAY
SELECT t.COLUMN_VALUE AS telephone
  FROM TABLE (SELECT telephones FROM client WHERE num_client = 99) t;

PROMPT ============================================================
PROMPT 2. B5b - CC99 SANS TITULAIRE, PUIS UPDATE
PROMPT ============================================================
-- La contrainte ck_cc_client est DEFERRABLE INITIALLY DEFERRED :
-- l'insertion avec ref_client NULL est acceptee, et n'est controlee
-- qu'au COMMIT. L'UPDATE a lieu avant le COMMIT.
INSERT INTO cpt_courant (num_compte, solde, date_ouverture, ref_client,
                         ref_agence, decouvert, signataires)
VALUES ('CC99', 0, SYSDATE, NULL,
        (SELECT REF(a) FROM agence a WHERE a.code = 'A1'),
        10000, signataire_nt_type());

SELECT c.num_compte, c.ref_client.nom AS titulaire, c.solde, c.statut
  FROM cpt_courant c
 WHERE c.num_compte = 'CC99';

UPDATE cpt_courant
   SET ref_client = (SELECT REF(c) FROM client c WHERE c.num_client = 99)
 WHERE num_compte = 'CC99';

COMMIT;

SELECT c.num_compte, c.ref_client.nom AS titulaire, c.solde, c.statut
  FROM cpt_courant c
 WHERE c.num_compte = 'CC99';

PROMPT ============================================================
PROMPT 3. B5c - OPERATION SANS DATE (DEFAUT SYSDATE)
PROMPT ============================================================
-- Insertion par liste de colonnes : ni date_op ni commission.
-- Aucun constructeur operation_type(...) : les valeurs par defaut
-- (SYSDATE et 0) s'appliquent aux colonnes omises.
INSERT INTO operation (id_op, ref_client, ref_compte, montant, type_op)
VALUES (seq_operation.NEXTVAL,
        (SELECT REF(c) FROM client c WHERE c.num_client = 99),
        (SELECT REF(x) FROM cpt_courant x WHERE x.num_compte = 'CC99'),
        50000, 'DEPOT');
COMMIT;

SELECT o.id_op, o.type_op, o.montant, o.commission,
       TO_CHAR(o.date_op, 'DD/MM/YYYY HH24:MI:SS') AS date_op,
       TO_CHAR(SYSDATE,  'DD/MM/YYYY HH24:MI:SS') AS date_sys
  FROM operation o
 WHERE o.ref_compte = (SELECT REF(x) FROM cpt_courant x
                        WHERE x.num_compte = 'CC99');

PROMPT ============================================================
PROMPT 4. B5d - SIGNATAIRE DE DROIT D SUR CC99
PROMPT ============================================================
INSERT INTO TABLE (SELECT signataires FROM cpt_courant
                    WHERE num_compte = 'CC99')
SELECT signataire_elt_nt_type(REF(c), 'D')
  FROM client c
 WHERE c.num_client = 1;
COMMIT;

SELECT s.ref_client.nom AS signataire, s.droit
  FROM cpt_courant c, TABLE(c.signataires) s
 WHERE c.num_compte = 'CC99';

PROMPT ============================================================
PROMPT 5. B5e - CHANGE_PORTABLE (AVANT / APRES)
PROMPT ============================================================
-- Client 99 : VARRAY a 1 element -> extension a 2 elements
DECLARE
  v tel_vry_type;
BEGIN
  SELECT telephones INTO v FROM client WHERE num_client = 99;
  DBMS_OUTPUT.PUT_LINE('AVANT client 99 : COUNT='||v.COUNT
                       ||'  element2='||CASE WHEN v.COUNT >= 2
                                             THEN NVL(v(2),'<NULL>')
                                             ELSE '<ABSENT>' END);
END;
/

EXEC change_Portable(99, '0770-99-88-77');

DECLARE
  v tel_vry_type;
BEGIN
  SELECT telephones INTO v FROM client WHERE num_client = 99;
  DBMS_OUTPUT.PUT_LINE('APRES client 99 : COUNT='||v.COUNT
                       ||'  element2='||CASE WHEN v.COUNT >= 2
                                             THEN NVL(v(2),'<NULL>')
                                             ELSE '<ABSENT>' END);
END;
/

-- Client 3 : 3 elements -> simple remplacement de l'element 2
DECLARE
  v tel_vry_type;
BEGIN
  SELECT telephones INTO v FROM client WHERE num_client = 3;
  DBMS_OUTPUT.PUT_LINE('AVANT client 3  : COUNT='||v.COUNT
                       ||'  element2='||CASE WHEN v.COUNT >= 2
                                             THEN NVL(v(2),'<NULL>')
                                             ELSE '<ABSENT>' END);
END;
/

EXEC change_Portable(3, '0777-11-22-33');

DECLARE
  v tel_vry_type;
BEGIN
  SELECT telephones INTO v FROM client WHERE num_client = 3;
  DBMS_OUTPUT.PUT_LINE('APRES client 3  : COUNT='||v.COUNT
                       ||'  element2='||CASE WHEN v.COUNT >= 2
                                             THEN NVL(v(2),'<NULL>')
                                             ELSE '<ABSENT>' END);
END;
/

-- Client inexistant : message, aucune modification
EXEC change_Portable(12345, '0555-00-00-00');

PROMPT ============================================================
PROMPT 6. B5f - DROP_CLIENT(99) (AVANT / APRES)
PROMPT ============================================================
-- Preparation : on rend 99 signataire de CC4 (compte d'un autre client)
-- et parrain du client 5, afin de verifier les deux regles de la question.
INSERT INTO TABLE (SELECT signataires FROM cpt_courant
                    WHERE num_compte = 'CC4')
SELECT signataire_elt_nt_type(REF(c), 'R')
  FROM client c
 WHERE c.num_client = 99;

UPDATE client
   SET ref_parrain = (SELECT REF(p) FROM client p WHERE p.num_client = 99)
 WHERE num_client = 5;
COMMIT;

PROMPT *** ETAT AVANT SUPPRESSION ***
SELECT 'CLIENT 99'        AS objet, COUNT(*) AS nb
  FROM client WHERE num_client = 99
UNION ALL
SELECT 'COMPTES 99',      COUNT(*)
  FROM cpt_courant
 WHERE ref_client = (SELECT REF(c) FROM client c WHERE c.num_client = 99)
UNION ALL
SELECT 'OPERATIONS 99',   COUNT(*)
  FROM operation
 WHERE ref_client = (SELECT REF(c) FROM client c WHERE c.num_client = 99)
UNION ALL
SELECT 'SIGNATAIRES 99',  COUNT(*)
  FROM cpt_courant c, TABLE(c.signataires) s
 WHERE s.ref_client = (SELECT REF(p) FROM client p WHERE p.num_client = 99)
UNION ALL
SELECT 'FILLEULS 99',     COUNT(*)
  FROM client
 WHERE ref_parrain = (SELECT REF(p) FROM client p WHERE p.num_client = 99)
UNION ALL
SELECT 'CC99',            COUNT(*)
  FROM cpt_courant WHERE num_compte = 'CC99'
UNION ALL
SELECT 'OPS SUR CC99',    COUNT(*)
  FROM operation
 WHERE ref_compte = (SELECT REF(x) FROM cpt_courant x
                      WHERE x.num_compte = 'CC99');

SELECT c.num_client, c.nom, c.ref_parrain.nom AS parrain
  FROM client c
 WHERE c.num_client = 5;

EXEC drop_client(99);

PROMPT *** ETAT APRES SUPPRESSION ***
SELECT 'CLIENT 99'        AS objet, COUNT(*) AS nb
  FROM client WHERE num_client = 99
UNION ALL
SELECT 'COMPTES 99',      COUNT(*)
  FROM cpt_courant
 WHERE ref_client = (SELECT REF(c) FROM client c WHERE c.num_client = 99)
UNION ALL
SELECT 'OPERATIONS 99',   COUNT(*)
  FROM operation
 WHERE ref_client = (SELECT REF(c) FROM client c WHERE c.num_client = 99)
UNION ALL
SELECT 'SIGNATAIRES 99',  COUNT(*)
  FROM cpt_courant c, TABLE(c.signataires) s
 WHERE s.ref_client = (SELECT REF(p) FROM client p WHERE p.num_client = 99)
UNION ALL
SELECT 'FILLEULS 99',     COUNT(*)
  FROM client
 WHERE ref_parrain = (SELECT REF(p) FROM client p WHERE p.num_client = 99)
UNION ALL
SELECT 'CC99',            COUNT(*)
  FROM cpt_courant WHERE num_compte = 'CC99'
UNION ALL
SELECT 'OPS SUR CC99',    COUNT(*)
  FROM operation
 WHERE ref_compte = (SELECT REF(x) FROM cpt_courant x
                      WHERE x.num_compte = 'CC99');

SELECT c.num_client, c.nom, c.ref_parrain.nom AS parrain
  FROM client c
 WHERE c.num_client = 5;

-- Deuxieme appel : le client n'existe plus, message et aucune erreur
EXEC drop_client(99);

PROMPT ============================================================
PROMPT 7. ETAT FINAL DE LA BASE APRES LA PARTIE B
PROMPT ============================================================
SELECT 'CLIENTS'    AS objet, COUNT(*) AS nb FROM client
UNION ALL SELECT 'CC',         COUNT(*) FROM cpt_courant
UNION ALL SELECT 'CE',         COUNT(*) FROM cpt_epargne
UNION ALL SELECT 'CT',         COUNT(*) FROM cpt_terme
UNION ALL SELECT 'OPERATIONS', COUNT(*) FROM operation
UNION ALL SELECT 'SIGNATAIRES',COUNT(*) FROM cpt_courant c, TABLE(c.signataires) s;

PROMPT ============================================================
PROMPT FIN PARTIE B
PROMPT ============================================================

PROMPT ############################################################
PROMPT # PARTIE_C_REQUETES.SQL
PROMPT ############################################################
-- =====================================================================
-- partie_C_requetes.sql
-- Mini-projet BDDA - M1 ASR - 2026/2027
-- .
-- PARTIE C - Requetes SQL (question 6)
--   6.1  a 6.3   requetes simples
--   6.4  a 6.10  requetes sur les references (notation pointee)
--   6.11 a 6.15  requetes avec agregats
--   6.16 a 6.20  requetes sur les collections (TABLE)
--   6.21 a 6.25  requetes de gestion
-- .
-- A executer APRES les parties A et B.
-- La requete 6.25 est destructive (elle supprime CT4) : c'est voulu.
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 250
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF

ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

-- Largeurs d'affichage pour garder une ligne par tuple
COLUMN nom        FORMAT A14
COLUMN prenom     FORMAT A12
COLUMN num_secu   FORMAT A12
COLUMN rue        FORMAT A28
COLUMN ville      FORMAT A10
COLUMN email      FORMAT A24
COLUMN conseiller FORMAT A11
COLUMN parrain    FORMAT A11

PROMPT ############################################################
PROMPT 6.1 - CLIENTS SANS LEURS NUMEROS DE TELEPHONE
PROMPT ############################################################
SELECT c.num_client, c.nom, c.prenom, c.date_naissance, c.num_secu,
       c.adresse.num_rue AS num, c.adresse.rue AS rue, c.adresse.ville AS ville,
       c.adresse.cp AS cp, c.email, c.date_entree,
       c.ref_conseiller.nom AS conseiller,
       c.ref_parrain.nom    AS parrain
  FROM client c
 ORDER BY c.num_client;

PROMPT ############################################################
PROMPT 6.2 - COMPTES COURANTS
PROMPT ############################################################
SELECT num_compte, solde, date_ouverture, decouvert, nb_op_cb
  FROM cpt_courant
 ORDER BY num_compte;

PROMPT ############################################################
PROMPT 6.3a - COMPTES D'EPARGNE TRIES PAR TAUX DECROISSANT
PROMPT ############################################################
SELECT num_compte, solde, date_ouverture, taux_interet, plafond_depot
  FROM cpt_epargne
 ORDER BY taux_interet DESC;

PROMPT ############################################################
PROMPT 6.3b - COMPTES A TERME
PROMPT ############################################################
SELECT num_compte, solde, date_ouverture, montant_bloque,
       duree_mois, date_echeance, taux_garanti
  FROM cpt_terme
 ORDER BY date_echeance;

PROMPT ############################################################
PROMPT 6.4 - COMPTES COURANTS DU CLIENT 4 (JOINTURE IMPLICITE)
PROMPT ############################################################
SELECT cc.num_compte, cc.solde, cc.date_ouverture, cc.decouvert
  FROM cpt_courant cc, client c
 WHERE cc.ref_client = REF(c)
   AND c.num_client = 4
 ORDER BY cc.num_compte;

PROMPT ############################################################
PROMPT 6.5 - TOUS LES COMPTES DU CLIENT 4 (UNION)
PROMPT ############################################################
SELECT cc.num_compte, 'COURANT' AS type_compte, cc.solde, cc.date_ouverture,
       'decouvert='||cc.decouvert AS info
  FROM cpt_courant cc, client c
 WHERE cc.ref_client = REF(c) AND c.num_client = 4
UNION ALL
SELECT ce.num_compte, 'EPARGNE', ce.solde, ce.date_ouverture,
       'taux='||ce.taux_interet
  FROM cpt_epargne ce, client c
 WHERE ce.ref_client = REF(c) AND c.num_client = 4
UNION ALL
SELECT ct.num_compte, 'TERME', ct.solde, ct.date_ouverture,
       'bloque='||ct.montant_bloque
  FROM cpt_terme ct, client c
 WHERE ct.ref_client = REF(c) AND c.num_client = 4
 ORDER BY 2, 1;

PROMPT ############################################################
PROMPT 6.6 - CLIENTS ET COMPTES COURANTS DE SOLDE < 100 000 DA
PROMPT ############################################################
-- Seuil choisi : 100 000 DA (le sujet parle d'un seuil "donne").
SELECT c.num_client, c.nom, c.adresse.ville AS ville,
       cc.num_compte, cc.solde
  FROM client c, cpt_courant cc
 WHERE cc.ref_client = REF(c)
   AND cc.solde < 100000
 ORDER BY c.num_client, cc.num_compte;

PROMPT ############################################################
PROMPT 6.7a - CLIENTS TITULAIRES D'AU MOINS UN COMPTE D'EPARGNE
PROMPT ############################################################
SELECT DISTINCT c.num_client, c.nom, c.adresse.ville AS ville
  FROM client c, cpt_epargne ce
 WHERE ce.ref_client = REF(c)
 ORDER BY c.num_client;

PROMPT ############################################################
PROMPT 6.7b - CLIENTS TITULAIRES D'UN SEUL COMPTE D'EPARGNE
PROMPT ############################################################
SELECT c.num_client, c.nom, c.adresse.ville AS ville
  FROM client c, cpt_epargne ce
 WHERE ce.ref_client = REF(c)
 GROUP BY c.num_client, c.nom, c.adresse.ville
HAVING COUNT(*) = 1
 ORDER BY c.num_client;

PROMPT ############################################################
PROMPT 6.8 - CLIENTS AYANT OPERE SUR CC7
PROMPT ############################################################
SELECT c.num_client, c.nom, o.date_op, o.montant, o.type_op
  FROM client c, operation o, cpt_courant cc
 WHERE o.ref_client = REF(c)
   AND o.ref_compte = REF(cc)
   AND cc.num_compte = 'CC7'
 ORDER BY o.date_op;

PROMPT ############################################################
PROMPT 6.9a - OPERATIONS SUR CC7 FAITES PAR LE PROPRIETAIRE
PROMPT ############################################################
SELECT o.id_op, o.date_op, o.montant, o.type_op, c.nom AS client
  FROM operation o, client c, cpt_courant cc
 WHERE o.ref_client = REF(c)
   AND o.ref_compte = REF(cc)
   AND cc.num_compte = 'CC7'
   AND o.ref_client = cc.ref_client
 ORDER BY o.date_op;

PROMPT ############################################################
PROMPT 6.9b - OPERATIONS SUR CC7 FAITES PAR DES NON-PROPRIETAIRES
PROMPT ############################################################
SELECT o.id_op, o.date_op, o.montant, o.type_op, c.nom AS client
  FROM operation o, client c, cpt_courant cc
 WHERE o.ref_client = REF(c)
   AND o.ref_compte = REF(cc)
   AND cc.num_compte = 'CC7'
   AND o.ref_client <> cc.ref_client
 ORDER BY o.date_op;

PROMPT ############################################################
PROMPT 6.10 - COMPTES COURANTS A SOLDE NEGATIF + TITULAIRE + CONSEILLER
PROMPT ############################################################
SELECT cc.num_compte, cc.solde, cc.decouvert,
       c.nom AS titulaire,
       c.ref_conseiller.nom AS conseiller
  FROM cpt_courant cc, client c
 WHERE cc.ref_client = REF(c)
   AND cc.solde < 0
 ORDER BY cc.num_compte;

PROMPT ############################################################
PROMPT 6.11a - NOMBRE DE COMPTES D'EPARGNE PAR CLIENT
PROMPT ############################################################
SELECT c.num_client, c.nom, COUNT(ce.num_compte) AS nb_epargne
  FROM client c, cpt_epargne ce
 WHERE ce.ref_client = REF(c)
 GROUP BY c.num_client, c.nom
 ORDER BY c.num_client;

PROMPT ############################################################
PROMPT 6.11b - IDEM, Y COMPRIS LES CLIENTS SANS COMPTE D'EPARGNE
PROMPT ############################################################
SELECT c.num_client, c.nom, COUNT(ce.num_compte) AS nb_epargne
  FROM client c
  LEFT JOIN cpt_epargne ce ON ce.ref_client = REF(c)
 GROUP BY c.num_client, c.nom
 ORDER BY c.num_client;

PROMPT ############################################################
PROMPT 6.12 - TITULAIRE AYANT LE PLUS DE COMPTES D'EPARGNE
PROMPT ############################################################
SELECT c.num_client, c.nom, COUNT(*) AS nb_epargne
  FROM client c, cpt_epargne ce
 WHERE ce.ref_client = REF(c)
 GROUP BY c.num_client, c.nom
HAVING COUNT(*) = (SELECT MAX(COUNT(*))
                     FROM cpt_epargne ce2, client c2
                    WHERE ce2.ref_client = REF(c2)
                    GROUP BY c2.num_client)
 ORDER BY c.num_client;

PROMPT ############################################################
PROMPT 6.13 - PAR TYPE D'OPERATION : NOMBRE ET MONTANT MOYEN
PROMPT ############################################################
SELECT type_op, COUNT(*) AS nb_operations,
       ROUND(AVG(montant), 2) AS montant_moyen
  FROM operation
 GROUP BY type_op
 ORDER BY type_op;

PROMPT ############################################################
PROMPT 6.14 - PAR AGENCE : TOTAL DES SOLDES (COURANTS + EPARGNE)
PROMPT ############################################################
SELECT a.code, a.nom, SUM(x.solde) AS total_soldes
  FROM agence a,
       (SELECT ref_agence, solde FROM cpt_courant
        UNION ALL
        SELECT ref_agence, solde FROM cpt_epargne) x
 WHERE x.ref_agence = REF(a)
 GROUP BY a.code, a.nom
 ORDER BY a.code;

PROMPT ############################################################
PROMPT 6.15 - LES 3 CLIENTS AU SOLDE TOTAL LE PLUS ELEVE
PROMPT ############################################################
SELECT c.num_client, c.nom,
       NVL((SELECT SUM(solde) FROM cpt_courant x WHERE x.ref_client = REF(c)), 0)
     + NVL((SELECT SUM(solde) FROM cpt_epargne x WHERE x.ref_client = REF(c)), 0)
     + NVL((SELECT SUM(solde) FROM cpt_terme   x WHERE x.ref_client = REF(c)), 0)
       AS solde_total
  FROM client c
 ORDER BY solde_total DESC
 FETCH FIRST 3 ROWS ONLY;

PROMPT ############################################################
PROMPT 6.16a - TELEPHONES RENSEIGNES DU CLIENT 1
PROMPT ############################################################
SELECT COUNT(*)                AS nb_elements,
       COUNT(t.COLUMN_VALUE)   AS nb_renseignes
  FROM TABLE (SELECT telephones FROM client WHERE num_client = 1) t;

PROMPT ############################################################
PROMPT 6.16b - TELEPHONES RENSEIGNES POUR CHAQUE CLIENT
PROMPT ############################################################
-- COUNT(*) compte les 3 emplacements du VARRAY, COUNT(COLUMN_VALUE)
-- ne compte que ceux qui ne sont pas NULL.
SELECT c.num_client, c.nom,
       COUNT(*)              AS nb_elements,
       COUNT(t.COLUMN_VALUE) AS nb_renseignes
  FROM client c, TABLE(c.telephones) t
 GROUP BY c.num_client, c.nom
 ORDER BY c.num_client;

PROMPT ############################################################
PROMPT 6.17 - NUMEROS DE TELEPHONE DE CHAQUE CLIENT
PROMPT ############################################################
SELECT c.num_client, c.nom,
       NVL(t.COLUMN_VALUE, '<non renseigne>') AS telephone
  FROM client c, TABLE(c.telephones) t
 ORDER BY c.num_client;

PROMPT ############################################################
PROMPT 6.18a - NOMBRE DE SIGNATAIRES DE CC7
PROMPT ############################################################
SELECT COUNT(*) AS nb_signataires
  FROM TABLE (SELECT signataires FROM cpt_courant WHERE num_compte = 'CC7');

PROMPT ############################################################
PROMPT 6.18b - NOMBRE DE SIGNATAIRES POUR CHAQUE COMPTE COURANT
PROMPT ############################################################
SELECT cc.num_compte,
       (SELECT COUNT(*) FROM TABLE(cc.signataires)) AS nb_signataires
  FROM cpt_courant cc
 ORDER BY cc.num_compte;

PROMPT ############################################################
PROMPT 6.19a - SIGNATAIRES DE CC7 (NUMERO ET DROIT)
PROMPT ############################################################
SELECT s.ref_client.num_client AS num_client,
       s.ref_client.nom        AS nom,
       s.droit
  FROM cpt_courant cc, TABLE(cc.signataires) s
 WHERE cc.num_compte = 'CC7'
 ORDER BY s.ref_client.num_client;

PROMPT ############################################################
PROMPT 6.19b - SIGNATAIRES DE TOUS LES COMPTES COURANTS
PROMPT ############################################################
SELECT cc.num_compte, s.ref_client.num_client AS num_client,
       s.ref_client.nom AS nom, s.droit
  FROM cpt_courant cc, TABLE(cc.signataires) s
 ORDER BY cc.num_compte, s.ref_client.num_client;

PROMPT ############################################################
PROMPT 6.19c - MEME RESULTAT AVEC UN CURSEUR IMBRIQUE
PROMPT ############################################################
DECLARE
  CURSOR c_comptes IS
    SELECT num_compte FROM cpt_courant ORDER BY num_compte;
  CURSOR c_sigs (p_compte VARCHAR2) IS
    SELECT s.ref_client.nom AS nom, s.droit
      FROM cpt_courant cc, TABLE(cc.signataires) s
     WHERE cc.num_compte = p_compte
     ORDER BY s.ref_client.num_client;
BEGIN
  FOR r IN c_comptes LOOP
    DBMS_OUTPUT.PUT_LINE('Compte '||r.num_compte);
    FOR s IN c_sigs(r.num_compte) LOOP
      DBMS_OUTPUT.PUT_LINE('   '||RPAD(s.nom, 15)||' droit '||s.droit);
    END LOOP;
  END LOOP;
END;
/

PROMPT ############################################################
PROMPT 6.20 - SIGNATAIRES DE CC7 : JOINTURE NESTED TABLE / CLIENT
PROMPT ############################################################
COLUMN adresse FORMAT A50
SELECT c.num_client, c.nom,
       c.adresse.num_rue||' '||c.adresse.rue||', '||c.adresse.ville AS adresse,
       s.droit
  FROM cpt_courant cc, TABLE(cc.signataires) s, client c
 WHERE cc.num_compte = 'CC7'
   AND s.ref_client = REF(c)
 ORDER BY c.num_client;

PROMPT ############################################################
PROMPT 6.21a - TOUS LES CLIENTS PAR VILLE
PROMPT ############################################################
SELECT c.adresse.ville AS ville, c.num_client, c.nom, c.prenom
  FROM client c
 ORDER BY c.adresse.ville, c.nom;

PROMPT ############################################################
PROMPT 6.21b - RECHERCHE D'UNE VILLE (EXEMPLE : BEJAIA)
PROMPT ############################################################
SELECT c.num_client, c.nom, c.prenom, c.adresse.ville AS ville
  FROM client c
 WHERE c.adresse.ville = 'Bejaia'
 ORDER BY c.nom;

PROMPT ############################################################
PROMPT 6.22 - COMPTES A TERME DONT L'ECHEANCE EST DANS 30 JOURS
PROMPT ############################################################
SELECT num_compte, montant_bloque, date_echeance,
       date_echeance - TRUNC(SYSDATE) AS jours_restants
  FROM cpt_terme
 WHERE date_echeance BETWEEN TRUNC(SYSDATE) AND TRUNC(SYSDATE) + 30
 ORDER BY date_echeance;

PROMPT ############################################################
PROMPT 6.23 - COMPTES COURANTS SANS OPERATION DEPUIS PLUS DE 12 MOIS
PROMPT ############################################################
SELECT cc.num_compte, cc.solde, cc.statut,
       (SELECT MAX(o.date_op) FROM operation o
         WHERE o.ref_compte = REF(cc)) AS derniere_operation
  FROM cpt_courant cc
 WHERE NOT EXISTS (SELECT 1 FROM operation o
                    WHERE o.ref_compte = REF(cc)
                      AND o.date_op > ADD_MONTHS(TRUNC(SYSDATE), -12))
 ORDER BY cc.num_compte;

PROMPT ############################################################
PROMPT 6.24 - OPERATIONS DE PLUS DE 1 000 000 DA
PROMPT ############################################################
SELECT o.id_op, o.date_op, o.montant, o.type_op,
       c.num_client, c.nom AS client, cc.num_compte
  FROM operation o, client c, cpt_courant cc
 WHERE o.ref_client = REF(c)
   AND o.ref_compte = REF(cc)
   AND o.montant > 1000000
 ORDER BY o.montant DESC;

PROMPT ############################################################
PROMPT 6.25 - SUPPRESSION DES COMPTES A TERME EXPIRES > 1 AN, MONTANT NUL
PROMPT ############################################################
SELECT num_compte, montant_bloque, date_echeance
  FROM cpt_terme
 WHERE date_echeance < ADD_MONTHS(TRUNC(SYSDATE), -12)
   AND montant_bloque = 0;

DELETE FROM cpt_terme
 WHERE date_echeance < ADD_MONTHS(TRUNC(SYSDATE), -12)
   AND montant_bloque = 0;

COMMIT;

PROMPT *** Verification apres suppression ***
SELECT num_compte, montant_bloque, date_echeance
  FROM cpt_terme
 ORDER BY num_compte;

PROMPT ############################################################
PROMPT FIN PARTIE C
PROMPT ############################################################

PROMPT ############################################################
PROMPT # PARTIE_D_PROGRAMMATION.SQL
PROMPT ############################################################
-- =====================================================================
-- partie_D_programmation.sql
-- Mini-projet BDDA - M1 ASR - 2026/2027
-- .
-- PARTIE D - Programmation PL/SQL
--   D1 : sous-programmes catalogues (elements a programmer 1 a 5)
--   D7 : blocs PL/SQL anonymes (question 7)
--   D8 : methodes des types objet (question 8)
--   D9 : triggers (question 9)
-- .
-- ORDRE D EXECUTION ET JUSTIFICATION
--   Les methodes D8 sont ajoutees puis testees. Les tests non destructifs
--   (nbCepargne, soldeTotal, nbSignataire, calculeInterets, ...) sont faits
--   immediatement. Les tests de passeMvt (D8i) sont faits APRES la creation
--   des triggers D9, car passeMvt insere une operation et doit etre confronte
--   aux triggers. Les tests de fermeCompte (D8n) sont faits EN DERNIER car
--   ils detruisent CE4 et CC1.
-- .
--   Les tests qui modifient les donnees se terminent par ROLLBACK, sauf
--   scan_echeances (COMMIT volontaire) et fermeCompte (COMMIT exige par le
--   sujet). Le script peut donc etre rejoue apres une partie A fraiche.
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 250
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF
WHENEVER SQLERROR CONTINUE

PROMPT ============================================================
PROMPT D1. SOUS-PROGRAMMES CATALOGUES
PROMPT ============================================================

-- =====================================================================
-- D1.1 nb_comptes : nombre total de comptes (courants + epargne + terme)
-- =====================================================================
CREATE OR REPLACE FUNCTION nb_comptes RETURN NUMBER IS
  v_nb NUMBER;
BEGIN
  SELECT (SELECT COUNT(*) FROM cpt_courant)
       + (SELECT COUNT(*) FROM cpt_epargne)
       + (SELECT COUNT(*) FROM cpt_terme)
    INTO v_nb
    FROM dual;
  RETURN v_nb;
END;
/
SHOW ERRORS FUNCTION nb_comptes

-- =====================================================================
-- D1.2 solde_total : somme des soldes de tous les comptes d un client
-- =====================================================================
CREATE OR REPLACE FUNCTION solde_total (paramcli IN NUMBER) RETURN NUMBER IS
  v_nb    NUMBER;
  v_total NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_nb FROM client WHERE num_client = paramcli;
  IF v_nb = 0 THEN
    RAISE NO_DATA_FOUND;
  END IF;

  SELECT NVL((SELECT SUM(solde) FROM cpt_courant x
               WHERE x.ref_client = (SELECT REF(c) FROM client c
                                      WHERE c.num_client = paramcli)), 0)
       + NVL((SELECT SUM(solde) FROM cpt_epargne x
               WHERE x.ref_client = (SELECT REF(c) FROM client c
                                      WHERE c.num_client = paramcli)), 0)
       + NVL((SELECT SUM(solde) FROM cpt_terme x
               WHERE x.ref_client = (SELECT REF(c) FROM client c
                                      WHERE c.num_client = paramcli)), 0)
    INTO v_total
    FROM dual;
  RETURN v_total;
END;
/
SHOW ERRORS FUNCTION solde_total

-- =====================================================================
-- D1.3 ville_client : ville du client
-- =====================================================================
CREATE OR REPLACE FUNCTION ville_client (paramcli IN NUMBER) RETURN VARCHAR2 IS
  v_ville VARCHAR2(40);
BEGIN
  SELECT c.adresse.ville INTO v_ville
    FROM client c
   WHERE c.num_client = paramcli;
  RETURN v_ville;
END;
/
SHOW ERRORS FUNCTION ville_client

-- =====================================================================
-- D1.4 ajout_client : ajout d un client complet
--      Le parrain est optionnel. La procedure ne fait pas COMMIT :
--      la validation est laissee a l appelant.
-- =====================================================================
CREATE OR REPLACE PROCEDURE ajout_client (
  p_num        IN NUMBER,
  p_nom        IN VARCHAR2,
  p_prenom     IN VARCHAR2,
  p_naissance  IN DATE,
  p_secu       IN VARCHAR2,
  p_adresse    IN adresse_type,
  p_telephones IN tel_vry_type,
  p_email      IN VARCHAR2,
  p_conseiller IN NUMBER,
  p_parrain    IN NUMBER DEFAULT NULL
) IS
  v_ref_cons    REF conseiller_type;
  v_ref_parrain REF client_type;
BEGIN
  SELECT REF(c) INTO v_ref_cons
    FROM conseiller c
   WHERE c.num_conseiller = p_conseiller;

  IF p_parrain IS NOT NULL THEN
    SELECT REF(c) INTO v_ref_parrain
      FROM client c
     WHERE c.num_client = p_parrain;
  END IF;

  INSERT INTO client (num_client, nom, prenom, date_naissance, num_secu,
                      adresse, telephones, email, date_entree,
                      ref_conseiller, ref_parrain)
  VALUES (p_num, p_nom, p_prenom, p_naissance, p_secu,
          p_adresse, p_telephones, p_email, TRUNC(SYSDATE),
          v_ref_cons, v_ref_parrain);

  DBMS_OUTPUT.PUT_LINE('ajout_client : client '||p_num||' ajoute.');
EXCEPTION
  WHEN DUP_VAL_ON_INDEX THEN
    DBMS_OUTPUT.PUT_LINE('ajout_client : client '||p_num||' deja existant.');
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('ajout_client : conseiller ou parrain inexistant.');
END;
/
SHOW ERRORS PROCEDURE ajout_client

-- =====================================================================
-- D1.5 virement : virement atomique entre deux comptes courants
--      SAVEPOINT + ROLLBACK TO : les deux mouvements ou aucun.
--      La procedure ne fait pas COMMIT : l appelant valide ou annule.
--      Le debit est controle par les triggers (droits, decouvert, plafond).
-- =====================================================================
CREATE OR REPLACE PROCEDURE virement (
  cptsrc  IN VARCHAR2,
  cptdest IN VARCHAR2,
  montant IN NUMBER,
  cli     IN NUMBER
) IS
  v_ref_src  REF cptCourant_type;
  v_ref_dest REF cptCourant_type;
  v_ref_cli  REF client_type;
  v_ag_src   VARCHAR2(6);
  v_ag_dest  VARCHAR2(6);
  v_comm     NUMBER(12,2) := 0;
BEGIN
  SAVEPOINT av_virement;

  IF montant <= 0 THEN
    RAISE_APPLICATION_ERROR(-20020, 'Le montant doit etre strictement positif.');
  END IF;
  IF cptsrc = cptdest THEN
    RAISE_APPLICATION_ERROR(-20021, 'Comptes source et destination identiques.');
  END IF;

  SELECT REF(x) INTO v_ref_src
    FROM cpt_courant x WHERE x.num_compte = cptsrc;
  SELECT REF(x) INTO v_ref_dest
    FROM cpt_courant x WHERE x.num_compte = cptdest;
  SELECT REF(c) INTO v_ref_cli
    FROM client c WHERE c.num_client = cli;

  -- Regle de gestion : virement inter-agences = 1 % du montant, minimum 100 DA.
  SELECT x.ref_agence.code INTO v_ag_src
    FROM cpt_courant x WHERE x.num_compte = cptsrc;
  SELECT x.ref_agence.code INTO v_ag_dest
    FROM cpt_courant x WHERE x.num_compte = cptdest;
  IF v_ag_src <> v_ag_dest THEN
    v_comm := GREATEST(ROUND(montant * 0.01, 2), 100);
  END IF;

  -- Debit : montant negatif + commission prelevee sur le compte source.
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL, v_ref_cli, v_ref_src, TRUNC(SYSDATE),
          -montant, 'VIREMENT', v_comm);

  -- Credit : montant positif, sans commission sur le compte destination.
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL, v_ref_cli, v_ref_dest, TRUNC(SYSDATE),
          montant, 'VIREMENT', 0);

  DBMS_OUTPUT.PUT_LINE('virement OK : '||montant||' DA de '||cptsrc
                       ||' vers '||cptdest||' (commission='||v_comm||')');
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK TO av_virement;
    DBMS_OUTPUT.PUT_LINE('virement ANNULE : '||SQLERRM);
END;
/
SHOW ERRORS PROCEDURE virement

-- =====================================================================
-- D1.6 maj_statuts_dormants : bonus. Passe en DORMANT les comptes
--      courants sans operation depuis plus de 12 mois.
-- =====================================================================
CREATE OR REPLACE PROCEDURE maj_statuts_dormants IS
  v_nb NUMBER;
BEGIN
  UPDATE cpt_courant cc
     SET statut = 'DORMANT'
   WHERE statut = 'ACTIF'
     AND NOT EXISTS (SELECT 1 FROM operation o
                      WHERE o.ref_compte = REF(cc)
                        AND o.date_op > ADD_MONTHS(TRUNC(SYSDATE), -12));
  v_nb := SQL%ROWCOUNT;
  DBMS_OUTPUT.PUT_LINE('maj_statuts_dormants : '||v_nb
                       ||' compte(s) passe(s) DORMANT.');
END;
/
SHOW ERRORS PROCEDURE maj_statuts_dormants

-- =====================================================================
-- D1.7 scan_echeances : balayage des comptes a terme existants.
--      Utilise par le trigger trg_ct_echeance pour les lignes deja
--      presentes avant la creation du trigger. COMMIT volontaire.
-- =====================================================================
CREATE OR REPLACE PROCEDURE scan_echeances IS
  v_jours NUMBER;
  v_nb    NUMBER;
BEGIN
  FOR r IN (SELECT num_compte, date_echeance
              FROM cpt_terme
             ORDER BY num_compte) LOOP
    v_jours := TRUNC(r.date_echeance) - TRUNC(SYSDATE);

    IF v_jours < 0 THEN
      SELECT COUNT(*) INTO v_nb
        FROM alerte
       WHERE num_compte = r.num_compte
         AND type_alerte = 'ECHEANCE_DEPASSEE'
         AND traitee = 'N';
      IF v_nb = 0 THEN
        INSERT INTO alerte (id_alerte, type_alerte, num_compte,
                            message, date_alerte, traitee)
        VALUES (seq_alerte.NEXTVAL, 'ECHEANCE_DEPASSEE', r.num_compte,
                'Echeance du compte '||r.num_compte||' depassee de '
                ||(-v_jours)||' jour(s).', SYSDATE, 'N');
      END IF;

    ELSIF v_jours <= 8 THEN
      SELECT COUNT(*) INTO v_nb
        FROM alerte
       WHERE num_compte = r.num_compte
         AND type_alerte = 'ECHEANCE_PROCHE'
         AND traitee = 'N';
      IF v_nb = 0 THEN
        INSERT INTO alerte (id_alerte, type_alerte, num_compte,
                            message, date_alerte, traitee)
        VALUES (seq_alerte.NEXTVAL, 'ECHEANCE_PROCHE', r.num_compte,
                'Echeance du compte '||r.num_compte||' dans '
                ||v_jours||' jour(s).', SYSDATE, 'N');
      END IF;
    END IF;
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('scan_echeances : traitement termine.');
END;
/
SHOW ERRORS PROCEDURE scan_echeances

PROMPT *** Tests des sous-programmes catalogues ***
SELECT nb_comptes() AS nb_comptes FROM dual;
SELECT solde_total(1) AS solde_client_1 FROM dual;
SELECT solde_total(4) AS solde_client_4 FROM dual;
SELECT ville_client(1) AS ville_client_1 FROM dual;
SELECT ville_client(3) AS ville_client_3 FROM dual;

-- Test ajout_client avec le client 97 (supprime ensuite)
BEGIN
  ajout_client(97, 'TEST', 'Ajout', DATE '1990-01-01', '900101097',
               adresse_type(1, 'Rue du Test', 'Bejaia', '06000'),
               tel_vry_type('034-00-00-97', '0661-00-00-97'),
               'test.ajout@mail.dz', 1, 1);
  COMMIT;
END;
/
SELECT c.num_client, c.nom, c.prenom, c.adresse.ville AS ville,
       c.ref_conseiller.nom AS conseiller, c.ref_parrain.nom AS parrain
  FROM client c
 WHERE c.num_client = 97;

-- Deuxieme appel : doublon
BEGIN
  ajout_client(97, 'TEST', 'Doublon', DATE '1990-01-01', '900101097',
               adresse_type(1, 'Rue du Test', 'Bejaia', '06000'),
               tel_vry_type('034-00-00-97'), 'test.doublon@mail.dz', 1, NULL);
END;
/
DELETE FROM client WHERE num_client = 97;
COMMIT;

PROMPT ============================================================
PROMPT D7. BLOCS PL/SQL ANONYMES
PROMPT ============================================================

-- =====================================================================
-- D7a : deuxieme telephone (travail) du client 3
-- =====================================================================
DECLARE
  v_tel tel_vry_type;
BEGIN
  SELECT telephones INTO v_tel
    FROM client
   WHERE num_client = 3;

  IF v_tel IS NULL OR v_tel.COUNT < 2 THEN
    DBMS_OUTPUT.PUT_LINE('Client 3 : aucun deuxieme telephone (travail).');
  ELSIF v_tel(2) IS NULL THEN
    DBMS_OUTPUT.PUT_LINE('Client 3 : deuxieme telephone (travail) non renseigne.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Client 3 : telephone travail = '||v_tel(2));
  END IF;
END;
/

-- =====================================================================
-- D7b : meme information pour tous les titulaires d un compte courant
-- =====================================================================
DECLARE
  CURSOR c_clients IS
    SELECT c.num_client, c.nom, c.telephones
      FROM client c
     WHERE EXISTS (SELECT 1 FROM cpt_courant cc
                    WHERE cc.ref_client = REF(c))
     ORDER BY c.num_client;
  v_tel tel_vry_type;
BEGIN
  FOR r IN c_clients LOOP
    v_tel := r.telephones;
    IF v_tel IS NULL OR v_tel.COUNT < 2 THEN
      DBMS_OUTPUT.PUT_LINE(RPAD(r.num_client||' '||r.nom, 22)
                           ||': pas de deuxieme telephone');
    ELSIF v_tel(2) IS NULL THEN
      DBMS_OUTPUT.PUT_LINE(RPAD(r.num_client||' '||r.nom, 22)
                           ||': deuxieme telephone non renseigne');
    ELSE
      DBMS_OUTPUT.PUT_LINE(RPAD(r.num_client||' '||r.nom, 22)
                           ||': '||v_tel(2));
    END IF;
  END LOOP;
END;
/

-- =====================================================================
-- D7c : curseur parametre par un seuil de solde.
--       Traite NO_DATA_FOUND et l exception utilisateur aucun_compte.
-- =====================================================================
DECLARE
  e_aucun_compte EXCEPTION;
  CURSOR c_comptes (p_seuil NUMBER) IS
    SELECT cc.num_compte, cc.ref_client, cc.solde,
           (SELECT COUNT(*) FROM TABLE(cc.signataires)) AS nb_sig
      FROM cpt_courant cc
     WHERE cc.solde < p_seuil
     ORDER BY cc.num_compte;
  v_nom VARCHAR2(30);
  v_nb  NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('*** Seuil 100000 ***');
  FOR r IN c_comptes(100000) LOOP
    BEGIN
      SELECT c.nom INTO v_nom
        FROM client c
       WHERE REF(c) = r.ref_client;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_nom := '<titulaire inconnu>';
    END;
    DBMS_OUTPUT.PUT_LINE(RPAD(r.num_compte, 6)||' '
                         ||RPAD(v_nom, 14)
                         ||' solde='||r.solde
                         ||' signataires='||r.nb_sig);
    v_nb := v_nb + 1;
  END LOOP;
  IF v_nb = 0 THEN
    RAISE e_aucun_compte;
  END IF;

  DBMS_OUTPUT.PUT_LINE('*** Seuil -1000000 ***');
  v_nb := 0;
  FOR r IN c_comptes(-1000000) LOOP
    v_nb := v_nb + 1;
  END LOOP;
  IF v_nb = 0 THEN
    RAISE e_aucun_compte;
  END IF;
EXCEPTION
  WHEN e_aucun_compte THEN
    DBMS_OUTPUT.PUT_LINE('aucun_compte : aucun compte courant sous le seuil demande.');
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('NO_DATA_FOUND : donnee absente.');
END;
/

-- =====================================================================
-- D7d : ajout d un 3e telephone avec EXTEND, LIMIT, COUNT, LAST.
--       Un client temporaire 98 est cree avec 2 telephones, puis
--       supprime a la fin du test.
-- =====================================================================
DELETE FROM client WHERE num_client = 98;
INSERT INTO client (num_client, nom, prenom, date_naissance, num_secu,
                    adresse, telephones, email, date_entree,
                    ref_conseiller, ref_parrain)
VALUES (98, 'TEST', 'Varray', DATE '1990-01-01', '900101098',
        adresse_type(1, 'Rue du Test', 'Bejaia', '06000'),
        tel_vry_type('034-00-00-01', '0661-00-00-02'),
        'test.varray@mail.dz', TRUNC(SYSDATE),
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 1), NULL);
COMMIT;

DECLARE
  v_tel tel_vry_type;
BEGIN
  SELECT telephones INTO v_tel
    FROM client
   WHERE num_client = 98;

  DBMS_OUTPUT.PUT_LINE('Avant : COUNT='||v_tel.COUNT
                       ||' LIMIT='||v_tel.LIMIT
                       ||' LAST='||v_tel.LAST);

  FOR i IN 1..2 LOOP
    IF v_tel.COUNT >= v_tel.LIMIT THEN
      DBMS_OUTPUT.PUT_LINE('Ajout '||i||' refuse : limite de '
                           ||v_tel.LIMIT||' atteinte.');
    ELSE
      v_tel.EXTEND(1);
      v_tel(v_tel.LAST) := '0770-98-98-0'||i;
      DBMS_OUTPUT.PUT_LINE('Ajout '||i||' : COUNT='||v_tel.COUNT
                           ||' LAST='||v_tel.LAST
                           ||' valeur='||v_tel(v_tel.LAST));
    END IF;
  END LOOP;

  UPDATE client SET telephones = v_tel WHERE num_client = 98;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Apres : COUNT='||v_tel.COUNT);
END;
/

SELECT t.COLUMN_VALUE AS telephone
  FROM TABLE (SELECT telephones FROM client WHERE num_client = 98) t;

DELETE FROM client WHERE num_client = 98;
COMMIT;

-- =====================================================================
-- D7e : total des interets annuels des comptes d epargne de l agence A1
-- =====================================================================
DECLARE
  CURSOR c_epargne (p_agence VARCHAR2) IS
    SELECT ce.num_compte, ce.solde, ce.taux_interet
      FROM cpt_epargne ce, agence a
     WHERE ce.ref_agence = REF(a)
       AND a.code = p_agence
     ORDER BY ce.num_compte;
  v_interet NUMBER;
  v_total   NUMBER := 0;
BEGIN
  DBMS_OUTPUT.PUT_LINE('Interets annuels des comptes d epargne de A1 :');
  FOR r IN c_epargne('A1') LOOP
    v_interet := ROUND(r.solde * r.taux_interet / 100, 2);
    DBMS_OUTPUT.PUT_LINE('  '||r.num_compte
                         ||' : solde='||r.solde
                         ||' taux='||r.taux_interet||'%'
                         ||' interet='||v_interet);
    v_total := v_total + v_interet;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('  TOTAL ANNUEL = '||v_total);
END;
/

PROMPT ============================================================
PROMPT D8. METHODES DES TYPES OBJET - ALTER TYPE ... ADD MEMBER
PROMPT ============================================================
-- Chaque ALTER TYPE est protege contre ORA-22324 (membre deja present)
-- afin que le script puisse etre rejoue sans regenerer la partie A.
-- Un seul membre par instruction : Oracle n accepte pas plusieurs
-- ADD MEMBER dans un meme ALTER TYPE.

DECLARE
  TYPE t_sql IS TABLE OF VARCHAR2(400);
  v_sql t_sql := t_sql(
    'ALTER TYPE client_type ADD MEMBER FUNCTION nbCepargne RETURN NUMBER CASCADE',
    'ALTER TYPE client_type ADD MEMBER FUNCTION soldeTotal RETURN NUMBER CASCADE',
    'ALTER TYPE client_type ADD MEMBER PROCEDURE supprimeTel(indice IN NUMBER) CASCADE',
    'ALTER TYPE client_type ADD MEMBER PROCEDURE afficheInterets CASCADE',
    'ALTER TYPE cptCourant_type ADD MEMBER FUNCTION nbSignataire RETURN NUMBER CASCADE',
    'ALTER TYPE cptCourant_type ADD MEMBER FUNCTION nbSignataire(droitparam IN CHAR) RETURN NUMBER CASCADE',
    'ALTER TYPE cptCourant_type ADD MEMBER FUNCTION estTitulaire(cli IN NUMBER) RETURN BOOLEAN CASCADE',
    'ALTER TYPE cptCourant_type ADD MEMBER FUNCTION estSignataire(cli IN NUMBER, droitparam IN CHAR) RETURN BOOLEAN CASCADE',
    'ALTER TYPE cptCourant_type ADD MEMBER PROCEDURE supprimeSign(nclient IN NUMBER) CASCADE',
    'ALTER TYPE cptCourant_type ADD MEMBER PROCEDURE passeMvt(cli IN NUMBER, somme IN NUMBER) CASCADE',
    'ALTER TYPE cptCourant_type ADD MEMBER FUNCTION peutRetirer(cli IN NUMBER, somme IN NUMBER) RETURN BOOLEAN CASCADE',
    'ALTER TYPE cptEpargne_type ADD MEMBER FUNCTION calculeInterets RETURN NUMBER CASCADE',
    'ALTER TYPE cptEpargne_type ADD MEMBER FUNCTION sortieAnticipee RETURN NUMBER CASCADE',
    'ALTER TYPE cptTerme_type ADD MEMBER FUNCTION calculeInterets RETURN NUMBER CASCADE',
    'ALTER TYPE cptTerme_type ADD MEMBER FUNCTION sortieAnticipee RETURN NUMBER CASCADE',
    'ALTER TYPE compte_type ADD STATIC PROCEDURE fermeCompte(cpt IN VARCHAR2) CASCADE'
  );
BEGIN
  FOR i IN 1..v_sql.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE v_sql(i);
      DBMS_OUTPUT.PUT_LINE('OK   : '||v_sql(i));
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -22324 THEN
          DBMS_OUTPUT.PUT_LINE('DEJA : '||v_sql(i));
        ELSE
          DBMS_OUTPUT.PUT_LINE('ERREUR '||SQLCODE||' : '||v_sql(i));
          RAISE;
        END IF;
    END;
  END LOOP;
END;
/

PROMPT *** Etat des types apres ALTER (les corps sont INVALID) ***
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_type IN ('TYPE', 'TYPE BODY')
 ORDER BY object_type, object_name;

PROMPT ============================================================
PROMPT D8. CORPS DES TYPES (CREATE OR REPLACE TYPE BODY)
PROMPT ============================================================

-- =====================================================================
-- D8.0 compte_type : fraisTenue + STATIC fermeCompte
-- =====================================================================
CREATE OR REPLACE TYPE BODY compte_type AS
  MEMBER FUNCTION fraisTenue RETURN NUMBER IS
  BEGIN
    RETURN 500;
  END;

  STATIC PROCEDURE fermeCompte (cpt IN VARCHAR2) IS
    v_nb    NUMBER;
    v_solde NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_nb
      FROM cpt_courant WHERE num_compte = cpt;

    IF v_nb > 0 THEN
      SELECT solde INTO v_solde
        FROM cpt_courant WHERE num_compte = cpt;
      DBMS_OUTPUT.PUT_LINE('fermeCompte : compte courant '||cpt
                           ||' - solde avant = '||v_solde);
      DELETE FROM operation
       WHERE ref_compte = (SELECT REF(x) FROM cpt_courant x
                            WHERE x.num_compte = cpt);
      DELETE FROM cpt_courant WHERE num_compte = cpt;

    ELSE
      SELECT COUNT(*) INTO v_nb
        FROM cpt_epargne WHERE num_compte = cpt;
      IF v_nb > 0 THEN
        SELECT solde INTO v_solde
          FROM cpt_epargne WHERE num_compte = cpt;
        DBMS_OUTPUT.PUT_LINE('fermeCompte : compte epargne '||cpt
                             ||' - solde avant = '||v_solde);
        DELETE FROM cpt_epargne WHERE num_compte = cpt;

      ELSE
        SELECT COUNT(*) INTO v_nb
          FROM cpt_terme WHERE num_compte = cpt;
        IF v_nb > 0 THEN
          SELECT solde INTO v_solde
            FROM cpt_terme WHERE num_compte = cpt;
          DBMS_OUTPUT.PUT_LINE('fermeCompte : compte a terme '||cpt
                               ||' - solde avant = '||v_solde);
          DELETE FROM cpt_terme WHERE num_compte = cpt;
        ELSE
          RAISE NO_DATA_FOUND;
        END IF;
      END IF;
    END IF;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('fermeCompte : compte '||cpt||' ferme (COMMIT).');
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('fermeCompte : compte '||cpt||' inexistant.');
      ROLLBACK;
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('fermeCompte : echec ('||SQLERRM||'), ROLLBACK.');
      ROLLBACK;
  END;
END;
/
SHOW ERRORS TYPE BODY compte_type

-- =====================================================================
-- D8.l cptEpargne_type : calculeInterets + sortieAnticipee
-- =====================================================================
CREATE OR REPLACE TYPE BODY cptEpargne_type AS
  OVERRIDING MEMBER FUNCTION fraisTenue RETURN NUMBER IS
  BEGIN
    RETURN 0;
  END;

  MEMBER FUNCTION calculeInterets RETURN NUMBER IS
  BEGIN
    RETURN ROUND(SELF.solde * (1 + SELF.taux_interet / 100), 2);
  END;

  MEMBER FUNCTION sortieAnticipee RETURN NUMBER IS
  BEGIN
    RETURN ROUND(SELF.solde * 0.95, 2);
  END;
END;
/
SHOW ERRORS TYPE BODY cptEpargne_type

-- =====================================================================
-- D8.l cptTerme_type : calculeInterets (duree en mois) + sortieAnticipee
-- =====================================================================
CREATE OR REPLACE TYPE BODY cptTerme_type AS
  OVERRIDING MEMBER FUNCTION fraisTenue RETURN NUMBER IS
  BEGIN
    RETURN 0;
  END;

  MEMBER FUNCTION calculeInterets RETURN NUMBER IS
  BEGIN
    RETURN ROUND(SELF.solde
                 * (1 + (SELF.taux_garanti / 100) * (SELF.duree_mois / 12)),
                 2);
  END;

  MEMBER FUNCTION sortieAnticipee RETURN NUMBER IS
  BEGIN
    RETURN ROUND(SELF.solde * 0.95, 2);
  END;
END;
/
SHOW ERRORS TYPE BODY cptTerme_type

-- =====================================================================
-- D8.e a D8.k cptCourant_type
-- =====================================================================
CREATE OR REPLACE TYPE BODY cptCourant_type AS
  OVERRIDING MEMBER FUNCTION fraisTenue RETURN NUMBER IS
  BEGIN
    RETURN 1200;
  END;

  -- D8e : nombre de signataires
  MEMBER FUNCTION nbSignataire RETURN NUMBER IS
  BEGIN
    RETURN SELF.signataires.COUNT;
  END;

  -- D8e : surcharge sur le droit
  MEMBER FUNCTION nbSignataire (droitparam IN CHAR) RETURN NUMBER IS
    v_nb NUMBER := 0;
  BEGIN
    FOR i IN 1..SELF.signataires.COUNT LOOP
      IF SELF.signataires(i).droit = droitparam THEN
        v_nb := v_nb + 1;
      END IF;
    END LOOP;
    RETURN v_nb;
  END;

  -- D8f : titulaire du compte
  MEMBER FUNCTION estTitulaire (cli IN NUMBER) RETURN BOOLEAN IS
    v_ref REF client_type;
    v_nb  NUMBER;
  BEGIN
    v_ref := SELF.ref_client;
    SELECT COUNT(*) INTO v_nb
      FROM client c
     WHERE c.num_client = cli
       AND REF(c) = v_ref;
    RETURN v_nb > 0;
  END;

  -- D8g : signataire avec un droit donne
  MEMBER FUNCTION estSignataire (cli IN NUMBER, droitparam IN CHAR)
    RETURN BOOLEAN IS
    v_ref REF client_type;
  BEGIN
    SELECT REF(c) INTO v_ref
      FROM client c
     WHERE c.num_client = cli;

    FOR i IN 1..SELF.signataires.COUNT LOOP
      IF SELF.signataires(i).ref_client = v_ref
         AND SELF.signataires(i).droit = droitparam THEN
        RETURN TRUE;
      END IF;
    END LOOP;
    RETURN FALSE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN FALSE;
  END;

  -- D8h : suppression d un signataire
  MEMBER PROCEDURE supprimeSign (nclient IN NUMBER) IS
    v_ref   REF client_type;
    v_new   signataire_nt_type := signataire_nt_type();
    v_trouve BOOLEAN := FALSE;
  BEGIN
    SELECT REF(c) INTO v_ref
      FROM client c
     WHERE c.num_client = nclient;

    FOR i IN 1..SELF.signataires.COUNT LOOP
      IF SELF.signataires(i).ref_client = v_ref THEN
        v_trouve := TRUE;
      ELSE
        v_new.EXTEND;
        v_new(v_new.LAST) := SELF.signataires(i);
      END IF;
    END LOOP;

    IF v_trouve THEN
      UPDATE cpt_courant
         SET signataires = v_new
       WHERE num_compte = SELF.num_compte;
      DBMS_OUTPUT.PUT_LINE('supprimeSign : client '||nclient
                           ||' retire du compte '||SELF.num_compte);
    ELSE
      DBMS_OUTPUT.PUT_LINE('supprimeSign : client '||nclient
                           ||' absent du compte '||SELF.num_compte);
    END IF;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('supprimeSign : client '||nclient||' inexistant.');
  END;

  -- D8j : peutRetirer, reutilisee par passeMvt
  MEMBER FUNCTION peutRetirer (cli IN NUMBER, somme IN NUMBER)
    RETURN BOOLEAN IS
    v_statut    VARCHAR2(10);
    v_solde     NUMBER;
    v_decouvert NUMBER;
    v_retraits  NUMBER;
  BEGIN
    SELECT statut, solde, decouvert
      INTO v_statut, v_solde, v_decouvert
      FROM cpt_courant
     WHERE num_compte = SELF.num_compte;

    IF v_statut <> 'ACTIF' THEN
      RETURN FALSE;
    END IF;
    IF somme >= 0 THEN
      RETURN TRUE;
    END IF;

    IF NOT estTitulaire(cli)
       AND NOT estSignataire(cli, 'D')
       AND NOT estSignataire(cli, 'X') THEN
      RETURN FALSE;
    END IF;

    IF v_solde + somme < -NVL(v_decouvert, 0) THEN
      RETURN FALSE;
    END IF;

    SELECT NVL(SUM(-o.montant), 0) INTO v_retraits
      FROM operation o
     WHERE o.ref_compte = (SELECT REF(x) FROM cpt_courant x
                            WHERE x.num_compte = SELF.num_compte)
       AND o.montant < 0
       AND o.date_op >= TRUNC(SYSDATE);

    IF v_retraits - somme > 200000 THEN
      RETURN FALSE;
    END IF;

    RETURN TRUE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN FALSE;
  END;

  -- D8i : debit ou credit a la date du jour
  MEMBER PROCEDURE passeMvt (cli IN NUMBER, somme IN NUMBER) IS
    v_ref_client REF client_type;
    v_ref_compte REF cptCourant_type;
    v_num        VARCHAR2(10);
    e_ref_null   EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_ref_null, -1400);
    e_check_null EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_check_null, -2290);
    e_refus      EXCEPTION;
  BEGIN
    IF somme = 0 THEN
      -- Code distinct de ORA-20010 (mutation) pour eviter toute ambiguite.
      RAISE_APPLICATION_ERROR(-20030, 'Montant nul interdit.');
    END IF;

    v_num := SELF.num_compte;

    SELECT REF(c) INTO v_ref_client
      FROM client c
     WHERE c.num_client = cli;
    SELECT REF(x) INTO v_ref_compte
      FROM cpt_courant x
     WHERE x.num_compte = v_num;

    IF NOT peutRetirer(cli, somme) THEN
      RAISE e_refus;
    END IF;

    INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                           montant, type_op, commission)
    VALUES (seq_operation.NEXTVAL, v_ref_client, v_ref_compte,
            TRUNC(SYSDATE), somme,
            CASE WHEN somme < 0 THEN 'RETRAIT' ELSE 'DEPOT' END, 0);

    UPDATE cpt_courant
       SET solde = (SELECT NVL(SUM(o.montant - o.commission), 0)
                      FROM operation o
                     WHERE o.ref_compte = v_ref_compte)
     WHERE num_compte = v_num;

    DBMS_OUTPUT.PUT_LINE('passeMvt OK : compte '||v_num
                         ||' montant '||somme);
  EXCEPTION
    WHEN e_refus THEN
      DBMS_OUTPUT.PUT_LINE('passeMvt REFUS : droits, decouvert ou plafond journalier insuffisant.');
    WHEN e_ref_null OR e_check_null THEN
      DBMS_OUTPUT.PUT_LINE('passeMvt : violation NOT NULL sur la reference client.');
    WHEN NO_DATA_FOUND THEN
      DBMS_OUTPUT.PUT_LINE('passeMvt : client '||cli||' ou compte inexistant.');
  END;
END;
/
SHOW ERRORS TYPE BODY cptCourant_type

-- =====================================================================
-- D8.a a D8.d client_type
-- =====================================================================
CREATE OR REPLACE TYPE BODY client_type AS
  -- D8a : nombre de comptes d epargne
  MEMBER FUNCTION nbCepargne RETURN NUMBER IS
    v_nb NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_nb
      FROM cpt_epargne e
     WHERE e.ref_client = (SELECT REF(c) FROM client c
                            WHERE c.num_client = SELF.num_client);
    RETURN v_nb;
  END;

  -- D8b : solde total de tous les comptes
  MEMBER FUNCTION soldeTotal RETURN NUMBER IS
    v_total NUMBER;
  BEGIN
    SELECT NVL((SELECT SUM(solde) FROM cpt_courant x
                 WHERE x.ref_client = (SELECT REF(c) FROM client c
                                        WHERE c.num_client = SELF.num_client)), 0)
         + NVL((SELECT SUM(solde) FROM cpt_epargne x
                 WHERE x.ref_client = (SELECT REF(c) FROM client c
                                        WHERE c.num_client = SELF.num_client)), 0)
         + NVL((SELECT SUM(solde) FROM cpt_terme x
                 WHERE x.ref_client = (SELECT REF(c) FROM client c
                                        WHERE c.num_client = SELF.num_client)), 0)
      INTO v_total
      FROM dual;
    RETURN v_total;
  END;

  -- D8c : suppression du telephone d indice donne
  MEMBER PROCEDURE supprimeTel (indice IN NUMBER) IS
    v_tel tel_vry_type;
  BEGIN
    v_tel := SELF.telephones;

    IF v_tel IS NULL OR v_tel.COUNT = 0 THEN
      DBMS_OUTPUT.PUT_LINE('supprimeTel : aucun telephone pour le client '
                           ||SELF.num_client);
      RETURN;
    END IF;
    IF indice < 1 OR indice > v_tel.COUNT THEN
      DBMS_OUTPUT.PUT_LINE('supprimeTel : aucun telephone a l indice '
                           ||indice||'.');
      RETURN;
    END IF;
    IF v_tel(indice) IS NULL THEN
      DBMS_OUTPUT.PUT_LINE('supprimeTel : telephone a l indice '
                           ||indice||' non renseigne.');
      RETURN;
    END IF;

    FOR i IN indice..v_tel.COUNT-1 LOOP
      v_tel(i) := v_tel(i+1);
    END LOOP;
    v_tel.TRIM(1);

    UPDATE client SET telephones = v_tel WHERE num_client = SELF.num_client;
    DBMS_OUTPUT.PUT_LINE('supprimeTel : indice '||indice
                         ||' supprime, COUNT='||v_tel.COUNT);
  END;

  -- D8d : interets cumules du client avec calculeInterets
  MEMBER PROCEDURE afficheInterets IS
    v_ce       cptEpargne_type;
    v_interet  NUMBER;
    v_total    NUMBER := 0;
  BEGIN
    DBMS_OUTPUT.PUT_LINE('Interets annuels du client '||SELF.num_client||' :');
    FOR r IN (SELECT e.num_compte
                FROM cpt_epargne e
               WHERE e.ref_client = (SELECT REF(c) FROM client c
                                      WHERE c.num_client = SELF.num_client)
               ORDER BY e.num_compte) LOOP
      SELECT VALUE(e) INTO v_ce
        FROM cpt_epargne e
       WHERE e.num_compte = r.num_compte;
      v_interet := v_ce.calculeInterets() - v_ce.solde;
      DBMS_OUTPUT.PUT_LINE('  '||r.num_compte||' : '||v_interet);
      v_total := v_total + v_interet;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('  TOTAL = '||v_total);
  END;
END;
/
SHOW ERRORS TYPE BODY client_type

PROMPT *** Etat des types apres creation des corps ***
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_type IN ('TYPE', 'TYPE BODY')
 ORDER BY object_type, object_name;

PROMPT ============================================================
PROMPT D8. TESTS DES METHODES DANS DES REQUETES SQL
PROMPT ============================================================

PROMPT *** nbCepargne ***
SELECT c.num_client, c.nom, c.nbCepargne() AS nb_epargne
  FROM client c
 ORDER BY c.num_client;

PROMPT *** soldeTotal ***
SELECT c.num_client, c.nom, c.soldeTotal() AS solde_total
  FROM client c
 ORDER BY c.num_client;

PROMPT *** nbSignataire() et nbSignataire(droit) ***
COLUMN num_compte FORMAT A10
SELECT cc.num_compte,
       cc.nbSignataire()    AS total,
       cc.nbSignataire('D') AS droit_d,
       cc.nbSignataire('R') AS droit_r,
       cc.nbSignataire('X') AS droit_x
  FROM cpt_courant cc
 ORDER BY cc.num_compte;

PROMPT *** calculeInterets et sortieAnticipee des comptes d epargne ***
SELECT ce.num_compte, ce.solde, ce.taux_interet,
       ce.calculeInterets()  AS avec_interets,
       ce.sortieAnticipee()  AS sortie_anticipee
  FROM cpt_epargne ce
 ORDER BY ce.num_compte;

PROMPT *** calculeInterets et sortieAnticipee des comptes a terme ***
SELECT ct.num_compte, ct.solde, ct.duree_mois, ct.taux_garanti,
       ct.calculeInterets()  AS avec_interets,
       ct.sortieAnticipee()  AS sortie_anticipee
  FROM cpt_terme ct
 ORDER BY ct.num_compte;

PROMPT *** fraisTenue : polymorphisme ***
SELECT 'COURANT' AS type_compte, cc.num_compte, cc.fraisTenue() AS frais
  FROM cpt_courant cc
UNION ALL
SELECT 'EPARGNE', ce.num_compte, ce.fraisTenue()
  FROM cpt_epargne ce
UNION ALL
SELECT 'TERME', ct.num_compte, ct.fraisTenue()
  FROM cpt_terme ct
 ORDER BY 1, 2;

PROMPT ============================================================
PROMPT D8. TESTS DES METHODES DANS DES BLOCS PL/SQL (VALUE)
PROMPT ============================================================

PROMPT *** VALUE + nbCepargne + soldeTotal + afficheInterets ***
DECLARE
  v_client client_type;
BEGIN
  SELECT VALUE(c) INTO v_client
    FROM client c
   WHERE c.num_client = 1;

  DBMS_OUTPUT.PUT_LINE('Client 1 : nbCepargne = '||v_client.nbCepargne());
  DBMS_OUTPUT.PUT_LINE('Client 1 : soldeTotal = '||v_client.soldeTotal());
  v_client.afficheInterets();
END;
/

PROMPT *** estTitulaire et estSignataire (BOOLEAN : PL/SQL seulement) ***
DECLARE
  v_cc cptCourant_type;
BEGIN
  SELECT VALUE(cc) INTO v_cc
    FROM cpt_courant cc
   WHERE cc.num_compte = 'CC7';

  DBMS_OUTPUT.PUT_LINE('CC7 estTitulaire(4)      = '
    ||CASE WHEN v_cc.estTitulaire(4) THEN 'TRUE' ELSE 'FALSE' END);
  DBMS_OUTPUT.PUT_LINE('CC7 estTitulaire(1)      = '
    ||CASE WHEN v_cc.estTitulaire(1) THEN 'TRUE' ELSE 'FALSE' END);
  DBMS_OUTPUT.PUT_LINE('CC7 estSignataire(2,D)   = '
    ||CASE WHEN v_cc.estSignataire(2,'D') THEN 'TRUE' ELSE 'FALSE' END);
  DBMS_OUTPUT.PUT_LINE('CC7 estSignataire(5,R)   = '
    ||CASE WHEN v_cc.estSignataire(5,'R') THEN 'TRUE' ELSE 'FALSE' END);
  DBMS_OUTPUT.PUT_LINE('CC7 estSignataire(5,D)   = '
    ||CASE WHEN v_cc.estSignataire(5,'D') THEN 'TRUE' ELSE 'FALSE' END);
  DBMS_OUTPUT.PUT_LINE('CC7 peutRetirer(4,-1000) = '
    ||CASE WHEN v_cc.peutRetirer(4,-1000) THEN 'TRUE' ELSE 'FALSE' END);
  DBMS_OUTPUT.PUT_LINE('CC7 peutRetirer(5,-1000) = '
    ||CASE WHEN v_cc.peutRetirer(5,-1000) THEN 'TRUE' ELSE 'FALSE' END);
  DBMS_OUTPUT.PUT_LINE('CC7 peutRetirer(6,-1000) = '
    ||CASE WHEN v_cc.peutRetirer(6,-1000) THEN 'TRUE' ELSE 'FALSE' END);
  DBMS_OUTPUT.PUT_LINE('CC7 peutRetirer(4,-300000) = '
    ||CASE WHEN v_cc.peutRetirer(4,-300000) THEN 'TRUE' ELSE 'FALSE' END);
END;
/

PROMPT *** supprimeTel sur le client 4 (puis restauration) ***
DECLARE
  v_client client_type;
  v_tel    tel_vry_type;
BEGIN
  SELECT VALUE(c) INTO v_client
    FROM client c WHERE c.num_client = 4;
  v_client.supprimeTel(2);

  SELECT telephones INTO v_tel
    FROM client WHERE num_client = 4;
  DBMS_OUTPUT.PUT_LINE('Apres supprimeTel : COUNT='||v_tel.COUNT);

  -- Cas d erreur : indice absent
  v_client.supprimeTel(9);
END;
/

SELECT t.COLUMN_VALUE AS telephone
  FROM TABLE (SELECT telephones FROM client WHERE num_client = 4) t;

-- Restauration du VARRAY initial du client 4
UPDATE client
   SET telephones = tel_vry_type('034-98-76-54', '0662-33-44-55',
                                 '0771-22-33-44')
 WHERE num_client = 4;
COMMIT;

PROMPT *** supprimeTel sur le client 5 (un seul element) ***
DECLARE
  v_client client_type;
BEGIN
  SELECT VALUE(c) INTO v_client
    FROM client c WHERE c.num_client = 5;
  v_client.supprimeTel(2);
END;
/

PROMPT *** supprimeSign : retrait du signataire 2 de CC7, puis restauration ***
DECLARE
  v_cc cptCourant_type;
BEGIN
  SELECT VALUE(cc) INTO v_cc
    FROM cpt_courant cc WHERE cc.num_compte = 'CC7';
  DBMS_OUTPUT.PUT_LINE('CC7 avant : '||v_cc.nbSignataire()||' signataires');
  v_cc.supprimeSign(2);
  v_cc.supprimeSign(999);
END;
/

SELECT cc.num_compte, cc.nbSignataire() AS nb_signataires
  FROM cpt_courant cc
 WHERE cc.num_compte = 'CC7';

-- Restauration : le client 2 redevient signataire de droit D de CC7
INSERT INTO TABLE (SELECT signataires FROM cpt_courant
                    WHERE num_compte = 'CC7')
SELECT signataire_elt_nt_type(REF(c), 'D')
  FROM client c
 WHERE c.num_client = 2;
COMMIT;

SELECT cc.num_compte, cc.nbSignataire() AS nb_signataires
  FROM cpt_courant cc
 WHERE cc.num_compte = 'CC7';

PROMPT *** maj_statuts_dormants (test avec ROLLBACK) ***
BEGIN
  maj_statuts_dormants();
  ROLLBACK;
END;
/

PROMPT ============================================================
PROMPT D9. TRIGGERS
PROMPT ============================================================

-- =====================================================================
-- D9.1 trg_op_avant : controle BEFORE INSERT sur operation.
--      Trigger COMPOUND pour eviter ORA-04091 (table en mutation) :
--        BEFORE STATEMENT : photographie des retraits du jour
--        BEFORE EACH ROW  : statut, droits, plafond, decouvert
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_op_avant
FOR INSERT ON operation
COMPOUND TRIGGER
  c_plafond CONSTANT NUMBER := 200000;
  TYPE t_retraits IS TABLE OF NUMBER INDEX BY VARCHAR2(10);
  v_retraits t_retraits;
  v_num      VARCHAR2(10);
  v_statut   VARCHAR2(10);
  v_solde    NUMBER;
  v_decouvert NUMBER;
  v_nb       NUMBER;
  v_cumul    NUMBER;

  BEFORE STATEMENT IS
  BEGIN
    FOR r IN (SELECT cc.num_compte, SUM(-o.montant) AS total
                FROM operation o, cpt_courant cc
               WHERE o.ref_compte = REF(cc)
                 AND o.montant < 0
                 AND o.date_op >= TRUNC(SYSDATE)
               GROUP BY cc.num_compte) LOOP
      v_retraits(r.num_compte) := r.total;
    END LOOP;
  END BEFORE STATEMENT;

  BEFORE EACH ROW IS
  BEGIN
    SELECT x.num_compte, x.statut, x.solde, x.decouvert
      INTO v_num, v_statut, v_solde, v_decouvert
      FROM cpt_courant x
     WHERE REF(x) = :NEW.ref_compte;

    IF v_statut <> 'ACTIF' THEN
      RAISE_APPLICATION_ERROR(-20001, 'Compte '||v_num||' non actif (statut '
                              ||v_statut||') : operation refusee.');
    END IF;

    IF :NEW.montant < 0 THEN
      -- Droits : titulaire ou signataire D/X
      SELECT COUNT(*) INTO v_nb
        FROM cpt_courant x
       WHERE REF(x) = :NEW.ref_compte
         AND x.ref_client = :NEW.ref_client;

      IF v_nb = 0 THEN
        SELECT COUNT(*) INTO v_nb
          FROM cpt_courant x, TABLE(x.signataires) s
         WHERE REF(x) = :NEW.ref_compte
           AND s.ref_client = :NEW.ref_client
           AND s.droit IN ('D', 'X');
        IF v_nb = 0 THEN
          RAISE_APPLICATION_ERROR(-20002, 'Client sans droit de debit sur le compte '
                                  ||v_num||'.');
        END IF;
      END IF;

      -- Plafond journalier de retrait
      v_cumul := CASE WHEN v_retraits.EXISTS(v_num)
                      THEN v_retraits(v_num) ELSE 0 END;
      IF v_cumul - :NEW.montant > c_plafond THEN
        RAISE_APPLICATION_ERROR(-20003, 'Plafond journalier de retrait (200000 DA) depasse sur '
                                ||v_num||'.');
      END IF;
      v_retraits(v_num) := v_cumul - :NEW.montant;

      -- Decouvert autorise
      IF v_solde + :NEW.montant - :NEW.commission < -NVL(v_decouvert, 0) THEN
        RAISE_APPLICATION_ERROR(-20004, 'Decouvert autorise depasse sur '
                                ||v_num||'.');
      END IF;
    END IF;
  END BEFORE EACH ROW;
END;
/
SHOW ERRORS TRIGGER trg_op_avant

-- =====================================================================
-- D9.2 trg_op_apres : mise a jour du solde et du compteur CB,
--      puis alertes SOLDE_NEGATIF et OPERATION_SUSPECTE.
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_op_apres
AFTER INSERT ON operation
FOR EACH ROW
DECLARE
  v_num         VARCHAR2(10);
  v_solde_avant NUMBER;
  v_solde_apres NUMBER;
  v_nom         VARCHAR2(30);
BEGIN
  SELECT x.num_compte, x.solde
    INTO v_num, v_solde_avant
    FROM cpt_courant x
   WHERE REF(x) = :NEW.ref_compte;

  v_solde_apres := v_solde_avant + :NEW.montant - :NEW.commission;

  UPDATE cpt_courant
     SET solde = v_solde_apres,
         nb_op_cb = NVL(nb_op_cb, 0)
                    + CASE WHEN :NEW.type_op = 'CB' THEN 1 ELSE 0 END
   WHERE num_compte = v_num;

  SELECT c.nom INTO v_nom
    FROM client c
   WHERE REF(c) = :NEW.ref_client;

  IF v_solde_avant >= 0 AND v_solde_apres < 0 THEN
    INSERT INTO alerte (id_alerte, type_alerte, num_compte,
                        message, date_alerte, traitee)
    VALUES (seq_alerte.NEXTVAL, 'SOLDE_NEGATIF', v_num,
            'Le compte '||v_num||' de '||v_nom
            ||' passe en solde negatif ('||v_solde_apres||' DA).',
            SYSDATE, 'N');
  END IF;

  IF :NEW.montant > 1000000 THEN
    INSERT INTO alerte (id_alerte, type_alerte, num_compte,
                        message, date_alerte, traitee)
    VALUES (seq_alerte.NEXTVAL, 'OPERATION_SUSPECTE', v_num,
            'Operation de '||:NEW.montant||' DA (> 1000000) par '
            ||v_nom||'.', SYSDATE, 'N');
  END IF;
END;
/
SHOW ERRORS TRIGGER trg_op_apres

-- =====================================================================
-- D9.3 trg_ct_echeance : alerte a l approche (<= 8 jours) ou au
--      depassement de l echeance d un compte a terme.
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_ct_echeance
AFTER INSERT OR UPDATE OF date_echeance ON cpt_terme
FOR EACH ROW
DECLARE
  v_jours NUMBER;
  v_nb    NUMBER;
BEGIN
  v_jours := TRUNC(:NEW.date_echeance) - TRUNC(SYSDATE);

  IF v_jours < 0 THEN
    SELECT COUNT(*) INTO v_nb
      FROM alerte
     WHERE num_compte = :NEW.num_compte
       AND type_alerte = 'ECHEANCE_DEPASSEE'
       AND traitee = 'N';
    IF v_nb = 0 THEN
      INSERT INTO alerte (id_alerte, type_alerte, num_compte,
                          message, date_alerte, traitee)
      VALUES (seq_alerte.NEXTVAL, 'ECHEANCE_DEPASSEE', :NEW.num_compte,
              'Echeance du compte '||:NEW.num_compte||' depassee de '
              ||(-v_jours)||' jour(s).', SYSDATE, 'N');
    END IF;

  ELSIF v_jours <= 8 THEN
    SELECT COUNT(*) INTO v_nb
      FROM alerte
     WHERE num_compte = :NEW.num_compte
       AND type_alerte = 'ECHEANCE_PROCHE'
       AND traitee = 'N';
    IF v_nb = 0 THEN
      INSERT INTO alerte (id_alerte, type_alerte, num_compte,
                          message, date_alerte, traitee)
      VALUES (seq_alerte.NEXTVAL, 'ECHEANCE_PROCHE', :NEW.num_compte,
              'Echeance du compte '||:NEW.num_compte||' dans '
              ||v_jours||' jour(s).', SYSDATE, 'N');
    END IF;
  END IF;
END;
/
SHOW ERRORS TRIGGER trg_ct_echeance

-- =====================================================================
-- D9.4 Audit du taux d interet des comptes d epargne
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_audit_taux
AFTER UPDATE OF taux_interet ON cpt_epargne
FOR EACH ROW
BEGIN
  INSERT INTO "AUDIT" (id_audit, nom_table, nom_colonne, num_compte,
                       ancienne_valeur, nouvelle_valeur, date_modif,
                       utilisateur)
  VALUES (seq_audit.NEXTVAL, 'CPT_EPARGNE', 'TAUX_INTERET',
          :OLD.num_compte, :OLD.taux_interet, :NEW.taux_interet,
          SYSDATE, USER);
END;
/
SHOW ERRORS TRIGGER trg_audit_taux

-- =====================================================================
-- D9.5 Audit du taux garanti des comptes a terme
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_audit_taux_terme
AFTER UPDATE OF taux_garanti ON cpt_terme
FOR EACH ROW
BEGIN
  INSERT INTO "AUDIT" (id_audit, nom_table, nom_colonne, num_compte,
                       ancienne_valeur, nouvelle_valeur, date_modif,
                       utilisateur)
  VALUES (seq_audit.NEXTVAL, 'CPT_TERME', 'TAUX_GARANTI',
          :OLD.num_compte, :OLD.taux_garanti, :NEW.taux_garanti,
          SYSDATE, USER);
END;
/
SHOW ERRORS TRIGGER trg_audit_taux_terme

-- =====================================================================
-- D9.6 Audit du decouvert autorise des comptes courants
-- =====================================================================
CREATE OR REPLACE TRIGGER trg_audit_decouvert
AFTER UPDATE OF decouvert ON cpt_courant
FOR EACH ROW
BEGIN
  INSERT INTO "AUDIT" (id_audit, nom_table, nom_colonne, num_compte,
                       ancienne_valeur, nouvelle_valeur, date_modif,
                       utilisateur)
  VALUES (seq_audit.NEXTVAL, 'CPT_COURANT', 'DECOUVERT',
          :OLD.num_compte, :OLD.decouvert, :NEW.decouvert,
          SYSDATE, USER);
END;
/
SHOW ERRORS TRIGGER trg_audit_decouvert

PROMPT *** Triggers crees ***
SELECT trigger_name, status
  FROM user_triggers
 ORDER BY trigger_name;

PROMPT ============================================================
PROMPT D9. TESTS DES TRIGGERS
PROMPT ============================================================

PROMPT *** Test 1 : compte bloque CC5 (refus attendu) ***
DECLARE
  v_ref_cli REF client_type;
  v_ref_cpt REF cptCourant_type;
BEGIN
  SELECT REF(c) INTO v_ref_cli FROM client c WHERE c.num_client = 5;
  SELECT REF(x) INTO v_ref_cpt FROM cpt_courant x WHERE x.num_compte = 'CC5';
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL, v_ref_cli, v_ref_cpt, TRUNC(SYSDATE),
          1000, 'DEPOT', 0);
  DBMS_OUTPUT.PUT_LINE('ERREUR : operation acceptee sur un compte bloque !');
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Refus attendu : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT *** Test 2 : client sans droits sur CC1 (refus attendu) ***
DECLARE
  v_ref_cli REF client_type;
  v_ref_cpt REF cptCourant_type;
BEGIN
  SELECT REF(c) INTO v_ref_cli FROM client c WHERE c.num_client = 6;
  SELECT REF(x) INTO v_ref_cpt FROM cpt_courant x WHERE x.num_compte = 'CC1';
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL, v_ref_cli, v_ref_cpt, TRUNC(SYSDATE),
          -1000, 'RETRAIT', 0);
  DBMS_OUTPUT.PUT_LINE('ERREUR : operation acceptee sans droits !');
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Refus attendu : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT *** Test 3 : signataire de droit R sur CC7 (refus attendu) ***
DECLARE
  v_ref_cli REF client_type;
  v_ref_cpt REF cptCourant_type;
BEGIN
  SELECT REF(c) INTO v_ref_cli FROM client c WHERE c.num_client = 5;
  SELECT REF(x) INTO v_ref_cpt FROM cpt_courant x WHERE x.num_compte = 'CC7';
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL, v_ref_cli, v_ref_cpt, TRUNC(SYSDATE),
          -1000, 'RETRAIT', 0);
  DBMS_OUTPUT.PUT_LINE('ERREUR : debit accepte pour un droit R !');
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Refus attendu : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT *** Test 4 : decouvert depasse sur CC3 (refus attendu) ***
DECLARE
  v_ref_cli REF client_type;
  v_ref_cpt REF cptCourant_type;
BEGIN
  SELECT REF(c) INTO v_ref_cli FROM client c WHERE c.num_client = 3;
  SELECT REF(x) INTO v_ref_cpt FROM cpt_courant x WHERE x.num_compte = 'CC3';
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL, v_ref_cli, v_ref_cpt, TRUNC(SYSDATE),
          -60000, 'RETRAIT', 0);
  DBMS_OUTPUT.PUT_LINE('ERREUR : decouvert depasse accepte !');
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Refus attendu : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT *** Test 5 : plafond journalier depasse sur CC4 (refus attendu) ***
DECLARE
  v_ref_cli REF client_type;
  v_ref_cpt REF cptCourant_type;
BEGIN
  SELECT REF(c) INTO v_ref_cli FROM client c WHERE c.num_client = 4;
  SELECT REF(x) INTO v_ref_cpt FROM cpt_courant x WHERE x.num_compte = 'CC4';
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL, v_ref_cli, v_ref_cpt, TRUNC(SYSDATE),
          -210000, 'RETRAIT', 0);
  DBMS_OUTPUT.PUT_LINE('ERREUR : plafond journalier depasse accepte !');
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Refus attendu : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT *** Test 6 : signataire D autorise sur CC7 (succes attendu) ***
DECLARE
  v_ref_cli REF client_type;
  v_ref_cpt REF cptCourant_type;
  v_avant   NUMBER;
  v_apres   NUMBER;
BEGIN
  SELECT solde INTO v_avant FROM cpt_courant WHERE num_compte = 'CC7';
  SELECT REF(c) INTO v_ref_cli FROM client c WHERE c.num_client = 2;
  SELECT REF(x) INTO v_ref_cpt FROM cpt_courant x WHERE x.num_compte = 'CC7';
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL, v_ref_cli, v_ref_cpt, TRUNC(SYSDATE),
          -1000, 'RETRAIT', 0);
  SELECT solde INTO v_apres FROM cpt_courant WHERE num_compte = 'CC7';
  DBMS_OUTPUT.PUT_LINE('CC7 solde '||v_avant||' -> '||v_apres);
  ROLLBACK;
END;
/

PROMPT *** Test 7 : signataire X autorise sur CC4 (succes attendu) ***
DECLARE
  v_ref_cli REF client_type;
  v_ref_cpt REF cptCourant_type;
  v_avant   NUMBER;
  v_apres   NUMBER;
BEGIN
  SELECT solde INTO v_avant FROM cpt_courant WHERE num_compte = 'CC4';
  SELECT REF(c) INTO v_ref_cli FROM client c WHERE c.num_client = 3;
  SELECT REF(x) INTO v_ref_cpt FROM cpt_courant x WHERE x.num_compte = 'CC4';
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL, v_ref_cli, v_ref_cpt, TRUNC(SYSDATE),
          -1000, 'RETRAIT', 0);
  SELECT solde INTO v_apres FROM cpt_courant WHERE num_compte = 'CC4';
  DBMS_OUTPUT.PUT_LINE('CC4 solde '||v_avant||' -> '||v_apres);
  ROLLBACK;
END;
/

PROMPT *** Test 8 : AFTER INSERT, solde et compteur CB sur CC6 ***
DECLARE
  v_ref_cli REF client_type;
  v_ref_cpt REF cptCourant_type;
  v_solde   NUMBER;
  v_cb      NUMBER;
BEGIN
  SELECT REF(c) INTO v_ref_cli FROM client c WHERE c.num_client = 6;
  SELECT REF(x) INTO v_ref_cpt FROM cpt_courant x WHERE x.num_compte = 'CC6';
  SELECT solde, nb_op_cb INTO v_solde, v_cb
    FROM cpt_courant WHERE num_compte = 'CC6';
  DBMS_OUTPUT.PUT_LINE('CC6 avant : solde='||v_solde||' nb_op_cb='||v_cb);

  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL, v_ref_cli, v_ref_cpt, TRUNC(SYSDATE),
          -1000, 'CB', 0);

  SELECT solde, nb_op_cb INTO v_solde, v_cb
    FROM cpt_courant WHERE num_compte = 'CC6';
  DBMS_OUTPUT.PUT_LINE('CC6 apres : solde='||v_solde||' nb_op_cb='||v_cb);
  ROLLBACK;
END;
/

PROMPT *** Test 9 : alerte SOLDE_NEGATIF sur CC6 ***
DECLARE
  v_ref_cli REF client_type;
  v_ref_cpt REF cptCourant_type;
  v_nb      NUMBER;
BEGIN
  SELECT REF(c) INTO v_ref_cli FROM client c WHERE c.num_client = 6;
  SELECT REF(x) INTO v_ref_cpt FROM cpt_courant x WHERE x.num_compte = 'CC6';
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL, v_ref_cli, v_ref_cpt, TRUNC(SYSDATE),
          -60000, 'RETRAIT', 0);
  SELECT COUNT(*) INTO v_nb
    FROM alerte
   WHERE num_compte = 'CC6' AND type_alerte = 'SOLDE_NEGATIF';
  DBMS_OUTPUT.PUT_LINE('Alertes SOLDE_NEGATIF pour CC6 = '||v_nb);
  ROLLBACK;
END;
/

PROMPT *** Test 10 : alerte OPERATION_SUSPECTE sur CC1 ***
DECLARE
  v_ref_cli REF client_type;
  v_ref_cpt REF cptCourant_type;
  v_nb      NUMBER;
BEGIN
  SELECT REF(c) INTO v_ref_cli FROM client c WHERE c.num_client = 1;
  SELECT REF(x) INTO v_ref_cpt FROM cpt_courant x WHERE x.num_compte = 'CC1';
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL, v_ref_cli, v_ref_cpt, TRUNC(SYSDATE),
          1500000, 'DEPOT', 0);
  SELECT COUNT(*) INTO v_nb
    FROM alerte
   WHERE num_compte = 'CC1' AND type_alerte = 'OPERATION_SUSPECTE';
  DBMS_OUTPUT.PUT_LINE('Alertes OPERATION_SUSPECTE pour CC1 = '||v_nb);
  ROLLBACK;
END;
/

PROMPT *** Test 11 : trigger echeance proche (CT99, J+3) ***
DECLARE
  v_nb NUMBER;
BEGIN
  INSERT INTO cpt_terme (num_compte, solde, date_ouverture, ref_client,
                         ref_agence, montant_bloque, duree_mois,
                         date_echeance, taux_garanti)
  VALUES ('CT99', 1000, TRUNC(SYSDATE),
          (SELECT REF(c) FROM client c WHERE c.num_client = 1),
          (SELECT REF(a) FROM agence a WHERE a.code = 'A1'),
          1000, 6, TRUNC(SYSDATE) + 3, 2.00);

  SELECT COUNT(*) INTO v_nb
    FROM alerte
   WHERE num_compte = 'CT99' AND type_alerte = 'ECHEANCE_PROCHE';
  DBMS_OUTPUT.PUT_LINE('Alertes ECHEANCE_PROCHE pour CT99 = '||v_nb);
  ROLLBACK;
END;
/

PROMPT *** Test 12 : trigger echeance depassee (CT98, J-1) ***
DECLARE
  v_nb NUMBER;
BEGIN
  INSERT INTO cpt_terme (num_compte, solde, date_ouverture, ref_client,
                         ref_agence, montant_bloque, duree_mois,
                         date_echeance, taux_garanti)
  VALUES ('CT98', 1000, TRUNC(SYSDATE),
          (SELECT REF(c) FROM client c WHERE c.num_client = 1),
          (SELECT REF(a) FROM agence a WHERE a.code = 'A1'),
          1000, 6, TRUNC(SYSDATE) - 1, 2.00);

  SELECT COUNT(*) INTO v_nb
    FROM alerte
   WHERE num_compte = 'CT98' AND type_alerte = 'ECHEANCE_DEPASSEE';
  DBMS_OUTPUT.PUT_LINE('Alertes ECHEANCE_DEPASSEE pour CT98 = '||v_nb);
  ROLLBACK;
END;
/

PROMPT *** Test 13 : audit du taux d interet (CE1) ***
UPDATE cpt_epargne SET taux_interet = 2.60 WHERE num_compte = 'CE1';
SELECT id_audit, nom_table, nom_colonne, num_compte,
       ancienne_valeur, nouvelle_valeur, utilisateur
  FROM "AUDIT"
 WHERE nom_table = 'CPT_EPARGNE' AND num_compte = 'CE1'
 ORDER BY id_audit;
ROLLBACK;

PROMPT *** Test 14 : audit du decouvert (CC1) ***
UPDATE cpt_courant SET decouvert = 60000 WHERE num_compte = 'CC1';
SELECT id_audit, nom_table, nom_colonne, num_compte,
       ancienne_valeur, nouvelle_valeur, utilisateur
  FROM "AUDIT"
 WHERE nom_table = 'CPT_COURANT' AND num_compte = 'CC1'
 ORDER BY id_audit;
ROLLBACK;

PROMPT *** Test 15 : audit du taux garanti (CT1) ***
UPDATE cpt_terme SET taux_garanti = 3.30 WHERE num_compte = 'CT1';
SELECT id_audit, nom_table, nom_colonne, num_compte,
       ancienne_valeur, nouvelle_valeur, utilisateur
  FROM "AUDIT"
 WHERE nom_table = 'CPT_TERME' AND num_compte = 'CT1'
 ORDER BY id_audit;
ROLLBACK;

PROMPT *** Test 16 : balayage des echeances existantes (COMMIT) ***
EXEC scan_echeances;

SELECT id_alerte, type_alerte, num_compte, message
  FROM alerte
 ORDER BY id_alerte;

PROMPT ============================================================
PROMPT D8i. TESTS DE passeMvt (APRES LES TRIGGERS)
PROMPT ============================================================

PROMPT *** passeMvt : titulaire, credit +10000 sur CC7 (client 4) ***
DECLARE
  v_cc    cptCourant_type;
  v_avant NUMBER;
  v_apres NUMBER;
BEGIN
  SELECT solde INTO v_avant FROM cpt_courant WHERE num_compte = 'CC7';
  SELECT VALUE(cc) INTO v_cc FROM cpt_courant cc WHERE cc.num_compte = 'CC7';
  v_cc.passeMvt(4, 10000);
  SELECT solde INTO v_apres FROM cpt_courant WHERE num_compte = 'CC7';
  DBMS_OUTPUT.PUT_LINE('CC7 solde '||v_avant||' -> '||v_apres);
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Erreur : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT *** passeMvt : signataire D, debit -5000 sur CC7 (client 2) ***
DECLARE
  v_cc    cptCourant_type;
  v_avant NUMBER;
  v_apres NUMBER;
BEGIN
  SELECT solde INTO v_avant FROM cpt_courant WHERE num_compte = 'CC7';
  SELECT VALUE(cc) INTO v_cc FROM cpt_courant cc WHERE cc.num_compte = 'CC7';
  v_cc.passeMvt(2, -5000);
  SELECT solde INTO v_apres FROM cpt_courant WHERE num_compte = 'CC7';
  DBMS_OUTPUT.PUT_LINE('CC7 solde '||v_avant||' -> '||v_apres);
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Erreur : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT *** passeMvt : signataire X, debit -5000 sur CC4 (client 3) ***
DECLARE
  v_cc    cptCourant_type;
  v_avant NUMBER;
  v_apres NUMBER;
BEGIN
  SELECT solde INTO v_avant FROM cpt_courant WHERE num_compte = 'CC4';
  SELECT VALUE(cc) INTO v_cc FROM cpt_courant cc WHERE cc.num_compte = 'CC4';
  v_cc.passeMvt(3, -5000);
  SELECT solde INTO v_apres FROM cpt_courant WHERE num_compte = 'CC4';
  DBMS_OUTPUT.PUT_LINE('CC4 solde '||v_avant||' -> '||v_apres);
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Erreur : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT *** passeMvt : signataire R, debit -5000 sur CC7 (client 5, refus) ***
DECLARE
  v_cc cptCourant_type;
BEGIN
  SELECT VALUE(cc) INTO v_cc FROM cpt_courant cc WHERE cc.num_compte = 'CC7';
  v_cc.passeMvt(5, -5000);
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Erreur : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT *** passeMvt : non-signataire, debit -5000 sur CC7 (client 6, refus) ***
DECLARE
  v_cc cptCourant_type;
BEGIN
  SELECT VALUE(cc) INTO v_cc FROM cpt_courant cc WHERE cc.num_compte = 'CC7';
  v_cc.passeMvt(6, -5000);
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Erreur : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT *** passeMvt : client inconnu 999 sur CC7 (refus) ***
DECLARE
  v_cc cptCourant_type;
BEGIN
  SELECT VALUE(cc) INTO v_cc FROM cpt_courant cc WHERE cc.num_compte = 'CC7';
  v_cc.passeMvt(999, -5000);
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Erreur : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT *** passeMvt : decouvert depasse sur CC3 (client 3, refus) ***
DECLARE
  v_cc cptCourant_type;
BEGIN
  SELECT VALUE(cc) INTO v_cc FROM cpt_courant cc WHERE cc.num_compte = 'CC3';
  v_cc.passeMvt(3, -60000);
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Erreur : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT *** passeMvt : plafond journalier depasse sur CC4 (client 4, refus) ***
DECLARE
  v_cc cptCourant_type;
BEGIN
  SELECT VALUE(cc) INTO v_cc FROM cpt_courant cc WHERE cc.num_compte = 'CC4';
  v_cc.passeMvt(4, -210000);
  ROLLBACK;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Erreur : '||SQLERRM);
    ROLLBACK;
END;
/

PROMPT ============================================================
PROMPT D1.5. TESTS DE virement
PROMPT ============================================================

PROMPT *** virement CC4 -> CC7 de 1000 DA (client 4) ***
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
  DBMS_OUTPUT.PUT_LINE('Apres : CC4='||v_cc4||' CC7='||v_cc7);
  ROLLBACK;
END;
/

PROMPT *** virement atomique refuse CC3 -> CC4 de 60000 DA ***
DECLARE
  v_cc4_avant NUMBER;
  v_cc4_apres NUMBER;
BEGIN
  SELECT solde INTO v_cc4_avant FROM cpt_courant WHERE num_compte = 'CC4';
  DBMS_OUTPUT.PUT_LINE('CC4 avant = '||v_cc4_avant);

  virement('CC3', 'CC4', 60000, 3);

  SELECT solde INTO v_cc4_apres FROM cpt_courant WHERE num_compte = 'CC4';
  DBMS_OUTPUT.PUT_LINE('CC4 apres = '||v_cc4_apres||' (doit etre inchange)');
  ROLLBACK;
END;
/

PROMPT *** virement inter-agences CC4 (A1) -> CC3 (A3), commission 1 % ***
DECLARE
  v_cc4 NUMBER;
  v_cc3 NUMBER;
BEGIN
  SELECT solde INTO v_cc4 FROM cpt_courant WHERE num_compte = 'CC4';
  SELECT solde INTO v_cc3 FROM cpt_courant WHERE num_compte = 'CC3';
  DBMS_OUTPUT.PUT_LINE('Avant : CC4='||v_cc4||' CC3='||v_cc3);

  -- Client 3 : signataire X de CC4 (debit autorise) et titulaire de CC3.
  virement('CC4', 'CC3', 1000, 3);

  SELECT solde INTO v_cc4 FROM cpt_courant WHERE num_compte = 'CC4';
  SELECT solde INTO v_cc3 FROM cpt_courant WHERE num_compte = 'CC3';
  DBMS_OUTPUT.PUT_LINE('Apres : CC4='||v_cc4||' CC3='||v_cc3
    ||' (commission 100 attendue)');
  ROLLBACK;
END;
/

PROMPT ============================================================
PROMPT D8n. TESTS DE fermeCompte (DESTRUCTIFS, EN DERNIER)
PROMPT ============================================================

PROMPT *** fermeCompte CE4 ***
SELECT num_compte, solde FROM cpt_epargne WHERE num_compte = 'CE4';
BEGIN
  compte_type.fermeCompte('CE4');
END;
/
SELECT COUNT(*) AS ce4_restant FROM cpt_epargne WHERE num_compte = 'CE4';

PROMPT *** fermeCompte CC1 ***
SELECT COUNT(*) AS operations_cc1
  FROM operation
 WHERE ref_compte = (SELECT REF(x) FROM cpt_courant x
                      WHERE x.num_compte = 'CC1');
BEGIN
  compte_type.fermeCompte('CC1');
END;
/
SELECT COUNT(*) AS cc1_restant FROM cpt_courant WHERE num_compte = 'CC1';
SELECT COUNT(*) AS operations_cc1_restants
  FROM operation
 WHERE ref_compte = (SELECT REF(x) FROM cpt_courant x
                      WHERE x.num_compte = 'CC1');

PROMPT *** fermeCompte : comptes inexistants ***
BEGIN
  compte_type.fermeCompte('CE9');
END;
/
BEGIN
  compte_type.fermeCompte('XX1');
END;
/

PROMPT ============================================================
PROMPT D. ETAT FINAL ET CONTROLES
PROMPT ============================================================

PROMPT *** Recompilation des sous-programmes dependants ***
ALTER PROCEDURE change_Portable COMPILE;
ALTER PROCEDURE drop_client COMPILE;
ALTER PROCEDURE ajout_client COMPILE;
ALTER PROCEDURE virement COMPILE;
ALTER PROCEDURE maj_statuts_dormants COMPILE;
ALTER PROCEDURE scan_echeances COMPILE;
ALTER FUNCTION nb_comptes COMPILE;
ALTER FUNCTION solde_total COMPILE;
ALTER FUNCTION ville_client COMPILE;
SHOW ERRORS PROCEDURE change_Portable
SHOW ERRORS PROCEDURE drop_client
SHOW ERRORS PROCEDURE ajout_client
SHOW ERRORS PROCEDURE virement
SHOW ERRORS PROCEDURE maj_statuts_dormants
SHOW ERRORS PROCEDURE scan_echeances
SHOW ERRORS FUNCTION nb_comptes
SHOW ERRORS FUNCTION solde_total
SHOW ERRORS FUNCTION ville_client

PROMPT *** Objets invalides eventuels ***
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status <> 'VALID'
 ORDER BY object_type, object_name;

PROMPT *** Etat final des donnees ***
SELECT 'CLIENTS'      AS objet, COUNT(*) AS nb FROM client
UNION ALL SELECT 'CONSEILLERS',  COUNT(*) FROM conseiller
UNION ALL SELECT 'AGENCES',      COUNT(*) FROM agence
UNION ALL SELECT 'AFFECTATIONS', COUNT(*) FROM affectation
UNION ALL SELECT 'CC',           COUNT(*) FROM cpt_courant
UNION ALL SELECT 'CE',           COUNT(*) FROM cpt_epargne
UNION ALL SELECT 'CT',           COUNT(*) FROM cpt_terme
UNION ALL SELECT 'OPERATIONS',   COUNT(*) FROM operation
UNION ALL SELECT 'SIGNATAIRES',  COUNT(*) FROM cpt_courant c, TABLE(c.signataires) s
UNION ALL SELECT 'ALERTES',      COUNT(*) FROM alerte
UNION ALL SELECT 'AUDIT',        COUNT(*) FROM "AUDIT";

PROMPT *** Alertes presentes ***
SELECT id_alerte, type_alerte, num_compte, message
  FROM alerte
 ORDER BY id_alerte;

PROMPT *** Soldes finaux des comptes courants restants ***
SELECT num_compte, solde, nb_op_cb, statut
  FROM cpt_courant
 ORDER BY num_compte;

PROMPT *** Soldes finaux des comptes d epargne restants ***
SELECT num_compte, solde, taux_interet
  FROM cpt_epargne
 ORDER BY num_compte;

PROMPT ============================================================
PROMPT FIN PARTIE D
PROMPT ============================================================

PROMPT ############################################################
PROMPT # PARTIE_E_OBJET_AVANCE.SQL
PROMPT ############################################################
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

PROMPT ############################################################
PROMPT # CONTROLE FINAL
PROMPT ############################################################
COLUMN object_name FORMAT A35
COLUMN object_type FORMAT A20
PROMPT *** Objets invalides (aucune ligne attendue) ***
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status <> 'VALID'
 ORDER BY object_type, object_name;

PROMPT *** Nombre d objets par categorie ***
SELECT object_type, COUNT(*) AS nb
  FROM user_objects
 GROUP BY object_type
 ORDER BY object_type;

PROMPT ============================================================
PROMPT FIN DU SCRIPT UNIQUE - PARTIES A A E
PROMPT ============================================================
