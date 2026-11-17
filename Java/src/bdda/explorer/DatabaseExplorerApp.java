package bdda.explorer;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Component;
import java.awt.Dimension;
import java.awt.FlowLayout;
import java.awt.Font;
import java.awt.GridBagConstraints;
import java.awt.GridBagLayout;
import java.awt.Insets;
import java.awt.event.ActionEvent;
import java.awt.event.InputEvent;
import java.awt.event.KeyEvent;
import java.awt.event.MouseAdapter;
import java.awt.event.MouseEvent;
import java.awt.event.WindowAdapter;
import java.awt.event.WindowEvent;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.prefs.Preferences;
import java.util.regex.Pattern;
import javax.swing.AbstractAction;
import javax.swing.Box;
import javax.swing.BoxLayout;
import javax.swing.DefaultListModel;
import javax.swing.JButton;
import javax.swing.JCheckBox;
import javax.swing.JComponent;
import javax.swing.JDialog;
import javax.swing.JFileChooser;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JList;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JPasswordField;
import javax.swing.JScrollPane;
import javax.swing.JSplitPane;
import javax.swing.JTabbedPane;
import javax.swing.JTable;
import javax.swing.JTextArea;
import javax.swing.JTextField;
import javax.swing.KeyStroke;
import javax.swing.ListSelectionModel;
import javax.swing.SwingConstants;
import javax.swing.SwingUtilities;
import javax.swing.SwingWorker;
import javax.swing.border.EmptyBorder;
import javax.swing.event.DocumentEvent;
import javax.swing.event.DocumentListener;
import javax.swing.table.TableRowSorter;

/** Interface graphique pour tester les requêtes SQL du mini-projet BDDA. */
public final class DatabaseExplorerApp extends JFrame {

    private static final long serialVersionUID = 1L;

    private static final Preferences PREFS = Preferences.userNodeForPackage(DatabaseExplorerApp.class);
    private static final Pattern RISKY_SQL = Pattern.compile(
            "\\b(DELETE|DROP|TRUNCATE|UPDATE|INSERT|MERGE|ALTER|COMMIT|ROLLBACK)\\b",
            Pattern.CASE_INSENSITIVE);
    private static final Pattern PLSQL_START = Pattern.compile(
            "^\\s*(DECLARE|BEGIN|CREATE|ALTER|DROP)\\b", Pattern.CASE_INSENSITIVE);

    private final DatabaseService database = new DatabaseService();
    private final List<QueryDefinition> queries = QueryCatalog.all();

    private final List<QueryCard> cards = new ArrayList<>();
    private final SqlEditorPanel editor = new SqlEditorPanel();
    private final ResultTableModel resultModel = new ResultTableModel();
    private final JTable resultTable = new JTable(resultModel);
    private final DefaultListModel<HistoryEntry> historyModel = new DefaultListModel<>();
    private final JList<HistoryEntry> historyList = new JList<>(historyModel);
    private final JTextArea messagesArea = new JTextArea();

    private String activeCategory = "Tout";
    private QueryDefinition current;
    private JTextField searchField;
    private JLabel countLabel;
    private JPanel cardsPanel;
    private JScrollPane catalogScroll;
    private JLabel statusPill;
    private JLabel sidebarStatus;
    private JLabel editorCodePill;
    private JLabel destructivePill;
    private JLabel summaryLabel;
    private JButton runButton;
    private JButton connectButton;
    private JTabbedPane tabs;
    private final List<ModernTheme.NavButton> navButtons = new ArrayList<>();

    public static void main(String[] args) {
        ModernTheme.install();
        SwingUtilities.invokeLater(() -> {
            DatabaseExplorerApp app = new DatabaseExplorerApp();
            app.setVisible(true);
        });
    }

    private DatabaseExplorerApp() {
        super("BDDA Explorer — Requêtes SQL Oracle");
        setDefaultCloseOperation(JFrame.DO_NOTHING_ON_CLOSE);
        addWindowListener(new WindowAdapter() {
            @Override
            public void windowClosing(WindowEvent e) {
                database.close();
                dispose();
                System.exit(0);
            }
        });
        setMinimumSize(new Dimension(1120, 700));
        setSize(new Dimension(1420, 860));
        setLocationRelativeTo(null);
        setContentPane(buildRoot());
        installShortcuts();
        selectQuery(queries.getFirst());
        updateConnectionUi("Non connecté", ModernTheme.MUTED, new Color(238, 242, 248));
    }

    /* ------------------------------------------------------------------ */
    /* Construction de l'interface                                        */
    /* ------------------------------------------------------------------ */

    private JComponent buildRoot() {
        JPanel root = new JPanel(new BorderLayout());
        root.setBackground(ModernTheme.BG);
        root.add(buildSidebar(), BorderLayout.WEST);

        JPanel main = new JPanel(new BorderLayout());
        main.setBackground(ModernTheme.BG);
        main.add(buildHeader(), BorderLayout.NORTH);

        JSplitPane body = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT, buildCatalog(), buildWorkspace());
        body.setDividerLocation(358);
        body.setResizeWeight(0.0);
        body.setBorder(null);
        body.setBackground(ModernTheme.BG);
        main.add(body, BorderLayout.CENTER);

