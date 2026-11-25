-- =====================================================================
-- 00_creation_utilisateur.sql
-- Question A2 : creation de l'utilisateur MASTER1 et de ses privileges.
--
-- A EXECUTER PAR UN ADMINISTRATEUR (SYSTEM / SYS), PAS PAR MASTER1.
-- Ce script n'a pas ete execute pendant le projet : le compte MASTER1
-- existait deja. Il est rendu idempotent pour pouvoir etre rejoue.
-- =====================================================================
SET SERVEROUTPUT ON
SET DEFINE OFF

DECLARE
  v_nb NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_nb FROM dba_users WHERE username = 'MASTER1';
  IF v_nb = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER MASTER1 IDENTIFIED BY system';
    DBMS_OUTPUT.PUT_LINE('Utilisateur MASTER1 cree.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Utilisateur MASTER1 deja present : aucune creation.');
  END IF;
END;
/

-- Privileges de connexion et de creation d'objets
GRANT CREATE SESSION   TO MASTER1;
GRANT CREATE TABLE     TO MASTER1;
GRANT CREATE TYPE      TO MASTER1;
GRANT CREATE VIEW      TO MASTER1;
GRANT CREATE PROCEDURE TO MASTER1;
GRANT CREATE SEQUENCE  TO MASTER1;
GRANT CREATE TRIGGER   TO MASTER1;

-- Job optionnel pour le passage automatique en DORMANT (partie D)
GRANT CREATE JOB       TO MASTER1;
GRANT EXECUTE ON DBMS_SCHEDULER TO MASTER1;

-- Espace disque
GRANT UNLIMITED TABLESPACE TO MASTER1;
ALTER USER MASTER1 QUOTA UNLIMITED ON USERS;

PROMPT Droits accordes a MASTER1.
