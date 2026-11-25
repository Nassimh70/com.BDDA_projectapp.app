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
UNION
SELECT ce.num_compte, 'EPARGNE', ce.solde, ce.date_ouverture,
       'taux='||ce.taux_interet
  FROM cpt_epargne ce, client c
 WHERE ce.ref_client = REF(c) AND c.num_client = 4
UNION
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
