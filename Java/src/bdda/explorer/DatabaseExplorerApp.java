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
import java.awt.event.ComponentAdapter;
import java.awt.event.ComponentEvent;
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
    private JLabel editorCodePill;
    private JLabel destructivePill;
    private JLabel summaryLabel;
    private JLabel statusBarConnection;
    private JLabel statusBarSelection;
    private JLabel statusBarRows;
    private int lastRowCount = -1;
    private JButton runButton;
    private JButton connectButton;
    private JTabbedPane tabs;
    private final List<JButton> categoryButtons = new ArrayList<>();

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
        updateConnectionUi("Non connecté", ModernTheme.MUTED, ModernTheme.SOFT_GRAY);
    }

    /* ------------------------------------------------------------------ */
    /* Construction de l'interface                                        */
    /* ------------------------------------------------------------------ */

    private JComponent buildRoot() {
        JPanel root = new JPanel(new BorderLayout());
        root.setBackground(ModernTheme.BG);

        // La barre d'état est construite avant le catalogue, qui la met à jour
        // dès son premier filtrage.
        root.add(buildStatusBar(), BorderLayout.SOUTH);
        root.add(buildHeader(), BorderLayout.NORTH);
        root.add(buildBody(), BorderLayout.CENTER);
        return root;
    }

    /**
     * Corps en trois colonnes : catalogue à gauche, éditeur au centre,
     * résultats à droite. Deux séparateurs imbriqués gardent des proportions
     * stables quelle que soit la taille de la fenêtre.
     */
    private JComponent buildBody() {
        JSplitPane editorAndResults = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT,
                buildEditorColumn(), buildResultColumn());
        editorAndResults.setResizeWeight(0.52);
        editorAndResults.setBorder(null);
        editorAndResults.setBackground(ModernTheme.BG);
        placeDivider(editorAndResults, 0.52);

        JSplitPane body = new JSplitPane(JSplitPane.HORIZONTAL_SPLIT,
                buildCatalogColumn(), editorAndResults);
        body.setResizeWeight(0.24);
        body.setBorder(null);
        body.setBackground(ModernTheme.BG);
        placeDivider(body, 0.24);
        return body;
    }

    /**
     * Place le séparateur en pourcentage une fois que le panneau a une taille
     * réelle. setDividerLocation(double) avant l'affichage est ignoré par Swing.
     */
    private static void placeDivider(JSplitPane split, double proportion) {
        split.addComponentListener(new ComponentAdapter() {
            @Override
            public void componentResized(ComponentEvent e) {
                split.setDividerLocation(proportion);
                split.removeComponentListener(this);
            }
        });
    }

    /** Bandeau inférieur : connexion, sélection courante et raccourcis. */
    private JComponent buildStatusBar() {
        JPanel bar = new JPanel(new BorderLayout(16, 0));
        bar.setBackground(ModernTheme.CARD);
        bar.setBorder(javax.swing.BorderFactory.createCompoundBorder(
                javax.swing.BorderFactory.createMatteBorder(1, 0, 0, 0, ModernTheme.BORDER),
                new EmptyBorder(10, 24, 10, 24)));

        statusBarConnection = new JLabel("Non connecté");
        statusBarSelection = new JLabel("Catalogue : " + queries.size() + " requêtes");
        statusBarRows = new JLabel("Ctrl+Entrée : exécuter · Double-clic : copier une ligne");
        for (JLabel label : new JLabel[]{statusBarConnection, statusBarSelection, statusBarRows}) {
            label.setFont(ModernTheme.UI_SMALL);
            label.setForeground(ModernTheme.MUTED);
        }
        statusBarRows.setHorizontalAlignment(SwingConstants.RIGHT);

        bar.add(statusBarConnection, BorderLayout.WEST);
        bar.add(statusBarSelection, BorderLayout.CENTER);
        bar.add(statusBarRows, BorderLayout.EAST);
        return bar;
    }

    /** Remet à jour le bandeau inférieur selon l'état courant. */
    private void updateStatusBar() {
        if (statusBarSelection == null) {
            return;
        }
        String category = "Tout".equals(activeCategory) ? "Toutes les catégories" : activeCategory;
        String query = current == null ? "Aucune requête sélectionnée"
                : current.code() + " · " + current.title();
        String rows = lastRowCount < 0 ? "" : " · " + lastRowCount + " ligne(s)";
        statusBarSelection.setText(category + "  |  " + query + rows);
    }

    /** En-tête unique et compact : identité à gauche, connexion à droite. */
    private JComponent buildHeader() {
        JPanel header = new JPanel(new BorderLayout(16, 0));
        header.setBackground(ModernTheme.CARD);
        header.setBorder(javax.swing.BorderFactory.createCompoundBorder(
                javax.swing.BorderFactory.createMatteBorder(0, 0, 1, 0, ModernTheme.BORDER),
                new EmptyBorder(14, 24, 14, 24)));

        JPanel identity = new JPanel(new FlowLayout(FlowLayout.LEFT, 11, 0));
        identity.setOpaque(false);
        JLabel mark = ModernTheme.pill("DB", ModernTheme.ACCENT, Color.WHITE);
        JLabel title = new JLabel("BDDA Explorer");
        title.setFont(ModernTheme.UI_SEMIBOLD);
        title.setForeground(ModernTheme.TEXT);
        JLabel subtitle = new JLabel("Requêtes SQL Oracle · schéma MASTER1");
        subtitle.setFont(ModernTheme.UI_SMALL);
        subtitle.setForeground(ModernTheme.MUTED);
        identity.add(mark);
        identity.add(title);
        identity.add(subtitle);

        JPanel actions = new JPanel(new FlowLayout(FlowLayout.RIGHT, 9, 0));
        actions.setOpaque(false);
        statusPill = ModernTheme.pill("Non connecté", ModernTheme.SOFT_GRAY, ModernTheme.MUTED);
        connectButton = ModernTheme.button("Configurer", ModernTheme.ButtonStyle.SECONDARY);
        connectButton.addActionListener(e -> openConnectionDialog());
        JButton quick = ModernTheme.button("⚡  Connexion rapide", ModernTheme.ButtonStyle.PRIMARY);
        quick.addActionListener(e -> connectWith(defaultConfig()));
        actions.add(statusPill);
        actions.add(connectButton);
        actions.add(quick);

        header.add(identity, BorderLayout.WEST);
        header.add(actions, BorderLayout.EAST);
        return header;
    }

    /** Colonne 1 : catégories, recherche puis liste des requêtes. */
    private JComponent buildCatalogColumn() {
        JPanel catalog = new JPanel(new BorderLayout());
        catalog.setBackground(ModernTheme.CARD);
        catalog.setBorder(javax.swing.BorderFactory.createMatteBorder(0, 0, 0, 1, ModernTheme.BORDER));
        catalog.setPreferredSize(new Dimension(330, 0));

        JPanel top = new JPanel(new BorderLayout(0, 12));
        top.setBackground(ModernTheme.ZONE_CATALOG_BG);
        top.setBorder(new EmptyBorder(20, 18, 16, 18));

        JPanel titleRow = new JPanel(new BorderLayout());
        titleRow.setOpaque(false);
        JLabel title = new JLabel("1  ·  Catalogue de requêtes");
        title.setFont(ModernTheme.UI_SEMIBOLD);
        title.setForeground(ModernTheme.ZONE_CATALOG);
        countLabel = ModernTheme.pill(queries.size() + " requêtes",
                ModernTheme.ZONE_CATALOG_BG, ModernTheme.ZONE_CATALOG);
        titleRow.add(title, BorderLayout.WEST);
        titleRow.add(countLabel, BorderLayout.EAST);

        JLabel categoriesTitle = new JLabel("CATÉGORIES");
        categoriesTitle.setFont(ModernTheme.UI_SMALL.deriveFont(Font.BOLD));
        categoriesTitle.setForeground(ModernTheme.MUTED);

        JPanel chips = new JPanel(new FlowLayout(FlowLayout.LEFT, 5, 4));
        chips.setOpaque(false);
        addCategoryChip(chips, "Tout", "Tout");
        for (String category : QueryCatalog.categories()) {
            addCategoryChip(chips, category, category);
        }

        searchField = ModernTheme.searchField("⌕  Rechercher une requête ou du SQL…");
        searchField.setMaximumSize(new Dimension(Integer.MAX_VALUE, 40));
        searchField.getDocument().addDocumentListener(new DocumentListener() {
            @Override public void insertUpdate(DocumentEvent e) { filterCards(); }
            @Override public void removeUpdate(DocumentEvent e) { filterCards(); }
            @Override public void changedUpdate(DocumentEvent e) { filterCards(); }
        });

        JPanel filters = new JPanel(new BorderLayout(0, 6));
        filters.setOpaque(false);
        filters.add(categoriesTitle, BorderLayout.NORTH);
        filters.add(chips, BorderLayout.CENTER);
        filters.add(searchField, BorderLayout.SOUTH);

        top.add(titleRow, BorderLayout.NORTH);
        top.add(filters, BorderLayout.CENTER);

        cardsPanel = new JPanel();
        cardsPanel.setBackground(ModernTheme.BG);
        cardsPanel.setLayout(new BoxLayout(cardsPanel, BoxLayout.Y_AXIS));
        cardsPanel.setBorder(new EmptyBorder(8, 14, 22, 14));
        catalogScroll = new JScrollPane(cardsPanel);
        ModernTheme.styleScroll(catalogScroll);
        catalogScroll.getVerticalScrollBar().setUnitIncrement(16);

        catalog.add(top, BorderLayout.NORTH);
        catalog.add(catalogScroll, BorderLayout.CENTER);
        filterCards();
        return catalog;
    }

    private void addCategoryChip(JPanel parent, String label, String category) {
        JButton button = ModernTheme.chip(label);
        ModernTheme.setChipSelected(button, "Tout".equals(category));
        button.addActionListener(e -> {
            activeCategory = category;
            for (JButton chip : categoryButtons) {
                ModernTheme.setChipSelected(chip, chip == button);
            }
            filterCards();
        });
        categoryButtons.add(button);
        parent.add(button);
    }

    /** Colonne 2 : l'éditeur SQL et ses actions, sur toute la hauteur. */
    private JComponent buildEditorColumn() {
        JPanel column = new JPanel(new BorderLayout());
        column.setBackground(ModernTheme.BG);
        column.setBorder(new EmptyBorder(20, 18, 20, 12));
        column.add(buildEditorCard(), BorderLayout.CENTER);
        return column;
    }

    /** Colonne 3 : résultats, historique et messages, sur toute la hauteur. */
    private JComponent buildResultColumn() {
        JPanel column = new JPanel(new BorderLayout());
        column.setBackground(ModernTheme.BG);
        column.setBorder(new EmptyBorder(20, 12, 20, 20));
        column.add(buildResultCard(), BorderLayout.CENTER);
        return column;
    }

    /** Actions de l'éditeur réparties sur deux rangées pour rester lisibles. */
    private JComponent buildEditorToolbar() {
        JPanel toolbar = new JPanel();
        toolbar.setOpaque(false);
        toolbar.setLayout(new BoxLayout(toolbar, BoxLayout.Y_AXIS));

        JPanel execution = new JPanel(new FlowLayout(FlowLayout.LEFT, 0, 0));
        execution.setOpaque(false);
        runButton = ModernTheme.button("▶  Exécuter  (Ctrl+Entrée)", ModernTheme.ButtonStyle.PRIMARY);
        runButton.addActionListener(e -> runQuery());
        JButton reset = ModernTheme.button("↻  Réinitialiser", ModernTheme.ButtonStyle.SECONDARY);
        reset.addActionListener(e -> {
            if (current != null) {
                selectQuery(current);
            }
        });
        execution.add(runButton);
        execution.add(Box.createHorizontalStrut(8));
        execution.add(reset);

        JPanel tools = new JPanel(new FlowLayout(FlowLayout.LEFT, 10, 0));
        tools.setOpaque(false);
        JButton copy = ModernTheme.button("⧉  Copier SQL", ModernTheme.ButtonStyle.GHOST);
        copy.addActionListener(e -> copySql());
        JButton export = ModernTheme.button("⬇  Exporter CSV", ModernTheme.ButtonStyle.GHOST);
        export.addActionListener(e -> exportCsv());
        destructivePill = ModernTheme.pill("⚠  Requête destructive", ModernTheme.SOFT_RED, ModernTheme.DANGER);
        destructivePill.setVisible(false);
        tools.add(copy);
        tools.add(export);
        tools.add(Box.createHorizontalStrut(4));
        tools.add(destructivePill);

        toolbar.add(execution);
        toolbar.add(Box.createVerticalStrut(10));
        toolbar.add(tools);
        return toolbar;
    }

    /** Carte réutilisable : titre coloré par zone, badge à droite, contenu. */
    private JPanel buildCard(String title, JComponent badge, JComponent content,
                             Color zoneColor, Color zoneBackground) {
        JPanel wrapper = ModernTheme.roundedPanel(ModernTheme.CARD, ModernTheme.BORDER, 14);
        wrapper.setLayout(new BorderLayout());

        JPanel header = new JPanel(new BorderLayout());
        header.setBackground(zoneBackground);
        header.setBorder(new EmptyBorder(16, 20, 12, 20));
        JLabel label = new JLabel(title);
        label.setFont(ModernTheme.UI_BOLD);
        label.setForeground(zoneColor);
        header.add(label, BorderLayout.WEST);
        if (badge != null) {
            header.add(badge, BorderLayout.EAST);
        }

        wrapper.add(header, BorderLayout.NORTH);
        wrapper.add(content, BorderLayout.CENTER);
        return wrapper;
    }

    private JComponent buildEditorCard() {
        editorCodePill = ModernTheme.pill("—",
                ModernTheme.ZONE_EDITOR_BG, ModernTheme.ZONE_EDITOR);

        JPanel content = new JPanel(new BorderLayout(0, 12));
        content.setBackground(ModernTheme.CARD);
        content.setBorder(new EmptyBorder(0, 18, 16, 18));
        content.add(buildEditorToolbar(), BorderLayout.NORTH);
        content.add(editor, BorderLayout.CENTER);

        return buildCard("2  ·  Éditeur SQL", editorCodePill, content,
                ModernTheme.ZONE_EDITOR, ModernTheme.ZONE_EDITOR_BG);
    }

    private JComponent buildResultCard() {
        summaryLabel = new JLabel("Prêt");
        summaryLabel.setFont(ModernTheme.UI_SMALL);
        summaryLabel.setForeground(ModernTheme.ZONE_RESULTS);

        tabs = new JTabbedPane();
        tabs.setFont(ModernTheme.UI);
        tabs.setBackground(ModernTheme.CARD);
        tabs.addTab("Résultats", buildResultsTab());
        tabs.addTab("Historique", buildHistoryTab());
        tabs.addTab("Messages", buildMessagesTab());

        return buildCard("3  ·  Résultats", summaryLabel, tabs,
                ModernTheme.ZONE_RESULTS, ModernTheme.ZONE_RESULTS_BG);
    }

    private JComponent buildResultsTab() {
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
        JScrollPane scroll = new JScrollPane(resultTable);
        ModernTheme.styleScroll(scroll);
        return scroll;
    }

    private JComponent buildHistoryTab() {
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
        JScrollPane scroll = new JScrollPane(historyList);
        ModernTheme.styleScroll(scroll);
        return scroll;
    }

    private JComponent buildMessagesTab() {
        messagesArea.setEditable(false);
        messagesArea.setFont(ModernTheme.MONO);
        messagesArea.setBackground(ModernTheme.CARD_ALT);
        messagesArea.setBorder(new EmptyBorder(12, 14, 12, 14));
        messagesArea.setLineWrap(true);
        messagesArea.setWrapStyleWord(true);
        JScrollPane scroll = new JScrollPane(messagesArea);
        ModernTheme.styleScroll(scroll);
        return scroll;
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
            cardsPanel.add(Box.createVerticalStrut(12));
        }
        if (filtered.isEmpty()) {
            JLabel empty = new JLabel("Aucune requête ne correspond à la recherche.", SwingConstants.CENTER);
            empty.setFont(ModernTheme.UI);
            empty.setForeground(ModernTheme.MUTED);
            empty.setBorder(new EmptyBorder(30, 10, 30, 10));
            cardsPanel.add(empty);
        }
        countLabel.setText(filtered.size() + " requête" + (filtered.size() > 1 ? "s" : ""));
        updateStatusBar();
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
            ModernTheme.setPillColors(destructivePill,
                    ModernTheme.ZONE_RESULTS_BG, ModernTheme.ZONE_RESULTS);
        } else {
            destructivePill.setText("⚠  Requête destructive");
            ModernTheme.setPillColors(destructivePill, ModernTheme.SOFT_RED, ModernTheme.DANGER);
        }
        for (QueryCard card : cards) {
            card.setSelected(card.query() == query);
        }
        summaryLabel.setText("Prêt · " + query.title());
        lastRowCount = -1;
        updateStatusBar();
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
        setBusy(true, "Exécution…", new Color(69, 52, 13), ModernTheme.WARNING);

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
                    lastRowCount = result.rows().size();
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
                    updateStatusBar();
                    updateConnectionUi("Connecté · OK", ModernTheme.SUCCESS, ModernTheme.SOFT_GREEN);
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
                    lastRowCount = -1;
                    updateStatusBar();
                    updateConnectionUi("Connecté · Erreur", ModernTheme.DANGER, ModernTheme.SOFT_RED);
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
        statusBarConnection.setText(text);
        Color barForeground = foreground == ModernTheme.SUCCESS ? ModernTheme.SUCCESS
                : foreground == ModernTheme.DANGER ? ModernTheme.DANGER
                : ModernTheme.MUTED;
        statusBarConnection.setForeground(barForeground);
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
                    statusBarConnection.setText("Connecté à " + cfg.service());
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
            setSize(new Dimension(560, 540));
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
            JPanel root = new JPanel(new BorderLayout(0, 8));
            root.setBackground(ModernTheme.CARD);
            root.setBorder(new EmptyBorder(22, 26, 20, 26));

            JPanel header = new JPanel();
            header.setOpaque(false);
            header.setLayout(new BoxLayout(header, BoxLayout.Y_AXIS));
            JLabel title = new JLabel("Connexion Oracle");
            title.setFont(ModernTheme.TITLE);
            JLabel subtitle = new JLabel("Renseigne les paramètres de la base Oracle 21c XE.");
            subtitle.setFont(ModernTheme.UI_SMALL);
            subtitle.setForeground(ModernTheme.MUTED);
            header.add(title);
            header.add(Box.createVerticalStrut(4));
            header.add(subtitle);

            // Deux sections distinctes : serveur puis compte.
            JPanel form = new JPanel();
            form.setOpaque(false);
            form.setLayout(new BoxLayout(form, BoxLayout.Y_AXIS));
            form.setBorder(new EmptyBorder(18, 0, 0, 0));
            form.add(buildSection("1  ·  Serveur Oracle", buildServerFields()));
            form.add(Box.createVerticalStrut(10));
            form.add(buildSection("2  ·  Compte Oracle", buildAccountFields()));

            root.add(header, BorderLayout.NORTH);
            root.add(form, BorderLayout.CENTER);
            root.add(buildDialogFooter(), BorderLayout.SOUTH);
            return root;
        }

        /** Carte de formulaire avec un titre de section. */
        private JPanel buildSection(String title, JComponent fields) {
            JPanel card = ModernTheme.roundedPanel(ModernTheme.SOFT_GRAY, ModernTheme.BORDER, 10);
            card.setLayout(new BorderLayout());
            card.setBorder(new EmptyBorder(12, 14, 10, 14));

            JLabel label = new JLabel(title);
            label.setFont(ModernTheme.UI_SMALL.deriveFont(Font.BOLD));
            label.setForeground(ModernTheme.MUTED);
            label.setBorder(new EmptyBorder(0, 0, 6, 0));

            card.add(label, BorderLayout.NORTH);
            card.add(fields, BorderLayout.CENTER);
            return card;
        }

        private JComponent buildServerFields() {
            JPanel grid = new JPanel(new GridBagLayout());
            grid.setOpaque(false);
            GridBagConstraints gc = newConstraints();
            addField(grid, gc, 0, "Hôte", host);
            addField(grid, gc, 1, "Port", port);
            addField(grid, gc, 2, "Service / PDB", service);
            return grid;
        }

        private JComponent buildAccountFields() {
            JPanel grid = new JPanel(new GridBagLayout());
            grid.setOpaque(false);
            GridBagConstraints gc = newConstraints();
            addField(grid, gc, 0, "Utilisateur", user);
            addField(grid, gc, 1, "Mot de passe", password);

            gc.gridx = 0;
            gc.gridy = 2;
            gc.gridwidth = 2;
            gc.fill = GridBagConstraints.NONE;
            gc.insets = new Insets(8, 4, 2, 4);
            grid.add(remember, gc);
            return grid;
        }

        private static GridBagConstraints newConstraints() {
            GridBagConstraints gc = new GridBagConstraints();
            gc.insets = new Insets(4, 4, 4, 4);
            gc.anchor = GridBagConstraints.WEST;
            return gc;
        }

        private JComponent buildDialogFooter() {
            JPanel urlCard = ModernTheme.roundedPanel(ModernTheme.SOFT_BLUE, null, 10);
            urlCard.setBorder(new EmptyBorder(9, 12, 9, 12));
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

            JPanel left = new JPanel();
            left.setOpaque(false);
            left.setLayout(new BoxLayout(left, BoxLayout.Y_AXIS));
            left.add(preset);
            left.add(Box.createVerticalStrut(6));
            left.add(urlCard);

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

            JPanel footer = new JPanel(new BorderLayout(12, 0));
            footer.setOpaque(false);
            footer.setBorder(new EmptyBorder(8, 0, 0, 0));
            footer.add(left, BorderLayout.WEST);
            footer.add(buttons, BorderLayout.EAST);
            return footer;
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
