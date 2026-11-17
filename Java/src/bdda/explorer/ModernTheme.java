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
import javax.swing.SwingConstants;
import javax.swing.UIManager;
import javax.swing.border.Border;
import javax.swing.table.DefaultTableCellRenderer;
import javax.swing.table.TableCellRenderer;

/** Palette claire, composants "soft" et boutons sans fond coloré plein. */
public final class ModernTheme {

    public static final Color NAVY = new Color(30, 41, 59);
    public static final Color NAVY_LIGHT = new Color(51, 65, 85);
    public static final Color ACCENT = new Color(37, 99, 235);
    public static final Color ACCENT_HOVER = new Color(29, 78, 216);
    public static final Color SUCCESS = new Color(22, 163, 74);
    public static final Color DANGER = new Color(220, 38, 38);
    public static final Color WARNING = new Color(217, 119, 6);
    public static final Color BG = new Color(247, 249, 252);
    public static final Color CARD = Color.WHITE;
    public static final Color TEXT = new Color(30, 41, 59);
    public static final Color MUTED = new Color(107, 114, 128);
    public static final Color BORDER = new Color(226, 232, 240);
    public static final Color SOFT_BLUE = new Color(239, 246, 255);
    public static final Color SOFT_RED = new Color(254, 242, 242);
    public static final Color SOFT_GREEN = new Color(240, 253, 244);
    public static final Color SOFT_GRAY = new Color(248, 250, 252);

    public static final Color SQL_KEYWORD = new Color(37, 99, 235);
    public static final Color SQL_STRING = new Color(161, 98, 7);
    public static final Color SQL_COMMENT = new Color(107, 114, 128);
    public static final Color SQL_NUMBER = new Color(124, 58, 237);

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
        UIManager.put("TextField.font", UI);
        UIManager.put("PasswordField.font", UI);
        UIManager.put("TextArea.font", UI);
        UIManager.put("Table.font", UI);
        UIManager.put("Table.rowHeight", 30);
        UIManager.put("Table.gridColor", BORDER);
        UIManager.put("TableHeader.font", UI_BOLD);
        UIManager.put("ScrollPane.background", CARD);
        UIManager.put("Viewport.background", CARD);
        UIManager.put("TabbedPane.font", UI);
        UIManager.put("ToolTip.font", UI_SMALL);
        UIManager.put("List.font", UI);
        UIManager.put("CheckBox.font", UI);
        UIManager.put("OptionPane.font", UI);
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

    /** Bouton de navigation clair : texte gris, sélection bleu très pâle. */
    public static final class NavButton extends JButton {
        private static final long serialVersionUID = 1L;
        private boolean selected;

        public NavButton(String text) {
            super(text);
            setOpaque(false);
            setFocusable(false);
            setHorizontalAlignment(SwingConstants.LEFT);
            setBorder(BorderFactory.createEmptyBorder(11, 16, 11, 14));
            setFont(selected ? UI_BOLD : UI);
            setForeground(new Color(71, 85, 105));
            setRolloverEnabled(true);
        }

        public void setSelected(boolean selected) {
            this.selected = selected;
            setFont(selected ? UI_BOLD : UI);
            setForeground(selected ? ACCENT : new Color(71, 85, 105));
            repaint();
        }

        @Override
        protected void paintComponent(Graphics g) {
            Graphics2D g2 = antialias(g);
            if (selected) {
                g2.setColor(SOFT_BLUE);
                g2.fill(new RoundRectangle2D.Float(6, 3, getWidth() - 12, getHeight() - 6, 9, 9));
                g2.setColor(ACCENT);
                g2.fillRoundRect(6, 8, 4, getHeight() - 16, 3, 3);
            } else if (getModel().isRollover()) {
                g2.setColor(new Color(241, 245, 249));
                g2.fill(new RoundRectangle2D.Float(6, 3, getWidth() - 12, getHeight() - 6, 9, 9));
            }
            g2.dispose();
            super.paintComponent(g);
        }
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
            setBorder(BorderFactory.createEmptyBorder(9, 15, 9, 15));
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
                case PRIMARY, GHOST -> hover ? ACCENT_HOVER : ACCENT;
                case SECONDARY -> TEXT;
                case DANGER -> hover ? new Color(185, 28, 28) : DANGER;
                default -> new Color(71, 85, 105);
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
                    hoverBg = new Color(219, 234, 254);
                    border = new Color(191, 219, 254);
                    hoverBorder = ACCENT;
                }
                case DANGER -> {
                    base = SOFT_RED;
                    hoverBg = new Color(254, 226, 226);
                    border = new Color(254, 202, 202);
                    hoverBorder = DANGER;
                }
                case SECONDARY -> {
                    base = CARD;
                    hoverBg = SOFT_GRAY;
                    border = BORDER;
                    hoverBorder = new Color(203, 213, 225);
                }
                case GHOST -> {
                    base = new Color(0, 0, 0, 0);
                    hoverBg = SOFT_BLUE;
                    border = null;
                    hoverBorder = null;
                }
                default -> {
                    base = new Color(0, 0, 0, 0);
                    hoverBg = SOFT_BLUE;
                    border = null;
                    hoverBorder = null;
                }
            }

            Color fill = !isEnabled() ? new Color(248, 250, 252) : hover ? hoverBg : base;
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
            g2.setColor(new Color(226, 232, 240));
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
        table.setRowHeight(30);
        table.setShowGrid(false);
        table.setIntercellSpacing(new java.awt.Dimension(0, 0));
        table.setFillsViewportHeight(true);
        table.setSelectionBackground(new Color(219, 234, 254));
        table.setSelectionForeground(TEXT);
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
                c.setBackground(new Color(219, 234, 254));
                c.setForeground(TEXT);
            } else {
                c.setBackground(row % 2 == 0 ? CARD : new Color(250, 251, 253));
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
