package bdda.explorer;

import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.Component;
import java.awt.Font;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.Insets;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.awt.RenderingHints;
import java.awt.geom.RoundRectangle2D;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;
import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JPasswordField;
import javax.swing.JScrollPane;
import javax.swing.JTable;
import javax.swing.JTextField;
import javax.swing.UIManager;
import javax.swing.border.Border;
import javax.swing.table.DefaultTableCellRenderer;
import javax.swing.table.TableCellRenderer;

/** Palette sombre, accents par zone et composants arrondis. */
public final class ModernTheme {

    /* Fond et surfaces */
    public static final Color BG = new Color(15, 23, 42);          // slate-900
    public static final Color CARD = new Color(30, 41, 59);        // slate-800
    public static final Color CARD_ALT = new Color(23, 32, 51);    // slate-800 foncé
    public static final Color TEXT = new Color(226, 232, 240);     // slate-200
    public static final Color MUTED = new Color(148, 163, 184);    // slate-400
    public static final Color BORDER = new Color(51, 65, 85);      // slate-700
    public static final Color NAVY = BG;
    public static final Color NAVY_LIGHT = CARD;

    /* Accents généraux */
    public static final Color ACCENT = new Color(56, 189, 248);    // sky-400
    public static final Color ACCENT_HOVER = new Color(125, 211, 252);
    public static final Color SUCCESS = new Color(52, 211, 153);   // emerald-400
    public static final Color DANGER = new Color(248, 113, 113);   // red-400
    public static final Color WARNING = new Color(251, 191, 36);   // amber-400

    /* Fonds teintés (remplacent les anciens "soft" clairs) */
    public static final Color SOFT_BLUE = new Color(12, 74, 110);
    public static final Color SOFT_RED = new Color(76, 29, 36);
    public static final Color SOFT_GREEN = new Color(6, 61, 46);
    public static final Color SOFT_GRAY = new Color(36, 50, 68);
    public static final Color HOVER = new Color(43, 59, 80);

    /* Couleurs par zone : catalogue, éditeur, résultats */
    public static final Color ZONE_CATALOG = new Color(34, 211, 238);   // cyan
    public static final Color ZONE_EDITOR = new Color(96, 165, 250);    // blue
    public static final Color ZONE_RESULTS = new Color(167, 139, 250);  // violet
    public static final Color ZONE_CATALOG_BG = new Color(8, 51, 68);
    public static final Color ZONE_EDITOR_BG = new Color(23, 49, 83);
    public static final Color ZONE_RESULTS_BG = new Color(46, 30, 82);

    /* Coloration SQL */
    public static final Color SQL_KEYWORD = new Color(125, 211, 252);
    public static final Color SQL_STRING = new Color(251, 191, 36);
    public static final Color SQL_COMMENT = new Color(100, 116, 139);
    public static final Color SQL_NUMBER = new Color(192, 132, 252);

    public static final Font UI = font(new String[]{"Segoe UI", "Inter", "Arial"}, Font.PLAIN, 13);
    public static final Font UI_BOLD = font(new String[]{"Segoe UI", "Inter", "Arial"}, Font.BOLD, 13);
    public static final Font UI_SMALL = font(new String[]{"Segoe UI", "Inter", "Arial"}, Font.PLAIN, 11);
    public static final Font UI_SEMIBOLD = font(new String[]{"Segoe UI", "Inter", "Arial"}, Font.BOLD, 14);
    public static final Font TITLE = font(new String[]{"Segoe UI", "Inter", "Arial"}, Font.BOLD, 20);
    public static final Font MONO = font(new String[]{"Consolas", "Cascadia Mono", "Courier New"}, Font.PLAIN, 13);

    private ModernTheme() {
    }

    private static Font font(String[] candidates, int style, int size) {
        Set<String> available = new HashSet<>(Arrays.asList(
                java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment().getAvailableFontFamilyNames()));
        for (String candidate : candidates) {
            if (available.contains(candidate)) {
                return new Font(candidate, style, size);
            }
        }
        return new Font(Font.SANS_SERIF, style, size);
    }

