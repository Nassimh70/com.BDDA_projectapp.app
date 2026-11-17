package bdda.explorer;

import java.util.ArrayList;
import java.util.List;
import javax.swing.table.AbstractTableModel;

/** Modèle de tableau pour le résultat d'une requête. */
public final class ResultTableModel extends AbstractTableModel {

    private static final long serialVersionUID = 1L;

    private List<String> columns = List.of();
    private List<List<String>> rows = List.of();

    public void setData(DatabaseService.QueryResult result) {
        this.columns = new ArrayList<>(result.columns());
        this.rows = new ArrayList<>(result.rows());
        fireTableStructureChanged();
    }

    public void clear() {
        this.columns = List.of();
        this.rows = List.of();
        fireTableStructureChanged();
    }

    @Override
    public int getRowCount() {
        return rows.size();
    }

    @Override
    public int getColumnCount() {
        return columns.size();
    }

    @Override
    public Object getValueAt(int rowIndex, int columnIndex) {
        return rows.get(rowIndex).get(columnIndex);
    }

    @Override
    public String getColumnName(int column) {
        if (column >= 0 && column < columns.size()) {
            return columns.get(column);
        }
        return "COLONNE_" + (column + 1);
    }

    @Override
    public Class<?> getColumnClass(int columnIndex) {
        return String.class;
    }

    /** Lignes brutes, utilisées par l'export CSV. */
    public List<List<String>> rows() {
        return rows;
    }

    public List<String> columns() {
        return columns;
    }
}
