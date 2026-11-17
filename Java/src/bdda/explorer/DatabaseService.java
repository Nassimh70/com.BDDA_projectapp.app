package bdda.explorer;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.Date;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/** Accès JDBC Oracle et exécution des requêtes du catalogue. */
public final class DatabaseService implements AutoCloseable {

    /** Résultat d'une exécution, prêt à être affiché dans la table. */
    public record QueryResult(
            List<String> columns,
            List<List<String>> rows,
            int updateCount,
            List<String> messages,
            long elapsedMillis,
            int statements) {
    }

    private Connection connection;

    /** Construit une URL JDBC Oracle Thin. Une URL complète est acceptée aussi. */
    public static String buildUrl(String host, String port, String service) {
        String h = host == null ? "" : host.trim();
        if (h.toLowerCase(Locale.ROOT).startsWith("jdbc:")) {
            return h;
        }
        String p = port == null || port.isBlank() ? "1521" : port.trim();
        String svc = service == null || service.isBlank() ? "XEPDB1" : service.trim();
        return "jdbc:oracle:thin:@//" + h + ":" + p + "/" + svc;
    }

    /** Ouvre (ou remplace) la connexion courante. */
    public void connect(String url, String user, String password) throws SQLException {
        disconnect();
        connection = DriverManager.getConnection(url, user, password);
        try (Statement st = connection.createStatement()) {
            st.execute("ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY'");
        } catch (SQLException ignored) {
            // Non bloquant : l'affichage des dates reste géré côté Java.
        }
    }

    public boolean isConnected() {
        try {
            return connection != null && !connection.isClosed();
        } catch (SQLException e) {
            return false;
        }
    }

    public String currentUrl() {
        if (!isConnected()) {
            return "—";
        }
        try {
            return connection.getMetaData().getURL();
        } catch (SQLException e) {
            return "Connecté";
        }
    }

    /**
     * Exécute le texte issu de l'éditeur. Les instructions SELECT multiples sont
     * séparées sur ";". Les blocs PL/SQL sont exécutés en un seul appel et leurs
     * lignes DBMS_OUTPUT sont récupérées.
     */
    public QueryResult execute(String sqlText, boolean plsql) throws SQLException {
        if (!isConnected()) {
            throw new SQLException("Aucune connexion à la base de données.");
        }
        if (sqlText == null || sqlText.isBlank()) {
            throw new SQLException("L'éditeur SQL est vide.");
        }

        long start = System.nanoTime();
        List<String> columns = new ArrayList<>();
        List<List<String>> rows = new ArrayList<>();
        List<String> messages = new ArrayList<>();
        int[] update = {-1};
        int[] statements = {0};

        if (plsql) {
            enableDbmsOutput();
            executeOne(sqlText.strip(), columns, rows, update);
            statements[0] = 1;
            readDbmsOutput(messages);
        } else {
            String[] parts = sqlText.split(";\\s*");
            for (String part : parts) {
                String statement = part.strip();
                if (statement.isEmpty() || statement.startsWith("--")) {
                    continue;
                }
                executeOne(statement, columns, rows, update);
                statements[0]++;
            }
        }

        if (statements[0] == 0) {
            throw new SQLException("Aucune instruction SQL exécutable trouvée.");
        }

        long elapsed = (System.nanoTime() - start) / 1_000_000L;
        return new QueryResult(
                List.copyOf(columns),
                List.copyOf(rows),
                update[0],
                List.copyOf(messages),
                elapsed,
                statements[0]);
    }

    private void executeOne(String sql, List<String> columns, List<List<String>> rows, int[] update)
            throws SQLException {
        try (Statement statement = connection.createStatement()) {
            boolean hasResultSet = statement.execute(sql);
            if (hasResultSet) {
                try (ResultSet rs = statement.getResultSet()) {
                    TabularData data = readResultSet(rs);
                    if (columns.isEmpty()) {
                        columns.addAll(data.columns());
                    }
                    rows.addAll(data.rows());
                }
            } else {
                int count = statement.getUpdateCount();
                if (count >= 0) {
                    update[0] = count;
                }
            }
        }
    }

    private void enableDbmsOutput() {
        try (Statement st = connection.createStatement()) {
            st.execute("BEGIN DBMS_OUTPUT.ENABLE(1000000); END;");
        } catch (SQLException ignored) {
            // DBMS_OUTPUT peut être indisponible selon les droits : on continue.
        }
    }

    private void readDbmsOutput(List<String> messages) {
        String call = "BEGIN DBMS_OUTPUT.GET_LINE(?, ?); END;";
        try (CallableStatement cs = connection.prepareCall(call)) {
            cs.registerOutParameter(1, Types.VARCHAR);
            cs.registerOutParameter(2, Types.INTEGER);
            for (int i = 0; i < 2000; i++) {
                cs.execute();
                if (cs.getInt(2) != 0) {
                    break;
                }
                messages.add(cs.getString(1));
            }
        } catch (SQLException ignored) {
            // Silencieux : le bloc a tout de même été exécuté.
        }
    }

    private static TabularData readResultSet(ResultSet rs) throws SQLException {
        ResultSetMetaData md = rs.getMetaData();
        int colCount = md.getColumnCount();
        List<String> columns = new ArrayList<>(colCount);
        for (int i = 1; i <= colCount; i++) {
            String label = md.getColumnLabel(i);
            columns.add(label == null || label.isBlank() ? "COLONNE_" + i : label);
        }
        List<List<String>> rows = new ArrayList<>();
        while (rs.next()) {
            List<String> row = new ArrayList<>(colCount);
            for (int i = 1; i <= colCount; i++) {
                row.add(format(rs.getObject(i)));
            }
            rows.add(row);
        }
        return new TabularData(columns, rows);
    }

    private static String format(Object value) {
        if (value == null) {
            return "—";
        }
        if (value instanceof Timestamp ts) {
            return ts.toLocalDateTime().format(java.time.format.DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
        }
        if (value instanceof Date date) {
            return date.toLocalDate().toString();
        }
        return String.valueOf(value).trim();
    }

    private record TabularData(List<String> columns, List<List<String>> rows) {
    }

    public void disconnect() {
        if (connection != null) {
            try {
                connection.close();
            } catch (SQLException ignored) {
                // Fermetage best-effort.
            } finally {
                connection = null;
            }
        }
    }

    @Override
    public void close() {
        disconnect();
    }
}