    public static void install() {
        UIManager.put("Panel.background", BG);
        UIManager.put("Label.foreground", TEXT);
        UIManager.put("Label.font", UI);
        UIManager.put("Button.font", UI);
        UIManager.put("Button.background", CARD);
        UIManager.put("Button.foreground", TEXT);
        UIManager.put("TextField.font", UI);
        UIManager.put("TextField.background", CARD);
        UIManager.put("TextField.foreground", TEXT);
        UIManager.put("PasswordField.font", UI);
        UIManager.put("PasswordField.background", CARD);
        UIManager.put("PasswordField.foreground", TEXT);
        UIManager.put("TextArea.font", UI);
        UIManager.put("TextArea.background", CARD);
        UIManager.put("TextArea.foreground", TEXT);
        UIManager.put("TextPane.background", CARD);
        UIManager.put("TextPane.foreground", TEXT);
        UIManager.put("Table.font", UI);
        UIManager.put("Table.rowHeight", 34);
        UIManager.put("Table.background", CARD);
        UIManager.put("Table.foreground", TEXT);
        UIManager.put("Table.gridColor", BORDER);
        UIManager.put("TableHeader.font", UI_BOLD);
        UIManager.put("TableHeader.background", SOFT_GRAY);
        UIManager.put("TableHeader.foreground", TEXT);
        UIManager.put("ScrollPane.background", CARD);
        UIManager.put("Viewport.background", CARD);
        UIManager.put("TabbedPane.font", UI);
        UIManager.put("TabbedPane.background", CARD);
        UIManager.put("TabbedPane.foreground", TEXT);
        UIManager.put("TabbedPane.selected", CARD);
        UIManager.put("TabbedPane.contentAreaColor", CARD);
        UIManager.put("TabbedPane.focus", ACCENT);
        UIManager.put("ToolTip.font", UI_SMALL);
        UIManager.put("List.font", UI);
        UIManager.put("List.background", CARD);
        UIManager.put("List.foreground", TEXT);
        UIManager.put("CheckBox.font", UI);
        UIManager.put("CheckBox.background", BG);
        UIManager.put("CheckBox.foreground", TEXT);
        UIManager.put("OptionPane.font", UI);
        UIManager.put("OptionPane.background", CARD);
        UIManager.put("OptionPane.foreground", TEXT);
        UIManager.put("OptionPane.messageForeground", TEXT);
    }

    /* ------------------------------ Panneaux ------------------------------ */

    public static JPanel roundedPanel(Color background, Color border, int radius) {
        return new RoundedPanel(background, border, radius);
    }

    public static JPanel gradientPanel(Color top, Color bottom) {
        return new RoundedPanel(top, bottom, 0);
    }

    private static final class RoundedPanel extends JPanel {
        private static final long serialVersionUID = 1L;
        private final Color background;
        private final Color border;
        private final int radius;

        RoundedPanel(Color background, Color border, int radius) {
            this.background = background;
            this.border = border;
            this.radius = radius;
            setOpaque(false);
        }

        @Override
        protected void paintComponent(Graphics g) {
            Graphics2D g2 = antialias(g);
            int w = getWidth();
            int h = getHeight();
            g2.setColor(background);
            g2.fill(new RoundRectangle2D.Float(0, 0, w - 1, h - 1, radius, radius));
            if (border != null) {
                g2.setStroke(new BasicStroke(1f));
                g2.setColor(border);
                g2.draw(new RoundRectangle2D.Float(0.5f, 0.5f, w - 2, h - 2, radius, radius));
            }
            g2.dispose();
        }
    }

    /* ------------------------------ Boutons ------------------------------ */

    public enum ButtonStyle { PRIMARY, SECONDARY, GHOST, DANGER, NAV }

    public static JButton button(String text, ButtonStyle style) {
        return new ActionButton(text, style);
    }

    private static final class ActionButton extends JButton {
        private static final long serialVersionUID = 1L;
        private final ButtonStyle style;

