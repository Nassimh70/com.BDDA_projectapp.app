SET PAGESIZE 100
SET LINESIZE 200
SELECT 'CLIENTS' AS objet, COUNT(*) AS nb FROM client
UNION ALL SELECT 'CC', COUNT(*) FROM cpt_courant
UNION ALL SELECT 'CE', COUNT(*) FROM cpt_epargne
UNION ALL SELECT 'CT', COUNT(*) FROM cpt_terme
UNION ALL SELECT 'OPS', COUNT(*) FROM operation
UNION ALL SELECT 'SIG', COUNT(*) FROM cpt_courant c, TABLE(c.signataires) s
UNION ALL SELECT 'ALERTES', COUNT(*) FROM alerte;
SELECT object_name, object_type, status FROM user_objects WHERE status <> 'VALID';
EXIT
