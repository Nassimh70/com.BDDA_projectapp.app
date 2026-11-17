package bdda.explorer;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Cursor;
import java.awt.Dimension;
import java.awt.Font;
import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.Insets;
import java.awt.RenderingHints;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.awt.geom.RoundRectangle2D;
import javax.swing.BorderFactory;
import javax.swing.Box;
import javax.swing.BoxLayout;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.SwingConstants;

/** Carte cliquable d'une requête dans le catalogue. */
final class QueryCard extends JPanel {

    private static final long serialVersionUID = 1L;

    private final QueryDefinition query;
    private final Runnable onClick;
    private boolean selected;
    private boolean hovered;

    QueryCard(QueryDefinition query, Runnable onClick) {
        this.query = query;
        this.onClick = onClick;
        setLayout(new BorderLayout());
        setOpaque(false);
        setBorder(BorderFactory.createEmptyBorder(14, 14, 12, 14));
        setCursor(Cursor.getPredefinedCursor(Cursor.HAND_CURSOR));

        JPanel content = new JPanel();
        content.setOpaque(false);
        content.setLayout(new BoxLayout(content, BoxLayout.Y_AXIS));

        JPanel top = new JPanel(new BorderLayout(8, 0));
        top.setOpaque(false);
        JLabel code = ModernTheme.pill(query.code(), ModernTheme.SOFT_BLUE, ModernTheme.ACCENT);
        code.setHorizontalAlignment(SwingConstants.CENTER);
        JLabel category = ModernTheme.pill(query.category(), new Color(238, 242, 248), ModernTheme.MUTED);
        top.add(code, BorderLayout.WEST);
        top.add(Box.createHorizontalGlue(), BorderLayout.CENTER);
        top.add(category, BorderLayout.EAST);

        JLabel title = new JLabel(query.title());
        title.setFont(ModernTheme.UI_BOLD);
        title.setForeground(ModernTheme.TEXT);
        title.setAlignmentX(LEFT_ALIGNMENT);
        title.setBorder(BorderFactory.createEmptyBorder(10, 0, 4, 0));

        JLabel description = new JLabel("<html><body style='width:270px'>" + escape(query.description()) + "</body></html>");
        description.setFont(ModernTheme.UI_SMALL);
        description.setForeground(ModernTheme.MUTED);
        description.setAlignmentX(LEFT_ALIGNMENT);

        JPanel footer = new JPanel(new GridBagLayout());
        footer.setOpaque(false);
        GridBagConstraints gc = new GridBagConstraints();
        gc.anchor = GridBagConstraints.WEST;
        gc.gridy = 0;
        JLabel run = new JLabel(query.destructive() ? "⚠  Destructive · exécuter" : "▶  Exécuter");
        run.setFont(ModernTheme.UI_SMALL.deriveFont(Font.BOLD));
        run.setForeground(query.destructive() ? ModernTheme.DANGER : ModernTheme.ACCENT);
        footer.add(run, gc);
        if (query.plsql()) {
            gc.gridx = 1;
            gc.insets = new Insets(0, 10, 0, 0);
            footer.add(ModernTheme.pill("PL/SQL", new Color(245, 238, 255), new Color(126, 65, 180)), gc);
        }

        content.add(top);
        content.add(title);
        content.add(description);
        content.add(Box.createVerticalStrut(10));
        content.add(footer);
        add(content, BorderLayout.CENTER);

        addMouseListener(new MouseAdapter() {
            @Override
            public void mouseClicked(MouseEvent e) {
                onClick.run();
            }

            @Override
            public void mouseEntered(MouseEvent e) {
                hovered = true;
                repaint();
            }

            @Override
            public void mouseExited(MouseEvent e) {
                hovered = false;
                repaint();
            }
        });
    }

    void setSelected(boolean selected) {
        this.selected = selected;
        repaint();
    }

    QueryDefinition query() {
        return query;
    }

    @Override
    protected void paintComponent(Graphics g) {
        Graphics2D g2 = (Graphics2D) g.create();
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        int w = getWidth();
        int h = getHeight();
        if (selected) {
            g2.setColor(new Color(232, 240, 255));
            g2.fill(new RoundRectangle2D.Float(0, 0, w - 1, h - 1, 12, 12));
            g2.setColor(ModernTheme.ACCENT);
            g2.setStroke(new java.awt.BasicStroke(1.3f));
            g2.draw(new RoundRectangle2D.Float(0.7f, 0.7f, w - 2, h - 2, 12, 12));
        } else if (hovered) {
            g2.setColor(new Color(249, 251, 255));
            g2.fill(new RoundRectangle2D.Float(0, 0, w - 1, h - 1, 12, 12));
            g2.setColor(new Color(214, 226, 245));
            g2.draw(new RoundRectangle2D.Float(0.5f, 0.5f, w - 2, h - 2, 12, 12));
        } else {
            g2.setColor(Color.WHITE);
            g2.fill(new RoundRectangle2D.Float(0, 0, w - 1, h - 1, 12, 12));
            g2.setColor(ModernTheme.BORDER);
            g2.draw(new RoundRectangle2D.Float(0.5f, 0.5f, w - 2, h - 2, 12, 12));
        }
        g2.dispose();
        super.paintComponent(g);
    }

    @Override
    public Dimension getMaximumSize() {
        Dimension size = super.getMaximumSize();
        size.width = Integer.MAX_VALUE;
        return size;
    }

    private static String escape(String text) {
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }
}