        ActionButton(String text, ButtonStyle style) {
            super(text);
            this.style = style;
            setOpaque(false);
            setFocusable(false);
            setRolloverEnabled(true);
            setBorder(BorderFactory.createEmptyBorder(10, 17, 10, 17));
            setFont(style == ButtonStyle.PRIMARY ? UI_BOLD : UI);
            setForeground(foregroundFor(false));
            addMouseListener(new MouseAdapter() {
                @Override
                public void mouseEntered(MouseEvent e) {
                    setForeground(foregroundFor(true));
                }

                @Override
                public void mouseExited(MouseEvent e) {
                    setForeground(foregroundFor(false));
                }
            });
        }

        private Color foregroundFor(boolean hover) {
            return switch (style) {
                case PRIMARY, GHOST -> hover ? Color.WHITE : ACCENT;
                case SECONDARY -> hover ? ACCENT_HOVER : TEXT;
                case DANGER -> hover ? new Color(252, 165, 165) : DANGER;
                default -> MUTED;
            };
        }

        @Override
        protected void paintComponent(Graphics g) {
            boolean hover = getModel().isRollover() && isEnabled();

            Graphics2D g2 = antialias(g);
            Color base;
            Color hoverBg;
            Color border;
            Color hoverBorder;

            switch (style) {
                case PRIMARY -> {
                    base = SOFT_BLUE;
                    hoverBg = new Color(14, 96, 140);
                    border = new Color(14, 116, 144);
                    hoverBorder = ACCENT;
                }
                case DANGER -> {
                    base = SOFT_RED;
                    hoverBg = new Color(92, 35, 42);
                    border = new Color(120, 45, 54);
                    hoverBorder = DANGER;
                }
                case SECONDARY -> {
                    base = CARD_ALT;
                    hoverBg = HOVER;
                    border = BORDER;
                    hoverBorder = MUTED;
                }
                case GHOST -> {
                    base = new Color(0, 0, 0, 0);
                    hoverBg = HOVER;
                    border = null;
                    hoverBorder = null;
                }
                default -> {
                    base = new Color(0, 0, 0, 0);
                    hoverBg = HOVER;
                    border = null;
                    hoverBorder = null;
                }
            }

            Color fill = !isEnabled() ? CARD_ALT : hover ? hoverBg : base;
            if (fill.getAlpha() > 0) {
                g2.setColor(fill);
                g2.fill(new RoundRectangle2D.Float(0, 0, getWidth() - 1, getHeight() - 1, 9, 9));
            }
            Color activeBorder = hover ? hoverBorder : border;
            if (activeBorder != null && isEnabled()) {
                g2.setColor(activeBorder);
                g2.setStroke(new BasicStroke(1f));
                g2.draw(new RoundRectangle2D.Float(0.5f, 0.5f, getWidth() - 2, getHeight() - 2, 9, 9));
            }
            g2.dispose();
            super.paintComponent(g);
        }
    }

    /* --------------------------- Filtres / puces --------------------------- */

    /** Petit bouton de filtre utilisé pour les catégories du catalogue. */
    public static JButton chip(String text) {
        return new ChipButton(text);
    }

    public static void setChipSelected(JButton button, boolean selected) {
        if (button instanceof ChipButton chip) {
            chip.selected = selected;
            chip.setForeground(selected ? ACCENT : MUTED);
            chip.repaint();
        }
    }

    private static final class ChipButton extends JButton {
        private static final long serialVersionUID = 1L;
        private boolean selected;

        ChipButton(String text) {
            super(text);
            setOpaque(false);
            setFocusable(false);
            setFont(UI_SMALL);
            setForeground(MUTED);
            setBorder(BorderFactory.createEmptyBorder(8, 14, 8, 14));
            setRolloverEnabled(true);
        }

