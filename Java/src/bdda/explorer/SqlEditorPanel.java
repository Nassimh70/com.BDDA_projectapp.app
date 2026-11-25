package bdda.explorer;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Font;
import java.awt.Point;
import java.awt.event.AdjustmentEvent;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import javax.swing.BorderFactory;
import javax.swing.JPanel;
import javax.swing.JScrollPane;
import javax.swing.JTextArea;
import javax.swing.JTextPane;
import javax.swing.SwingUtilities;
import javax.swing.event.DocumentEvent;
import javax.swing.event.DocumentListener;
import javax.swing.text.AttributeSet;
import javax.swing.text.DefaultStyledDocument;
import javax.swing.text.SimpleAttributeSet;
import javax.swing.text.StyleConstants;
import javax.swing.text.StyledDocument;

/** Éditeur SQL avec coloration syntaxique et numéros de ligne. */
final class SqlEditorPanel extends JPanel {

    private static final long serialVersionUID = 1L;

    private static final Pattern TOKEN = Pattern.compile(
            "(--[^\\n]*)|" +
            "('(?:''|[^'])*')|" +
            "\\b(SELECT|FROM|WHERE|AND|OR|NOT|NULL|IS|IN|BETWEEN|LIKE|ORDER|BY|GROUP|HAVING|" +
            "UNION|ALL|DISTINCT|JOIN|LEFT|RIGHT|ON|AS|ASC|DESC|FETCH|FIRST|ROWS|ONLY|" +
            "INSERT|UPDATE|DELETE|COMMIT|ROLLBACK|TABLE|VALUE|REF|CAST|MULTISET|" +
            "DECLARE|BEGIN|END|LOOP|FOR|INTO|CURSOR|IF|THEN|ELSE|END|" +
            "CREATE|OR|REPLACE|VIEW|TYPE|BODY|FUNCTION|PROCEDURE|RETURN|NUMBER|VARCHAR2)\\b|" +
            "(\\b\\d+(?:\\.\\d+)?\\b)",
            Pattern.CASE_INSENSITIVE);

    private final JTextPane editor = new JTextPane();
    private final JTextArea gutter = new JTextArea("1");
    private final JScrollPane editorScroll;
    private final JScrollPane gutterScroll;
    private boolean highlighting;

    SqlEditorPanel() {
        setLayout(new BorderLayout());
        setBackground(ModernTheme.CARD);

        editor.setFont(ModernTheme.MONO);
        editor.setForeground(ModernTheme.TEXT);
        editor.setCaretColor(ModernTheme.ACCENT);
        editor.setBackground(ModernTheme.CARD);
        editor.setBorder(BorderFactory.createEmptyBorder(10, 12, 10, 12));
        editor.setDocument(new DefaultStyledDocument());

        gutter.setFont(ModernTheme.MONO);
        gutter.setForeground(ModernTheme.MUTED);
        gutter.setBackground(ModernTheme.CARD_ALT);
        gutter.setEditable(false);
        gutter.setFocusable(false);
        gutter.setHighlighter(null);
        gutter.setBorder(BorderFactory.createEmptyBorder(10, 10, 10, 8));
        gutter.setAlignmentX(RIGHT_ALIGNMENT);

        gutterScroll = new JScrollPane(gutter);
        gutterScroll.setBorder(null);
        gutterScroll.setBackground(gutter.getBackground());
        gutterScroll.getViewport().setBackground(gutter.getBackground());
        gutterScroll.setVerticalScrollBarPolicy(JScrollPane.VERTICAL_SCROLLBAR_NEVER);
        gutterScroll.setHorizontalScrollBarPolicy(JScrollPane.HORIZONTAL_SCROLLBAR_NEVER);

        editorScroll = new JScrollPane(editor);
        editorScroll.setBorder(null);
        editorScroll.setBackground(ModernTheme.CARD);
        editorScroll.getViewport().setBackground(ModernTheme.CARD);

        editorScroll.getVerticalScrollBar().addAdjustmentListener(this::syncGutter);
        editor.getDocument().addDocumentListener(new DocumentListener() {
            @Override public void insertUpdate(DocumentEvent e) { changed(); }
            @Override public void removeUpdate(DocumentEvent e) { changed(); }
            @Override public void changedUpdate(DocumentEvent e) {
                // Ignoré : setCharacterAttributes() déclenche_changedUpdate et
                // provoquerait une boucle de coloration infinie.
            }

            private void changed() {
                if (highlighting) {
                    return;
                }
                SwingUtilities.invokeLater(() -> {
                    updateGutter();
                    highlight();
                });
            }
        });

        add(gutterScroll, BorderLayout.WEST);
        add(editorScroll, BorderLayout.CENTER);
        updateGutter();
        highlight();
    }

    String getSql() {
        return editor.getText();
    }

    void setSql(String sql) {
        editor.setText(sql == null ? "" : sql);
        editor.setCaretPosition(0);
        editorScroll.getVerticalScrollBar().setValue(0);
        updateGutter();
        highlight();
    }

    private void syncGutter(AdjustmentEvent e) {
        int value = editorScroll.getVerticalScrollBar().getValue();
        gutterScroll.getViewport().setViewPosition(new Point(0, value));
    }

    private void updateGutter() {
        int lines = editor.getText().split("\n", -1).length;
        StringBuilder sb = new StringBuilder(lines * 4);
        for (int i = 1; i <= lines; i++) {
            if (i > 1) {
                sb.append('\n');
            }
            sb.append(i);
        }
        gutter.setText(sb.toString());
    }

    private void highlight() {
        if (highlighting) {
            return;
        }
        highlighting = true;
        StyledDocument doc = editor.getStyledDocument();
        String text = editor.getText();
        doc.setCharacterAttributes(0, text.length(), plain(), true);

        Matcher matcher = TOKEN.matcher(text);
        while (matcher.find()) {
            AttributeSet style;
            if (matcher.group(1) != null) {
                style = style(ModernTheme.SQL_COMMENT, Font.ITALIC);
            } else if (matcher.group(2) != null) {
                style = style(ModernTheme.SQL_STRING, Font.PLAIN);
            } else if (matcher.group(4) != null) {
                style = style(ModernTheme.SQL_NUMBER, Font.PLAIN);
            } else {
                style = style(ModernTheme.SQL_KEYWORD, Font.BOLD);
            }
            doc.setCharacterAttributes(matcher.start(), matcher.end() - matcher.start(), style, true);
        }
        highlighting = false;
    }

    private static AttributeSet plain() {
        SimpleAttributeSet set = new SimpleAttributeSet();
        StyleConstants.setForeground(set, ModernTheme.TEXT);
        StyleConstants.setFontFamily(set, ModernTheme.MONO.getFamily());
        StyleConstants.setFontSize(set, ModernTheme.MONO.getSize());
        StyleConstants.setBold(set, false);
        StyleConstants.setItalic(set, false);
        return set;
    }

    private static AttributeSet style(Color color, int fontStyle) {
        SimpleAttributeSet set = new SimpleAttributeSet();
        StyleConstants.setForeground(set, color);
        StyleConstants.setBold(set, fontStyle == Font.BOLD);
        StyleConstants.setItalic(set, fontStyle == Font.ITALIC);
        return set;
    }
}
