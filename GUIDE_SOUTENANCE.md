# Guide de soutenance — Mini-projet BDDA Banque

**Module :** BDDA — M1 ASR  
**Année :** 2026/2027  
**Sujet :** Gestion d'une banque (clients, comptes et opérations) avec Oracle relationnel-objet  
**Base :** Oracle Database 21c Express Edition, PDB `XEPDB1`  
**Utilisateur :** `MASTER1` — mot de passe utilisé en local : `system`  
**Connexion :** `sqlplus MASTER1/system@localhost:1521/XEPDB1`

> **But de ce guide.** Tu vas défendre un code que tu n'as pas forcément écrit ligne par ligne. Le jury ne veut pas t'entendre réciter du SQL : il veut vérifier que tu comprends **pourquoi** le schéma est ainsi, **ce que** chaque partie démontre, et **comment** tu réagis si on te demande de modifier ou d'expliquer un point. Ce guide te donne les réponses courtes, les réponses détaillées, les preuves dans les fichiers et les pièges à éviter.

> **Règle d'or.** Ne dis jamais « ça marche » sans montrer où. Dis plutôt : « Cela marche, voici la preuve : le script s'exécute sans objet invalide, et voici la sortie attendue. »

---

## Sommaire

1. [Fiche projet et mode d'emploi](#1-fiche-projet-et-mode-demploi)
2. [Architecture et choix de conception](#2-architecture-et-choix-de-conception)
3. [Partie A — Schéma et données](#3-partie-a--schéma-et-données)
4. [Partie B — Manipulations de données](#4-partie-b--manipulations-de-données)
5. [Partie C — Requêtes SQL](#5-partie-c--requêtes-sql)
6. [Partie D — Programmation PL/SQL](#6-partie-d--programmation-plsql)
7. [Partie E — Fonctionnalités objet avancées](#7-partie-e--fonctionnalités-objet-avancées)
8. [Démonstration de 10 minutes, Q&R et pièges](#8-démonstration-de-10-minutes-qr-et-pièges)

---

# 1. Fiche projet et mode d'emploi

## 1.1 Ce qu'il faut retenir en 30 secondes

Le projet implémente une banque avec :

- des **types objet** pour les clients, conseillers, agences, comptes et opérations ;
- de l'**héritage** : `compte_type` est une super-classe non instanciable, avec trois sous-types (`cptCourant_type`, `cptEpargne_type`, `cptTerme_type`) ;
- des **références `REF`** entre objets (client → conseiller, client → parrain, compte → agence, opération → compte) ;
- des **collections** : `VARRAY(3)` pour les téléphones, *nested table* pour les signataires, *nested table* de statistiques et `VARRAY(12)` pour les relevés mensuels ;
- des **méthodes** (dont un polymorphisme de `fraisTenue`) et des **triggers** de sécurité ;
- un **type récursif** (`ref_parrain REF client_type`) et une **vue objet** (`Agence_VOR`) avec une méthode `mutation`.

Le script unique `projet_bdda_banque.sql` rejoue les parties A → E. Il a été exécuté en entier : **0 objet invalide**, aucune erreur de compilation, et les seules erreurs `ORA-` sont des **tests d'exception volontaires**.

## 1.2 Livrables

| Fichier | Rôle | Exécuté ? |
|---|---|---|
| `00_creation_utilisateur.sql` | Script de création de l'utilisateur `MASTER1` (question 2) | **Non** — fourni, volontairement non exécuté |
| `partie_A_schema.sql` | Types, tables, contraintes, séquences, données, nettoyage/rejeu | Oui |
| `partie_B_manipulations.sql` | B5a à B5f + `change_Portable` + `drop_client` | Oui |
| `partie_C_requetes.sql` | Requêtes 6.1 à 6.25 | Oui |
| `partie_D_programmation.sql` | Sous-programmes, blocs 7a–7e, méthodes 8, triggers 9 | Oui |
| `partie_E_objet_avance.sql` | Type récursif, collections multi-niveaux, vue objet, mutation | Oui |
| `projet_bdda_banque.sql` | Concaténation A → E, rejouable en une commande | Oui |
| `purge_donnees.sql` | Suppression des données (`DELETE`), testée | Oui |
| `uml/banque.puml`, `uml/banque.mermaid`, `uml/banque.txt` | Diagramme de classes et version texte | — |
| `ETAPE_0_CADRAGE.md` | Hypothèses H1–H14 et choix de conception | — |
| `GUIDE_SOUTENANCE.md` | Ce guide | — |
| `CAPTURES_A_FAIRE.md` | Liste ordonnée des captures pour le rapport PDF | — |

> **Ce qu'il faut dire :** « Le script de création d'utilisateur est fourni séparément. Je ne me connecte jamais en SYSTEM ou SYS pour le projet : je travaille avec `MASTER1`, qui possède les objets. »

## 1.3 Commandes utiles

```sql
-- Connexion
sqlplus MASTER1/system@localhost:1521/XEPDB1

-- Rejouer tout le projet
SQL> @projet_bdda_banque.sql

-- Vérifier les objets invalides (aucune ligne attendue)
SQL> SELECT object_name, object_type, status
  2    FROM user_objects
  3   WHERE status <> 'VALID';

-- Vérifier les types métier
SQL> SELECT type_name, typecode FROM user_types ORDER BY type_name;

-- Vérifier les tables
SQL> SELECT table_name FROM user_tables ORDER BY table_name;

-- Purger uniquement les données (garder le schéma)
SQL> @purge_donnees.sql
```

> **Attention :** `projet_bdda_banque.sql` commence par supprimer les objets existants. C'est ce qui le rend rejouable, mais cela efface les données précédentes. Ce n'est pas un script de production : c'est un script de régénération de TP.

## 1.4 Ce qu'il ne faut pas dire

- « J'ai tout fait dans un seul fichier, sans parties. » → Faux : il y a cinq parties A–E, plus un script unique de confort.
- « Je me connecte en SYSTEM pour créer les objets. » → Faux : le projet tourne sous `MASTER1`. Le script `00_creation_utilisateur.sql` est fourni pour la question 2, mais il n'est pas exécuté dans la démonstration.
- « Les erreurs ORA sont des bugs. » → Faux : ce sont des **refus volontaires** testés dans des blocs `BEGIN ... EXCEPTION`. Il faut savoir lesquelles et pourquoi.
- « J'ai utilisé `CARDINALITY` partout. » → Faux : `CARDINALITY` fonctionne sur les *nested tables*, mais pas sur les `VARRAY` dans cette version d'Oracle (`ORA-00932`). Pour les VARRAY, on passe par `TABLE(...)` et `COUNT(*)`.

## 1.5 Plan B si la base ne répond pas

1. Montrer `_travail/_FULL.out` : la sortie complète du script, avec les résultats et le contrôle final.
2. Montrer les captures d'écran préparées (`CAPTURES_A_FAIRE.md`).
3. Montrer le diagramme UML et expliquer les choix.
4. Proposer de rejouer seulement une partie (A, B ou C) si la base est disponible mais lente.

> **Phrase de secours :** « La base de démonstration n'est pas disponible, mais la sortie complète du script est dans `_FULL.out`. Je peux vous montrer le contrôle final : zéro objet invalide, et les erreurs ORA visibles sont toutes des tests d'exception. »

---

# 2. Architecture et choix de conception

## 2.1 Vue d'ensemble

```text
                 +-------------------+
                 |   conseiller_type |
                 +-------------------+
                          ^ 1
                          | *
+----------------+   +-------------------+   +----------------+
|  agence_type   |1  |    client_type    |*  |  compte_type   |
|  ref_responsable|--|  ref_conseiller   |---|  (NOT FINAL,   |
+----------------+   |  ref_parrain      |   |  NOT INSTANT.) |
        ^ 1          |  adresse_type     |   +----------------+
        |            |  tel_vry_type     |       ^       ^
        | *          +-------------------+       |       |
+----------------+                                 |       |
|   affectation  |  (historique conseiller/agence) |       |
+----------------+                                 |       |
                                          +--------+  +----+-----+
                                          |cptCourant| |cptEpargne|
                                          |  + signa | |          |
                                          +----------+ +----------+
                                               | 1
                                               | *
                                          +----------+
                                          |operation |
                                          +----------+
```

Le diagramme complet est dans `uml/banque.puml` (PlantUML), `uml/banque.mermaid` (Mermaid) et `uml/banque.txt` (version texte, utile si l'outil de rendu n'est pas disponible).

## 2.2 Tables objet et tables relationnelles : le partage

| Élément | Implémentation | Pourquoi |
|---|---|---|
| `conseiller`, `agence`, `client` | Tables **objet** (`CREATE TABLE ... OF ...`) | Ce sont des entités avec des `REF`, des méthodes et des attributs structurés. |
| `cpt_courant`, `cpt_epargne`, `cpt_terme` | Tables **objet**, une par sous-type | Le sujet interdit le compte générique ; chaque sous-type a ses attributs propres. |
| `operation` | Table **objet** | Elle référence un compte courant par `REF` et porte la logique de commission. |
| `affectation` | Table **relationnelle** | C'est une association datée (historique), pas une entité objet. |
| `alerte`, `"AUDIT"` | Tables **relationnelles** | Journaux/alertes, sans besoin de `REF` ni de méthodes. |
| `releves` | Table **relationnelle** avec colonne `VARRAY` | Agrégat annuel multi-niveaux, pas une entité objet. |
| `signataires` | *Nested table* dans `cptCourant_type` | Collection d'objets `signataire_elt_nt_type`, stockée dans `signataire_nt_st`. |

> **Question probable :** « Pourquoi ne pas tout faire en relationnel ? »  
> **Réponse :** Le sujet impose les types objet, l'héritage, les `REF`, les collections, les méthodes, le type récursif et les vues objet. Le modèle relationnel pur ne permettrait pas de démontrer ces mécanismes. On garde néanmoins du relationnel là où c'est plus simple (historique, alertes, audit).

## 2.3 Héritage des comptes

```sql
CREATE TYPE compte_type AS OBJECT (
  num_compte    VARCHAR2(10),
  solde         NUMBER(14,2),
  statut        VARCHAR2(10),
  date_ouverture DATE,
  ref_client    REF client_type,
  ref_agence    REF agence_type,
  MEMBER FUNCTION fraisTenue RETURN NUMBER
) NOT FINAL NOT INSTANTIABLE;
```

- `NOT FINAL` : la classe peut être héritée.
- `NOT INSTANTIABLE` : on ne peut pas créer un `compte_type` « nu ». C'est exactement la règle métier : **la banque ne gère jamais de compte générique**.
- Les sous-types sont `cptCourant_type`, `cptEpargne_type`, `cptTerme_type`.
- `fraisTenue` est déclarée dans la super-classe et **redéfinie** dans les sous-types avec `OVERRIDING`.

> **Pourquoi `fraisTenue` est-elle déclarée dès le `CREATE TYPE` ?**  
> Parce qu'`ALTER TYPE ... ADD MEMBER` ne permet pas de créer un *override* (erreur `ORA-22324` / `PLS-00636`). On déclare donc la méthode dans la super-classe au moment de la création, puis on écrit les corps avec `OVERRIDING MEMBER FUNCTION fraisTenue`.

## 2.4 Références et intégrité

- Un `REF` est un **pointeur** vers un objet.
- Les clés étrangères sur les colonnes/attributs `REF` sont **supportées et vérifiées** par Oracle.
- `client_type.ref_parrain REF client_type` est un **type récursif** : un client peut parrainer d'autres clients.
- `agence_type.ref_responsable REF conseiller_type` : chaque agence a un responsable.
- `affectation` relie un conseiller et une agence avec `date_debut` / `date_fin` : un conseiller peut changer d'agence, on garde l'historique.

> **Pourquoi ne pas mettre `ref_agence` directement dans `conseiller_type` ?**  
> Parce qu'un conseiller peut être muté. Un attribut unique dans le conseiller écraserait l'historique. La table `affectation` permet plusieurs lignes datées et une ligne ouverte (`date_fin IS NULL`).

## 2.5 Collections

| Collection | Type | Stockage | Utilisation |
|---|---|---|---|
| Téléphones | `tel_vry_type VARRAY(3) OF VARCHAR2(20)` | Inline dans `client` | Jusqu'à 3 numéros, éléments éventuellement `NULL`. |
| Signataires | `signataire_nt_type TABLE OF signataire_elt_nt_type` | `NESTED TABLE ... STORE AS signataire_nt_st` | Droits `X`, `R`, `D` sur un compte courant. |
| Statistiques | `type_stat_nt_type TABLE OF type_stat_elt_nt_type` | Dans `mois_elt_vry_type` | Nombre et montant par type d'opération. |
| Mois | `mois_vry_type VARRAY(12) OF mois_elt_vry_type` | Dans `releves` | 12 mois d'un relevé annuel. |
| Conseillers d'une agence | `conseiller_nt_type TABLE OF conseiller_type` | Vue objet `Agence_VOR` | Collection calculée par `CAST(MULTISET(...))`. |
| Comptes d'une agence | `cptCourant_nt_type TABLE OF cptCourant_type` | Vue objet `Agence_VOR` | Collection calculée par `CAST(MULTISET(...))`. |

> **Pourquoi une *nested table* pour les signataires et un `VARRAY` pour les téléphones ?**  
> Le nombre de signataires n'est pas borné par le sujet (et peut évoluer) : une *nested table* est plus adaptée. Les téléphones sont limités à 3 : un `VARRAY(3)` impose la limite et permet l'accès par indice (`telephones(2)`).

## 2.6 Méthodes et polymorphisme

- `fraisTenue` : 1 200 DA pour un compte courant, 0 pour épargne et terme. C'est le polymorphisme : le même appel `c.fraisTenue()` donne un résultat différent selon le sous-type.
- `nbCepargne`, `soldeTotal`, `afficheInterets`, `supprimeTel` : méthodes de `client_type`.
- `nbSignataire` (deux surcharges), `estTitulaire`, `estSignataire`, `supprimeSign`, `peutRetirer`, `passeMvt` : méthodes de `cptCourant_type`.
- `calculeInterets`, `sortieAnticipee` : méthodes de `cptEpargne_type` et `cptTerme_type`.
- `fermeCompte` : **procédure statique** de `compte_type` (elle ne s'applique pas à une instance, mais à un numéro de compte).
- `mutation` : méthode de la vue objet `agence_vor_type`.

> **Membre, statique, catalogué : quelle différence ?**  
> - **Membre** : appelée sur une instance (`c.nbCepargne()`), elle peut lire `SELF`.
> - **Statique** : appelée sur le type (`compte_type.fermeCompte('CC1')`), elle ne dépend pas d'une instance.
> - **Cataloguée** : procédure/fonction autonome (`virement(...)`, `drop_client(...)`), utilisable hors d'un type.

## 2.7 Triggers : où et pourquoi

| Trigger | Événement | Rôle |
|---|---|---|
| `trg_op_avant` | `BEFORE INSERT` sur `operation`, **COMPOUND** | Vérifie statut, droits, plafond journalier, découvert. |
| `trg_op_apres` | `AFTER INSERT` sur `operation` | Met à jour le solde, `nb_op_cb`, crée les alertes. |
| `trg_ct_echeance` | `AFTER INSERT OR UPDATE OF date_echeance` sur `cpt_terme` | Crée une alerte `ECHEANCE_PROCHE` ou `ECHEANCE_DEPASSEE`. |
| `trg_audit_taux` | `AFTER UPDATE OF taux_interet` sur `cpt_epargne` | Trace l'ancien/nouveau taux dans `"AUDIT"`. |
| `trg_audit_taux_terme` | `AFTER UPDATE OF taux_garanti` sur `cpt_terme` | Trace l'ancien/nouveau taux garanti. |
| `trg_audit_decouvert` | `AFTER UPDATE OF decouvert` sur `cpt_courant` | Trace l'ancien/nouveau découvert. |

> **Pourquoi un trigger COMPOUND pour `trg_op_avant` ?**  
> Parce qu'un trigger ligne par ligne qui interroge `operation` (la table en cours de modification) provoque `ORA-04091` (table mutante). Le trigger COMPOUND sépare :
> - `BEFORE STATEMENT` : on prend un instantané des retraits du jour ;
> - `BEFORE EACH ROW` : on accumule le montant de la ligne courante ;
> - on ne relit jamais `operation` dans la partie ligne par ligne.

## 2.8 Vue objet

`Agence_VOR` est une vue objet de type `agence_vor_type`. Elle expose :

- les attributs de l'agence (`code`, `nom`, `ville`, `ref_responsable`) ;
- une collection `conseillers` (les conseillers actuellement affectés) ;
- une collection `comptes` (les comptes courants de l'agence) ;
- une méthode `mutation` pour changer un conseiller d'agence.

Elle est construite avec `CAST(MULTISET(...))` et `MAKE_REF(agence, a.code)`. Le `MAKE_REF` est possible parce que la table `agence` a un `OBJECT IDENTIFIER IS PRIMARY KEY`.

## 2.9 Tableau des choix à défendre

| Choix | Justification | Alternative rejetée |
|---|---|---|
| Une table par sous-type de compte | Chaque sous-type a ses attributs ; pas de colonnes nulles inutiles ; le sujet interdit le compte générique. | Une seule table `compte` avec un discriminant et des colonnes nullables. |
| `client` avec OID système | Un `REF` basé sur la PK ne peut pas être inséré dans une *nested table* (`ORA-22979`). | `OBJECT IDENTIFIER IS PRIMARY KEY` sur `client` → blocage des signataires. |
| `agence` avec OID basé sur la PK | Nécessaire pour `MAKE_REF(agence, a.code)` dans la vue objet. | OID système → `MAKE_REF` impossible. |
| `affectation` relationnelle | Historique daté, plusieurs lignes par conseiller. | Attribut `ref_agence` unique dans `conseiller_type`. |
| `ref_parrain` ajouté par `ALTER TYPE` | Le sujet demande le parrainage ; cela montre aussi l'évolution d'un type. | Recréer `client_type` from scratch → perte des dépendances. |
| `CHECK(ref_client IS NOT NULL) DEFERRABLE` | B5b insère un compte sans titulaire puis le met à jour. | `NOT NULL` immédiat → B5b impossible. |
| Trigger sur `operation`, pas sur la *nested table* | Oracle interdit les triggers sur le stockage d'une *nested table* (`ORA-22812`). | Trigger sur `signataire_nt_st` → impossible. |
| `virement` sans `COMMIT` | Le appelant doit pouvoir enchaîner ou annuler. | `COMMIT` interne → impossible de tester le rollback global. |
| `fermeCompte` avec `COMMIT` | C'est une opération de clôture définitive, testée en dernier. | Pas de `COMMIT` → la suppression ne persiste pas. |
| `date_fin = GREATEST(SYSDATE, date_debut) + 1/86400` | Évite `ORA-02290` sur `CK_AFF_DATES` lors d'une mutation le même jour. | `date_fin = SYSDATE` → `date_fin <= date_debut` possible. |

---

# 3. Partie A — Schéma et données

## 3.1 Les types métier

| Type | Nature | Rôle |
|---|---|---|
| `adresse_type` | Object | `num_rue`, `rue`, `ville`, `code_postal`. |
| `tel_vry_type` | VARRAY(3) | Téléphones d'un client. |
| `conseiller_type` | Object | `num_conseiller`, `nom`, `prenom`, `specialite`. |
| `agence_type` | Object | `code`, `nom`, `ville`, `ref_responsable`. |
| `client_type` | Object | Identité, adresse, téléphones, conseiller, parrain. |
| `signataire_elt_nt_type` | Object | `ref_client REF client_type`, `droit CHAR(1)`. |
| `signataire_nt_type` | Nested table | Collection de signataires. |
| `compte_type` | Object, NOT FINAL NOT INSTANTIABLE | Super-classe des comptes. |
| `cptCourant_type` | Object UNDER `compte_type` | Découvert, `nb_op_cb`, signataires (nested table) ; opérations via la table `operation`. |
| `cptEpargne_type` | Object UNDER `compte_type` | Taux d'intérêt, plafond de dépôt. |
| `cptTerme_type` | Object UNDER `compte_type` | Montant bloqué, durée, échéance, taux garanti. |
| `operation_type` | Object | Opération sur un compte courant. |
| `conseiller_nt_type` | Nested table | Collection de conseillers pour la vue objet. |
| `cptCourant_nt_type` | Nested table | Collection de comptes courants pour la vue objet. |
| `type_stat_elt_nt_type` | Object | `type_op`, `nb`, `montant_total`. |
| `type_stat_nt_type` | Nested table | Collection de statistiques. |
| `mois_elt_vry_type` | Object | `mois`, `nb_operations`, `types`. |
| `mois_vry_type` | VARRAY(12) | Mois d'un relevé annuel. |
| `agence_vor_type` | Object (Partie E) | Type de la vue objet `Agence_VOR`. |

> **À retenir :** 18 types créés en partie A, plus `agence_vor_type` en partie E, soit 19 types métier dans `USER_TYPES`. Dans `USER_OBJECTS`, on voit 26 lignes de type `TYPE` : il y a des types internes `SYS_YOID...` créés par Oracle et une version supplémentaire de `CLIENT_TYPE` due à l'évolution `ALTER TYPE ... ADD ATTRIBUTE`. Ce n'est pas une erreur.

## 3.2 Les tables

| Table | Type | Contenu |
|---|---|---|
| `conseiller` | Objet | 4 conseillers. |
| `agence` | Objet | 3 agences. |
| `affectation` | Relationnelle | Historique conseiller/agence. |
| `client` | Objet | 6 clients. |
| `cpt_courant` | Objet | 7 comptes courants au départ, 6 après les tests destructifs. |
| `cpt_epargne` | Objet | 5 comptes d'épargne au départ, 4 après `fermeCompte('CE4')`. |
| `cpt_terme` | Objet | 4 comptes à terme au départ, 3 après la requête 6.25. |
| `operation` | Objet | 20 opérations au départ, 15 après la suppression de CC1. |
| `alerte` | Relationnelle | Alertes d'échéance et de solde. |
| `"AUDIT"` | Relationnelle | Journal des modifications de taux/découvert. |
| `releves` | Relationnelle + VARRAY | Relevé annuel multi-niveaux. |
| `signataire_nt_st` | Stockage de *nested table* | Table physique créée par `NESTED TABLE ... STORE AS`. |

> **Pourquoi `"AUDIT"` est-il entre guillemets ?**  
> Parce que `AUDIT` est un mot réservé Oracle. Sans guillemets, `CREATE TABLE AUDIT` échoue. On écrit donc `"AUDIT"` partout (création, insertion, select).

## 3.3 Contraintes et valeurs par défaut

| Contrainte | Table | Rôle |
|---|---|---|
| PK sur `num_client`, `num_conseiller`, `code`, etc. | Toutes | Identifiants. |
| `UNIQUE(num_secu)` | `client` | Un numéro de sécurité sociale unique. |
| `CHECK(ref_client IS NOT NULL)` | `cpt_courant`, `cpt_epargne`, `cpt_terme` | Un compte doit avoir un titulaire. Sur `cpt_courant` seulement, la contrainte est `DEFERRABLE INITIALLY DEFERRED` pour B5b. |
| `CHECK(droit IN ('X','R','D'))` | `signataire_nt_st` | Domaine des droits. |
| `CHECK(statut IN ('ACTIF','BLOQUE','DORMANT'))` | Comptes | Domaine du statut. |
| `CHECK(type_op IN ('DEPOT','RETRAIT','VIREMENT','CB'))` | `operation` | Domaine du type d'opération. |
| `CHECK(taux_interet >= 0 AND taux_interet < 3.5)` | `cpt_epargne` | Limite du taux d'épargne. |
| `CHECK(duree_mois IN (6,12,24,36))` | `cpt_terme` | Durées autorisées. |
| `CHECK(decouvert >= 0)` | `cpt_courant` | Découvert positif ou nul. |
| `DEFAULT SYSDATE` | `operation.date_op` | Date d'opération par défaut. |
| `DEFAULT 'ACTIF'` | `statut` des comptes | Statut par défaut. |
| FK sur les `REF` | Comptes, opérations, agence | Intégrité référentielle. |

> **Pourquoi la contrainte `ref_client IS NOT NULL` est-elle `DEFERRABLE` ?**  
> Parce que B5b insère volontairement un compte `CC99` **sans titulaire**, puis le met à jour avant le `COMMIT`. Une contrainte immédiate refuserait l'insertion. La contrainte différée vérifie au moment du `COMMIT`.

## 3.4 Séquences

| Séquence | Utilisation |
|---|---|
| `seq_operation` | Identifiants d'opération. |
| `seq_alerte` | Identifiants d'alerte. |
| `seq_audit` | Identifiants d'audit. |
| `seq_affectation` | Identifiants d'affectation. |

## 3.5 Jeu de données initial

| Élément | Quantité | Détail |
|---|---|---|
| Agences | 3 | A1 Bejaia Centre, A2 Alger Grande Poste, A3 Oran Front de Mer. |
| Conseillers | 4 | BENALI Karim, HAMDI Sara, TOUATI Yacine, KACI Nadia. |
| Clients | 6 | AMRANI Ali, BENALI Samia, CHERIF Mohamed, DJEBBAR Lina, HADDAD Omar, ZERROUKI Nour. |
| Comptes courants | 7 | CC1 à CC7, dont CC5 `BLOQUE`. |
| Comptes d'épargne | 5 | CE1 à CE5, dont CE2 à taux 3,49 (proche de la limite 3,5). |
| Comptes à terme | 4 | CT1 à CT4 ; CT4 a un montant 0 et une échéance > 1 an pour la suppression 6.25. |
| Opérations | 20 | Dépôts, retraits, virements, CB. |
| Signataires | 10 | Droits `X`, `R`, `D` sur au moins 4 comptes. |

> **Pourquoi un 4e compte à terme `CT4` ?**  
> Pour que la requête 6.25 ait quelque chose à supprimer : `CT4` a `montant_bloque = 0` et une échéance de plus d'un an. Les autres comptes à terme ont un montant bloqué > 0 et ne doivent pas être supprimés.

## 3.6 Rejeu et purge

Le début de `partie_A_schema.sql` contient le nettoyage :

```sql
DROP VIEW Agence_VOR;
DROP TABLE releves CASCADE CONSTRAINTS PURGE;
DROP TABLE "AUDIT" CASCADE CONSTRAINTS PURGE;
DROP TABLE alerte CASCADE CONSTRAINTS PURGE;
DROP TABLE operation CASCADE CONSTRAINTS PURGE;
DROP TABLE cpt_terme CASCADE CONSTRAINTS PURGE;
DROP TABLE cpt_epargne CASCADE CONSTRAINTS PURGE;
DROP TABLE cpt_courant CASCADE CONSTRAINTS PURGE;
DROP TABLE client CASCADE CONSTRAINTS PURGE;
DROP TABLE affectation CASCADE CONSTRAINTS PURGE;
DROP TABLE agence CASCADE CONSTRAINTS PURGE;
DROP TABLE conseiller CASCADE CONSTRAINTS PURGE;
DROP SEQUENCE seq_operation;
DROP SEQUENCE seq_alerte;
DROP SEQUENCE seq_audit;
DROP SEQUENCE seq_affectation;
DROP TYPE agence_vor_type FORCE;
DROP TYPE mois_vry_type FORCE;
DROP TYPE mois_elt_vry_type FORCE;
DROP TYPE type_stat_nt_type FORCE;
DROP TYPE type_stat_elt_nt_type FORCE;
DROP TYPE cptCourant_nt_type FORCE;
DROP TYPE conseiller_nt_type FORCE;
DROP TYPE operation_type FORCE;
DROP TYPE cptTerme_type FORCE;
DROP TYPE cptEpargne_type FORCE;
DROP TYPE cptCourant_type FORCE;
DROP TYPE compte_type FORCE;
DROP TYPE signataire_nt_type FORCE;
DROP TYPE signataire_elt_nt_type FORCE;
DROP TYPE client_type FORCE;
DROP TYPE agence_type FORCE;
DROP TYPE conseiller_type FORCE;
DROP TYPE tel_vry_type FORCE;
DROP TYPE adresse_type FORCE;
```

- On supprime d'abord la vue, puis les tables, puis les séquences, puis les types.
- `purge_donnees.sql` utilise `DELETE`, pas `TRUNCATE` : les tables objet et les `REF` se prêtent mieux à un `DELETE` contrôlé, et cela préserve la structure.
- Le script unique `projet_bdda_banque.sql` est une **concaténation physique** A → B → C → D → E, pas un script d'inclusion `@`. Cela évite les problèmes de chemin et permet de le déposer seul.

> **Question probable :** « Si je relance le script, est-ce que je perds les données ? »  
> **Réponse :** Oui, le script est un script de régénération de TP. Il supprime et recrée tout. Ce n'est pas un script de production. La purge séparée `purge_donnees.sql` permet de vider les données sans toucher au schéma.

## 3.7 Pièges de la partie A

| Piège | Symptôme | Solution |
|---|---|---|
| `CREATE TYPE` direct dans SQL*Plus | La session se ferme silencieusement. | Utiliser `BEGIN EXECUTE IMMEDIATE q'[...]'; END; /`. |
| Ligne terminée par `-` | SQL*Plus la prend pour une continuation. | Éviter les lignes qui finissent par `-`. |
| `AUDIT` sans guillemets | `ORA-00903: nom de table non valide`. | Écrire `"AUDIT"`. |
| `ALTER TABLE` pour ajouter un attribut à une table objet | `ORA-22856`. | Utiliser `ALTER TYPE ... ADD ATTRIBUTE ... CASCADE`. |
| Contrainte de même nom sur deux tables | `ORA-02264`. | Les noms de contraintes sont uniques dans le schéma : préfixer. |
| `REF` basé sur la PK dans une *nested table* | `ORA-22979`. | Garder l'OID système pour `client`. |
| `CARDINALITY` sur un VARRAY | `ORA-00932`. | Utiliser `TABLE(...)` + `COUNT(*)`. |

---

# 4. Partie B — Manipulations de données

## 4.1 Les six manipulations B5a–B5f

| Bloc | Action | Technique démontrée | Résultat attendu |
|---|---|---|---|
| B5a | Ajout du client 99 `OUKACI Ahmed` | Insertion d'un client avec un `VARRAY` d'un seul téléphone. | 1 ligne créée. |
| B5b | Création de `CC99` sans titulaire, puis `UPDATE` | Contrainte `REF IS NOT NULL` **différée sur `cpt_courant`**. | Insertion acceptée, puis mise à jour, puis `COMMIT`. |
| B5c | Opération de 50 000 DA sans date | `DEFAULT SYSDATE` sur `date_op`. | La date du jour est automatiquement mise. |
| B5d | Signataire de droit `D` sur `CC99` | `INSERT INTO TABLE(SELECT signataires ...)`. | 1 signataire ajouté dans la *nested table*. |
| B5e | `change_Portable` | Mise à jour d'un élément de `VARRAY` avec gestion de `NULL`, 1, 2 ou 3 éléments. | Client 99 : 1 → 2 téléphones ; client 3 : 2e téléphone = `0777-11-22-33`. |
| B5f | `drop_client(99)` | Suppression en cascade applicative : opérations, signataires, filleuls, comptes, client. | Client 99 supprimé, aucun orphelin. |

> **Ce que B5b démontre exactement :** on peut insérer un compte courant sans titulaire **à l'intérieur d'une transaction**, puis le mettre à jour avant le `COMMIT`. La contrainte `ck_cc_client` est différée et vérifiée à la validation. C'est un cas typique de contrainte différée.

## 4.2 `change_Portable` : logique

La procédure :

1. lit le `VARRAY` de téléphones du client ;
2. si le `VARRAY` est `NULL` ou vide, elle le recrée avec deux éléments `(NULL, paramtel)` ;
3. si `COUNT = 1`, elle fait `EXTEND` puis affecte l'indice 2 ;
4. si `COUNT >= 2`, elle remplace directement l'élément 2 ;
5. elle gère `NO_DATA_FOUND` pour un client inexistant ;
6. elle fait `COMMIT` en succès et `ROLLBACK` en erreur : c'est une opération autonome de mise à jour d'un téléphone.

> **Pourquoi ne pas écrire `telephones(2) := ...` sans vérifier `COUNT` ?**  
> Parce que si le `VARRAY` n'a qu'un élément, `telephones(2)` lève `ORA-06533` (indice hors limites). Il faut `EXTEND` avant.

## 4.3 `drop_client` : logique

La procédure supprime, dans l'ordre :

1. les opérations du client et celles de ses comptes ;
2. les lignes de signataire qui le référencent dans les autres comptes ;
3. met à `NULL` le `ref_parrain` des clients qu'il parrainait ;
4. supprime ses comptes à terme, d'épargne et courants ;
5. supprime le client.

Elle fait `COMMIT` en cas de succès et `ROLLBACK` dans le `WHEN OTHERS`. Elle affiche un message si le client n'existe pas.

> **Pourquoi ce `COMMIT` alors que `virement` n'en fait pas ?**  
> `drop_client` est une opération de gestion autonome : elle doit persister. `virement` est une brique réutilisable : c'est l'appelant qui décide de valider ou d'annuler. Les deux choix sont cohérents avec leur usage.

## 4.4 Résultats à montrer

- B5a : `SELECT * FROM client WHERE num_client = 99;` → `OUKACI Ahmed`.
- B5b : `CC99` sans titulaire, puis `UPDATE`, puis `COMMIT`.
- B5c : `SELECT date_op FROM operation WHERE ...` → date du jour.
- B5d : `SELECT ... FROM TABLE(SELECT signataires ...)` → droit `D`.
- B5e : `SELECT ... FROM TABLE(c.telephones)` → client 3 a `0777-11-22-33` en 2e position.
- B5f : `SELECT COUNT(*) FROM client WHERE num_client = 99;` → 0.

> **Preuve :** `_travail/_FULL.out`, section « PARTIE_B_MANIPULATIONS.SQL » ; ou `_travail/_B.out`.

## 4.5 Pièges de la partie B

| Piège | Symptôme | Solution |
|---|---|---|
| `VARRAY` à 1 élément | `ORA-06533` sur l'indice 2. | Vérifier `COUNT`, puis `EXTEND`. |
| Insertion d'un signataire | `ORA-22979` si le `REF` est basé sur la PK. | Garder l'OID système pour `client`. |
| Suppression d'un client référencé | `ORA-02292` (FK). | Supprimer d'abord les dépendances ou les mettre à `NULL`. |
| `COMMIT` au mauvais moment | Le test de rollback ne fonctionne plus. | Ne pas `COMMIT` dans `virement` ; `COMMIT` dans `drop_client`. |

---

# 5. Partie C — Requêtes SQL

## 5.1 Les 25 requêtes

| N° | Thème | Technique clé | Résultat clé (au moment de C) |
|---|---|---|---|
| 6.1 | Fiche client sans afficher les téléphones | `SELECT` avec formats `COLUMN` | 6 clients. |
| 6.2 | Comptes courants | `REF` déréférencé | 7 CC, dont CC1 à 2 498 500. |
| 6.3a | Épargne triée par taux | `ORDER BY taux_interet DESC` | CE2 en tête (3,49). |
| 6.3b | Comptes à terme | `SELECT` simple | 4 CT. |
| 6.4 | CC du client 4 | Jointure implicite | CC4 et CC7. |
| 6.5 | Tous les comptes du client 4 | `UNION` CC + CE + CT | CC4, CC7, CE4. |
| 6.6 | Clients + CC < 100 000 | Jointure + filtre | CC2, CC3, CC5, CC6. |
| 6.7a | Clients avec au moins un CE | `EXISTS` / jointure | Clients 1, 2, 3, 4. |
| 6.7b | Clients avec un seul CE | `GROUP BY ... HAVING COUNT(*) = 1` | Clients 2, 3, 4. |
| 6.8 | Clients ayant opéré sur CC7 | Jointure `operation` | Clients 2, 3, 4. |
| 6.9a | Opérations CC7 par le propriétaire | `o.ref_client = cc.ref_client` | Opérations de client 4. |
| 6.9b | Opérations CC7 par non-propriétaires | `o.ref_client <> cc.ref_client` | Opérations de clients 1/2. |
| 6.10 | CC à solde négatif + titulaire + conseiller | Jointures + `solde < 0` | CC2 : -50 000. |
| 6.11a | Nombre de CE par client | `GROUP BY` | 4 lignes : 2, 1, 1, 1 (clients 1 à 4). |
| 6.11b | Idem avec clients sans CE | `LEFT JOIN` / `NVL` | 6 lignes, dont 0. |
| 6.12 | Client avec le plus de CE | Sous-requête + `HAVING` | Client 1 (2 CE). |
| 6.13 | Par type : nombre et montant moyen | `GROUP BY type_op` | 20 opérations au moment de C. |
| 6.14 | Total des soldes par agence | `UNION ALL` CC + CE | A1 : 3 478 500 ; A2 : 700 000 ; A3 : 158 000. |
| 6.15 | Top 3 clients par solde total | `ORDER BY ... FETCH FIRST 3 ROWS` | Client 1 : 3 348 500 ; client 4 : 830 000 ; client 2 : 300 000. |
| 6.16a | Téléphones du client 1 | `TABLE(c.telephones)` | 3 éléments, 2 renseignés. |
| 6.16b | Téléphones de tous les clients | `TABLE` + jointure | 6 clients. |
| 6.17 | Numéros de téléphone de chaque client | `TABLE(c.telephones)` + `NVL` | 6 clients, 3 éléments chacun, certains `<non renseigne>`. |
| 6.18a | Nombre de signataires de CC7 | `COUNT(*)` sur `TABLE(SELECT signataires ...)` | 3. |
| 6.18b | Nombre de signataires par CC | Sous-requête scalaire `COUNT(*)` sur `TABLE(cc.signataires)` | CC1:1, CC2:1, CC3:2, CC4:3, CC5:0, CC6:0, CC7:3. |
| 6.19a | Signataires de CC7 | `TABLE` | 3 lignes. |
| 6.19b | Signataires de tous les CC | `TABLE` + jointure | Tous les comptes. |
| 6.19c | Idem avec curseur imbriqué | Curseur paramétré + `FOR` | Affichage par compte. |
| 6.20 | Signataires de CC7 + adresse | `TABLE` + `s.ref_client = REF(c)` | Clients 2 (D), 3 (X), 5 (R). |
| 6.21a | Clients par ville | `ORDER BY adresse.ville` | Bejaia, Alger, Oran. |
| 6.21b | Clients de Bejaia | `WHERE adresse.ville = 'Bejaia'` | Clients 1 et 4. |
| 6.22 | CT à échéance dans 30 jours | `BETWEEN SYSDATE AND SYSDATE+30` | CT2 (5 jours), CT1 (20 jours). |
| 6.23 | CC sans opération depuis 12 mois | `NOT EXISTS` + sous-requête | CC5 et CC6. |
| 6.24 | Opérations > 1 000 000 DA | Filtre `montant > 1000000` | Opération 1 500 000 sur CC1. |
| 6.25 | Suppression CT expirés > 1 an, montant 0 | `DELETE` + `ADD_MONTHS` | CT4 supprimé. |

> **Attention à la chronologie :** la partie C s'exécute **avant** les tests destructifs de la partie D. C'est pour cela que 6.2 montre encore CC1, que 6.13 compte 20 opérations et que 6.24 trouve l'opération de 1 500 000 DA. Après la partie D, CC1 et ses 5 opérations sont supprimés, et CE4 est supprimé. Si tu refais les captures après avoir tout exécuté, ces résultats ne seront plus visibles. Il faut soit capturer la sortie de C avant D, soit utiliser `_C.out` / `_FULL.out`.

## 5.2 Techniques à savoir expliquer

### Déréférencement d'attributs

```sql
SELECT c.num_client, c.nom, c.adresse.ville, c.ref_conseiller.nom
  FROM client c;
```

- Il faut un **alias de table** (`c`) pour déréférencer un attribut objet.
- `ref_parrain.num_client` sans alias échoue avec `ORA-00904`.
- Pour le parrain du parrain : `c.ref_parrain.ref_parrain.nom`.

### Interroger un VARRAY

```sql
SELECT c.num_client, t.COLUMN_VALUE AS telephone
  FROM client c, TABLE(c.telephones) t
 WHERE c.num_client = 1;
```

- `TABLE(...)` transforme la collection en lignes.
- `COUNT(*)` compte les emplacements du `VARRAY` ; `COUNT(COLUMN_VALUE)` ne compte que les valeurs non `NULL`.
- `CARDINALITY` ne fonctionne pas sur un `VARRAY` dans cette version (`ORA-00932`).

### Interroger une nested table

```sql
SELECT cc.num_compte, s.ref_client.nom, s.droit
  FROM cpt_courant cc, TABLE(cc.signataires) s
 WHERE cc.num_compte = 'CC7';
```

- `CARDINALITY(cc.signataires)` donne le nombre d'éléments ; les requêtes 6.18a/b utilisent `COUNT(*)` pour rester homogènes avec le reste du script.
- `TABLE(cc.signataires)` permet le détail.
- Pour joindre au client : `s.ref_client = REF(c)`.

### Agrégats et classements

- `GROUP BY ... HAVING COUNT(*) = 1` pour les clients avec un seul CE.
- `ORDER BY ... FETCH FIRST 3 ROWS ONLY` pour le top 3.
- `UNION ALL` pour additionner CC + CE dans le total par agence (6.14) ; 6.15 ajoute aussi les CT pour le solde total par client.

### `NOT EXISTS`

```sql
SELECT cc.num_compte
  FROM cpt_courant cc
 WHERE NOT EXISTS (
   SELECT 1 FROM operation o
    WHERE o.ref_compte = REF(cc)
      AND o.date_op > ADD_MONTHS(TRUNC(SYSDATE), -12)
 );
```

- `NOT EXISTS` est plus robuste que `NOT IN` en présence de `NULL`.
- La sous-requête corrélée utilise `REF(cc)`.

## 5.3 Résultats à montrer en priorité

1. **6.10** : CC2 à -50 000, avec titulaire et conseiller.
2. **6.15** : top 3 clients (1 : 3 348 500 ; 4 : 830 000 ; 2 : 300 000).
3. **6.16a** : téléphones du client 1 (3 éléments, 2 renseignés).
4. **6.18a** : CC7 a 3 signataires.
5. **6.20** : signataires de CC7 avec adresse complète — clients 2 (D), 3 (X), 5 (R).
6. **6.22** : CT2 à 5 jours, CT1 à 20 jours.
7. **6.24** : opération de 1 500 000 DA (avant suppression de CC1).
8. **6.25** : CT4 supprimé, les autres CT restent.

> **Preuve :** `_travail/_C.out` ou `_FULL.out`, section « PARTIE_C_REQUETES.SQL ».

## 5.4 Pièges de la partie C

| Piège | Symptôme | Solution |
|---|---|---|
| Déréférencement sans alias | `ORA-00904`. | Toujours `c.adresse.ville`, `c.ref_conseiller.nom`. |
| `CARDINALITY` sur un VARRAY | `ORA-00932`. | `TABLE(...)` + `COUNT(*)`. |
| `COUNT` sur un VARRAY en SQL | `ORA-00904`. | Idem. |
| `NOT IN` avec `NULL` | Aucun résultat inattendu. | Préférer `NOT EXISTS`. |
| Confondre `montant` signé et valeur absolue | Les totaux sont faux. | Les retraits sont négatifs ; utiliser `SUM(montant)` ou `ABS`. |
| Capturer C après D | CC1/CE4/1,5 M absents. | Capturer avant D ou utiliser `_C.out`. |

---

# 6. Partie D — Programmation PL/SQL

## 6.1 Sous-programmes catalogués (D1)

| Sous-programme | Signature | Rôle | Transaction |
|---|---|---|---|
| `nb_comptes` | `FUNCTION nb_comptes RETURN NUMBER` | Nombre total de comptes (CC + CE + CT). | Lecture seule. |
| `solde_total` | `FUNCTION solde_total(paramcli IN NUMBER) RETURN NUMBER` | Somme des soldes d'un client. | Lecture seule. |
| `ville_client` | `FUNCTION ville_client(paramcli IN NUMBER) RETURN VARCHAR2` | Ville d'un client. | Lecture seule. |
| `ajout_client` | `PROCEDURE ajout_client(...)` | Ajout complet d'un client, parrain optionnel. | Pas de `COMMIT`. |
| `virement` | `PROCEDURE virement(cptsrc, cptdest, montant, cli)` | Virement atomique entre deux comptes courants, commission inter-agences. | Pas de `COMMIT`. |
| `maj_statuts_dormants` | `PROCEDURE maj_statuts_dormants` | Passe en `DORMANT` les comptes courants sans opération depuis 12 mois. | Pas de `COMMIT` (testé avec `ROLLBACK`). |
| `scan_echeances` | `PROCEDURE scan_echeances` | Crée les alertes d'échéance pour les CT. | `COMMIT`. |
| `change_Portable` | `PROCEDURE change_Portable(...)` | Modifie le 2e téléphone. | `COMMIT` en succès, `ROLLBACK` en erreur (partie B). |
| `drop_client` | `PROCEDURE drop_client(...)` | Supprime un client et ses dépendances. | `COMMIT` / `ROLLBACK` (partie B). |

> **Question probable :** « Pourquoi `virement` ne fait-il pas `COMMIT` ? »  
> **Réponse :** Parce qu'un virement peut faire partie d'une transaction plus large. Le `COMMIT` appartient à l'appelant. Le procédure utilise un `SAVEPOINT` et un `ROLLBACK TO` pour garantir l'atomicité des deux écritures.

## 6.2 Blocs anonymes D7 a–e

| Bloc | Consigne | Technique | Résultat |
|---|---|---|---|
| 7a | Téléphone travail (2e élément) du client 3 | `v_tel(2)` + test `NULL` | `0777-11-22-33`. |
| 7b | Même chose pour tous les titulaires de CC | Curseur + `FOR` | Affiche les 6 clients, certains « non renseigné ». |
| 7c | Curseur paramétré seuil, titulaire, solde, nb signataires | Curseur paramétré + `NO_DATA_FOUND` + `aucun_compte` | Seuil 100 000 : CC2, CC3, CC5, CC6 ; seuil -1 000 000 : `aucun_compte`. |
| 7d | Ajouter un 3e téléphone avec `EXTEND`, `LIMIT`, `COUNT`, `LAST` | Client 98 temporaire | `COUNT` 2 → 3 ; 4e refusé ; client 98 supprimé ensuite. |
| 7e | Total des intérêts annuels des CE d'une agence | Curseur + `ROUND(solde * taux / 100, 2)` | A1 : 10 150 DA. |

> **Détail 7e :** CE1 (150 000 × 2,5 % = 3 750) + CE4 (320 000 × 2 % = 6 400) = 10 150. CE4 existe encore à ce moment ; il est supprimé plus tard par `fermeCompte('CE4')`.

## 6.3 Méthodes D8

| Type | Méthode | Rôle | Résultat clé |
|---|---|---|---|
| `client_type` | `nbCepargne` | Nombre de CE du client. | 2, 1, 1, 1, 0, 0. |
| `client_type` | `soldeTotal` | Somme CC + CE + CT. | 3 348 500 ; 300 000 ; 168 000 ; 830 000 ; 0 ; 40 000. |
| `client_type` | `supprimeTel(indice)` | Supprime un téléphone. | Client 4 : indice 2 supprimé puis restauré ; client 5 : indice 2 non renseigné. |
| `client_type` | `afficheInterets` | Affiche les intérêts des CE. | Client 1 : 18 750 DA. |
| `cptCourant_type` | `nbSignataire` / `nbSignataire(droit)` | Nombre de signataires, éventuellement par droit. | Surcharge. |
| `cptCourant_type` | `estTitulaire(cli)` | Booléen : le client est-il titulaire ? | Testé en PL/SQL. |
| `cptCourant_type` | `estSignataire(cli)` | Booléen : le client est-il signataire ? | Testé en PL/SQL. |
| `cptCourant_type` | `supprimeSign(cli)` | Retire un signataire. | CC7 : 3 → 2, puis restauration. |
| `cptCourant_type` | `peutRetirer(cli, montant)` | Vérifie les droits et le découvert. | `peutRetirer(4, -1000) = TRUE`. |
| `cptCourant_type` | `passeMvt(cli, somme)` | Insère une opération et met à jour le solde. | CC7 +10 000 → 195 000 ; -5 000 → 180 000. |
| `cptCourant_type` | `fraisTenue` | Frais de tenue de compte. | 1 200 DA (CC), 0 (CE/CT). |
| `cptEpargne_type` | `calculeInterets` | Solde + intérêts. | CE5 : 515 000. |
| `cptEpargne_type` | `sortieAnticipee` | Solde avec pénalité de 5 %. | CE5 : 475 000. |
| `cptTerme_type` | `calculeInterets` | Solde + intérêts proratisés. | CT1 : 206 400. |
| `cptTerme_type` | `sortieAnticipee` | Solde avec pénalité de 5 %. | CT1 : 190 000. |
| `compte_type` | `fermeCompte(cpt)` (STATIC) | Clôture un compte. | CE4 : 320 000 ; CC1 : 2 498 500 + 5 opérations. |

> **Pourquoi `calculeInterets` retourne-t-il le solde + les intérêts, et pas seulement les intérêts ?**  
> Parce que la méthode est utilisée pour simuler le montant disponible à l'échéance. Pour l'épargne, `solde * (1 + taux/100)` ; pour le terme, `solde * (1 + taux/100 * durée/12)`. Les intérêts seuls sont visibles dans `afficheInterets` (3 750 + 15 000 = 18 750).

> **Pourquoi `sortieAnticipee` retourne-t-il 95 % du solde ?**  
> Parce qu'une sortie anticipée applique une pénalité de 5 %. CE5 : 500 000 × 0,95 = 475 000. CT1 : 200 000 × 0,95 = 190 000.

## 6.4 Triggers D9

### `trg_op_avant` (COMPOUND, BEFORE INSERT)

Il vérifie, dans cet ordre :

1. **statut du compte** : si `BLOQUE` ou `DORMANT` → `ORA-20001`.
2. **droits du client** : titulaire = tous droits ; signataire `X` = tous pouvoirs ; `D` = consultation, dépôts et retraits ; `R` = consultation seulement ; sinon `ORA-20002`.
3. **plafond journalier** : somme des retraits du jour + nouveau retrait > 200 000 DA → `ORA-20003`.
4. **découvert** : `solde + montant - commission < -decouvert` → `ORA-20004`.

> **Pourquoi COMPOUND ?** Parce que le plafond journalier nécessite la somme des retraits du jour. Un trigger ligne par ligne qui lit `operation` provoque `ORA-04091`. Le COMPOUND prend l'instantané en `BEFORE STATEMENT`, puis accumule en `BEFORE EACH ROW`.

### `trg_op_apres` (AFTER INSERT)

- Met à jour `solde = solde + montant - commission`.
- Incrémente `nb_op_cb` si `type_op = 'CB'`.
- Crée une alerte `SOLDE_NEGATIF` si le solde devient négatif.
- Crée une alerte `OPERATION_SUSPECTE` si `montant > 1 000 000` DA (crédit important).

> **Pourquoi le solde est-il mis à jour dans un trigger AFTER et non dans `passeMvt` ?**  
> Pour que **toute** insertion dans `operation` mette le solde à jour, même une insertion SQL directe. `passeMvt` insère l'opération, puis **recalcule** le solde à partir de `operation` : c'est idempotent, il ne double pas le montant.

### `trg_ct_echeance`

- `AFTER INSERT OR UPDATE OF date_echeance` sur `cpt_terme`.
- Si l'échéance est dans 8 jours ou moins : alerte `ECHEANCE_PROCHE`.
- Si l'échéance est dépassée : alerte `ECHEANCE_DEPASSEE`.
- Évite les doublons avec `NOT EXISTS` sur `alerte`.

### Triggers d'audit

- `trg_audit_taux` : `AFTER UPDATE OF taux_interet` sur `cpt_epargne`.
- `trg_audit_taux_terme` : `AFTER UPDATE OF taux_garanti` sur `cpt_terme`.
- `trg_audit_decouvert` : `AFTER UPDATE OF decouvert` sur `cpt_courant`.
- Ils insèrent dans `"AUDIT"` : table, colonne, ancienne valeur, nouvelle valeur, date, utilisateur.

## 6.5 Résultats des tests D9

| Test | Résultat attendu |
|---|---|
| Test 1 : opération sur CC5 `BLOQUE` | `ORA-20001`. |
| Test 2 : client 6 sur CC1 (pas de droit de débit) | `ORA-20002`. |
| Test 3 : client 5 (droit `R`) sur CC7 | `ORA-20002`. |
| Test 4 : retrait de 60 000 sur CC3 | `ORA-20004` (découvert). |
| Test 5 : retrait de 210 000 sur CC4 | `ORA-20003` (plafond 200 000). |
| Test 6 : retrait de 1 000 par signataire `D` (client 2) sur CC7 | Succès, solde 185 000 → 184 000. |
| Test 7 : retrait de 1 000 par signataire `X` (client 3) sur CC4 | Succès, solde 325 000 → 324 000. |
| Test 8 : CB sur CC6 | Solde 40 000 → 39 000 ; `nb_op_cb` 0 → 1. |
| Test 9 : alerte `SOLDE_NEGATIF` | 1 alerte pour CC6. |
| Test 10 : alerte `OPERATION_SUSPECTE` | 1 alerte pour CC1. |
| Test 11 : échéance proche CT99 | 1 alerte `ECHEANCE_PROCHE`. |
| Test 12 : échéance dépassée CT98 | 1 alerte `ECHEANCE_DEPASSEE`. |
| Tests 13–15 : audit | Lignes dans `"AUDIT"` (taux CE1, découvert CC1, taux garanti CT1). |
| Test 16 : `scan_echeances` | Alertes CT2/CT3, sans doublon. |

> **Preuve :** `_FULL.out`, section « D9. TRIGGERS ». Les erreurs sont dans des blocs `BEGIN ... EXCEPTION WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Refus attendu : '||SQLERRM); END;`.

## 6.6 `passeMvt` et `virement` en détail

### `passeMvt`

- Insère une opération avec `ref_client`, `ref_compte`, `montant`, `type_op`, `commission`.
- Le trigger `trg_op_apres` met à jour le solde.
- Ensuite, `passeMvt` **recalcule** le solde :
  ```sql
  UPDATE cpt_courant
     SET solde = (SELECT NVL(SUM(o.montant - o.commission), 0)
                    FROM operation o
                   WHERE o.ref_compte = REF(cpt_courant))
   WHERE num_compte = ...;
  ```
- Comme le trigger a déjà appliqué le mouvement, le recalcul redonne le même résultat : il est **idempotent**. Il ne double pas.
- Il gère les exceptions `NO_DATA_FOUND`, `ORA-01400` (REF NULL) et `ORA-02290` (CHECK NULL) avec `PRAGMA EXCEPTION_INIT` ; `DUP_VAL_ON_INDEX` est géré dans `ajout_client`.
- Un montant nul lève `ORA-20030` (code distinct de `ORA-20010` utilisé par `mutation`).
- Il ne fait pas `COMMIT`.

> **Question probable :** « Pourquoi recalculer le solde si le trigger le fait déjà ? »  
> **Réponse :** Pour garantir la cohérence si la méthode est appelée après une insertion directe ou si le trigger est désactivé. Le recalcul est une sécurité ; il est idempotent.

### `virement`

- Vérifie `montant > 0` et `cptsrc <> cptdest`.
- Récupère les `REF` source, destination et client.
- Calcule la commission : **1 % du montant, minimum 100 DA**, si les agences sont différentes ; sinon 0.
- Insère le débit (`-montant`, commission) et le crédit (`+montant`, commission 0).
- En cas d'erreur : `ROLLBACK TO av_virement`, puis message.
- Pas de `COMMIT`.

> **Test same-agency :** CC4 → CC7, 1 000 DA, commission 0 : CC4 325 000 → 324 000 ; CC7 185 000 → 186 000.  
> **Test inter-agences :** CC4 (A1) → CC3 (A3), 1 000 DA, commission 100 : CC4 325 000 → 323 900 ; CC3 38 000 → 39 000.  
> **Test rollback :** CC3 → CC4, 60 000 DA : `ORA-20004` sur CC3, CC4 reste à 325 000.

> **Pourquoi le virement est-il limité aux comptes courants ?**  
> Parce que `operation_type.ref_compte` est `REF cptCourant_type`. Le sujet parle des opérations sur les comptes courants. Un virement vers un compte d'épargne serait possible conceptuellement, mais il faudrait un modèle d'opération polymorphe ou une seconde table. On l'a documenté comme limite.

## 6.7 `fermeCompte`

- Procédure **statique** de `compte_type`.
- Cherche le compte dans `cpt_courant`, puis `cpt_epargne`, puis `cpt_terme`.
- Affiche le solde avant clôture.
- Si c'est un CC, supprime d'abord ses opérations.
- Supprime le compte.
- `COMMIT`.
- `NO_DATA_FOUND` : message « compte inexistant » + `ROLLBACK`.
- `WHEN OTHERS` : `ROLLBACK` + message.

> **Pourquoi est-elle testée en dernier ?**  
> Parce qu'elle est destructive : elle supprime CE4 et CC1. Ces comptes sont utilisés par les tests précédents (intérêts, opérations, alertes). On la place donc à la fin de la partie D.

## 6.8 Pièges de la partie D

| Piège | Symptôme | Solution |
|---|---|---|
| Trigger ligne par ligne qui lit `operation` | `ORA-04091`. | Trigger COMPOUND. |
| `ALTER TYPE ADD MEMBER` pour un override | `ORA-22324` / `PLS-00636`. | Déclarer `OVERRIDING` dès le `CREATE TYPE`. |
| `ALTER TYPE` avec plusieurs membres | Erreur de syntaxe. | Un membre par `ALTER TYPE`. |
| `ALTER TYPE` rejoué | `ORA-22324`. | Protéger avec `SQLCODE = -22324`. |
| Objets dépendants invalides après `CASCADE` | `STATUS = INVALID`. | Recompiler les procédures/fonctions à la fin. |
| `COMMIT` dans `virement` | Le test de rollback échoue. | Pas de `COMMIT`. |
| `COMMIT` dans `passeMvt` | Le test de rollback échoue. | Pas de `COMMIT`. |
| `valeur(2)` sur un VARRAY de 1 élément | `ORA-06533`. | Vérifier `COUNT`. |

---

# 7. Partie E — Fonctionnalités objet avancées

## 7.1 E10 — Type récursif et parrainage

- `client_type` contient `ref_parrain REF client_type`.
- On peut interroger le parrain : `c.ref_parrain.nom`.
- Et le grand-parrain : `c.ref_parrain.ref_parrain.nom`.
- E10 met à jour :
  - client 4 → parrain 1 ;
  - client 5 → parrain 2 ;
  - client 6 → parrain 3.
- Clients 2 et 3 restent parrainés par 1.

Résultat de la requête à double notation :

| Client | Parrain | Grand-parrain |
|---|---|---|
| 2 | AMRANI | — |
| 3 | AMRANI | — |
| 4 | AMRANI | — |
| 5 | BENALI | AMRANI |
| 6 | CHERIF | AMRANI |

> **Pourquoi `c.ref_parrain.ref_parrain.nom` fonctionne-t-il ?**  
> Parce que `ref_parrain` est un `REF` vers `client_type`, et que `client_type` contient lui-même `ref_parrain`. Oracle peut suivre la chaîne. Il faut un alias de table (`c`) pour déréférencer.

## 7.2 E11 — Collection multi-niveaux `releves`

Structure :

```sql
CREATE TABLE releves (
  annee    NUMBER PRIMARY KEY,
  mois_vry mois_vry_type
);

-- mois_vry_type = VARRAY(12) OF mois_elt_vry_type
-- mois_elt_vry_type = (mois, nb_operations, types)
-- types = type_stat_nt_type (nested table de type_stat_elt_nt_type)
```

E11 :

1. insère 4 mois (janvier à avril) avec des statistiques par type ;
2. étend le `VARRAY` à 5 mois avec `EXTEND(1)` ;
3. ajoute une nouvelle *nested table* de types pour le mois 5 ;
4. affiche le total par type d'opération sur l'année.

Résultat (relevé 2026, 5 mois) :

| Type | Nb total | Montant total |
|---|---|---|
| DEPOT | 13 | 880 000 |
| RETRAIT | 32 | 620 000 |
| VIREMENT | 3 | 130 000 |
| CB | 2 | 35 000 |

> **Pourquoi `CARDINALITY` ne fonctionne-t-il pas ici ?**  
> Parce que `mois_vry` est un `VARRAY`, et `CARDINALITY` sur un VARRAY lève `ORA-00932` dans cette version. On utilise `TABLE(r.mois_vry)` et `COUNT(*)`.

> **Comment interroger le 2e niveau ?**  
> ```sql
> SELECT t.type_op, SUM(t.nb), SUM(t.montant_total)
>   FROM releves r, TABLE(r.mois_vry) m, TABLE(m.types) t
>  WHERE r.annee = 2026
>  GROUP BY t.type_op;
> ```
> Le premier `TABLE` ouvre le VARRAY des mois ; le second ouvre la *nested table* des types.

## 7.3 E12 — Vue objet `Agence_VOR`

### Définition

```sql
CREATE TYPE agence_vor_type AS OBJECT (
  code            VARCHAR2(6),
  nom             VARCHAR2(40),
  ville           VARCHAR2(40),
  ref_responsable REF conseiller_type,
  conseillers     conseiller_nt_type,
  comptes         cptCourant_nt_type,
  MEMBER PROCEDURE mutation(
    nConseiller   NUMBER,
    nAgenceCible  VARCHAR2
  )
);
```

### Vue

```sql
CREATE OR REPLACE VIEW Agence_VOR OF agence_vor_type
WITH OBJECT IDENTIFIER (code)
AS
SELECT a.code, a.nom, a.ville, a.ref_responsable,
       CAST(MULTISET(
         SELECT VALUE(c)
           FROM conseiller c, affectation af
          WHERE af.ref_conseiller = REF(c)
            AND af.ref_agence = MAKE_REF(agence, a.code)
            AND af.date_fin IS NULL
       ) AS conseiller_nt_type) AS conseillers,
       CAST(MULTISET(
         SELECT VALUE(cc)
           FROM cpt_courant cc
          WHERE cc.ref_agence = MAKE_REF(agence, a.code)
       ) AS cptCourant_nt_type) AS comptes
  FROM agence a;
```

- `WITH OBJECT IDENTIFIER (code)` : la vue a un identifiant objet.
- `CAST(MULTISET(...))` : transforme le résultat d'une sous-requête en collection.
- `MAKE_REF(agence, a.code)` fabrique une `REF` d'agence à partir du code ; il est utilisé dans la vue et dans la méthode `mutation`.
- Les collections sont accessibles par `TABLE(v.conseillers)` et `TABLE(v.comptes)`.

### Requêtes

```sql
-- Les agences
SELECT code, nom, ville FROM Agence_VOR;

-- Les conseillers d'une agence
SELECT v.code, k.nom, k.prenom
  FROM Agence_VOR v, TABLE(v.conseillers) k;

-- Les comptes d'une agence
SELECT v.code, c.num_compte, c.solde
  FROM Agence_VOR v, TABLE(v.comptes) c;
```

### Méthode `mutation`

- Vérifie que le conseiller existe et que l'agence cible existe (`ORA-20011` sinon).
- Vérifie que le conseiller est actuellement affecté à l'agence source (`ORA-20010` sinon).
- Ferme l'affectation courante :
  ```sql
  UPDATE affectation
     SET date_fin = GREATEST(SYSDATE, date_debut) + 1/86400
   WHERE ref_conseiller = ...
     AND ref_agence = ...
     AND date_fin IS NULL;
  ```
- Ouvre une nouvelle affectation vers l'agence cible.
- **Signale** que le responsable de l'agence doit être revu, mais **ne remplace pas** automatiquement le responsable.

> **Pourquoi `GREATEST(SYSDATE, date_debut) + 1/86400` ?**  
> Parce que la contrainte `CK_AFF_DATES` impose `date_fin > date_debut`. Si on mute le même jour, `SYSDATE` peut être égal à `date_debut`, ce qui viole la contrainte (`ORA-02290`). On ajoute une seconde (`1/86400`) pour garantir `date_fin > date_debut`.

> **Pourquoi ne pas remplacer automatiquement le responsable ?**  
> Parce que le sujet demande de **signaler** le changement, pas de changer le responsable. Le responsable est un rôle de management ; le remplacer automatiquement pourrait violer les règles internes. La méthode ferme l'affectation et laisse la décision au gestionnaire.

## 7.4 Résultats E12

- Vue `Agence_VOR` : 3 lignes (A1, A2, A3).
- A1 : 1 conseiller, 2 comptes (CC4, CC7).
- A2 : 2 conseillers, 2 comptes (CC2, CC5).
- A3 : 1 conseiller, 2 comptes (CC3, CC6).
- Mutations réussies : KACI (4) de A2 vers A3, puis BENALI (1) de A1 vers A2 ; restauration ensuite de 1 vers A1 et de 4 vers A2.
- Erreurs attendues : `A3.mutation(1, 'A2')` → `ORA-20010` (le conseiller 1 n'est pas affecté à A3) ; conseiller 99 → `ORA-20011` ; agence A9 → `ORA-20011`.
- Après les tests, les compteurs de **conseillers** de la vue sont restaurés : A1 = 1, A2 = 2, A3 = 1.

> **Preuve :** `_FULL.out`, section « PARTIE_E_OBJET_AVANCE.SQL ».

## 7.5 Pièges de la partie E

| Piège | Symptôme | Solution |
|---|---|---|
| `CARDINALITY` sur `mois_vry` | `ORA-00932`. | `TABLE(...)` + `COUNT(*)`. |
| `TABLE(m.COLUMN_VALUE.types)` | `ORA-00904`. | `TABLE(m.types)`. |
| `date_fin = SYSDATE` | `ORA-02290` sur `CK_AFF_DATES`. | `GREATEST(SYSDATE, date_debut) + 1/86400`. |
| Mutation sur un conseiller absent | `ORA-20010`. | C'est un test attendu. |
| Mutation sur un inconnu | `ORA-20011`. | C'est un test attendu. |
| `MAKE_REF` sans OID basé sur la PK | `ORA-22979` / impossible. | `agence` a `OBJECT IDENTIFIER IS PRIMARY KEY`. |

---

# 8. Démonstration de 10 minutes, Q&R et pièges

## 8.1 Script de démonstration minuté

> **Objectif :** montrer que le projet fonctionne, que tu comprends les choix, et que tu sais réagir aux erreurs. Ne montre pas tout : choisis les preuves les plus parlantes.

### 0:00–0:40 — Introduction

**À dire :**

> « Le projet implémente une banque en Oracle 21c avec des types objet, de l'héritage, des REF, des collections, des méthodes, un type récursif et une vue objet. Tout est rejouable avec `projet_bdda_banque.sql`. Le script a été exécuté en entier : zéro objet invalide. Les seules erreurs ORA sont des tests d'exception volontaires. »

**À montrer :**

```sql
SELECT USER FROM dual;
SELECT COUNT(*) AS objets_invalides
  FROM user_objects
 WHERE status <> 'VALID';
```

Résultat attendu : `MASTER1`, puis `0`.

### 0:40–2:00 — Partie A : schéma

**À montrer :**

```sql
SELECT type_name, typecode FROM user_types ORDER BY type_name;
SELECT table_name FROM user_tables ORDER BY table_name;
SELECT COUNT(*) AS clients FROM client;
SELECT COUNT(*) AS comptes_courants FROM cpt_courant;
```

**À dire :**

> « Il y a 19 types métier. Les comptes sont une hiérarchie : `compte_type` est non instanciable, et il y a une table par sous-type. Les clients ont un VARRAY de 3 téléphones et une nested table de signataires. La table `client` garde un OID système pour que les REF puissent être insérés dans la nested table. »

**Preuve UML :** montrer `uml/banque.puml` ou `uml/banque.mermaid`.

### 2:00–3:00 — Partie B : manipulations

**À montrer :**

```sql
-- Vérifier le téléphone du client 3
SELECT c.num_client, t.COLUMN_VALUE AS telephone
  FROM client c, TABLE(c.telephones) t
 WHERE c.num_client = 3;
```

**À dire :**

> « B5b insère un compte courant sans titulaire puis le met à jour : c'est possible parce que la contrainte `REF IS NOT NULL` est différée sur `cpt_courant`. B5e gère les VARRAY de 1, 2 ou 3 éléments. B5f supprime un client et toutes ses dépendances sans laisser d'orphelins. »

**Si on demande de montrer `drop_client` :** montrer la sortie de `_FULL.out` (B5f) plutôt que de supprimer un client réel.

### 3:00–4:15 — Partie C : requêtes

**À montrer :**

```sql
-- 6.10 : compte courant à solde négatif
SELECT cc.num_compte, cc.solde, c.nom, k.nom AS conseiller
  FROM cpt_courant cc, client c, conseiller k
 WHERE cc.ref_client = REF(c)
   AND c.ref_conseiller = REF(k)
   AND cc.solde < 0;

-- 6.20 : signataires de CC7 avec adresse
SELECT c.num_client, c.nom,
       c.adresse.num_rue||' '||c.adresse.rue||', '||c.adresse.ville AS adresse,
       s.droit
  FROM cpt_courant cc, TABLE(cc.signataires) s, client c
 WHERE cc.num_compte = 'CC7'
   AND s.ref_client = REF(c)
 ORDER BY c.num_client;
```

**À dire :**

> « 6.10 montre le découvert de CC2. 6.20 montre la jointure entre une nested table et la table client via `s.ref_client = REF(c)`. Les collections sont interrogées avec `TABLE`. »

> **Attention :** ne pas montrer 6.24 en direct après la partie D : l'opération de 1 500 000 a été supprimée avec CC1. Montrer `_C.out` si nécessaire.

### 4:15–6:00 — Partie D : méthodes et transactions

**À montrer :**

```sql
-- Méthodes de client
SELECT c.num_client, c.nom, c.nbCepargne() AS nb_epargne,
       c.soldeTotal() AS solde_total
  FROM client c
 ORDER BY c.num_client;

-- Méthodes d'épargne
SELECT ce.num_compte, ce.solde, ce.calculeInterets() AS a_l_echeance,
       ce.sortieAnticipee() AS sortie_anticipee
  FROM cpt_epargne ce
 ORDER BY ce.num_compte;
```

> **Chronologie :** après la clôture de CE4 par `fermeCompte`, le client 4 n'a plus aucun compte d'épargne : `nbCepargne()` affiche 0, alors que le tableau 6.3 donnait 1 avant cette clôture.

**Puis `passeMvt` :**

```sql
DECLARE
  v_cc    cptCourant_type;
  v_avant NUMBER;
  v_apres NUMBER;
BEGIN
  SELECT solde INTO v_avant FROM cpt_courant WHERE num_compte = 'CC7';
  DBMS_OUTPUT.PUT_LINE('Avant : '||v_avant);
  SELECT VALUE(cc) INTO v_cc FROM cpt_courant cc WHERE cc.num_compte = 'CC7';
  v_cc.passeMvt(4, 10000);
  SELECT solde INTO v_apres FROM cpt_courant WHERE num_compte = 'CC7';
  DBMS_OUTPUT.PUT_LINE('Apres : '||v_apres);
  ROLLBACK;
END;
/
```

**À dire :**

> « `passeMvt` insère l'opération, le trigger AFTER met à jour le solde, puis la méthode recalcule le solde à partir de l'historique : c'est idempotent. Elle ne fait pas COMMIT : le rollback du bloc remet le solde à 185 000. »

### 6:00–7:30 — Partie D : triggers

**À montrer (deux refus suffisent) :**

```sql
-- Refus 1 : compte bloqué
BEGIN
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL,
          (SELECT REF(c) FROM client c WHERE c.num_client = 5),
          (SELECT REF(cc) FROM cpt_courant cc WHERE cc.num_compte = 'CC5'),
          TRUNC(SYSDATE), -1000, 'RETRAIT', 0);
  DBMS_OUTPUT.PUT_LINE('Inattendu : accepte');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Refus attendu : '||SQLERRM);
END;
/

-- Refus 2 : plafond journalier
BEGIN
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL,
          (SELECT REF(c) FROM client c WHERE c.num_client = 4),
          (SELECT REF(cc) FROM cpt_courant cc WHERE cc.num_compte = 'CC4'),
          TRUNC(SYSDATE), -210000, 'RETRAIT', 0);
  DBMS_OUTPUT.PUT_LINE('Inattendu : accepte');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Refus attendu : '||SQLERRM);
END;
/
```

**À dire :**

> « Le trigger COMPOUND évite ORA-04091 : il prend un instantané des retraits du jour avant la ligne, puis accumule. Le plafond est de 200 000 DA. Les refus sont attendus et capturés. »

**Puis un succès + rollback :**

```sql
BEGIN
  INSERT INTO operation (id_op, ref_client, ref_compte, date_op,
                         montant, type_op, commission)
  VALUES (seq_operation.NEXTVAL,
          (SELECT REF(c) FROM client c WHERE c.num_client = 6),
          (SELECT REF(cc) FROM cpt_courant cc WHERE cc.num_compte = 'CC6'),
          TRUNC(SYSDATE), 10000, 'DEPOT', 0);
  DBMS_OUTPUT.PUT_LINE('Depot accepte');
  ROLLBACK;
END;
/
```

**À dire :**

> « Le solde de CC6 passe de 40 000 à 50 000, puis le rollback le remet à 40 000. Le trigger AFTER a fait son travail. »

### 7:30–8:45 — Partie E : vue objet

**À montrer :**

```sql
SELECT code, nom, ville FROM Agence_VOR ORDER BY code;

SELECT v.code, c.num_compte, c.solde
  FROM Agence_VOR v, TABLE(v.comptes) c
 ORDER BY v.code, c.num_compte;

SELECT v.code, k.nom, k.prenom
  FROM Agence_VOR v, TABLE(v.conseillers) k
 ORDER BY v.code, k.nom;
```

**À dire :**

> « La vue objet expose deux collections calculées par CAST(MULTISET). Le type récursif permet de naviguer de parrain en parrain. La méthode mutation ferme l'affectation courante et en ouvre une nouvelle ; elle signale le responsable mais ne le remplace pas. »

**Si on demande la mutation :** montrer la sortie de `_FULL.out` (tests E12) plutôt que de modifier l'état en direct.

### 8:45–10:00 — Conclusion

**À montrer :**

```sql
SELECT object_type, COUNT(*) AS nb
  FROM user_objects
 GROUP BY object_type
 ORDER BY object_type;

SELECT COUNT(*) AS objets_invalides
  FROM user_objects
 WHERE status <> 'VALID';
```

**À dire :**

> « Le projet est complet : 5 parties, un script unique rejouable, 0 objet invalide. Les points forts sont l'héritage des comptes, les collections, les triggers de sécurité et la vue objet. Les limites sont documentées : opérations uniquement sur les comptes courants, virement CC→CC, pas de remplacement automatique du responsable. »

## 8.2 Questions / réponses (45 questions)

### Conception et modèle

**Q1. Pourquoi des tables objet et pas uniquement du relationnel ?**  
**Réponse courte :** Le sujet impose types objet, héritage, REF, collections, méthodes, type récursif et vue objet.  
**Si on insiste :** Le relationnel pur ne permet pas de démontrer ces mécanismes. On garde du relationnel pour l'historique, les alertes et l'audit, là où c'est plus simple.

**Q2. Pourquoi `compte_type` est-il `NOT FINAL NOT INSTANTIABLE` ?**  
**Réponse courte :** `NOT FINAL` autorise l'héritage ; `NOT INSTANTIABLE` interdit un compte générique.  
**Si on insiste :** La règle métier dit que la banque ne gère jamais de compte « nu ». Chaque compte est obligatoirement courant, épargne ou terme.

**Q3. Pourquoi une table par sous-type et pas une seule table `compte` ?**  
**Réponse courte :** Chaque sous-type a ses attributs propres ; cela évite les colonnes nullables et respecte l'interdiction du compte générique.  
**Si on insiste :** Une table unique aurait un discriminant et des colonnes inutiles selon le type. La hiérarchie objet est plus propre et permet le polymorphisme de `fraisTenue`.

**Q4. Pourquoi `client_type` n'a-t-il pas d'attribut `agence` ?**  
**Réponse courte :** Parce qu'un client est suivi par un conseiller, et qu'un conseiller peut changer d'agence. L'agence se déduit de l'affectation du conseiller.  
**Si on insiste :** Mettre `ref_agence` dans le client dupliquerait l'information et poserait des problèmes de mise à jour.

**Q5. Pourquoi `affectation` est-elle une table relationnelle ?**  
**Réponse courte :** Parce que c'est une association datée, avec un historique.  
**Si on insiste :** Un attribut unique dans `conseiller_type` écraserait l'historique. La table permet plusieurs lignes et une ligne ouverte (`date_fin IS NULL`).

**Q6. Pourquoi `ref_parrain` est-il ajouté par `ALTER TYPE` ?**  
**Réponse courte :** Pour démontrer l'évolution d'un type et respecter le parrainage demandé.  
**Si on insiste :** Recréer `client_type` aurait cassé les dépendances. `ALTER TYPE ... ADD ATTRIBUTE ... CASCADE` ajoute l'attribut sans tout recréer.

**Q7. Pourquoi la table `client` a-t-elle un OID système et non `OBJECT IDENTIFIER IS PRIMARY KEY` ?**  
**Réponse courte :** Parce qu'un `REF` basé sur la PK ne peut pas être inséré dans une *nested table* (`ORA-22979`).  
**Si on insiste :** Les signataires stockent `REF client_type` dans une nested table. Avec un OID système, l'insertion fonctionne.

**Q8. Pourquoi la table `agence` a-t-elle `OBJECT IDENTIFIER IS PRIMARY KEY` ?**  
**Réponse courte :** Pour pouvoir utiliser `MAKE_REF(agence, a.code)` dans la vue objet.  
**Si on insiste :** `MAKE_REF` a besoin d'un OID basé sur une clé connue. C'est ce qui permet de construire les collections de la vue.

### Partie A

**Q9. Combien de types, tables et contraintes ?**  
**Réponse courte :** 19 types métier, 11 tables logiques + 1 table de stockage de nested table, 4 séquences, 13 FK, 6 triggers, 9 sous-programmes catalogués.  
**Si on insiste :** `USER_OBJECTS` affiche 26 lignes de type `TYPE` : il y a des types internes `SYS_YOID...` et une version supplémentaire de `CLIENT_TYPE` due à l'évolution. Les 19 types métier sont dans `USER_TYPES`.

**Q10. Comment sont stockés les téléphones ?**  
**Réponse courte :** Dans un `VARRAY(3) OF VARCHAR2(20)`, inline dans la table `client`.  
**Si on insiste :** On peut les interroger avec `TABLE(c.telephones)`. `CARDINALITY` ne fonctionne pas sur un VARRAY dans cette version (`ORA-00932`).

**Q11. Comment sont stockés les signataires ?**  
**Réponse courte :** Dans une *nested table* `signataire_nt_type`, stockée dans `signataire_nt_st` via `NESTED TABLE ... STORE AS`.  
**Si on insiste :** Chaque élément est un `signataire_elt_nt_type` avec `ref_client` et `droit`. La contrainte `droit IN ('X','R','D')` est ajoutée sur la table de stockage par `ALTER TABLE`.

**Q12. Pourquoi `AUDIT` est-il entre guillemets ?**  
**Réponse courte :** Parce que `AUDIT` est un mot réservé Oracle.  
**Si on insiste :** Sans guillemets, `CREATE TABLE AUDIT` échoue. On écrit `"AUDIT"` partout.

**Q13. Pourquoi la contrainte `ref_client IS NOT NULL` de `cpt_courant` est-elle différée ?**  
**Réponse courte :** Pour permettre B5b : insérer un compte courant sans titulaire, puis le mettre à jour avant le `COMMIT`.  
**Si on insiste :** Une contrainte immédiate refuserait l'insertion. La contrainte `ck_cc_client` est `DEFERRABLE INITIALLY DEFERRED` et vérifiée au moment de la validation. Les contraintes équivalentes de `cpt_epargne` et `cpt_terme` restent immédiates.

**Q14. Comment fonctionne l'intégrité des `REF` ?**  
**Réponse courte :** Oracle vérifie les FK sur les colonnes/attributs `REF`.  
**Si on insiste :** Un `REF` est un pointeur ; la FK garantit que l'objet référencé existe. Pour supprimer un client, il faut supprimer ou mettre à `NULL` les références.

**Q15. Pourquoi pas de FK ni de trigger sur la nested table des signataires ?**  
**Réponse courte :** Oracle l'interdit sur le stockage d'une nested table (`ORA-30730`, `ORA-22812`).  
**Si on insiste :** On contrôle les droits dans le trigger sur `operation` et dans les méthodes (`estSignataire`, `peutRetirer`).

**Q16. Comment le script est-il rejouable ?**  
**Réponse courte :** Il supprime la vue, les tables, les séquences et les types dans le bon ordre, puis recrée tout.  
**Si on insiste :** `purge_donnees.sql` fait des `DELETE` pour vider les données sans supprimer le schéma. Le script unique est une concaténation A→E.

### Partie B

**Q17. Que démontre B5b ?**  
**Réponse courte :** Une contrainte `REF IS NOT NULL` différée sur `cpt_courant` : on insère CC99 sans titulaire, puis on met à jour avant le `COMMIT`.  
**Si on insiste :** C'est un cas typique où la vérification doit attendre la fin de la transaction. Les comptes d'épargne et à terme gardent une contrainte immédiate.

**Q18. Comment `change_Portable` gère-t-il les VARRAY ?**  
**Réponse courte :** Elle vérifie `COUNT` : si 1 élément, `EXTEND` ; si 2 ou 3, remplacement ; si `NULL` ou vide, recréation avec deux éléments.  
**Si on insiste :** Elle gère aussi `NO_DATA_FOUND` pour un client inexistant. Elle fait `COMMIT` en succès et `ROLLBACK` en erreur.

**Q19. Que fait `drop_client` ?**  
**Réponse courte :** Elle supprime les opérations, retire le client des listes de signataires, met à `NULL` les parrainages, supprime ses comptes, puis supprime le client.  
**Si on insiste :** Elle fait `COMMIT` en succès et `ROLLBACK` en erreur. C'est une opération de gestion autonome.

**Q20. Pourquoi `drop_client` fait `COMMIT` et `virement` non ?**  
**Réponse courte :** Parce que `drop_client` est une opération finale, alors que `virement` est une brique réutilisable.  
**Si on insiste :** Le `COMMIT` de `virement` empêcherait l'appelant de rollback l'ensemble. `drop_client` doit persister.

### Partie C

**Q21. Comment accéder à `c.adresse.ville` ?**  
**Réponse courte :** Avec un alias de table : `SELECT c.adresse.ville FROM client c`.  
**Si on insiste :** Sans alias, Oracle ne sait pas déréférencer et lève `ORA-00904`. Pour le parrain du parrain : `c.ref_parrain.ref_parrain.nom`.

**Q22. Comment interroger un VARRAY et une nested table ?**  
**Réponse courte :** Avec `TABLE(...)`.  
**Si on insiste :** `TABLE(c.telephones)` pour le VARRAY, `TABLE(cc.signataires)` pour la nested table. On peut joindre avec `s.ref_client = REF(c)`.

**Q23. Pourquoi `CARDINALITY` échoue-t-il sur un VARRAY ?**  
**Réponse courte :** Parce que cette version d'Oracle ne l'accepte pas sur un VARRAY (`ORA-00932`).  
**Si on insiste :** On utilise `TABLE(...)` + `COUNT(*)`. `CARDINALITY` fonctionne sur les nested tables.

**Q24. Comment fonctionne 6.20 ?**  
**Réponse courte :** On ouvre la nested table des signataires de CC7 et on joint au client par `s.ref_client = REF(c)`.  
**Si on insiste :** On affiche l'adresse complète en concaténant `c.adresse.num_rue`, `c.adresse.rue`, `c.adresse.ville`. Résultat : clients 2 (droit D), 3 (droit X) et 5 (droit R).

**Q25. Que fait 6.25 ?**  
**Réponse courte :** Elle supprime les comptes à terme expirés depuis plus d'un an et dont le montant bloqué est nul.  
**Si on insiste :** CT4 est le seul concerné ; CT1, CT2 et CT3 ont un montant bloqué > 0 et sont conservés. La requête fait un `COMMIT`.

### Partie D

**Q26. Différence entre méthode membre, méthode statique et procédure cataloguée ?**  
**Réponse courte :** Membre = sur une instance ; statique = sur le type ; cataloguée = autonome.  
**Si on insiste :** `fermeCompte` est statique car elle prend un numéro de compte, pas une instance. `virement` est cataloguée car elle manipule plusieurs comptes.

**Q27. Pourquoi `fraisTenue` est-elle déclarée avec `OVERRIDING` dès le `CREATE TYPE` ?**  
**Réponse courte :** Parce qu'`ALTER TYPE ADD MEMBER` ne permet pas de créer un override (`ORA-22324` / `PLS-00636`).  
**Si on insiste :** On déclare la méthode dans la super-classe, puis on écrit `OVERRIDING MEMBER FUNCTION fraisTenue` dans les corps des sous-types.

**Q28. Pourquoi `passeMvt` ne fait-elle pas `COMMIT` ?**  
**Réponse courte :** Pour que l'appelant contrôle la transaction.  
**Si on insiste :** Elle insère l'opération, le trigger AFTER met à jour le solde, puis elle recalcule le solde depuis `operation` : c'est idempotent. Un `COMMIT` interne empêcherait les tests de rollback.

**Q29. Comment `virement` garantit-il l'atomicité ?**  
**Réponse courte :** Avec `SAVEPOINT` + `ROLLBACK TO` en cas d'erreur.  
**Si on insiste :** Les deux insertions sont dans la même transaction. La commission inter-agences est de 1 % avec un minimum de 100 DA. Le test CC3→CC4 échoue sur le découvert et CC4 reste inchangé.

**Q30. Comment `fermeCompte` gère-t-elle les erreurs ?**  
**Réponse courte :** `NO_DATA_FOUND` pour un compte inexistant ; `WHEN OTHERS` avec `ROLLBACK`.  
**Si on insiste :** Elle cherche dans CC, CE, CT, supprime les opérations si c'est un CC, supprime le compte, puis `COMMIT`. Elle est testée en dernier car elle est destructive.

**Q31. Pourquoi `trg_op_avant` est-il un COMPOUND TRIGGER ?**  
**Réponse courte :** Pour éviter `ORA-04091` en lisant `operation` pour le plafond journalier.  
**Si on insiste :** `BEFORE STATEMENT` prend l'instantané des retraits du jour ; `BEFORE EACH ROW` accumule. On ne relit jamais la table mutante dans la partie ligne par ligne.

**Q32. Quel est l'ordre des triggers et comment le solde est-il mis à jour ?**  
**Réponse courte :** `BEFORE` valide, `AFTER INSERT` met à jour le solde.  
**Si on insiste :** `trg_op_avant` refuse les opérations invalides ; `trg_op_apres` applique `solde = solde + montant - commission`. `passeMvt` recalcule ensuite depuis `operation`, sans double comptage.

**Q33. Comment sont calculés les intérêts et la sortie anticipée ?**  
**Réponse courte :** Épargne : `solde * (1 + taux/100)`. Terme : `solde * (1 + taux/100 * durée/12)`. Sortie anticipée : 95 % du solde.  
**Si on insiste :** CE5 : 500 000 × 1,03 = 515 000 ; sortie 475 000. CT1 : 200 000 × 1,032 = 206 400 ; sortie 190 000. `afficheInterets` affiche les intérêts seuls : 3 750 + 15 000 = 18 750 pour le client 1.

**Q34. Comment fonctionne `maj_statuts_dormants` ?**  
**Réponse courte :** Elle passe en `DORMANT` les comptes ACTIF sans opération depuis 12 mois.  
**Si on insiste :** Le test est fait dans un bloc avec `ROLLBACK` pour ne pas modifier l'état final. Le résultat affiché est « 1 compte(s) passe(s) DORMANT ».

**Q35. Comment `scan_echeances` évite-t-elle les doublons ?**  
**Réponse courte :** Avec `NOT EXISTS` sur `alerte` pour le même compte et le même type, avec `traitee = 'N'`.  
**Si on insiste :** Le trigger `trg_ct_echeance` crée les alertes à l'insertion/mise à jour ; `scan_echeances` fait un balayage global pour les comptes existants.

### Partie E

**Q36. Expliquez le type récursif et la double notation.**  
**Réponse courte :** `ref_parrain REF client_type` permet de chaîner les parrains. `c.ref_parrain.ref_parrain.nom` donne le grand-parrain.  
**Si on insiste :** E10 met à jour les parrains des clients 4, 5 et 6. Les clients 2 et 3 restent parrainés par 1. La requête affiche parrain et grand-parrain.

**Q37. Expliquez la collection multi-niveaux `releves`.**  
**Réponse courte :** `releves` contient un `VARRAY(12)` de mois ; chaque mois contient une *nested table* de statistiques par type.  
**Si on insiste :** On interroge avec un double `TABLE` : `TABLE(r.mois_vry) m, TABLE(m.types) t`. Le relevé 2026 a 5 mois. Les totaux sont DEPOT 13/880 000, RETRAIT 32/620 000, VIREMENT 3/130 000, CB 2/35 000.

**Q38. Expliquez la vue objet `Agence_VOR`.**  
**Réponse courte :** C'est une vue de type `agence_vor_type` avec deux collections calculées par `CAST(MULTISET(...))`.  
**Si on insiste :** `WITH OBJECT IDENTIFIER (code)` donne un OID à la vue. `MAKE_REF(agence, a.code)` fabrique les REF d'agence. On interroge les collections avec `TABLE(v.conseillers)` et `TABLE(v.comptes)`.

**Q39. Expliquez la méthode `mutation` et le problème de `date_fin`.**  
**Réponse courte :** Elle ferme l'affectation courante et en ouvre une nouvelle. `date_fin` doit être strictement supérieure à `date_debut`.  
**Si on insiste :** Si on mute le même jour, `SYSDATE` peut être égal à `date_debut`, ce qui viole `CK_AFF_DATES` (`ORA-02290`). On utilise `GREATEST(SYSDATE, date_debut) + 1/86400`.

**Q40. Pourquoi la mutation ne remplace-t-elle pas automatiquement le responsable ?**  
**Réponse courte :** Parce que le sujet demande de signaler, pas de remplacer.  
**Si on insiste :** Le responsable est un rôle de management. Le remplacer automatiquement pourrait violer les règles internes. La méthode ferme l'affectation et laisse la décision au gestionnaire.

### Validation et soutenance

**Q41. Pourquoi y a-t-il des erreurs ORA dans la sortie ?**  
**Réponse courte :** Ce sont des tests d'exception volontaires.  
**Si on insiste :** `ORA-20001` à `ORA-20004` pour les triggers, `ORA-20010`/`ORA-20011` pour la mutation, et les `ORA-06512`/`ORA-04088` associés. Ils sont capturés par `EXCEPTION WHEN OTHERS` et affichés comme « Refus attendu ». Aucune erreur de compilation.

**Q42. Pourquoi 0 objet invalide est-il important ?**  
**Réponse courte :** Parce qu'après `ALTER TYPE ... CASCADE`, les objets dépendants peuvent devenir INVALID.  
**Si on insiste :** On recompile toutes les procédures/fonctions à la fin de la partie D. Le contrôle final `WHERE status <> 'VALID'` ne retourne aucune ligne.

**Q43. Que se passe-t-il si on relance le script ?**  
**Réponse courte :** Il supprime et recrée tout ; le résultat final est identique.  
**Si on insiste :** Les séquences sont recréées, les données réinsérées. Ce n'est pas un script de production, c'est un script de régénération de TP.

**Q44. Pourquoi le script unique est-il une concaténation et pas un `@` ?**  
**Réponse courte :** Pour qu'il soit portable et exécutable seul, sans dépendre du chemin des parties.  
**Si on insiste :** Les parties restent séparées pour la lisibilité et l'évaluation. Le script unique ajoute des séparateurs et un contrôle final.

**Q45. Quelles sont les limites de votre projet ?**  
**Réponse courte :** Opérations uniquement sur les comptes courants ; virement CC→CC ; pas de remplacement automatique du responsable ; pas d'interface graphique ; pas de tests de concurrence.  
**Si on insiste :** Ces limites sont documentées dans `ETAPE_0_CADRAGE.md`. On peut les justifier par le sujet ou par le temps. Par exemple, `operation_type.ref_compte` est `REF cptCourant_type` : un virement vers l'épargne demanderait un modèle polymorphe.

## 8.3 Les 15 pièges à éviter

1. **Ne pas confondre `CARDINALITY` et `COUNT`** : `CARDINALITY` sur nested table, `TABLE` + `COUNT` sur VARRAY.
2. **Ne pas oublier l'alias** pour `c.adresse.ville`, `c.ref_conseiller.nom`, `c.ref_parrain.nom`.
3. **Ne pas dire que les ORA sont des bugs** : ce sont des tests.
4. **Ne pas dire que `virement` fait `COMMIT`** : il ne le fait pas.
5. **Ne pas dire que `passeMvt` double le solde** : le recalcul est idempotent.
6. **Ne pas confondre `trg_op_avant` et `trg_op_apres`** : avant = validation, après = solde/alertes.
7. **Ne pas oublier `GREATEST(SYSDATE, date_debut) + 1/86400`** dans la mutation.
8. **Ne pas dire que `client` a un OID basé sur la PK** : c'est `agence`.
9. **Ne pas dire que `AUDIT` est une table normale** : il est entre guillemets.
10. **Ne pas dire que la nested table des signataires a des FK/triggers** : Oracle l'interdit.
11. **Ne pas capturer la partie C après la partie D** : CC1/CE4/1,5 M ne sont plus là.
12. **Ne pas oublier que `CT4` est supprimé par 6.25**.
13. **Ne pas oublier que `CE4` et `CC1` sont supprimés par `fermeCompte`**.
14. **Ne pas dire que la vue objet est une table** : c'est une vue de type objet.
15. **Ne pas promettre une fonctionnalité non implémentée** : dis « limite documentée » et explique comment tu la ferais.

## 8.4 Phrases de secours

- « Je n'ai pas implémenté ce point, mais voici comment je le ferais… »
- « Ce n'est pas un bug : c'est un test d'exception volontaire, voici le bloc qui le capture. »
- « La sortie complète est dans `_FULL.out`, je peux vous montrer la section exacte. »
- « Ce choix est justifié dans `ETAPE_0_CADRAGE.md`, hypothèse H… »
- « Je préfère ne pas modifier l'état en direct ; je vous montre la sortie déjà exécutée. »

## 8.5 Chiffres à retenir

| Chiffre | Valeur |
|---|---|
| Clients | 6 |
| Conseillers | 4 |
| Agences | 3 |
| Comptes courants (final) | 6 |
| Comptes d'épargne (final) | 4 |
| Comptes à terme (final) | 3 |
| Opérations (final) | 15 |
| Signataires (final) | 9 |
| Alertes | 2 |
| Audit | 0 |
| Types métier | 19 |
| Tables logiques | 11 + 1 stockage |
| Séquences | 4 |
| Triggers | 6 |
| Sous-programmes catalogués | 9 |
| Objets invalides | 0 |

**Soldes finaux des CC :** CC2 -50 000 ; CC3 38 000 ; CC4 325 000 ; CC5 0 BLOQUE ; CC6 40 000 ; CC7 185 000.  
**Soldes finaux des CE :** CE1 150 000 ; CE2 250 000 ; CE3 80 000 ; CE5 500 000.  
**Soldes finaux des CT :** CT1 200 000 ; CT2 100 000 ; CT3 50 000.

## 8.6 Checklist avant de passer

- [ ] La base répond et `MASTER1` existe.
- [ ] `projet_bdda_banque.sql` a été exécuté en entier (exit code 0).
- [ ] `SELECT COUNT(*) FROM user_objects WHERE status <> 'VALID';` retourne 0.
- [ ] Je sais citer les 5 parties et les fichiers.
- [ ] Je sais expliquer 3 choix : héritage, OID client, trigger COMPOUND.
- [ ] Je sais montrer 3 preuves : `nbCepargne`, `passeMvt`, `Agence_VOR`.
- [ ] Je sais expliquer 3 erreurs attendues : ORA-20001, ORA-20003, ORA-20010.
- [ ] Je sais dire pourquoi CC1/CE4/CT4 ont disparu.
- [ ] J'ai mes captures d'écran prêtes (`CAPTURES_A_FAIRE.md`).
- [ ] J'ai `_FULL.out` en secours.

---

**Fin du guide.**  
Pour les captures, voir `CAPTURES_A_FAIRE.md`. Pour les hypothèses et les choix détaillés, voir `ETAPE_0_CADRAGE.md`.
