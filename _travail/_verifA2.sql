SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
PROMPT *** POLYMORPHISME fraisTenue (VALUE) ***
SELECT 'COURANT' AS sorte, c.num_compte, VALUE(c).fraisTenue() AS frais FROM cpt_courant c
UNION ALL SELECT 'EPARGNE', e.num_compte, VALUE(e).fraisTenue() FROM cpt_epargne e
UNION ALL SELECT 'TERME', t.num_compte, VALUE(t).fraisTenue() FROM cpt_terme t
ORDER BY 1,2;
PROMPT *** TAILLE VARRAY (CARDINALITY) ***
SELECT num_client, CARDINALITY(telephones) AS nb_elements FROM client ORDER BY num_client;
PROMPT *** DEREFERENCEMENT AVEC ALIAS ***
SELECT c.num_compte, c.ref_client.nom AS titulaire, c.ref_agence.nom AS agence
  FROM cpt_courant c ORDER BY c.num_compte;
PROMPT *** FIN ***
EXIT
