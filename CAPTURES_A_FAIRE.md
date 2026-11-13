# Captures à faire pour le rapport PDF

**Projet :** Mini-projet BDDA Banque — M1 ASR 2026/2027  
**Base :** Oracle 21c XE, `MASTER1/system@localhost:1521/XEPDB1`  
**But :** produire des captures lisibles, ordonnées et cohérentes avec le rapport PDF.

> **Règle importante.** La partie C s'exécute **avant** les tests destructifs de la partie D. Si tu prends toutes les captures après avoir exécuté `projet_bdda_banque.sql` en entier, tu ne verras plus :
> - CC1 (supprimé par `fermeCompte('CC1')`) ;
> - CE4 (supprimé par `fermeCompte('CE4')`) ;
> - l'opération de 1 500 000 DA (supprimée avec CC1) ;
> - CT4 (supprimé par la requête 6.25).
>
> Deux solutions :
> 1. prendre les captures de la partie C **juste après** l'exécution de `partie_C_requetes.sql`, avant la partie D ;
> 2. utiliser les sorties déjà enregistrées `_travail/_C.out` et `_travail/_FULL.out` pour les résultats de C.

---

## 0. Préparation de l'environnement de capture

Avant les captures, dans SQL*Plus :

```sql
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET DEFINE OFF
SET FEEDBACK ON
SET VERIFY OFF
```

Pour les colonnes larges :

```sql
COLUMN nom FORMAT A15
COLUMN prenom FORMAT A15
COLUMN num_compte FORMAT A10
COLUMN statut FORMAT A10
COLUMN type_op FORMAT A10
COLUMN type_alerte FORMAT A22
COLUMN adresse FORMAT A50
```

Conseils de capture :

- agrandir la fenêtre SQL*Plus ou du terminal ;
- zoomer suffisamment pour que les accents et les chiffres soient lisibles ;
- ne pas couper la partie droite des tableaux ;
- inclure la commande SQL et le résultat dans la même capture ;
- nommer les fichiers `01_environnement.png`, `02_uml.png`, etc. ;
- garder une version `PNG` haute résolution pour le PDF.

---

## 1. Page de garde et environnement

| N° | Titre | Commande / source | Ce qu'on doit voir | Où l'insérer | Priorité |
|---|---|---|---|---|---|
| 01 | Connexion à la base | `sqlplus MASTER1/system@localhost:1521/XEPDB1` puis `SELECT USER FROM dual;` | `MASTER1`, version Oracle, date. | Page de garde / annexe environnement | P1 |
| 02 | Arborescence des livrables | Capture de l'explorateur Windows sur `D:\bdda` | Les fichiers `partie_A...` à `partie_E...`, `projet_bdda_banque.sql`, `GUIDE_SOUTENANCE.md`, `uml/`. | Section « Livrables » | P1 |
| 03 | Diagramme UML | `uml/banque.puml` rendu (PlantUML) ou `uml/banque.mermaid` | Classes, héritage, REF, collections. | Section « Modèle de données » | P1 |
| 04 | Diagramme UML — version texte | `uml/banque.txt` | Version lisible si le rendu graphique manque. | Annexe | P2 |

> **Astuce :** si PlantUML n'est pas installé, utiliser un rendu Mermaid en ligne ou inclure `uml/banque.txt`. Le rapport doit avoir **au moins une** représentation graphique du modèle.

---

## 2. Partie A — Schéma et données

