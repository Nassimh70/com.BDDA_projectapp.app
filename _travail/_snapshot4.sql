SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
SELECT r.ref_client.num_client AS cli, r.annee, COUNT(*) AS nb_mois
  FROM releves r, TABLE(r.mois_vry) m
 GROUP BY r.ref_client.num_client, r.annee
 ORDER BY cli, r.annee;
SELECT r.ref_client.num_client AS cli, r.annee, m.COLUMN_VALUE.mois AS mois,
       m.COLUMN_VALUE.solde AS solde
  FROM releves r, TABLE(r.mois_vry) m
 ORDER BY cli, r.annee, m.COLUMN_VALUE.mois;
EXIT