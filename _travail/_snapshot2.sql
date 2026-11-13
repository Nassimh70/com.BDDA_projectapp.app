SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 220
SET PAGESIZE 100
SET DEFINE OFF
COLUMN nom FORMAT A12
COLUMN prenom FORMAT A12
COLUMN num_compte FORMAT A8
COLUMN statut FORMAT A8
COLUMN type_alerte FORMAT A22
PROMPT *** COUNTS ***
SELECT 'clients' AS objet, COUNT(*) AS nb FROM client
UNION ALL SELECT 'conseillers', COUNT(*) FROM conseiller
UNION ALL SELECT 'agences', COUNT(*) FROM agence
UNION ALL SELECT 'affectations', COUNT(*) FROM affectation
UNION ALL SELECT 'comptes_courants', COUNT(*) FROM cpt_courant
UNION ALL SELECT 'comptes_epargne', COUNT(*) FROM cpt_epargne
UNION ALL SELECT 'comptes_terme', COUNT(*) FROM cpt_terme
UNION ALL SELECT 'operations', COUNT(*) FROM operation
UNION ALL SELECT 'signataires', COUNT(*) FROM (SELECT s.* FROM cpt_courant c, TABLE(c.signataires) s)
UNION ALL SELECT 'alertes', COUNT(*) FROM alerte
UNION ALL SELECT 'audit', COUNT(*) FROM "AUDIT"
UNION ALL SELECT 'releves', COUNT(*) FROM releves;
PROMPT *** CLIENTS ***
SELECT c.num_client, c.nom, c.prenom, c.adresse.ville AS ville,
       c.ref_conseiller.num_conseiller AS cons,
       c.ref_parrain.num_client AS parrain
  FROM client c ORDER BY c.num_client;
PROMPT *** CC ***
SELECT cc.num_compte, cc.solde, cc.statut, cc.ref_client.num_client AS cli,
       cc.ref_agence.code AS ag, cc.decouvert, cc.nb_op_cb,
       CARDINALITY(cc.signataires) AS nb_sig
  FROM cpt_courant cc ORDER BY cc.num_compte;
PROMPT *** CE ***
SELECT ce.num_compte, ce.solde, ce.statut, ce.ref_client.num_client AS cli,
       ce.ref_agence.code AS ag, ce.taux_interet, ce.plafond_depot
  FROM cpt_epargne ce ORDER BY ce.num_compte;
PROMPT *** CT ***
SELECT ct.num_compte, ct.solde, ct.statut, ct.ref_client.num_client AS cli,
       ct.ref_agence.code AS ag, ct.montant_bloque, ct.duree_mois,
       TO_CHAR(ct.date_echeance,'DD/MM/YYYY') AS echeance, ct.taux_garanti
  FROM cpt_terme ct ORDER BY ct.num_compte;
PROMPT *** OPS PAR TYPE ***
SELECT type_op, COUNT(*) AS nb, SUM(montant) AS total
  FROM operation GROUP BY type_op ORDER BY type_op;
PROMPT *** ALERTES ***
SELECT id_alerte, type_alerte, num_compte, traitee FROM alerte ORDER BY id_alerte;
PROMPT *** RELEVES ***
SELECT ref_client.num_client AS cli, annee, COUNT(*) AS nb_mois
  FROM releves GROUP BY ref_client.num_client, annee ORDER BY cli, annee;
PROMPT *** AFFECTATIONS OUVERTES ***
SELECT af.ref_conseiller.num_conseiller AS cons, af.ref_agence.code AS ag,
       TO_CHAR(af.date_debut,'DD/MM/YYYY') AS debut
  FROM affectation af WHERE af.date_fin IS NULL ORDER BY cons;
EXIT