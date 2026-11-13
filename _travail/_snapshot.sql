SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 220
SET PAGESIZE 100
SET DEFINE OFF
COLUMN nom FORMAT A12
COLUMN prenom FORMAT A12
COLUMN num_compte FORMAT A8
COLUMN statut FORMAT A8
COLUMN type_alerte FORMAT A20
PROMPT *** CLIENTS ***
SELECT c.num_client, c.nom, c.prenom, c.adresse.ville AS ville,
       c.ref_conseiller.num_conseiller AS cons,
       c.ref_parrain.num_client AS parrain
  FROM client c ORDER BY c.num_client;
PROMPT *** TELEPHONES PAR CLIENT ***
SELECT c.num_client, COUNT(t.COLUMN_VALUE) AS nb_tel
  FROM client c, TABLE(c.telephones) t
 GROUP BY c.num_client ORDER BY c.num_client;
PROMPT *** CONSEILLERS ***
SELECT num_conseiller, nom, prenom, specialite FROM conseiller ORDER BY num_conseiller;
PROMPT *** AGENCES ***
SELECT a.code, a.nom, a.ville, a.ref_responsable.num_conseiller AS resp FROM agence a ORDER BY a.code;
PROMPT *** COMPTES COURANTS ***
SELECT cc.num_compte, cc.solde, cc.statut, cc.ref_client.num_client AS cli,
       cc.ref_agence.code AS ag, cc.decouvert, cc.nb_op_cb,
       CARDINALITY(cc.signataires) AS nb_sig
  FROM cpt_courant cc ORDER BY cc.num_compte;
PROMPT *** COMPTES EPARGNE ***
SELECT ce.num_compte, ce.solde, ce.statut, ce.ref_client.num_client AS cli,
       ce.ref_agence.code AS ag, ce.taux_interet, ce.plafond_depot
  FROM cpt_epargne ce ORDER BY ce.num_compte;
PROMPT *** COMPTES TERME ***
SELECT ct.num_compte, ct.solde, ct.statut, ct.ref_client.num_client AS cli,
       ct.ref_agence.code AS ag, ct.montant_bloque, ct.duree_mois, ct.date_echeance, ct.taux_garanti
  FROM cpt_terme ct ORDER BY ct.num_compte;
PROMPT *** OPERATIONS ***
SELECT COUNT(*) AS nb_operations FROM operation;
SELECT type_op, COUNT(*) AS nb, SUM(montant) AS total FROM operation GROUP BY type_op ORDER BY type_op;
PROMPT *** SIGNATAIRES ***
SELECT c.num_compte, s.ref_client.num_client AS cli, s.droit
  FROM cpt_courant c, TABLE(c.signataires) s
 ORDER BY c.num_compte, s.ref_client.num_client;
PROMPT *** ALERTES ***
SELECT id_alerte, type_alerte, num_compte, traitee FROM alerte ORDER BY id_alerte;
PROMPT *** AFFECTATIONS OUVERTES ***
SELECT af.id_affectation, af.ref_conseiller.num_conseiller AS cons,
       af.ref_agence.code AS ag, af.date_debut, af.date_fin
  FROM affectation af WHERE af.date_fin IS NULL ORDER BY af.ref_conseiller.num_conseiller;
EXIT