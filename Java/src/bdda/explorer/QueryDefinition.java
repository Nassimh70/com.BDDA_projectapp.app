package bdda.explorer;

import java.util.List;

/**
 * Définition d'une requête affichée dans l'explorateur.
 *
 * @param code        identifiant pédagogique (ex. {@code 6.10})
 * @param title       titre court affiché dans la carte
 * @param category    famille de la requête
 * @param description explication pédagogique
 * @param statements  instructions SQL, sans point-virgule final (sauf PL/SQL)
 * @param destructive true si la requête modifie des données
 * @param plsql       true pour un bloc PL/SQL avec DBMS_OUTPUT
 */
public record QueryDefinition(
        String code,
        String title,
        String category,
        String description,
        List<String> statements,
        boolean destructive,
        boolean plsql) {

    /** Texte affiché / édité dans l'éditeur SQL. */
    public String sqlText() {
        if (plsql) {
            return statements.getFirst();
        }
        return String.join(";\n\n", statements) + ";";
    }
}