| N° | Titre | Commande / source | Ce qu'on doit voir | Où l'insérer | Priorité |
|---|---|---|---|---|---|
| 05 | Types métier | `SELECT type_name, typecode FROM user_types ORDER BY type_name;` | 19 types : `ADRESSE_TYPE`, `CLIENT_TYPE`, `COMPTE_TYPE`, `CPTCOURANT_TYPE`, etc. | Partie A — types | P1 |
| 06 | Tables | `SELECT table_name FROM user_tables ORDER BY table_name;` | 12 tables, dont `SIGNATAIRE_NT_ST`. | Partie A — tables | P1 |
| 07 | Contraintes | `SELECT constraint_name, constraint_type, table_name FROM user_constraints WHERE table_name IN (...);` | PK, FK, CHECK, UNIQUE. | Partie A — contraintes | P1 |
| 08 | Clients | `SELECT c.num_client, c.nom, c.prenom, c.adresse.ville FROM client c ORDER BY c.num_client;` | 6 clients. | Partie A — données | P1 |
| 09 | Téléphones (VARRAY) | `SELECT c.num_client, t.COLUMN_VALUE FROM client c, TABLE(c.telephones) t ORDER BY c.num_client;` | 1 à 3 téléphones par client, certains `NULL`. | Partie A — collections | P1 |
| 10 | Comptes courants | `SELECT cc.num_compte, cc.solde, cc.statut, CARDINALITY(cc.signataires) AS nb_sig FROM cpt_courant cc ORDER BY cc.num_compte;` | 7 CC au départ, dont CC5 `BLOQUE`. | Partie A — comptes | P1 |
| 11 | Comptes d'épargne | `SELECT ce.num_compte, ce.solde, ce.taux_interet, ce.plafond_depot FROM cpt_epargne ce ORDER BY ce.num_compte;` | 5 CE, dont CE2 à 3,49. | Partie A — comptes | P1 |
| 12 | Comptes à terme | `SELECT ct.num_compte, ct.montant_bloque, ct.duree_mois, ct.date_echeance FROM cpt_terme ct ORDER BY ct.num_compte;` | 4 CT, dont CT4 à 0. | Partie A — comptes | P1 |
| 13 | Opérations | `SELECT id_op, date_op, montant, type_op FROM operation ORDER BY id_op;` | 20 opérations au départ. | Partie A — opérations | P1 |
| 14 | Signataires | `SELECT cc.num_compte, s.ref_client.nom, s.droit FROM cpt_courant cc, TABLE(cc.signataires) s ORDER BY cc.num_compte;` | Droits `X`, `R`, `D`. | Partie A — nested table | P1 |
| 15 | Agences / conseillers / affectations | `SELECT a.code, a.nom, a.ref_responsable.nom FROM agence a;` et `SELECT * FROM affectation;` | 3 agences, 4 conseillers, historique. | Partie A — organisation | P2 |
| 16 | Séquences | `SELECT sequence_name, last_number FROM user_sequences;` | `SEQ_OPERATION`, `SEQ_ALERTE`, `SEQ_AUDIT`, `SEQ_AFFECTATION`. | Partie A — séquences | P2 |

> **Attention :** `SELECT * FROM client` peut afficher les attributs objet et le VARRAY de façon compacte. Pour une capture lisible, préférer les colonnes détaillées et `TABLE(c.telephones)`.

---

## 3. Partie B — Manipulations

| N° | Titre | Commande / source | Ce qu'on doit voir | Où l'insérer | Priorité |
|---|---|---|---|---|---|
| 17 | B5a — client 99 | `SELECT * FROM client WHERE num_client = 99;` | `OUKACI Ahmed`, Bejaia, 1 téléphone. | Partie B — B5a | P1 |
| 18 | B5b — CC99 sans titulaire | `SELECT num_compte, solde, statut FROM cpt_courant WHERE num_compte = 'CC99';` puis l'`UPDATE` et le `COMMIT`. | Le compte existe avant l'`UPDATE`, puis a un titulaire. | Partie B — B5b | P1 |
| 19 | B5c — date par défaut | `SELECT id_op, date_op, montant, type_op FROM operation WHERE ...;` | `date_op` = date du jour sans saisie. | Partie B — B5c | P1 |
| 20 | B5d — signataire D | `SELECT s.ref_client.nom, s.droit FROM cpt_courant cc, TABLE(cc.signataires) s WHERE cc.num_compte = 'CC99';` | Un signataire avec droit `D`. | Partie B — B5d | P1 |
| 21 | B5e — `change_Portable` | `SELECT c.num_client, t.COLUMN_VALUE FROM client c, TABLE(c.telephones) t WHERE c.num_client IN (3, 99);` | Client 99 : 1 → 2 téléphones ; client 3 : `0777-11-22-33` en 2e. | Partie B — B5e | P1 |
| 22 | B5f — `drop_client` avant/après | `SELECT COUNT(*) FROM client WHERE num_client = 99;` avant et après. | 1 puis 0 ; aucun orphelin. | Partie B — B5f | P1 |
| 23 | B5f — contrôle des dépendances | `SELECT COUNT(*) FROM operation WHERE ref_client = ...;` et `SELECT COUNT(*) FROM cpt_courant WHERE ref_client = ...;` | 0 après suppression. | Partie B — B5f | P2 |