        @Override
        protected void paintComponent(Graphics g) {
            Graphics2D g2 = antialias(g);
            boolean hover = getModel().isRollover();
            if (selected) {
                g2.setColor(SOFT_BLUE);
                g2.fill(new RoundRectangle2D.Float(0, 0, getWidth() - 1, getHeight() - 1, 9, 9));
                g2.setColor(ACCENT);
                g2.setStroke(new BasicStroke(1f));
                g2.draw(new RoundRectangle2D.Float(0.5f, 0.5f, getWidth() - 2, getHeight() - 2, 9, 9));
            } else if (hover) {
                g2.setColor(HOVER);
                g2.fill(new RoundRectangle2D.Float(0, 0, getWidth() - 1, getHeight() - 1, 9, 9));
            }
            g2.dispose();
            super.paintComponent(g);
        }
    }

    /** Titre de zone, coloré selon la colonne (catalogue / éditeur / résultats). */
    public static JLabel zoneTitle(String text, Color color) {
        JLabel label = new JLabel(text);
        label.setFont(UI_SMALL.deriveFont(Font.BOLD));
        label.setForeground(color);
        return label;
    }

    /* ------------------------------ Pastilles ------------------------------ */

    public static JLabel pill(String text, Color background, Color foreground) {
        return new PillLabel(text, background, foreground);
    }

    public static void setPillColors(JLabel label, Color background, Color foreground) {
        if (label instanceof PillLabel pill) {
            pill.background = background;
            pill.foreground = foreground;
            pill.setForeground(foreground);
            pill.repaint();
        }
    }

    private static final class PillLabel extends JLabel {
        private static final long serialVersionUID = 1L;
        private Color background;
        private Color foreground;

        PillLabel(String text, Color background, Color foreground) {
            super(text);
            this.background = background;
            this.foreground = foreground;
            setOpaque(false);
            setFont(UI_SMALL);
            setForeground(foreground);
            setBorder(BorderFactory.createEmptyBorder(4, 10, 4, 10));
        }

        @Override
        protected void paintComponent(Graphics g) {
            Graphics2D g2 = antialias(g);
            g2.setColor(background);
            g2.fill(new RoundRectangle2D.Float(0, 0, getWidth() - 1, getHeight() - 1,
                    getHeight() / 2f, getHeight() / 2f));
            g2.setColor(BORDER);
            g2.setStroke(new BasicStroke(1f));
            g2.draw(new RoundRectangle2D.Float(0.5f, 0.5f, getWidth() - 2, getHeight() - 2,
                    getHeight() / 2f, getHeight() / 2f));
            g2.dispose();
            super.paintComponent(g);
        }
    }

    /* --------------------------- Champs de texte --------------------------- */

    /** Champ standard, editable, avec bordure arrondie (utilisé dans la connexion). */
    public static JTextField softField() {
        JTextField field = new JTextField();
        field.setFont(UI);
        field.setForeground(TEXT);
        field.setCaretColor(ACCENT);
        field.setBackground(CARD);
        field.setOpaque(true);
        field.setEditable(true);
        field.setEnabled(true);
        field.setFocusable(true);
        field.setBorder(new RoundedBorder(BORDER, 9, new Insets(8, 12, 8, 12)));
        return field;
    }

    public static JPasswordField softPasswordField() {
        JPasswordField field = new JPasswordField(18);
        field.setFont(UI);
        field.setForeground(TEXT);
        field.setCaretColor(ACCENT);
        field.setBackground(CARD);
        field.setOpaque(true);
        field.setEditable(true);
        field.setEnabled(true);
        field.setFocusable(true);
        field.setBorder(new RoundedBorder(BORDER, 9, new Insets(8, 12, 8, 12)));
        return field;
    }

    /** Champ de recherche avec placeholder. */
    public static JTextField searchField(String placeholder) {
        return new PlaceholderTextField(placeholder);
    }

    private static final class PlaceholderTextField extends JTextField {
        private static final long serialVersionUID = 1L;
        private final String placeholder;

        PlaceholderTextField(String placeholder) {
            this.placeholder = placeholder;
            setOpaque(false);
            setFont(UI);
            setForeground(TEXT);
            setCaretColor(ACCENT);
            setBorder(BorderFactory.createEmptyBorder(9, 13, 9, 13));
        }

