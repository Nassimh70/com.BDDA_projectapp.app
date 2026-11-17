package bdda.explorer;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/** Une entrée de l'historique d'exécution. */
public record HistoryEntry(
        String code,
        String label,
        String sql,
        int rowCount,
        long elapsedMillis,
        boolean success) {

    private static final DateTimeFormatter FORMAT = DateTimeFormatter.ofPattern("HH:mm:ss");

    public String time() {
        return LocalDateTime.now().format(FORMAT);
    }

    @Override
    public String toString() {
        String icon = success ? "✓" : "✕";
        return String.format("%s  %-7s %-34s %4d ligne(s)  %5d ms  %s",
                icon, code, abbreviate(label, 34), rowCount, elapsedMillis, time());
    }

    private static String abbreviate(String text, int max) {
        if (text == null || text.length() <= max) {
            return text == null ? "" : text;
        }
        return text.substring(0, max - 1) + "…";
    }
}