> **Astuce :** pour B5f, la sortie complète est dans `_FULL.out`. Si tu ne veux pas recréer le client 99, capture la sortie déjà exécutée.

---

## 4. Partie C — Requêtes SQL

> **Rappel :** prendre ces captures **avant** la partie D, ou utiliser `_C.out` / `_FULL.out`.

| N° | Titre | Commande / source | Ce qu'on doit voir | Où l'insérer | Priorité |
|---|---|---|---|---|---|
| 24 | 6.10 — solde négatif | Requête 6.10 | CC2 : -50 000, titulaire BENALI, conseiller HAMDI. | Partie C — 6.10 | P1 |
| 25 | 6.15 — top 3 clients | Requête 6.15 | Client 1 : 3 348 500 ; client 4 : 830 000 ; client 2 : 300 000. | Partie C — 6.15 | P1 |
| 26 | 6.16a — VARRAY | Requête 6.16a | Client 1 : 3 téléphones, 2 renseignés. | Partie C — 6.16 | P1 |
| 27 | 6.18a / 6.20 — nested table | Requêtes 6.18a et 6.20 | CC7 : 3 signataires ; adresse complète. | Partie C — 6.18/6.20 | P1 |
| 28 | 6.22 — échéances | Requête 6.22 | CT2 : 5 jours ; CT1 : 20 jours. | Partie C — 6.22 | P1 |
| 29 | 6.24 — opération > 1 M | Requête 6.24 | Opération de 1 500 000 DA sur CC1. | Partie C — 6.24 | P1 |
| 30 | 6.25 — suppression CT4 | Requête 6.25 + `SELECT` après | CT4 supprimé ; CT1, CT2, CT3 restants. | Partie C — 6.25 | P1 |
| 31 | 6.1 / 6.2 — formats | Requêtes 6.1 et 6.2 | Colonnes lisibles, clients et comptes. | Partie C — 6.1/6.2 | P2 |
| 32 | 6.12 — client avec le plus de CE | Requête 6.12 | Client 1 (2 CE). | Partie C — 6.12 | P2 |
| 33 | 6.23 — comptes dormants | Requête 6.23 | Comptes sans opération depuis 12 mois. | Partie C — 6.23 | P2 |

> **Astuce :** pour 6.24, si tu as déjà exécuté la partie D, l'opération de 1 500 000 DA n'existe plus. Utilise `_C.out` ou capture avant D. Ne « réinvente » pas le résultat.

---

## 5. Partie D — Programmation PL/SQL

