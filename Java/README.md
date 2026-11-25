# BDDA Explorer

Interface graphique Java/Swing moderne pour tester les requêtes SQL du mini-projet BDDA (M1 ASR, Oracle 21c XE).

L'application propose :

- un catalogue de **46 requêtes** prêtes à l'emploi :
  - les **34 requêtes de la partie C** (`partie_C_requetes.sql`, 6.1 à 6.25),
  - 12 requêtes de contrôle issues des parties D et E (fonctions, méthodes objet, `Agence_VOR`, diagnostics) ;
- une recherche instantanée par code, titre, description, catégorie ou texte SQL ;
- un éditeur SQL avec coloration syntaxique et numéros de ligne ;
- l'exécution par `Ctrl+Entrée`, avec gestion des blocs PL/SQL et récupération de `DBMS_OUTPUT` ;
- un tableau de résultats triable, un historique et un onglet « Messages » ;
- l'export CSV, la copie du SQL ou de la ligne sélectionnée ;
- une confirmation obligatoire avant toute instruction susceptible de modifier les données (notamment la requête destructive 6.25).

## Prérequis

- JDK **21 ou supérieur** (testé avec JDK 24).
- Pilote Oracle JDBC fourni dans `lib/ojdbc11.jar` (compatible Oracle 21c / 23ai).
- Une base Oracle accessible. Valeurs par défaut :

| Paramètre | Valeur |
|---|---|
| Hôte | `localhost` |
| Port | `1521` |
| Service / PDB | `XEPDB1` |
| Utilisateur | `MASTER1` |
| Mot de passe | celui utilisé lors de la création du compte |

> Si le schéma `MASTER1` a été purgé, rejouer `projet_bdda_banque.sql` (ou les scripts A → E) depuis la racine du projet avant d'exécuter les requêtes métier.

## Compilation et lancement

Depuis ce dossier `Java` :

```bat
build.bat
run.bat
```

`run.bat` compile puis lance l'application. Pour lancer sans recompiler :

```bat
java -cp "out;lib\ojdbc11.jar" bdda.explorer.DatabaseExplorerApp
```

Compilation manuelle équivalente :

```bat
javac -encoding UTF-8 -cp "lib\ojdbc11.jar" -d out src\bdda\explorer\*.java
```

## Utilisation

1. Cliquer sur **⚡ Connexion rapide** en haut à droite : les paramètres du projet (`localhost`, `1521`, `XEPDB1`, `MASTER1`, mot de passe `system`) sont appliqués immédiatement.
2. Pour une autre base, cliquer sur **Configurer** : la fenêtre de connexion permet de saisir l'hôte, le port, le service, l'utilisateur et le mot de passe. Un bouton « Valeurs du projet » pré-remplit les champs.
3. Choisir une catégorie dans la barre latérale ou utiliser le champ de recherche.
4. Cliquer sur une carte : la requête se charge dans l'éditeur.
5. Modifier si besoin le SQL (par exemple le numéro de client ou la ville), puis cliquer sur **Exécuter** ou appuyer sur `Ctrl+Entrée`.
6. Consulter les onglets **Résultats**, **Historique** et **Messages**.
7. Exporter le résultat avec **Exporter CSV**.

La configuration (hôte, port, service, utilisateur) est mémorisée dans les préférences utilisateur Java. Le mot de passe n'est jamais enregistré.

## Organisation de l'interface

La fenêtre principale adopte une organisation en **trois colonnes**, sous un en-tête unique, avec un **thème sombre** et une couleur d’accent propre à chaque zone : cyan pour le catalogue, bleu pour l’éditeur, violet pour les résultats.

| Colonne | Rôle |
|---|---|
| Gauche | catégories (puces cliquables), recherche et liste des requêtes |
| Centre | éditeur SQL avec ses actions (exécuter, réinitialiser, copier, exporter) |
| Droite | résultats, historique et messages dans des onglets |

Un bandeau inférieur affiche l'état de connexion, la catégorie/requête courante, le nombre de lignes et les raccourcis. Les deux séparateurs entre colonnes sont proportionnels : le catalogue occupe environ 24 % de la largeur, l'éditeur environ 40 % et les résultats le reste. Les espacements et les cartes sont volontairement généreux pour éviter l’effet « tout mélangé ». La fenêtre de connexion est organisée en deux sections : serveur Oracle puis compte Oracle.

## Structure

```text
Java/
├─ build.bat
├─ run.bat
├─ lib/
│  └─ ojdbc11.jar          # pilote Oracle JDBC
├─ out/                     # classes compilées (généré)
└─ src/bdda/explorer/
   ├─ DatabaseExplorerApp.java   # fenêtre principale, catalogue, exécution
   ├─ DatabaseService.java       # connexion JDBC, SELECT, DML, DBMS_OUTPUT
   ├─ QueryCatalog.java          # 46 requêtes pédagogiques
   ├─ QueryDefinition.java       # modèle d'une requête
   ├─ QueryCard.java             # carte cliquable du catalogue
   ├─ SqlEditorPanel.java        # éditeur SQL coloré
   ├─ ResultTableModel.java      # modèle du tableau de résultats
   ├─ HistoryEntry.java          # entrée d'historique
   └─ ModernTheme.java           # palette, boutons, tableaux, pastilles
```

## Notes techniques

- Les requêtes 6.1 → 6.25 sont reprises fidèlement de `partie_C_requetes.sql`; seule la ponctuation finale a été normalisée pour l'exécution JDBC.
- La requête 6.25 (« suppression des comptes à terme expirés ») est marquée comme destructive : une confirmation est demandée avant exécution.
- La requête 6.19c est un bloc PL/SQL : sortie via `DBMS_OUTPUT.GET_LINE`, affichée dans l'onglet **Messages**.
- Les objets Oracle (`REF`, `VALUE`, collections `TABLE(...)`) sont convertis en chaînes lisibles pour l'affichage.
- Aucune dépendance graphique externe : l'interface repose uniquement sur Swing et le pilote JDBC Oracle.
