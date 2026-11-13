SET LINESIZE 200
SET PAGESIZE 100
SELECT constraint_type, COUNT(*) AS nb FROM user_constraints GROUP BY constraint_type ORDER BY constraint_type;
SELECT COUNT(*) AS nb_fk FROM user_constraints WHERE constraint_type='R';
EXIT