        root.add(main, BorderLayout.CENTER);
        return root;
    }

    private JComponent buildSidebar() {
        JPanel sidebar = new JPanel(new BorderLayout());
        sidebar.setBackground(ModernTheme.CARD);
        sidebar.setPreferredSize(new Dimension(232, 0));
        sidebar.setBorder(javax.swing.BorderFactory.createCompoundBorder(
                new EmptyBorder(20, 14, 18, 14),
                javax.swing.BorderFactory.createMatteBorder(0, 0, 0, 1, ModernTheme.BORDER)));

        JPanel brand = ModernTheme.roundedPanel(ModernTheme.SOFT_BLUE, null, 14);
        brand.setPreferredSize(new Dimension(204, 74));
        brand.setLayout(new BorderLayout(12, 0));
        brand.setBorder(new EmptyBorder(12, 14, 12, 14));

        JLabel logo = new JLabel("DB", SwingConstants.CENTER) {
            private static final long serialVersionUID = 1L;

            @Override
            protected void paintComponent(java.awt.Graphics g) {
                java.awt.Graphics2D g2 = (java.awt.Graphics2D) g.create();
                g2.setRenderingHint(java.awt.RenderingHints.KEY_ANTIALIASING,
                        java.awt.RenderingHints.VALUE_ANTIALIAS_ON);
                g2.setColor(ModernTheme.ACCENT);
                g2.fillRoundRect(0, 0, getWidth() - 1, getHeight() - 1, 12, 12);
                g2.dispose();
                super.paintComponent(g);
            }
        };
        logo.setFont(new Font("Segoe UI", Font.BOLD, 15));
        logo.setForeground(Color.WHITE);
        logo.setOpaque(false);
        logo.setPreferredSize(new Dimension(42, 42));

        JPanel brandText = new JPanel();
        brandText.setOpaque(false);
        brandText.setLayout(new BoxLayout(brandText, BoxLayout.Y_AXIS));
        JLabel brandTitle = new JLabel("BDDA Explorer");
        brandTitle.setFont(ModernTheme.UI_SEMIBOLD);
        brandTitle.setForeground(ModernTheme.TEXT);
        JLabel brandSub = new JLabel("M1 ASR · Oracle 21c");
        brandSub.setFont(ModernTheme.UI_SMALL);
        brandSub.setForeground(ModernTheme.MUTED);
        brandText.add(brandTitle);
        brandText.add(Box.createVerticalStrut(3));
        brandText.add(brandSub);
        brand.add(logo, BorderLayout.WEST);
        brand.add(brandText, BorderLayout.CENTER);

        JPanel nav = new JPanel();
        nav.setOpaque(false);
        nav.setLayout(new BoxLayout(nav, BoxLayout.Y_AXIS));
        nav.setBorder(new EmptyBorder(24, 0, 0, 0));

        JLabel navTitle = new JLabel("CATALOGUE");
        navTitle.setFont(ModernTheme.UI_SMALL.deriveFont(Font.BOLD));
        navTitle.setForeground(ModernTheme.MUTED);
        navTitle.setBorder(new EmptyBorder(0, 14, 10, 0));
        nav.add(navTitle);

        addNavButton(nav, "Tout voir", "Tout");
        for (String category : QueryCatalog.categories()) {
            addNavButton(nav, category, category);
        }

        JPanel bottom = new JPanel();
        bottom.setOpaque(false);
        bottom.setLayout(new BoxLayout(bottom, BoxLayout.Y_AXIS));

        JPanel connectionCard = ModernTheme.roundedPanel(ModernTheme.SOFT_GRAY, ModernTheme.BORDER, 12);
        connectionCard.setBorder(new EmptyBorder(14, 14, 14, 14));
        connectionCard.setLayout(new BoxLayout(connectionCard, BoxLayout.Y_AXIS));
        JLabel connTitle = new JLabel("CONNEXION");
        connTitle.setFont(ModernTheme.UI_SMALL.deriveFont(Font.BOLD));
        connTitle.setForeground(ModernTheme.MUTED);
        sidebarStatus = new JLabel("Non connecté");
        sidebarStatus.setFont(ModernTheme.UI);
        sidebarStatus.setForeground(ModernTheme.TEXT);
        sidebarStatus.setBorder(new EmptyBorder(6, 0, 10, 0));
        JButton openConn = ModernTheme.button("Configurer", ModernTheme.ButtonStyle.GHOST);
        openConn.setAlignmentX(LEFT_ALIGNMENT);
        openConn.addActionListener(e -> openConnectionDialog());
        connectionCard.add(connTitle);
        connectionCard.add(sidebarStatus);
        connectionCard.add(openConn);

        JLabel hint = new JLabel("<html><body style='color:#6b7280'>MASTER1 / XEPDB1<br>Ctrl+Entrée : exécuter</body></html>");
        hint.setFont(ModernTheme.UI_SMALL);
        hint.setBorder(new EmptyBorder(12, 6, 0, 0));

        bottom.add(connectionCard);
        bottom.add(hint);

        sidebar.add(brand, BorderLayout.NORTH);
        sidebar.add(nav, BorderLayout.CENTER);
        sidebar.add(bottom, BorderLayout.SOUTH);
        return sidebar;
    }

    private void addNavButton(JPanel parent, String label, String category) {
        ModernTheme.NavButton button = new ModernTheme.NavButton(label);
        button.addActionListener(e -> {
            activeCategory = category;
            for (ModernTheme.NavButton nav : navButtons) {
                nav.setSelected(nav == button);
            }
            filterCards();
        });
        if ("Tout".equals(category)) {
            button.setSelected(true);
        }
        navButtons.add(button);
        parent.add(button);
        parent.add(Box.createVerticalStrut(3));
    }

    private JComponent buildHeader() {
        JPanel header = new JPanel(new BorderLayout());
        header.setBackground(ModernTheme.BG);
        header.setBorder(new EmptyBorder(22, 26, 16, 26));

        JPanel titles = new JPanel();
        titles.setOpaque(false);
        titles.setLayout(new BoxLayout(titles, BoxLayout.Y_AXIS));
        JLabel title = new JLabel("Explorateur de requêtes BDDA");
        title.setFont(ModernTheme.TITLE);
        title.setForeground(ModernTheme.TEXT);
        JLabel subtitle = new JLabel("Mini-projet BDDA · schéma MASTER1 · SQL objet, collections et objets avancés");
        subtitle.setFont(ModernTheme.UI_SMALL);
        subtitle.setForeground(ModernTheme.MUTED);
        subtitle.setBorder(new EmptyBorder(4, 0, 0, 0));
        titles.add(title);
        titles.add(subtitle);

        JPanel actions = new JPanel(new FlowLayout(FlowLayout.RIGHT, 10, 0));
        actions.setOpaque(false);
        statusPill = ModernTheme.pill("Non connecté", ModernTheme.SOFT_GRAY, ModernTheme.MUTED);
        connectButton = ModernTheme.button("Configurer", ModernTheme.ButtonStyle.SECONDARY);
        connectButton.addActionListener(e -> openConnectionDialog());
        JButton quick = ModernTheme.button("⚡  Connexion rapide", ModernTheme.ButtonStyle.PRIMARY);
        quick.addActionListener(e -> connectWith(defaultConfig()));
        actions.add(statusPill);
        actions.add(connectButton);
        actions.add(quick);

        header.add(titles, BorderLayout.WEST);
        header.add(actions, BorderLayout.EAST);
        return header;
    }

    private JComponent buildCatalog() {
        JPanel catalog = new JPanel(new BorderLayout());
        catalog.setBackground(ModernTheme.CARD);
        catalog.setBorder(javax.swing.BorderFactory.createMatteBorder(0, 0, 0, 1, ModernTheme.BORDER));
        catalog.setPreferredSize(new Dimension(358, 0));

        JPanel top = new JPanel();
        top.setBackground(ModernTheme.CARD);
        top.setLayout(new BoxLayout(top, BoxLayout.Y_AXIS));
        top.setBorder(new EmptyBorder(18, 18, 12, 18));

        JPanel titleRow = new JPanel(new BorderLayout());
        titleRow.setOpaque(false);
        JLabel title = new JLabel("Requêtes");
        title.setFont(ModernTheme.UI_SEMIBOLD);
        countLabel = ModernTheme.pill(queries.size() + " requêtes", ModernTheme.SOFT_BLUE, ModernTheme.ACCENT);
        titleRow.add(title, BorderLayout.WEST);
        titleRow.add(countLabel, BorderLayout.EAST);

        searchField = ModernTheme.searchField("⌕  Rechercher une requête ou du SQL…");
        searchField.setMaximumSize(new Dimension(Integer.MAX_VALUE, 40));
        searchField.getDocument().addDocumentListener(new DocumentListener() {
            @Override public void insertUpdate(DocumentEvent e) { filterCards(); }
            @Override public void removeUpdate(DocumentEvent e) { filterCards(); }
            @Override public void changedUpdate(DocumentEvent e) { filterCards(); }
        });

        top.add(titleRow);
        top.add(Box.createVerticalStrut(14));
        top.add(searchField);

        cardsPanel = new JPanel();
        cardsPanel.setBackground(ModernTheme.BG);
        cardsPanel.setLayout(new BoxLayout(cardsPanel, BoxLayout.Y_AXIS));
        cardsPanel.setBorder(new EmptyBorder(4, 14, 18, 14));
        catalogScroll = new JScrollPane(cardsPanel);
        ModernTheme.styleScroll(catalogScroll);
        catalogScroll.getVerticalScrollBar().setUnitIncrement(16);

        catalog.add(top, BorderLayout.NORTH);
        catalog.add(catalogScroll, BorderLayout.CENTER);
        filterCards();
        return catalog;
    }

    private JComponent buildWorkspace() {
        JPanel workspace = new JPanel(new BorderLayout());
        workspace.setBackground(ModernTheme.BG);
        workspace.setBorder(new EmptyBorder(16, 20, 20, 20));

        JPanel toolbar = new JPanel(new FlowLayout(FlowLayout.LEFT, 8, 0));
        toolbar.setOpaque(false);
        runButton = ModernTheme.button("▶  Exécuter  (Ctrl+Entrée)", ModernTheme.ButtonStyle.PRIMARY);
        runButton.addActionListener(e -> runQuery());
        JButton reset = ModernTheme.button("↻  Réinitialiser", ModernTheme.ButtonStyle.SECONDARY);
        reset.addActionListener(e -> {
            if (current != null) {
                selectQuery(current);
            }
        });
        JButton copy = ModernTheme.button("⧉  Copier SQL", ModernTheme.ButtonStyle.GHOST);
        copy.addActionListener(e -> copySql());
        JButton export = ModernTheme.button("⬇  Exporter CSV", ModernTheme.ButtonStyle.GHOST);
        export.addActionListener(e -> exportCsv());
        destructivePill = ModernTheme.pill("⚠  Requête destructive", ModernTheme.SOFT_RED, ModernTheme.DANGER);
        destructivePill.setVisible(false);
        toolbar.add(runButton);
        toolbar.add(reset);
        toolbar.add(copy);
        toolbar.add(export);
        toolbar.add(destructivePill);

        JPanel editorWrapper = ModernTheme.roundedPanel(ModernTheme.CARD, ModernTheme.BORDER, 12);
        editorWrapper.setLayout(new BorderLayout());
        JPanel editorHeader = new JPanel(new BorderLayout());
        editorHeader.setBackground(ModernTheme.CARD);
        editorHeader.setBorder(new EmptyBorder(12, 16, 8, 16));
        JLabel editorTitle = new JLabel("Éditeur SQL");
        editorTitle.setFont(ModernTheme.UI_BOLD);
        editorCodePill = ModernTheme.pill("—", ModernTheme.SOFT_BLUE, ModernTheme.ACCENT);
        editorHeader.add(editorTitle, BorderLayout.WEST);
        editorHeader.add(editorCodePill, BorderLayout.EAST);
        editorWrapper.add(editorHeader, BorderLayout.NORTH);
        editorWrapper.add(editor, BorderLayout.CENTER);

        JPanel resultWrapper = ModernTheme.roundedPanel(ModernTheme.CARD, ModernTheme.BORDER, 12);
        resultWrapper.setLayout(new BorderLayout());
        JPanel resultHeader = new JPanel(new BorderLayout());
        resultHeader.setBackground(ModernTheme.CARD);
        resultHeader.setBorder(new EmptyBorder(12, 16, 8, 16));
        JLabel resultTitle = new JLabel("Sortie");
        resultTitle.setFont(ModernTheme.UI_BOLD);
        summaryLabel = new JLabel("Prêt");
        summaryLabel.setFont(ModernTheme.UI_SMALL);
        summaryLabel.setForeground(ModernTheme.MUTED);
        resultHeader.add(resultTitle, BorderLayout.WEST);
        resultHeader.add(summaryLabel, BorderLayout.EAST);
        resultWrapper.add(resultHeader, BorderLayout.NORTH);

        ModernTheme.styleTable(resultTable);
        TableRowSorter<ResultTableModel> sorter = new TableRowSorter<>(resultModel);
        for (int i = 0; i < resultModel.getColumnCount(); i++) {
            sorter.setComparator(i, DatabaseExplorerApp::compareCells);
        }
        resultTable.setRowSorter(sorter);
        resultTable.addMouseListener(new MouseAdapter() {
            @Override
            public void mouseClicked(MouseEvent e) {
                if (e.getClickCount() == 2 && resultTable.getSelectedRow() >= 0) {
                    copySelectedRow();
                }
            }
        });
        JScrollPane resultScroll = new JScrollPane(resultTable);
        ModernTheme.styleScroll(resultScroll);

        historyList.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
        historyList.setFont(ModernTheme.UI);
        historyList.setBackground(ModernTheme.CARD);
        historyList.setFixedCellHeight(30);
        historyList.addListSelectionListener(e -> {
            if (!e.getValueIsAdjusting()) {
                HistoryEntry entry = historyList.getSelectedValue();
                if (entry != null) {
                    editor.setSql(entry.sql());
                    editorCodePill.setText(entry.code());
                    tabs.setSelectedIndex(0);
                }
            }
        });
        JScrollPane historyScroll = new JScrollPane(historyList);
        ModernTheme.styleScroll(historyScroll);

        messagesArea.setEditable(false);
        messagesArea.setFont(ModernTheme.MONO);
        messagesArea.setBackground(new Color(250, 251, 253));
        messagesArea.setBorder(new EmptyBorder(12, 14, 12, 14));
        messagesArea.setLineWrap(true);
        messagesArea.setWrapStyleWord(true);
        JScrollPane messagesScroll = new JScrollPane(messagesArea);
        ModernTheme.styleScroll(messagesScroll);

        tabs = new JTabbedPane();
        tabs.setFont(ModernTheme.UI);
        tabs.setBackground(ModernTheme.CARD);
        tabs.addTab("Résultats", resultScroll);
        tabs.addTab("Historique", historyScroll);
        tabs.addTab("Messages", messagesScroll);

        resultWrapper.add(tabs, BorderLayout.CENTER);

        JSplitPane vertical = new JSplitPane(JSplitPane.VERTICAL_SPLIT, editorWrapper, resultWrapper);
        vertical.setResizeWeight(0.38);
        vertical.setDividerLocation(300);
        vertical.setBorder(null);
        vertical.setBackground(ModernTheme.BG);

        JPanel top = new JPanel(new BorderLayout());
        top.setOpaque(false);
        top.add(toolbar, BorderLayout.CENTER);
        workspace.add(top, BorderLayout.NORTH);
        workspace.add(vertical, BorderLayout.CENTER);
        return workspace;
    }

    private void installShortcuts() {
        KeyStroke runKey = KeyStroke.getKeyStroke(KeyEvent.VK_ENTER, InputEvent.CTRL_DOWN_MASK);
        getRootPane().getInputMap(JComponent.WHEN_IN_FOCUSED_WINDOW).put(runKey, "run-query");
        getRootPane().getActionMap().put("run-query", new AbstractAction() {
            private static final long serialVersionUID = 1L;

            @Override
            public void actionPerformed(ActionEvent e) {
                runQuery();
            }
        });
    }

    /* ------------------------------------------------------------------ */
    /* Catalogue                                                          */
    /* ------------------------------------------------------------------ */

    private void filterCards() {
        String needle = normalize(searchField == null ? "" : searchField.getText());
        List<QueryDefinition> filtered = new ArrayList<>();
        for (QueryDefinition query : queries) {
            if (!"Tout".equals(activeCategory) && !query.category().equals(activeCategory)) {
                continue;
            }
            if (!needle.isEmpty()) {
                String haystack = normalize(query.code() + " " + query.title() + " "
                        + query.description() + " " + query.category() + " " + query.sqlText());
                if (!haystack.contains(needle)) {
                    continue;
                }
            }
            filtered.add(query);
        }

        cards.clear();
        cardsPanel.removeAll();
        for (QueryDefinition query : filtered) {
            QueryCard card = new QueryCard(query, () -> selectQuery(query));
            card.setSelected(query == current);
            cards.add(card);
            cardsPanel.add(card);
            cardsPanel.add(Box.createVerticalStrut(9));
        }
        if (filtered.isEmpty()) {
            JLabel empty = new JLabel("Aucune requête ne correspond à la recherche.", SwingConstants.CENTER);
            empty.setFont(ModernTheme.UI);
            empty.setForeground(ModernTheme.MUTED);
            empty.setBorder(new EmptyBorder(30, 10, 30, 10));
            cardsPanel.add(empty);
        }
        countLabel.setText(filtered.size() + " requête" + (filtered.size() > 1 ? "s" : ""));
        cardsPanel.revalidate();
        cardsPanel.repaint();
        catalogScroll.getVerticalScrollBar().setValue(0);
    }

    private static String normalize(String value) {
        String noAccent = Normalizer.normalize(value, Normalizer.Form.NFD)
                .replaceAll("\\p{InCombiningDiacriticalMarks}+", "");
        return noAccent.toLowerCase(java.util.Locale.ROOT);
    }

    private void selectQuery(QueryDefinition query) {
        current = query;
        editor.setSql(query.sqlText());
        editorCodePill.setText(query.code());
        destructivePill.setVisible(query.destructive() || query.plsql());
        if (query.plsql()) {
            destructivePill.setText("ℹ  Bloc PL/SQL · DBMS_OUTPUT");
            ModernTheme.setPillColors(destructivePill, new Color(245, 243, 255), new Color(109, 40, 217));
        } else {
            destructivePill.setText("⚠  Requête destructive");
            ModernTheme.setPillColors(destructivePill, ModernTheme.SOFT_RED, ModernTheme.DANGER);
        }
        for (QueryCard card : cards) {
            card.setSelected(card.query() == query);
        }
        summaryLabel.setText("Prêt · " + query.title());
    }

    /* ------------------------------------------------------------------ */
    /* Exécution                                                          */
    /* ------------------------------------------------------------------ */

    private void runQuery() {
        if (!database.isConnected()) {
            openConnectionDialog();
            if (!database.isConnected()) {
                return;
            }
        }

        String sql = editor.getSql().strip();
        if (sql.isEmpty()) {
            JOptionPane.showMessageDialog(this, "L'éditeur SQL est vide.", "BDDA Explorer",
                    JOptionPane.WARNING_MESSAGE);
            return;
        }

        QueryDefinition snapshot = current;
        boolean plsql = (snapshot != null && snapshot.plsql()) || PLSQL_START.matcher(sql).find();
        boolean risky = (snapshot != null && snapshot.destructive()) || RISKY_SQL.matcher(sql).find();
        if (risky) {
            int answer = JOptionPane.showConfirmDialog(this,
                    "Cette instruction peut modifier des données (DELETE, UPDATE, COMMIT…).\n\n"
                            + "Continuer l'exécution ?",
                    "Confirmation requise", JOptionPane.YES_NO_OPTION, JOptionPane.WARNING_MESSAGE);
            if (answer != JOptionPane.YES_OPTION) {
                return;
            }
        }

        String code = snapshot == null ? "SQL" : snapshot.code();
        String label = snapshot == null ? "Requête libre" : snapshot.title();
        setBusy(true, "Exécution…", new Color(255, 246, 224), ModernTheme.WARNING);

        SwingWorker<DatabaseService.QueryResult, Void> worker = new SwingWorker<>() {
            @Override
            protected DatabaseService.QueryResult doInBackground() throws Exception {
                return database.execute(sql, plsql);
            }

            @Override
            protected void done() {
                try {
                    DatabaseService.QueryResult result = get();
                    resultModel.setData(result);
                    TableRowSorter<ResultTableModel> newSorter = new TableRowSorter<>(resultModel);
                    for (int i = 0; i < resultModel.getColumnCount(); i++) {
                        newSorter.setComparator(i, DatabaseExplorerApp::compareCells);
                    }
                    resultTable.setRowSorter(newSorter);
                    tabs.setSelectedIndex(0);
                    summaryLabel.setText(String.format(
                            "%d ligne(s) · %d instruction(s) · %d ms",
                            result.rows().size(), result.statements(), result.elapsedMillis()));
                    messagesArea.setText(result.messages().isEmpty()
                            ? "Aucun message DBMS_OUTPUT."
                            : String.join(System.lineSeparator(), result.messages()));
                    updateConnectionUi("Connecté · OK", ModernTheme.SUCCESS, new Color(226, 246, 238));
                    historyModel.add(0, new HistoryEntry(code, label, sql,
                            result.rows().size(), result.elapsedMillis(), true));
                    if (result.rows().isEmpty() && result.updateCount() >= 0) {
                        summaryLabel.setText(summaryLabel.getText()
                                + " · " + result.updateCount() + " ligne(s) affectée(s)");
                    }
                } catch (Exception ex) {
                    Throwable cause = ex.getCause() == null ? ex : ex.getCause();
                    String message = cause.getMessage() == null ? cause.getClass().getSimpleName() : cause.getMessage();
                    messagesArea.setText("ERREUR ORACLE\n\n" + message);
                    summaryLabel.setText("Erreur d'exécution");
                    updateConnectionUi("Connecté · Erreur", ModernTheme.DANGER, new Color(255, 237, 238));
                    historyModel.add(0, new HistoryEntry(code, label, sql, 0, 0, false));
                    JOptionPane.showMessageDialog(DatabaseExplorerApp.this, message,
                            "Erreur lors de l'exécution", JOptionPane.ERROR_MESSAGE);
                } finally {
                    setBusy(false, null, null, null);
                }
            }
        };
        worker.execute();
    }

    private void setBusy(boolean busy, String status, Color background, Color foreground) {
        runButton.setEnabled(!busy);
        connectButton.setEnabled(!busy);
        if (status != null) {
            updateConnectionUi(status, foreground, background);
        }
    }

    private void updateConnectionUi(String text, Color foreground, Color background) {
        statusPill.setText(text);
        ModernTheme.setPillColors(statusPill, background == null ? ModernTheme.SOFT_GRAY : background, foreground);
        sidebarStatus.setText(text);
        Color sideForeground = foreground == ModernTheme.SUCCESS ? new Color(21, 128, 61)
                : foreground == ModernTheme.DANGER ? new Color(185, 28, 28)
                : ModernTheme.TEXT;
        sidebarStatus.setForeground(sideForeground);
    }

    private static int compareCells(Object a, Object b) {
        String sa = String.valueOf(a);
        String sb = String.valueOf(b);
        try {
            return Double.compare(Double.parseDouble(sa.replace(",", ".")),
                    Double.parseDouble(sb.replace(",", ".")));
        } catch (NumberFormatException ignored) {
            return sa.compareToIgnoreCase(sb);
        }
    }

    private void copySql() {
        java.awt.Toolkit.getDefaultToolkit().getSystemClipboard()
                .setContents(new java.awt.datatransfer.StringSelection(editor.getSql()), null);
        summaryLabel.setText("SQL copié dans le presse-papiers");
    }

    private void copySelectedRow() {
        int row = resultTable.getSelectedRow();
        StringBuilder sb = new StringBuilder();
        for (int col = 0; col < resultTable.getColumnCount(); col++) {
            if (col > 0) {
                sb.append('\t');
            }
            Object value = resultTable.getValueAt(row, col);
            sb.append(value == null ? "" : value);
        }
        java.awt.Toolkit.getDefaultToolkit().getSystemClipboard()
                .setContents(new java.awt.datatransfer.StringSelection(sb.toString()), null);
        summaryLabel.setText("Ligne copiée");
    }

    private void exportCsv() {
        if (resultModel.getRowCount() == 0) {
            JOptionPane.showMessageDialog(this, "Aucun résultat à exporter.", "BDDA Explorer",
                    JOptionPane.INFORMATION_MESSAGE);
            return;
        }
        JFileChooser chooser = new JFileChooser();
        chooser.setDialogTitle("Exporter le résultat en CSV");
        chooser.setSelectedFile(new File("resultat_bdda.csv"));
        if (chooser.showSaveDialog(this) != JFileChooser.APPROVE_OPTION) {
            return;
        }
        File file = chooser.getSelectedFile();
        try (BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(
                new FileOutputStream(file), StandardCharsets.UTF_8))) {
            writer.write('\uFEFF');
            writer.write(String.join(";", quoteAll(resultModel.columns())));
            writer.newLine();
            for (List<String> row : resultModel.rows()) {
                writer.write(String.join(";", quoteAll(row)));
                writer.newLine();
            }
            summaryLabel.setText("Exporté : " + file.getName());
        } catch (Exception ex) {
            JOptionPane.showMessageDialog(this, "Export impossible :\n" + ex.getMessage(),
                    "BDDA Explorer", JOptionPane.ERROR_MESSAGE);
        }
    }

    private static List<String> quoteAll(List<String> values) {
        List<String> quoted = new ArrayList<>(values.size());
        for (String value : values) {
            String safe = value == null ? "" : value;
            quoted.add("\"" + safe.replace("\"", "\"\"") + "\"");
        }
        return quoted;
    }

    /* ------------------------------------------------------------------ */
    /* Connexion                                                          */
    /* ------------------------------------------------------------------ */

    private void openConnectionDialog() {
        Optional<ConnectionConfig> config = ConnectionDialog.showDialog(this);
        config.ifPresent(this::connectWith);
    }

    private static ConnectionConfig defaultConfig() {
        String host = PREFS.get("host", "localhost");
        String port = PREFS.get("port", "1521");
        String service = PREFS.get("service", "XEPDB1");
        String user = PREFS.get("user", "MASTER1");
        return new ConnectionConfig(host, port, service, user, "system",
                DatabaseService.buildUrl(host, port, service), false);
    }

    private void connectWith(ConnectionConfig cfg) {
        setBusy(true, "Connexion…", ModernTheme.SOFT_BLUE, ModernTheme.ACCENT);

        SwingWorker<Void, Void> worker = new SwingWorker<>() {
            @Override
            protected Void doInBackground() throws Exception {
                database.connect(cfg.url(), cfg.user(), cfg.password());
                return null;
            }

            @Override
            protected void done() {
                try {
                    get();
                    savePreferences(cfg);
                    updateConnectionUi("Connecté", ModernTheme.SUCCESS, ModernTheme.SOFT_GREEN);
                    sidebarStatus.setText("Connecté à " + cfg.service());
                    summaryLabel.setText("Connexion établie · " + cfg.user());
                } catch (Exception ex) {
                    Throwable cause = ex.getCause() == null ? ex : ex.getCause();
                    String message = cause.getMessage() == null ? cause.getClass().getSimpleName() : cause.getMessage();
                    updateConnectionUi("Échec connexion", ModernTheme.DANGER, ModernTheme.SOFT_RED);
                    JOptionPane.showMessageDialog(DatabaseExplorerApp.this, message,
                            "Connexion Oracle impossible", JOptionPane.ERROR_MESSAGE);
                } finally {
                    setBusy(false, null, null, null);
                }
            }
        };
        worker.execute();
    }

    private static void savePreferences(ConnectionConfig cfg) {
        if (!cfg.remember()) {
            return;
        }
        PREFS.put("host", cfg.host());
        PREFS.put("port", cfg.port());
        PREFS.put("service", cfg.service());
        PREFS.put("user", cfg.user());
    }

    private record ConnectionConfig(String host, String port, String service, String user,
                                    String password, String url, boolean remember) {
    }

    private static final class ConnectionDialog extends JDialog {

        private static final long serialVersionUID = 1L;

        private final JTextField host = ModernTheme.softField();
        private final JTextField port = ModernTheme.softField();
        private final JTextField service = ModernTheme.softField();
        private final JTextField user = ModernTheme.softField();
        private final JPasswordField password = ModernTheme.softPasswordField();
        private final JCheckBox remember = new JCheckBox("Mémoriser la configuration (sans mot de passe)", true);
        private final JLabel urlPreview = new JLabel();
        private boolean accepted;

        private ConnectionDialog(JFrame owner) {
            super(owner, "Connexion à la base Oracle", true);
            host.setText(PREFS.get("host", "localhost"));
            port.setText(PREFS.get("port", "1521"));
            service.setText(PREFS.get("service", "XEPDB1"));
            user.setText(PREFS.get("user", "MASTER1"));
            setSize(new Dimension(520, 470));
            setLocationRelativeTo(owner);
            setResizable(false);
            setContentPane(buildContent());
            watchUrl();
            updateUrl();
        }

        static Optional<ConnectionConfig> showDialog(JFrame owner) {
            ConnectionDialog dialog = new ConnectionDialog(owner);
            dialog.setVisible(true);
            SwingUtilities.invokeLater(dialog.host::requestFocusInWindow);
            if (!dialog.accepted) {
                return Optional.empty();
            }
            String host = dialog.host.getText().trim();
            String port = dialog.port.getText().trim();
            String service = dialog.service.getText().trim();
            String user = dialog.user.getText().trim();
            String pwd = new String(dialog.password.getPassword());
            String url = DatabaseService.buildUrl(host, port, service);
            if (host.isEmpty() || user.isEmpty()) {
                return Optional.empty();
            }
            return Optional.of(new ConnectionConfig(host, port, service, user, pwd, url, dialog.remember.isSelected()));
        }

        private JComponent buildContent() {
            JPanel root = new JPanel(new BorderLayout());
            root.setBackground(ModernTheme.CARD);
            root.setBorder(new EmptyBorder(24, 28, 22, 28));

            JLabel title = new JLabel("Connexion Oracle");
            title.setFont(ModernTheme.TITLE);
            JLabel subtitle = new JLabel("Renseigne les paramètres de la base Oracle 21c XE.");
            subtitle.setFont(ModernTheme.UI_SMALL);
            subtitle.setForeground(ModernTheme.MUTED);

            JPanel header = new JPanel();
            header.setOpaque(false);
            header.setLayout(new BoxLayout(header, BoxLayout.Y_AXIS));
            header.add(title);
            header.add(Box.createVerticalStrut(4));
            header.add(subtitle);

            JPanel form = new JPanel(new GridBagLayout());
            form.setOpaque(false);
            form.setBorder(new EmptyBorder(22, 0, 8, 0));
            GridBagConstraints gc = new GridBagConstraints();
            gc.insets = new Insets(6, 4, 6, 4);
            gc.anchor = GridBagConstraints.WEST;

            addField(form, gc, 0, "Hôte", host);
            addField(form, gc, 1, "Port", port);
            addField(form, gc, 2, "Service / PDB", service);
            addField(form, gc, 3, "Utilisateur", user);
            addField(form, gc, 4, "Mot de passe", password);

            gc.gridx = 0;
            gc.gridy = 5;
            gc.gridwidth = 2;
            gc.fill = GridBagConstraints.NONE;
            gc.insets = new Insets(12, 4, 4, 4);
            form.add(remember, gc);

            JPanel urlCard = ModernTheme.roundedPanel(ModernTheme.SOFT_BLUE, null, 10);
            urlCard.setBorder(new EmptyBorder(10, 14, 10, 14));
            urlPreview.setFont(ModernTheme.UI_SMALL);
            urlPreview.setForeground(ModernTheme.ACCENT);
            urlCard.add(urlPreview);

            JButton preset = ModernTheme.button("↺  Valeurs du projet (localhost / XEPDB1)", ModernTheme.ButtonStyle.GHOST);
            preset.setAlignmentX(LEFT_ALIGNMENT);
            preset.addActionListener(e -> {
                host.setText("localhost");
                port.setText("1521");
                service.setText("XEPDB1");
                user.setText("MASTER1");
                password.setText("system");
                updateUrl();
            });

            JPanel bottomLeft = new JPanel();
            bottomLeft.setOpaque(false);
            bottomLeft.setLayout(new BoxLayout(bottomLeft, BoxLayout.Y_AXIS));
            bottomLeft.add(preset);
            bottomLeft.add(Box.createVerticalStrut(8));
            bottomLeft.add(urlCard);

            JPanel buttons = new JPanel(new FlowLayout(FlowLayout.RIGHT, 8, 0));
            buttons.setOpaque(false);
            JButton cancel = ModernTheme.button("Annuler", ModernTheme.ButtonStyle.SECONDARY);
            cancel.addActionListener(e -> dispose());
            JButton ok = ModernTheme.button("Se connecter", ModernTheme.ButtonStyle.PRIMARY);
            ok.addActionListener(e -> {
                accepted = true;
                dispose();
            });
            buttons.add(cancel);
            buttons.add(ok);

            root.add(header, BorderLayout.NORTH);
            root.add(form, BorderLayout.CENTER);
            JPanel footer = new JPanel(new BorderLayout());
            footer.setOpaque(false);
            footer.setBorder(new EmptyBorder(6, 0, 0, 0));
            footer.add(bottomLeft, BorderLayout.WEST);
            footer.add(buttons, BorderLayout.EAST);
            root.add(footer, BorderLayout.SOUTH);
            return root;
        }

        private void watchUrl() {
            DocumentListener listener = new DocumentListener() {
                @Override public void insertUpdate(DocumentEvent e) { updateUrl(); }
                @Override public void removeUpdate(DocumentEvent e) { updateUrl(); }
                @Override public void changedUpdate(DocumentEvent e) { updateUrl(); }
            };
            host.getDocument().addDocumentListener(listener);
            port.getDocument().addDocumentListener(listener);
            service.getDocument().addDocumentListener(listener);
        }

        private void updateUrl() {
            urlPreview.setText("URL : " + DatabaseService.buildUrl(
                    host.getText(), port.getText(), service.getText()));
        }

        private void addField(JPanel parent, GridBagConstraints gc, int row, String label, JComponent field) {
            gc.gridwidth = 1;
            gc.gridx = 0;
            gc.gridy = row;
            JLabel lbl = new JLabel(label);
            lbl.setFont(ModernTheme.UI);
            parent.add(lbl, gc);
            gc.gridx = 1;
            gc.fill = GridBagConstraints.HORIZONTAL;
            gc.weightx = 1;
            field.setPreferredSize(new Dimension(310, 38));
            field.setMaximumSize(new Dimension(310, 38));
            parent.add(field, gc);
            gc.weightx = 0;
            gc.fill = GridBagConstraints.NONE;
        }
    }
}