        @Override
        protected void paintComponent(Graphics g) {
            Graphics2D g2 = antialias(g);
            g2.setColor(CARD);
            g2.fill(new RoundRectangle2D.Float(0, 0, getWidth() - 1, getHeight() - 1, 10, 10));
            g2.setColor(isFocusOwner() ? ACCENT : BORDER);
            g2.setStroke(new BasicStroke(isFocusOwner() ? 1.4f : 1f));
            g2.draw(new RoundRectangle2D.Float(0.6f, 0.6f, getWidth() - 2, getHeight() - 2, 10, 10));
            g2.dispose();
            super.paintComponent(g);
            if (getText().isEmpty()) {
                g2 = antialias(g);
                g2.setColor(MUTED);
                g2.setFont(UI);
                g2.drawString(placeholder, 15, getHeight() / 2f + 4);
                g2.dispose();
            }
        }
    }

    private static final class RoundedBorder implements Border {
        private final Color color;
        private final int radius;
        private final Insets insets;

        RoundedBorder(Color color, int radius, Insets insets) {
            this.color = color;
            this.radius = radius;
            this.insets = insets;
        }

        @Override
        public void paintBorder(Component c, Graphics g, int x, int y, int width, int height) {
            Graphics2D g2 = antialias(g);
            g2.setColor(color);
            g2.setStroke(new BasicStroke(1f));
            g2.draw(new RoundRectangle2D.Float(x + 0.5f, y + 0.5f, width - 2, height - 2, radius, radius));
            g2.dispose();
        }

        @Override
        public Insets getBorderInsets(Component c) {
            return insets;
        }

        @Override
        public boolean isBorderOpaque() {
            return false;
        }
    }

    /* ------------------------------- Tableaux ------------------------------- */

    public static void styleTable(JTable table) {
        table.setRowHeight(34);
        table.setShowGrid(false);
        table.setIntercellSpacing(new java.awt.Dimension(0, 0));
        table.setFillsViewportHeight(true);
        table.setBackground(CARD);
        table.setForeground(TEXT);
        table.setSelectionBackground(new Color(14, 116, 144));
        table.setSelectionForeground(Color.WHITE);
        table.setFont(UI);
        table.getTableHeader().setFont(UI_BOLD);
        table.getTableHeader().setDefaultRenderer(new HeaderRenderer());
        table.setDefaultRenderer(Object.class, new StripedRenderer());
    }

    public static void styleScroll(JScrollPane scroll) {
        scroll.setBorder(null);
        scroll.setBackground(CARD);
        scroll.getViewport().setBackground(CARD);
    }

    private static final class HeaderRenderer extends JLabel implements TableCellRenderer {
        private static final long serialVersionUID = 1L;

        HeaderRenderer() {
            setOpaque(true);
            setFont(UI_BOLD);
            setForeground(TEXT);
            setBackground(SOFT_GRAY);
            setBorder(BorderFactory.createCompoundBorder(
                    BorderFactory.createMatteBorder(0, 0, 1, 0, BORDER),
                    BorderFactory.createEmptyBorder(7, 10, 7, 10)));
        }

        @Override
        public Component getTableCellRendererComponent(JTable table, Object value, boolean selected,
                                                       boolean focus, int row, int column) {
            setText(value == null ? "" : value.toString());
            return this;
        }
    }

    private static final class StripedRenderer extends DefaultTableCellRenderer {
        private static final long serialVersionUID = 1L;

        StripedRenderer() {
            setBorder(BorderFactory.createEmptyBorder(4, 10, 4, 10));
        }

        @Override
        public Component getTableCellRendererComponent(JTable table, Object value, boolean selected,
                                                       boolean focus, int row, int column) {
            Component c = super.getTableCellRendererComponent(table, value, selected, focus, row, column);
            if (selected) {
                c.setBackground(new Color(14, 116, 144));
                c.setForeground(Color.WHITE);
            } else {
                c.setBackground(row % 2 == 0 ? CARD : CARD_ALT);
                c.setForeground(TEXT);
            }
            return c;
        }
    }

    private static Graphics2D antialias(Graphics g) {
        Graphics2D g2 = (Graphics2D) g.create();
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        g2.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
        return g2;
    }
}
