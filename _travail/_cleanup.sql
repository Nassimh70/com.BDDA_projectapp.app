SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 300
SET DEFINE OFF
SET FEEDBACK OFF
SET ECHO OFF
WHENEVER SQLERROR CONTINUE

PROMPT ===== NETTOYAGE COMPLET DU SCHEMA MASTER1 =====
BEGIN
  FOR r IN (SELECT object_name, object_type FROM user_objects
             WHERE object_type IN ('TABLE','VIEW','SEQUENCE','PROCEDURE','FUNCTION',
                                   'PACKAGE','PACKAGE BODY','TRIGGER','TYPE','TYPE BODY')
               AND object_name NOT LIKE 'BIN$%'
             ORDER BY CASE object_type
                        WHEN 'TRIGGER' THEN 1 WHEN 'VIEW' THEN 2 WHEN 'TABLE' THEN 3
                        WHEN 'SEQUENCE' THEN 4 WHEN 'PROCEDURE' THEN 5 WHEN 'FUNCTION' THEN 6
                        WHEN 'PACKAGE BODY' THEN 7 WHEN 'PACKAGE' THEN 8
                        WHEN 'TYPE BODY' THEN 9 WHEN 'TYPE' THEN 10 END) LOOP
    BEGIN
      IF r.object_type = 'TABLE' THEN
        EXECUTE IMMEDIATE 'DROP TABLE "'||r.object_name||'" CASCADE CONSTRAINTS PURGE';
      ELSIF r.object_type = 'TYPE' THEN
        EXECUTE IMMEDIATE 'DROP TYPE "'||r.object_name||'" FORCE';
      ELSE
        EXECUTE IMMEDIATE 'DROP '||r.object_type||' "'||r.object_name||'"';
      END IF;
      DBMS_OUTPUT.PUT_LINE('OK   '||RPAD(r.object_type,14)||r.object_name);
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('SKIP '||RPAD(r.object_type,14)||r.object_name||' -> '||SQLERRM);
    END;
  END LOOP;
END;
/
PROMPT ===== ETAT FINAL =====
SELECT object_name, object_type FROM user_objects ORDER BY object_type, object_name;
PROMPT ===== RECYCLEBIN =====
SELECT COUNT(*) AS objets_recyclebin FROM user_recyclebin;
PROMPT ===== FIN =====
