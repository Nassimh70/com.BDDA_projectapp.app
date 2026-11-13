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