| N° | Titre | Commande / source | Ce qu'on doit voir | Où l'insérer | Priorité |
|---|---|---|---|---|---|
| 34 | D7a — téléphone client 3 | Bloc D7a | `0777-11-22-33`. | Partie D — 7a | P1 |
| 35 | D7b — tous les titulaires | Bloc D7b | 6 clients, certains « non renseigné ». | Partie D — 7b | P2 |
| 36 | D7c — curseur paramétré | Bloc D7c, seuil 100 000 puis -1 000 000 | CC2, CC3, CC5, CC6 ; puis `aucun_compte`. | Partie D — 7c | P1 |
| 37 | D7d — EXTEND/LIMIT/COUNT/LAST | Bloc D7d | Client 98 : 2 → 3 téléphones ; 4e refusé. | Partie D — 7d | P1 |
| 38 | D7e — total intérêts A1 | Bloc D7e | 10 150 DA. | Partie D — 7e | P1 |
| 39 | D8 — `nbCepargne` / `soldeTotal` | `SELECT c.num_client, c.nom, c.nbCepargne(), c.soldeTotal() FROM client c;` | 2/1/1/1/0/0 et les soldes totaux. | Partie D — méthodes client | P1 |
| 40 | D8 — intérêts et frais | `SELECT ce.num_compte, ce.calculeInterets(), ce.sortieAnticipee() FROM cpt_epargne ce;` | CE5 : 515 000 / 475 000. | Partie D — méthodes épargne | P1 |
| 41 | D8 — `passeMvt` | Bloc `passeMvt` + `ROLLBACK` | CC7 : 185 000 → 195 000, puis rollback. | Partie D — méthode courant | P1 |
| 42 | D8 — `virement` same-agency | Bloc virement CC4 → CC7 | 324 000 / 186 000, commission 0. | Partie D — virement | P1 |
| 43 | D8 — `virement` inter-agences | Bloc virement CC4 → CC3 | 323 900 / 39 000, commission 100. | Partie D — virement | P1 |
| 44 | D8 — `virement` rollback | Bloc CC3 → CC4 60 000 | `ORA-20004`, CC4 reste 325 000. | Partie D — virement | P1 |
| 45 | D8 — `fermeCompte` | Bloc `fermeCompte('CE4')` puis `('CC1')` | CE4 320 000 ; CC1 2 498 500 + 5 opérations. | Partie D — fermeture | P1 |
| 46 | D9 — refus trigger statut | Bloc opération sur CC5 | `ORA-20001`. | Partie D — triggers | P1 |
| 47 | D9 — refus droits | Bloc client sans droit | `ORA-20002`. | Partie D — triggers | P1 |
| 48 | D9 - refus plafond | Bloc 210 000 sur CC4 | `ORA-20003`. | Partie D - triggers | P1 |
| 49 | D9 — refus découvert | Bloc 100 000 sur CC2 | `ORA-20004`. | Partie D — triggers | P1 |
| 50 | D9 — succès + solde | Bloc dépôt 10 000 sur CC7 | 185 000 → 195 000. | Partie D — triggers | P1 |
| 51 | D9 — alertes | `SELECT * FROM alerte;` | `SOLDE_NEGATIF`, `OPERATION_SUSPECTE`, `ECHEANCE_PROCHE`, `ECHEANCE_DEPASSEE`. | Partie D — alertes | P1 |
| 52 | D9 — audit | `SELECT * FROM "AUDIT";` | Lignes d'audit après modification de taux/découvert. | Partie D — audit | P2 |
| 53 | D9 — `scan_echeances` | `EXEC scan_echeances;` puis `SELECT * FROM alerte;` | Alertes CT2/CT3, sans doublon. | Partie D — échéances | P2 |

> **Astuce :** les blocs de test sont déjà dans `partie_D_programmation.sql`. Pour une capture propre, exécuter le bloc seul dans SQL*Plus et capturer la sortie `DBMS_OUTPUT`.

---

## 6. Partie E — Objet avancé

