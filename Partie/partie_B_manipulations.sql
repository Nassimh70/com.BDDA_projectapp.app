-- =====================================================================
-- partie_B_manipulations.sql
-- Mini-projet BDDA - M1 ASR - 2026/2027
-- PARTIE B - Manipulation de la base (question B5)
-- A executer apres la partie A.
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 250
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF
WHENEVER SQLERROR CONTINUE

PROMPT 0. PROCEDURES CATALOGUEES UTILISEES EN PARTIE B

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
