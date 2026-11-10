SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
COLUMN nom FORMAT A12
PROMPT *** CONTRAINTES FK ***
SELECT constraint_name, table_name, constraint_type, status
  FROM user_constraints WHERE constraint_type IN ('R','C','P','U')
 ORDER BY table_name, constraint_type, constraint_name;
PROMPT *** DEREFERENCEMENT AGENCE ***
SELECT a.code, a.nom, a.ref_responsable.nom AS responsable FROM agence a ORDER BY a.code;
PROMPT *** POLYMORPHISME fraisTenue ***
SELECT 'COURANT' AS sorte, num_compte, fraisTenue() AS frais FROM cpt_courant
UNION ALL SELECT 'EPARGNE', num_compte, fraisTenue() FROM cpt_epargne
UNION ALL SELECT 'TERME', num_compte, fraisTenue() FROM cpt_terme
ORDER BY 1,2;
PROMPT *** PARRAINAGE (double notation) ***
SELECT c.num_client, c.nom, c.ref_parrain.nom AS parrain, c.ref_parrain.ref_parrain.nom AS grand_parrain
  FROM client c ORDER BY c.num_client;
PROMPT *** SIGNATAIRES CC7 ***
SELECT s.ref_client.nom AS signataire, s.droit FROM cpt_courant c, TABLE(c.signataires) s
 WHERE c.num_compte = 'CC7' ORDER BY 1;
PROMPT *** TAILLE VARRAY ***
SELECT num_client, c.telephones.COUNT AS nb_elements,
       CASE WHEN c.telephones IS NULL THEN 'NULL' ELSE 'INITIALISE' END AS etat
  FROM client c ORDER BY num_client;
PROMPT *** CHECK DEFERRABLE (test B5b en avance) ***
INSERT INTO cpt_courant (num_compte, solde, date_ouverture, ref_client, ref_agence, decouvert, signataires)
VALUES ('ZZTEST',0,SYSDATE,NULL,(SELECT REF(a) FROM agence a WHERE a.code='A1'),0,signataire_nt_type());
UPDATE cpt_courant SET ref_client = (SELECT REF(c) FROM client c WHERE c.num_client=1) WHERE num_compte='ZZTEST';
COMMIT;
SELECT num_compte, ref_client.nom AS titulaire FROM cpt_courant WHERE num_compte='ZZTEST';
DELETE FROM cpt_courant WHERE num_compte='ZZTEST';
COMMIT;
PROMPT *** FIN ***
EXIT