| N° | Titre | Commande / source | Ce qu'on doit voir | Où l'insérer | Priorité |
|---|---|---|---|---|---|
| 54 | E10 — parrainage | Requête à double notation | Clients 2/3/4 → AMRANI ; 5 → BENALI/AMRANI ; 6 → CHERIF/AMRANI. | Partie E — 10 | P1 |
| 55 | E11 — 5 mois | `SELECT r.annee, COUNT(*) FROM releves r, TABLE(r.mois_vry) m GROUP BY r.annee;` | 2026 : 5 mois. | Partie E — 11 | P1 |
| 56 | E11 — totaux par type | Requête double `TABLE` | DEPOT 13/880 000 ; RETRAIT 32/620 000 ; VIREMENT 3/130 000 ; CB 2/35 000. | Partie E — 11 | P1 |
| 57 | E12 — vue objet | `SELECT code, nom, ville FROM Agence_VOR;` | 3 agences. | Partie E — 12 | P1 |
| 58 | E12 — collections conseillers | `SELECT v.code, k.nom FROM Agence_VOR v, TABLE(v.conseillers) k;` | A1 : 1 ; A2 : 2 ; A3 : 1. | Partie E — 12 | P1 |
| 59 | E12 — collections comptes | `SELECT v.code, c.num_compte, c.solde FROM Agence_VOR v, TABLE(v.comptes) c;` | A1 : CC4/CC7 ; A2 : CC2/CC5 ; A3 : CC3/CC6. | Partie E — 12 | P1 |
| 60 | E12 — mutation | Bloc `mutation` + requête des compteurs | A2 2→1, A3 1→2, puis restauration. | Partie E — 12 | P1 |
| 61 | E12 — erreurs attendues | Bloc mutation conseiller 1 vers A3, inconnu, agence inconnue | `ORA-20010`, `ORA-20011`. | Partie E — 12 | P2 |

> **Astuce :** la méthode `mutation` modifie l'état. Pour une capture, exécuter le bloc de test complet (avec les mutations de retour) ou utiliser `_FULL.out`.

---

## 7. Validation finale et rejeu

| N° | Titre | Commande / source | Ce qu'on doit voir | Où l'insérer | Priorité |
|---|---|---|---|---|---|
| 62 | 0 objet invalide | `SELECT object_name, object_type, status FROM user_objects WHERE status <> 'VALID';` | `aucune ligne sélectionnée`. | Validation | P1 |
| 63 | Nombre d'objets | `SELECT object_type, COUNT(*) FROM user_objects GROUP BY object_type;` | FUNCTION 3, INDEX 21, LOB 1, PROCEDURE 6, SEQUENCE 4, TABLE 12, TRIGGER 6, TYPE 26, TYPE BODY 6, VIEW 1. | Validation | P1 |
| 64 | Rejeu du script unique | `@projet_bdda_banque.sql` puis fin de sortie | `FIN DU SCRIPT UNIQUE - PARTIES A A E`, aucune erreur de compilation. | Validation | P1 |
| 65 | État final | Requêtes de comptage | 6 clients, 6 CC, 4 CE, 3 CT, 15 opérations, 9 signataires, 2 alertes. | Validation | P1 |
| 66 | Sortie complète | `_travail/_FULL.out` | Toutes les sections A→E. | Annexe | P2 |

---

## 8. Ordre de prise recommandé

1. **01–04** : environnement et UML.
2. **05–16** : partie A.
3. **17–23** : partie B.
4. **24–33** : partie C **avant** la partie D.
5. **34–53** : partie D.
6. **54–61** : partie E.
7. **62–66** : validation finale.

> **Si tu dois tout refaire :** exécute `partie_A_schema.sql`, `partie_B_manipulations.sql`, `partie_C_requetes.sql`, prends les captures de C, puis exécute `partie_D_programmation.sql` et `partie_E_objet_avance.sql`, et prends les captures de D/E. Termine par `projet_bdda_banque.sql` pour prouver le rejeu complet.

---

## 9. Checklist avant de rendre le PDF

- [ ] Chaque capture contient la commande **et** le résultat.
- [ ] Les accents et les chiffres sont lisibles.
- [ ] La partie C est capturée avant les suppressions de D.
- [ ] Les captures 6.24 et 6.25 sont présentes (ou justifiées par `_C.out`).
- [ ] La capture « 0 objet invalide » est présente.
- [ ] La capture du rejeu complet est présente.
- [ ] Les captures sont numérotées et référencées dans le texte du rapport.
- [ ] Le diagramme UML est présent.
- [ ] Les captures d'erreurs ORA sont légendées « erreur attendue ».
- [ ] Les captures ne montrent pas de données personnelles réelles (le jeu de données est fictif).

---

**Fin de la liste.**  
Pour les commandes détaillées et les réponses aux questions, voir `GUIDE_SOUTENANCE.md`.
