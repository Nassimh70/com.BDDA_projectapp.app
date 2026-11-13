SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
COLUMN ref_client.num_client FORMAT 999
SELECT r.ref_client.num_client AS cli, r.annee, COUNT(*) AS nb_mois
  FROM releves r, TABLE(r.mois) m
 GROUP BY r.ref_client.num_client, r.annee
 ORDER BY cli, r.annee;
SELECT r.ref_client.num_client AS cli, r.annee, m.COLUMN_VALUE AS mois,
       r.soldes(m.COLUMN_VALUE) AS solde
  FROM releves r, TABLE(r.mois) m
 ORDER BY cli, r.annee, m.COLUMN_VALUE;
EXIT