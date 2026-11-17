package bdda.explorer;

import java.util.Arrays;
import java.util.List;

/**
 * Catalogue des requêtes pédagogiques du mini-projet BDDA.
 * Les requêtes 6.1 à 6.25 reprennent fidèlement {@code partie_C_requetes.sql}.
 */
public final class QueryCatalog {

    private static final List<QueryDefinition> QUERIES = List.of(

            /* ---------------- Partie C : requêtes simples ---------------- */
            q("6.1", "Clients sans leurs numéros de téléphone", "Simples",
                    "Projection complète des clients, avec notation pointée sur l'adresse et les références.",
                    """
                    SELECT c.num_client, c.nom, c.prenom, c.date_naissance, c.num_secu,
                           c.adresse.num_rue AS num, c.adresse.rue AS rue, c.adresse.ville AS ville,
                           c.adresse.cp AS cp, c.email, c.date_entree,
                           c.ref_conseiller.nom AS conseiller,
                           c.ref_parrain.nom    AS parrain
                      FROM client c
                     ORDER BY c.num_client
                    """),

            q("6.2", "Comptes courants", "Simples",
                    "Les attributs de base de la table objet CPT_COURANT.",
                    """
                    SELECT num_compte, solde, date_ouverture, decouvert, nb_op_cb
                      FROM cpt_courant
                     ORDER BY num_compte
                    """),

            q("6.3a", "Comptes d'épargne par taux décroissant", "Simples",
                    "Tri des comptes d'épargne sur le taux d'intérêt.",
                    """
                    SELECT num_compte, solde, date_ouverture, taux_interet, plafond_depot
                      FROM cpt_epargne
                     ORDER BY taux_interet DESC
                    """),

            q("6.3b", "Comptes à terme par échéance", "Simples",
                    "Tri des comptes à terme par date d'échéance.",
                    """
                    SELECT num_compte, solde, date_ouverture, montant_bloque,
                           duree_mois, date_echeance, taux_garanti
                      FROM cpt_terme
                     ORDER BY date_echeance
                    """),

            /* ---------------- Partie C : références ---------------- */
            q("6.4", "Comptes courants du client 4", "Références",
                    "Jointure implicite avec REF(c) : démonstration de l'égalité de références objets.",
                    """
                    SELECT cc.num_compte, cc.solde, cc.date_ouverture, cc.decouvert
                      FROM cpt_courant cc, client c
                     WHERE cc.ref_client = REF(c)
                       AND c.num_client = 4
                     ORDER BY cc.num_compte
                    """),

            q("6.5", "Tous les comptes du client 4", "Références",
                    "UNION ALL des trois familles de comptes avec un libellé de type.",
                    """
                    SELECT cc.num_compte, 'COURANT' AS type_compte, cc.solde, cc.date_ouverture,
                           'decouvert='||cc.decouvert AS info
                      FROM cpt_courant cc, client c
                     WHERE cc.ref_client = REF(c) AND c.num_client = 4
                    UNION ALL
                    SELECT ce.num_compte, 'EPARGNE', ce.solde, ce.date_ouverture,
                           'taux='||ce.taux_interet
                      FROM cpt_epargne ce, client c
                     WHERE ce.ref_client = REF(c) AND c.num_client = 4
                    UNION ALL
                    SELECT ct.num_compte, 'TERME', ct.solde, ct.date_ouverture,
                           'bloque='||ct.montant_bloque
                      FROM cpt_terme ct, client c
                     WHERE ct.ref_client = REF(c) AND c.num_client = 4
                     ORDER BY 2, 1
                    """),

            q("6.6", "Comptes courants sous le seuil de 100 000 DA", "Références",
                    "Seuil pédagogique fixé à 100 000 DA dans le guide de soutenance.",
                    """
                    -- Seuil choisi : 100 000 DA (le sujet parle d'un seuil "donne").
                    SELECT c.num_client, c.nom, c.adresse.ville AS ville,
                           cc.num_compte, cc.solde
                      FROM client c, cpt_courant cc
                     WHERE cc.ref_client = REF(c)
                       AND cc.solde < 100000
                     ORDER BY c.num_client, cc.num_compte
                    """),

            q("6.7a", "Clients ayant au moins un compte d'épargne", "Références",
                    "DISTINCT appliqué après une jointure sur référence objet.",
                    """
                    SELECT DISTINCT c.num_client, c.nom, c.adresse.ville AS ville
                      FROM client c, cpt_epargne ce
                     WHERE ce.ref_client = REF(c)
                     ORDER BY c.num_client
                    """),

            q("6.7b", "Clients ayant un seul compte d'épargne", "Références",
                    "GROUP BY / HAVING sur le dénombrement des comptes d'épargne.",
                    """
                    SELECT c.num_client, c.nom, c.adresse.ville AS ville
                      FROM client c, cpt_epargne ce
                     WHERE ce.ref_client = REF(c)
                     GROUP BY c.num_client, c.nom, c.adresse.ville
                    HAVING COUNT(*) = 1
                     ORDER BY c.num_client
                    """),

            q("6.8", "Clients ayant opéré sur CC7", "Références",
                    "Triple jointure CLIENT / OPERATION / CPT_COURANT.",
                    """
                    SELECT c.num_client, c.nom, o.date_op, o.montant, o.type_op
                      FROM client c, operation o, cpt_courant cc
                     WHERE o.ref_client = REF(c)
                       AND o.ref_compte = REF(cc)
                       AND cc.num_compte = 'CC7'
                     ORDER BY o.date_op
                    """),

            q("6.9a", "Opérations CC7 faites par le propriétaire", "Références",
                    "Comparaison directe entre la référence de l'opération et celle du titulaire.",
                    """
                    SELECT o.id_op, o.date_op, o.montant, o.type_op, c.nom AS client
                      FROM operation o, client c, cpt_courant cc
                     WHERE o.ref_client = REF(c)
                       AND o.ref_compte = REF(cc)
                       AND cc.num_compte = 'CC7'
                       AND o.ref_client = cc.ref_client
                     ORDER BY o.date_op
                    """),

            q("6.9b", "Opérations CC7 faites par des non-propriétaires", "Références",
                    "Le même raisonnement avec une inégalité de références.",
                    """
                    SELECT o.id_op, o.date_op, o.montant, o.type_op, c.nom AS client
                      FROM operation o, client c, cpt_courant cc
                     WHERE o.ref_client = REF(c)
                       AND o.ref_compte = REF(cc)
                       AND cc.num_compte = 'CC7'
                       AND o.ref_client <> cc.ref_client
                     ORDER BY o.date_op
                    """),

            q("6.10", "Soldes négatifs, titulaire et conseiller", "Références",
                    "Jointure objet puis notation pointée sur REF_CONSEILLER.",
                    """
                    SELECT cc.num_compte, cc.solde, cc.decouvert,
                           c.nom AS titulaire,
                           c.ref_conseiller.nom AS conseiller
                      FROM cpt_courant cc, client c
                     WHERE cc.ref_client = REF(c)
                       AND cc.solde < 0
                     ORDER BY cc.num_compte
                    """),

            /* ---------------- Partie C : agrégats ---------------- */
            q("6.11a", "Nombre de comptes d'épargne par client", "Agrégats",
                    "Agrégat simple : seuls les clients possédant un compte apparaissent.",
                    """
                    SELECT c.num_client, c.nom, COUNT(ce.num_compte) AS nb_epargne
                      FROM client c, cpt_epargne ce
                     WHERE ce.ref_client = REF(c)
                     GROUP BY c.num_client, c.nom
                     ORDER BY c.num_client
                    """),

            q("6.11b", "Comptes d'épargne, y compris les clients sans compte", "Agrégats",
                    "Jointure externe gauche pour conserver les clients sans épargne.",
                    """
                    SELECT c.num_client, c.nom, COUNT(ce.num_compte) AS nb_epargne
                      FROM client c
                      LEFT JOIN cpt_epargne ce ON ce.ref_client = REF(c)
                     GROUP BY c.num_client, c.nom
                     ORDER BY c.num_client
                    """),

            q("6.12", "Titulaire ayant le plus de comptes d'épargne", "Agrégats",
                    "HAVING COUNT(*) = MAX(COUNT(*)) avec sous-requête imbriquée.",
                    """
                    SELECT c.num_client, c.nom, COUNT(*) AS nb_epargne
                      FROM client c, cpt_epargne ce
                     WHERE ce.ref_client = REF(c)
                     GROUP BY c.num_client, c.nom
                    HAVING COUNT(*) = (SELECT MAX(COUNT(*))
                                         FROM cpt_epargne ce2, client c2
                                        WHERE ce2.ref_client = REF(c2)
                                        GROUP BY c2.num_client)
                     ORDER BY c.num_client
                    """),

            q("6.13", "Nombre et montant moyen par type d'opération", "Agrégats",
                    "COUNT, AVG et ROUND sur une table objet.",
                    """
                    SELECT type_op, COUNT(*) AS nb_operations,
                           ROUND(AVG(montant), 2) AS montant_moyen
                      FROM operation
                     GROUP BY type_op
                     ORDER BY type_op
                    """),

            q("6.14", "Total des soldes par agence", "Agrégats",
                    "Sous-requête UNION ALL puis agrégation sur REF_AGENCE.",
                    """
                    SELECT a.code, a.nom, SUM(x.solde) AS total_soldes
                      FROM agence a,
                           (SELECT ref_agence, solde FROM cpt_courant
                            UNION ALL
                            SELECT ref_agence, solde FROM cpt_epargne) x
                     WHERE x.ref_agence = REF(a)
                     GROUP BY a.code, a.nom
                     ORDER BY a.code
                    """),

            q("6.15", "Top 3 des clients par solde total", "Agrégats",
                    "Sous-requêtes corrélées, NVL et FETCH FIRST 3 ROWS ONLY.",
                    """
                    SELECT c.num_client, c.nom,
                           NVL((SELECT SUM(solde) FROM cpt_courant x WHERE x.ref_client = REF(c)), 0)
                         + NVL((SELECT SUM(solde) FROM cpt_epargne x WHERE x.ref_client = REF(c)), 0)
                         + NVL((SELECT SUM(solde) FROM cpt_terme   x WHERE x.ref_client = REF(c)), 0)
                           AS solde_total
                      FROM client c
                     ORDER BY solde_total DESC
                     FETCH FIRST 3 ROWS ONLY
                    """),

            /* ---------------- Partie C : collections ---------------- */
            q("6.16a", "Téléphones renseignés du client 1", "Collections",
                    "TABLE() sur un VARRAY : COUNT(*) vs COUNT(COLUMN_VALUE).",
                    """
                    SELECT COUNT(*)                AS nb_elements,
                           COUNT(t.COLUMN_VALUE)   AS nb_renseignes
                      FROM TABLE (SELECT telephones FROM client WHERE num_client = 1) t
                    """),

            q("6.16b", "Téléphones renseignés pour chaque client", "Collections",
                    "Le VARRAY est déroulé pour chaque ligne de CLIENT.",
                    """
                    -- COUNT(*) compte les 3 emplacements du VARRAY, COUNT(COLUMN_VALUE)
                    -- ne compte que ceux qui ne sont pas NULL.
                    SELECT c.num_client, c.nom,
                           COUNT(*)              AS nb_elements,
                           COUNT(t.COLUMN_VALUE) AS nb_renseignes
                      FROM client c, TABLE(c.telephones) t
                     GROUP BY c.num_client, c.nom
                     ORDER BY c.num_client
                    """),

            q("6.17", "Numéros de téléphone de chaque client", "Collections",
                    "NVL appliqué sur les cases vides du VARRAY.",
                    """
                    SELECT c.num_client, c.nom,
                           NVL(t.COLUMN_VALUE, '<non renseigne>') AS telephone
                      FROM client c, TABLE(c.telephones) t
                     ORDER BY c.num_client
                    """),

            q("6.18a", "Nombre de signataires de CC7", "Collections",
                    "TABLE() appliquée à la nested table SIGNATAIRES.",
                    """
                    SELECT COUNT(*) AS nb_signataires
                      FROM TABLE (SELECT signataires FROM cpt_courant WHERE num_compte = 'CC7')
                    """),

            q("6.18b", "Signataires de chaque compte courant", "Collections",
                    "Sous-requête corrélée COUNT(*) FROM TABLE(cc.signataires).",
                    """
                    SELECT cc.num_compte,
                           (SELECT COUNT(*) FROM TABLE(cc.signataires)) AS nb_signataires
                      FROM cpt_courant cc
                     ORDER BY cc.num_compte
                    """),

            q("6.19a", "Signataires de CC7", "Collections",
                    "Déréférencement de REF_CLIENT depuis la nested table.",
                    """
                    SELECT s.ref_client.num_client AS num_client,
                           s.ref_client.nom        AS nom,
                           s.droit
                      FROM cpt_courant cc, TABLE(cc.signataires) s
                     WHERE cc.num_compte = 'CC7'
                     ORDER BY s.ref_client.num_client
                    """),

            q("6.19b", "Signataires de tous les comptes courants", "Collections",
                    "Même requête sans filtre sur le compte.",
                    """
                    SELECT cc.num_compte, s.ref_client.num_client AS num_client,
                           s.ref_client.nom AS nom, s.droit
                      FROM cpt_courant cc, TABLE(cc.signataires) s
                     ORDER BY cc.num_compte, s.ref_client.num_client
                    """),

            plsql("6.19c", "Curseurs imbriqués (DBMS_OUTPUT)", "Collections",
                    "Bloc PL/SQL : résultat identique à 6.19b, mais affiché via DBMS_OUTPUT.",
                    """
                    DECLARE
                      CURSOR c_comptes IS
                        SELECT num_compte FROM cpt_courant ORDER BY num_compte;
                      CURSOR c_sigs (p_compte VARCHAR2) IS
                        SELECT s.ref_client.nom AS nom, s.droit
                          FROM cpt_courant cc, TABLE(cc.signataires) s
                         WHERE cc.num_compte = p_compte
                         ORDER BY s.ref_client.num_client;
                    BEGIN
                      FOR r IN c_comptes LOOP
                        DBMS_OUTPUT.PUT_LINE('Compte '||r.num_compte);
                        FOR s IN c_sigs(r.num_compte) LOOP
                          DBMS_OUTPUT.PUT_LINE('   '||RPAD(s.nom, 15)||' droit '||s.droit);
                        END LOOP;
                      END LOOP;
                    END;
                    """),

            q("6.20", "Signataires de CC7 avec adresse", "Collections",
                    "Jointure COLLECTION / CLIENT pour récupérer l'adresse objet.",
                    """
                    SELECT c.num_client, c.nom,
                           c.adresse.num_rue||' '||c.adresse.rue||', '||c.adresse.ville AS adresse,
                           s.droit
                      FROM cpt_courant cc, TABLE(cc.signataires) s, client c
                     WHERE cc.num_compte = 'CC7'
                       AND s.ref_client = REF(c)
                     ORDER BY c.num_client
                    """),

            /* ---------------- Partie C : gestion ---------------- */
            q("6.21a", "Tous les clients par ville", "Gestion",
                    "Tri sur un attribut imbriqué : C.ADRESSE.VILLE.",
                    """
                    SELECT c.adresse.ville AS ville, c.num_client, c.nom, c.prenom
                      FROM client c
                     ORDER BY c.adresse.ville, c.nom
                    """),

            q("6.21b", "Recherche d'une ville : Bejaia", "Gestion",
                    "Filtre sur ADRESSE.VILLE ; modifier la chaîne pour tester une autre ville.",
                    """
                    SELECT c.num_client, c.nom, c.prenom, c.adresse.ville AS ville
                      FROM client c
                     WHERE c.adresse.ville = 'Bejaia'
                     ORDER BY c.nom
                    """),

            q("6.22", "Échéances à 30 jours", "Gestion",
                    "BETWEEN TRUNC(SYSDATE) et TRUNC(SYSDATE) + 30.",
                    """
                    SELECT num_compte, montant_bloque, date_echeance,
                           date_echeance - TRUNC(SYSDATE) AS jours_restants
                      FROM cpt_terme
                     WHERE date_echeance BETWEEN TRUNC(SYSDATE) AND TRUNC(SYSDATE) + 30
                     ORDER BY date_echeance
                    """),

            q("6.23", "Comptes courants inactifs depuis 12 mois", "Gestion",
                    "NOT EXISTS et MAX(DATE_OP) sur une sous-requête corrélée.",
                    """
                    SELECT cc.num_compte, cc.solde, cc.statut,
                           (SELECT MAX(o.date_op) FROM operation o
                             WHERE o.ref_compte = REF(cc)) AS derniere_operation
                      FROM cpt_courant cc
                     WHERE NOT EXISTS (SELECT 1 FROM operation o
                                        WHERE o.ref_compte = REF(cc)
                                          AND o.date_op > ADD_MONTHS(TRUNC(SYSDATE), -12))
                     ORDER BY cc.num_compte
                    """),

            q("6.24", "Opérations de plus de 1 000 000 DA", "Gestion",
                    "Jointure trois tables et tri sur le montant décroissant.",
                    """
                    SELECT o.id_op, o.date_op, o.montant, o.type_op,
                           c.num_client, c.nom AS client, cc.num_compte
                      FROM operation o, client c, cpt_courant cc
                     WHERE o.ref_client = REF(c)
                       AND o.ref_compte = REF(cc)
                       AND o.montant > 1000000
                     ORDER BY o.montant DESC
                    """),

            multi("6.25", "Suppression des comptes à terme expirés", "Gestion",
                    "REQUÊTE DESTRUCTIVE : sélection, DELETE, COMMIT puis vérification. Confirmation requise.",
                    true,
                    """
                    SELECT num_compte, montant_bloque, date_echeance
                      FROM cpt_terme
                     WHERE date_echeance < ADD_MONTHS(TRUNC(SYSDATE), -12)
                       AND montant_bloque = 0
                    """,
                    """
                    DELETE FROM cpt_terme
                     WHERE date_echeance < ADD_MONTHS(TRUNC(SYSDATE), -12)
                       AND montant_bloque = 0
                    """,
                    """
                    COMMIT
                    """,
                    """
                    SELECT num_compte, montant_bloque, date_echeance
                      FROM cpt_terme
                     ORDER BY num_compte
                    """),

            /* ---------------- Partie D : fonctions et objets ---------------- */
            q("D-01", "Fonctions globales du schéma", "Diagnostic",
                    "Appel direct des trois fonctions stockées créées en partie D.",
                    """
                    SELECT nb_comptes()                        AS nb_comptes,
                           solde_total(1)                     AS solde_client_1,
                           ville_client(1)                    AS ville_client_1
                      FROM dual
                    """),

            q("D-02", "Méthodes objet du client 1", "Objets",
                    "NBCEPARGNE() et SOLDETOTAL() appelées sur VALUE(c).",
                    """
                    SELECT c.num_client, c.nom,
                           c.nbCepargne() AS nb_epargne,
                           c.soldeTotal() AS solde_total
                      FROM client c
                     WHERE c.num_client = 1
                    """),

            q("D-03", "Méthodes des comptes courants", "Objets",
                    "NBSIGNATAIRE(), NBSIGNATAIRE('T') et FRAISTENUE() sur la table objet.",
                    """
                    SELECT cc.num_compte, cc.solde,
                           cc.nbSignataire()        AS nb_signataires,
                           cc.nbSignataire('T')     AS nb_titulaires,
                           cc.fraisTenue()          AS frais_tenue
                      FROM cpt_courant cc
                     ORDER BY cc.num_compte
                    """),

            q("D-04", "Intérêts des comptes d'épargne", "Objets",
                    "CALCULEINTERETS() et SORTIEANTICIPEE() de CPTEPARGNE_TYPE.",
                    """
                    SELECT ce.num_compte, ce.solde, ce.taux_interet,
                           ce.calculeInterets()  AS interets,
                           ce.sortieAnticipee()  AS sortie_anticipee
                      FROM cpt_epargne ce
                     ORDER BY ce.num_compte
                    """),

            q("D-05", "Intérêts des comptes à terme", "Objets",
                    "Les mêmes méthodes appliquées au type CPTTERME_TYPE.",
                    """
                    SELECT ct.num_compte, ct.solde, ct.taux_garanti,
                           ct.calculeInterets()  AS interets,
                           ct.sortieAnticipee()  AS sortie_anticipee
                      FROM cpt_terme ct
                     ORDER BY ct.num_compte
                    """),

            /* ---------------- Partie E : objets avancés ---------------- */
            q("E-01", "Vue objet AGENCE_VOR : cardinalités", "Objets",
                    "CARDINALITY() sur les deux collections de la vue objet.",
                    """
                    SELECT a.code, a.nom,
                           CARDINALITY(a.conseillers) AS nb_conseillers,
                           CARDINALITY(a.comptes)     AS nb_comptes
                      FROM Agence_VOR a
                     ORDER BY a.code
                    """),

            q("E-02", "Conseillers en poste via la vue objet", "Collections",
                    "TABLE(a.conseillers) sur AGENCE_VOR.",
                    """
                    SELECT a.code AS agence, c.num_conseiller, c.nom AS conseiller, c.prenom
                      FROM Agence_VOR a, TABLE(a.conseillers) c
                     ORDER BY a.code, c.num_conseiller
                    """),

            q("E-03", "Comptes courants par agence (vue objet)", "Collections",
                    "TABLE(a.comptes) sur AGENCE_VOR.",
                    """
                    SELECT a.code AS agence, cc.num_compte, cc.solde, cc.statut
                      FROM Agence_VOR a, TABLE(a.comptes) cc
                     ORDER BY a.code, cc.num_compte
                    """),

            q("E-04", "Alertes et lignes d'audit", "Diagnostic",
                    "Contrôle du déclenchement des triggers et de la table AUDIT.",
                    """
                    SELECT 'ALERTE' AS origine, TO_CHAR(NULL) AS detail, COUNT(*) AS nb
                      FROM alerte
                    UNION ALL
                    SELECT 'AUDIT', TO_CHAR(NULL), COUNT(*)
                      FROM "AUDIT"
                    """),

            q("DIA-01", "Objets invalides du schéma", "Diagnostic",
                    "Doit renvoyer 0 lignes après une replay complète A → E.",
                    """
                    SELECT object_name, object_type, status
                      FROM user_objects
                     WHERE status <> 'VALID'
                     ORDER BY object_type, object_name
                    """),

            q("DIA-02", "Comptage des objets par type", "Diagnostic",
                    "Récapitulatif du schéma MASTER1 (12 tables, 6 triggers, etc.).",
                    """
                    SELECT object_type, COUNT(*) AS nb
                      FROM user_objects
                     GROUP BY object_type
                     ORDER BY object_type
                    """),

            q("DIA-03", "Volumes des tables métier", "Diagnostic",
                    "Contrôle rapide des effectifs après rejeu des scripts.",
                    """
                    SELECT 'CLIENT' AS table_name, COUNT(*) AS nb FROM client
                    UNION ALL SELECT 'CONSEILLER', COUNT(*) FROM conseiller
                    UNION ALL SELECT 'AGENCE', COUNT(*) FROM agence
                    UNION ALL SELECT 'CPT_COURANT', COUNT(*) FROM cpt_courant
                    UNION ALL SELECT 'CPT_EPARGNE', COUNT(*) FROM cpt_epargne
                    UNION ALL SELECT 'CPT_TERME', COUNT(*) FROM cpt_terme
                    UNION ALL SELECT 'OPERATION', COUNT(*) FROM operation
                    UNION ALL SELECT 'SIGNATAIRES CC7', COUNT(*) FROM TABLE(
                        SELECT signataires FROM cpt_courant WHERE num_compte = 'CC7')
                    UNION ALL SELECT 'AFFECTATION', COUNT(*) FROM affectation
                    ORDER BY 1
                    """)
    );

    private QueryCatalog() {
    }

    /** Toutes les requêtes, dans l'ordre pédagogique. */
    public static List<QueryDefinition> all() {
        return QUERIES;
    }

    /** Catégories affichées dans la barre latérale. */
    public static List<String> categories() {
        return List.of("Simples", "Références", "Agrégats", "Collections", "Gestion", "Objets", "Diagnostic");
    }

    private static String s(String sql) {
        return sql.strip();
    }

    private static QueryDefinition q(String code, String title, String category, String description, String sql) {
        return new QueryDefinition(code, title, category, description, List.of(s(sql)), false, false);
    }

    private static QueryDefinition multi(String code, String title, String category, String description,
                                         boolean destructive, String... sqls) {
        return new QueryDefinition(code, title, category, description,
                Arrays.stream(sqls).map(QueryCatalog::s).toList(), destructive, false);
    }

    private static QueryDefinition plsql(String code, String title, String category, String description, String block) {
        return new QueryDefinition(code, title, category, description, List.of(s(block)), false, true);
    }
}
