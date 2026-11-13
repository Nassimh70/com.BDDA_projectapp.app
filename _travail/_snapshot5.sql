SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
SELECT r.annee, m.COLUMN_VALUE.mois AS mois,
       m.COLUMN_VALUE.nb_operations AS nb_ops
  FROM releves r, TABLE(r.mois_vry) m
 ORDER BY r.annee, m.COLUMN_VALUE.mois;
SELECT r.annee, m.COLUMN_VALUE.mois AS mois,
       t.COLUMN_VALUE.type_op AS type_op,
       t.COLUMN_VALUE.nb AS nb,
       t.COLUMN_VALUE.total AS total
  FROM releves r, TABLE(r.mois_vry) m, TABLE(m.COLUMN_VALUE.types) t
 ORDER BY r.annee, m.COLUMN_VALUE.mois, t.COLUMN_VALUE.type_op;
EXIT