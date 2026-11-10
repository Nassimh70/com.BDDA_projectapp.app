-- =====================================================================
-- purge_donnees.sql
-- Script de suppression des DONNEES (question A3), sans toucher au schema.
-- Ordre compatible avec les contraintes d'integrite referentielle.
-- =====================================================================
SET SERVEROUTPUT ON
SET DEFINE OFF
SET FEEDBACK ON

-- 1. Detacher les parrainages (FK client -> client)
UPDATE client SET ref_parrain = NULL;

-- 2. Journaux et dependances des comptes
DELETE FROM releves;
DELETE FROM "AUDIT";
DELETE FROM alerte;
DELETE FROM operation;

-- 3. Comptes (les 3 sous-types)
DELETE FROM cpt_terme;
DELETE FROM cpt_epargne;
DELETE FROM cpt_courant;

-- 4. Clients, puis structures
DELETE FROM client;
DELETE FROM affectation;
DELETE FROM agence;
DELETE FROM conseiller;

COMMIT;

-- 5. Remise a zero des sequences
ALTER SEQUENCE seq_operation   RESTART START WITH 100;
ALTER SEQUENCE seq_alerte      RESTART START WITH 1;
ALTER SEQUENCE seq_audit       RESTART START WITH 1;
ALTER SEQUENCE seq_affectation RESTART START WITH 100;

PROMPT Donnees supprimees, sequences reinitialisees.
