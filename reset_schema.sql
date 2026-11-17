-- =====================================================================
-- reset_schema.sql
-- Mini-projet BDDA - M1 ASR - 2026/2027
-- .
-- REINITIALISATION COMPLETE DU SCHEMA MASTER1
-- .
-- Ce script supprime TOUS les objets du projet et ne recree RIEN.
-- Il laisse donc le schema vide, pret pour une reexecution de A a E.
-- Il est idempotent : on peut le relancer sur un schema deja vide.
-- .
-- Ordre de suppression (important pour les dependances) :
--   1. vue objet Agence_VOR
--   2. sous-programmes (procedures et fonctions)
--   3. triggers
--   4. tables (CASCADE CONSTRAINTS PURGE)
--   5. sequences
--   6. types (FORCE, sous-types avant super-types)
--   7. verification : aucun objet ne doit rester
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK ON
SET ECHO OFF
WHENEVER SQLERROR CONTINUE

PROMPT ============================================================
PROMPT 1. SUPPRESSION DE LA VUE OBJET
PROMPT ============================================================
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW Agence_VOR';
  DBMS_OUTPUT.PUT_LINE('Vue Agence_VOR supprimee.');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('Vue Agence_VOR absente (deja supprimee).');
END;
/

PROMPT ============================================================
PROMPT 2. SUPPRESSION DES SOUS-PROGRAMMES
PROMPT ============================================================
DECLARE
  TYPE t_liste IS TABLE OF VARCHAR2(30);
  v_noms t_liste := t_liste(
    'NB_COMPTES', 'SOLDE_TOTAL', 'VILLE_CLIENT',
    'AJOUT_CLIENT', 'CHANGE_PORTABLE', 'DROP_CLIENT',
    'MAJ_STATUTS_DORMANTS', 'SCAN_ECHEANCES', 'VIREMENT');
BEGIN
  FOR i IN 1..v_noms.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP PROCEDURE "'||v_noms(i)||'"';
      DBMS_OUTPUT.PUT_LINE('Procedure '||v_noms(i)||' supprimee.');
    EXCEPTION WHEN OTHERS THEN
      BEGIN
        EXECUTE IMMEDIATE 'DROP FUNCTION "'||v_noms(i)||'"';
        DBMS_OUTPUT.PUT_LINE('Fonction '||v_noms(i)||' supprimee.');
      EXCEPTION WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Sous-programme '||v_noms(i)||' absent.');
      END;
    END;
  END LOOP;
END;
/

PROMPT ============================================================
PROMPT 3. SUPPRESSION DES TRIGGERS
PROMPT ============================================================
DECLARE
  TYPE t_liste IS TABLE OF VARCHAR2(30);
  v_noms t_liste := t_liste(
    'TRG_AUDIT_DECOUVERT', 'TRG_AUDIT_TAUX', 'TRG_AUDIT_TAUX_TERME',
    'TRG_CT_ECHEANCE', 'TRG_OP_APRES', 'TRG_OP_AVANT');
BEGIN
  FOR i IN 1..v_noms.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TRIGGER "'||v_noms(i)||'"';
      DBMS_OUTPUT.PUT_LINE('Trigger '||v_noms(i)||' supprime.');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Trigger '||v_noms(i)||' absent.');
    END;
  END LOOP;
END;
/

PROMPT ============================================================
PROMPT 4. SUPPRESSION DES TABLES
PROMPT ============================================================
DECLARE
  TYPE t_liste IS TABLE OF VARCHAR2(30);
  v_noms t_liste := t_liste(
    'RELEVES', 'AUDIT', 'ALERTE', 'OPERATION',
    'CPT_TERME', 'CPT_EPARGNE', 'CPT_COURANT', 'SIGNATAIRE_NT_ST',
    'CLIENT', 'AFFECTATION', 'AGENCE', 'CONSEILLER');
BEGIN
  FOR i IN 1..v_noms.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE "'||v_noms(i)||'" CASCADE CONSTRAINTS PURGE';
      DBMS_OUTPUT.PUT_LINE('Table '||v_noms(i)||' supprimee.');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Table '||v_noms(i)||' absente.');
    END;
  END LOOP;
END;
/

PROMPT ============================================================
PROMPT 5. SUPPRESSION DES SEQUENCES
PROMPT ============================================================
DECLARE
  TYPE t_liste IS TABLE OF VARCHAR2(30);
  v_noms t_liste := t_liste(
    'SEQ_OPERATION', 'SEQ_ALERTE', 'SEQ_AUDIT', 'SEQ_AFFECTATION');
BEGIN
  FOR i IN 1..v_noms.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP SEQUENCE "'||v_noms(i)||'"';
      DBMS_OUTPUT.PUT_LINE('Sequence '||v_noms(i)||' supprimee.');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Sequence '||v_noms(i)||' absente.');
    END;
  END LOOP;
END;
/

PROMPT ============================================================
PROMPT 6. SUPPRESSION DES TYPES
PROMPT ============================================================
DECLARE
  TYPE t_liste IS TABLE OF VARCHAR2(30);
  v_noms t_liste := t_liste(
    'AGENCE_VOR_TYPE', 'MOIS_VRY_TYPE', 'MOIS_ELT_VRY_TYPE',
    'TYPE_STAT_NT_TYPE', 'TYPE_STAT_ELT_NT_TYPE',
    'CPTCOURANT_NT_TYPE', 'CONSEILLER_NT_TYPE',
    'OPERATION_TYPE', 'CPTTERME_TYPE', 'CPTEPARGNE_TYPE',
    'CPTCOURANT_TYPE', 'COMPTE_TYPE',
    'SIGNATAIRE_NT_TYPE', 'SIGNATAIRE_ELT_NT_TYPE',
    'CLIENT_TYPE', 'AGENCE_TYPE', 'CONSEILLER_TYPE',
    'TEL_VRY_TYPE', 'ADRESSE_TYPE');
BEGIN
  FOR i IN 1..v_noms.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TYPE "'||v_noms(i)||'" FORCE';
      DBMS_OUTPUT.PUT_LINE('Type '||v_noms(i)||' supprime.');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('Type '||v_noms(i)||' absent.');
    END;
  END LOOP;
END;
/

PROMPT ============================================================
PROMPT 7. VERIFICATION - LE SCHEMA DOIT ETRE VIDE
PROMPT ============================================================
COLUMN object_type FORMAT A25
COLUMN nb FORMAT 999
SELECT object_type, COUNT(*) AS nb
  FROM user_objects
 GROUP BY object_type
 ORDER BY object_type;

PROMPT *** Objets restants (aucune ligne attendue) ***
COLUMN object_name FORMAT A35
SELECT object_name, object_type
  FROM user_objects
 ORDER BY object_type, object_name;

PROMPT ============================================================
PROMPT FIN DE LA REINITIALISATION
PROMPT ============================================================
EXIT;
