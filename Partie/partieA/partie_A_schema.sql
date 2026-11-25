

PROMPT 1. CREATION DES TYPES OBJET
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


-- 1.2 Telephones : VARRAY de 3 elements scalaires (domicile, portable 1, portable 2)
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE tel_vry_type AS VARRAY(3) OF VARCHAR2(20)]';
END;
/


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


-- 1.5 Client (type de base ; le parrain est ajoute juste apres en 1.6
-- pour permettre les insertions de clients parraines de la question A4)
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

-- 1.6 Association recursive de parrainage (A4, puis E10)
DECLARE
  v_nb NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_nb
    FROM user_type_attrs
   WHERE type_name = 'CLIENT_TYPE' AND attr_name = 'REF_PARRAIN';
  IF v_nb = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TYPE client_type ADD ATTRIBUTE ref_parrain REF client_type CASCADE';
  END IF;
END;
/



-- 1.7 Signataires : nested table d'objets (client + droit)
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE signataire_elt_nt_type AS OBJECT (
      ref_client REF client_type,
      droit      CHAR(1)
    )]';
END;
/
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE signataire_nt_type AS TABLE OF signataire_elt_nt_type]';
END;
/


-- 1.8 Compte : racine NOT FINAL NOT INSTANTIABLE
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE compte_type AS OBJECT (
      num_compte     VARCHAR2(10),
      solde          NUMBER(12,2),
      date_ouverture DATE,
      statut         VARCHAR2(10),
      ref_client     REF client_type,
      ref_agence     REF agence_type
      -- MEMBER FUNCTION fraisTenue RETURN NUMBER  (ajoutee en D8)
    ) NOT FINAL NOT INSTANTIABLE]';
END;
/


-- 1.9 Compte courant
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE cptCourant_type UNDER compte_type (
      decouvert   NUMBER(12,2),
      nb_op_cb    NUMBER,
      signataires signataire_nt_type
      -- OVERRIDING MEMBER FUNCTION fraisTenue RETURN NUMBER  (ajoutee en D8)
    )]';
END;
/



-- 1.10 Compte d'epargne
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE cptEpargne_type UNDER compte_type (
      taux_interet  NUMBER(5,2),
      plafond_depot NUMBER(12,2)
      -- OVERRIDING MEMBER FUNCTION fraisTenue RETURN NUMBER  (ajoutee en D8)
    )]';
END;
/


-- 1.11 Compte a terme
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE cptTerme_type UNDER compte_type (
      montant_bloque NUMBER(12,2),
      duree_mois     NUMBER,
      date_echeance  DATE,
      taux_garanti   NUMBER(5,2)
      -- OVERRIDING MEMBER FUNCTION fraisTenue RETURN NUMBER  (ajoutee en D8)
    )]';
END;
/


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



-- 1.13 Collections pour la vue objet de E12
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE conseiller_nt_type AS TABLE OF conseiller_type]';
END;
/
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE cptCourant_nt_type AS TABLE OF cptCourant_type]';
END;
/



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
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE type_stat_nt_type AS TABLE OF type_stat_elt_nt_type]';
END;
/
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE mois_elt_vry_type AS OBJECT (
      mois          NUMBER,
      nb_operations NUMBER,
      types         type_stat_nt_type
    )]';
END;
/
BEGIN
  EXECUTE IMMEDIATE q'[
    CREATE TYPE mois_vry_type AS VARRAY(12) OF mois_elt_vry_type]';
END;
/

PROMPT 2. CREATION DES TABLES ET DES CONTRAINTES






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





PROMPT 3. SEQUENCES UTILISEES PAR LES TRIGGERS DE LA PARTIE D
CREATE SEQUENCE seq_operation   START WITH 100;
CREATE SEQUENCE seq_alerte      START WITH 1;
CREATE SEQUENCE seq_audit       START WITH 1;
CREATE SEQUENCE seq_affectation START WITH 100;

PROMPT 4. DONNEES DE TEST (A4)




-- 4.1 Conseillers (4)
INSERT INTO conseiller VALUES (conseiller_type(1,'BENALI','Karim','Particuliers',
                                               DATE '2015-03-01', 85000));
INSERT INTO conseiller VALUES (conseiller_type(2,'HAMDI','Sara','Entreprises',
                                               DATE '2018-09-15', 92000));
INSERT INTO conseiller VALUES (conseiller_type(3,'TOUATI','Yacine','Particuliers',
                                               DATE '2020-01-10', 78000));
INSERT INTO conseiller VALUES (conseiller_type(4,'KACI','Nadia','Epargne',
                                               DATE '2021-06-01', 81000));

-- 4.2 Agences (3), un responsable par agence
INSERT INTO agence (code, nom, ville, ref_responsable)
VALUES ('A1','Agence Bejaia Centre','Bejaia',
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 1));
INSERT INTO agence (code, nom, ville, ref_responsable)
VALUES ('A2','Agence Alger Grande Poste','Alger',
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 2));
INSERT INTO agence (code, nom, ville, ref_responsable)
VALUES ('A3','Agence Oran Front de Mer','Oran',
        (SELECT REF(c) FROM conseiller c WHERE c.num_conseiller = 3));
-- 4.3 Historique des affectations (mutation du conseiller 4)
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
-- 4.4 Clients (6) - VARRAY varies : NULL, partiel, complet
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
-- 4.5 Comptes courants (7) : nested table vide a la creation
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

-- 4.6 Remplissage des signataires (5 comptes, les trois droits X, R et D)
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

-- 4.7 Comptes d'epargne (5), dont CE2 a 3.49 % (limite < 3.5)
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
-- 4.8 Comptes a terme (4)
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
--Afficher les infromation de tous les client 

SELECT * FROM agence;