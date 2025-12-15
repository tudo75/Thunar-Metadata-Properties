using Gtk;

public class UiHelper {
    
    // ... (create_label_row, add_section_header, etc. remain the same) ...

    public static void create_label_row(Grid grid, ref int row, string label_text, string value_text) {
        var label = new Label("<b>%s</b>".printf(label_text)) { use_markup = true, xalign = 1.0f, hexpand = false };
        label.halign = Align.END;
        label.valign = Align.CENTER;
        label.hexpand = false;


        var value = new Label(value_text) { xalign = 0, hexpand = true };
        value.hexpand = true;
        //value.wrap = true;
        //value.max_width_chars = 40;
        value.selectable = true;

        grid.attach(label, 0, row, 1, 1);
        grid.attach(value, 1, row, 2, 1); // Span 2 columns
        row++;
    }

    // UPDATED: Added 'use_markup' parameter
    public static void create_list_row(Grid grid, ref int row, string label_text, GLib.List<string> items, bool use_markup = false) {
        if (items.length() == 0) return;

        // 1. Label (Col 0)
        var label = new Label("<b>%s</b>".printf(label_text)) { use_markup = true, xalign = 1.0f, hexpand = false };
        label.halign = Align.END;
        label.valign = Align.CENTER;
        label.hexpand = false;
        
        grid.attach(label, 0, row, 1, 1);

        // 2. Items (Col 1 & 2)
        int col_pointer = 1;

        foreach (string item in items) {
            var item_lbl = new Label(item) { use_markup = use_markup, xalign = 0, hexpand = true };
            item_lbl.use_markup = use_markup; // Enable Bold/Small support
            item_lbl.hexpand = true;
            
            // Layout Settings for multi-line items
            //item_lbl.ellipsize = Pango.EllipsizeMode.END;
            //item_lbl.max_width_chars = 25;
            item_lbl.selectable = true;
            item_lbl.margin_bottom = 6; // Add space between grid rows for readability

            grid.attach(item_lbl, col_pointer, row, 1, 1);

            col_pointer++;
            
            // Wrap after 2 columns (1 & 2)
            if (col_pointer > 2) {
                col_pointer = 1;
                row++;
            }
        }

        // If we ended mid-row, advance row for next section
        if (col_pointer == 2) {
            row++;
        }
    }

    public static void add_section_header(Grid grid, ref int row, string text) {
        var label = new Label("<b>%s</b>".printf(text)) { use_markup = true, xalign = 0 };
        label.valign = Align.CENTER;
        label.margin_top = 3;
        label.margin_bottom = 3;
        grid.attach(label, 0, row, 3, 1);
        row++;
    }

    public static void add_separator(Grid grid, ref int row) {
        var sep = new Separator(Orientation.HORIZONTAL);
        sep.margin_top = 2;
        sep.margin_bottom = 2;
        grid.attach(sep, 0, row, 3, 1);
        row++;
    }
}