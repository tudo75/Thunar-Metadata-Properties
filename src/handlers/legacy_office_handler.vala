using Gtk;
using Gsf;

public class LegacyOfficeHandler : GLib.Object, FileHandler {
    private File file;
    private Grid grid;

    // Metadata
    private string m_title = "-";
    private string m_subject = "-";
    private string m_author = "-";
    private string m_keywords = "-";
    private string m_comments = "-";
    private string m_last_author = "-";
    private string m_app_name = "-";
    private string m_created = "-";
    private string m_modified = "-";
    
    // Stats
    private string m_page_count = "-";
    private string m_word_count = "-";
    private string m_char_count = "-";
    private string m_security = "-";

    private bool is_supported = true;
    private string status_message = "";

    public LegacyOfficeHandler(File f) {
        this.file = f;
        parse_document();
    }

    public Widget get_main_view() {
        var box = new Box(Orientation.VERTICAL, 6);
        box.valign = Align.CENTER;
        box.halign = Align.CENTER;

        string name = file.get_basename().down();
        string icon_name = "x-office-document";
        
        if (name.has_suffix(".doc")) icon_name = "x-office-document";
        else if (name.has_suffix(".xls")) icon_name = "x-office-spreadsheet";
        else if (name.has_suffix(".ppt")) icon_name = "x-office-presentation";

        var icon = new Gtk.Image.from_icon_name(icon_name);
        icon.pixel_size = 128;
        icon.add_css_class("dim-label");
        
        box.append(icon);
        var name_lbl = new Label(file.get_basename());
        name_lbl.add_css_class("title-2");
        name_lbl.wrap = true;
        name_lbl.max_width_chars = 30;
        name_lbl.justify = Justification.CENTER;
        box.append(name_lbl);
        
        return box;
    }

    public Widget get_properties_panel() {
        var scroll = new ScrolledWindow(); 
        var box = new Box(Gtk.Orientation.VERTICAL, 6);
        box.margin_top = 12; box.margin_start = 12; box.margin_end = 12; box.margin_bottom = 12;

        this.grid = new Grid();
        grid.column_spacing = 12;
        grid.row_spacing = 6;
        
        int row = 0;

        UiHelper.add_section_header(grid, ref row, "Legacy Office Metadata");

        if (!is_supported) {
            UiHelper.create_label_row(grid, ref row, "Status:", status_message);
        } else {
            UiHelper.create_label_row(grid, ref row, "Title:", m_title);
            UiHelper.create_label_row(grid, ref row, "Subject:", m_subject);
            UiHelper.create_label_row(grid, ref row, "Keywords:", m_keywords);
            UiHelper.create_label_row(grid, ref row, "Comments:", m_comments);

            UiHelper.add_separator(grid, ref row);
            UiHelper.add_section_header(grid, ref row, "Authoring");

            UiHelper.create_label_row(grid, ref row, "Author:", m_author);
            UiHelper.create_label_row(grid, ref row, "Last Saved By:", m_last_author);
            UiHelper.create_label_row(grid, ref row, "Created:", m_created);
            UiHelper.create_label_row(grid, ref row, "Modified:", m_modified);
            UiHelper.create_label_row(grid, ref row, "Application:", m_app_name);

            UiHelper.add_separator(grid, ref row);
            UiHelper.add_section_header(grid, ref row, "Statistics");
            
            if (m_page_count != "-") UiHelper.create_label_row(grid, ref row, "Page Count:", m_page_count);
            if (m_word_count != "-") UiHelper.create_label_row(grid, ref row, "Word Count:", m_word_count);
            if (m_char_count != "-") UiHelper.create_label_row(grid, ref row, "Char Count:", m_char_count);
            if (m_security != "-")   UiHelper.create_label_row(grid, ref row, "Security:", m_security);
        }

        box.append(grid);
        var spacer = new Label(""); spacer.vexpand = true; box.append(spacer);
        scroll.child = box;
        return scroll;
    }

    private void parse_document() {
        try {
            Gsf.init();
            var input = new Gsf.InputStdio(file.get_path());
            var ole = new Gsf.InfileMSOle(input);

            var meta = new Gsf.DocMetaData();
            meta.read_from_msole(ole);
            
            if (meta != null) {
                m_title = get_prop(meta, "dc:title");
                m_subject = get_prop(meta, "dc:subject");
                m_author = get_prop(meta, "dc:creator");
                m_keywords = get_prop(meta, "dc:keywords");
                m_comments = get_prop(meta, "dc:description");
                
                m_last_author = get_prop(meta, "gsf:last-saved-by");
                m_app_name = get_prop(meta, "meta:generator");
                m_created = format_date(get_prop_val(meta, "meta:creation-date"));
                m_modified = format_date(get_prop_val(meta, "dc:date"));
                
                m_page_count = get_prop(meta, "meta:page-count");
                m_word_count = get_prop(meta, "meta:word-count");
                m_char_count = get_prop(meta, "meta:character-count");
                m_security = get_prop(meta, "gsf:security");
            }

        } catch (GLib.Error e) {
            is_supported = false;
            status_message = "Failed to read OLE2 file: %s".printf(e.message);
        }
    }

    private string get_prop(Gsf.DocMetaData meta, string name) {
        var val = meta.lookup(name);
        if (val == null) return "-";
        
        // FIX: Use 'get_val()' method instead of 'value' property
        // The Vala binding for gsf_doc_prop_get_val is usually get_val()
        GLib.Value? gval = val.get_val();
        
        if (gval == null) return "-";

        if (gval.holds(typeof(string))) return gval.get_string();
        if (gval.holds(typeof(uint))) return "%u".printf(gval.get_uint());
        if (gval.holds(typeof(int))) return "%d".printf(gval.get_int());
        if (gval.holds(typeof(long))) return "%ld".printf(gval.get_long());
        if (gval.holds(typeof(ulong))) return "%lu".printf(gval.get_ulong());
        
        return "-";
    }
    
    private GLib.Value? get_prop_val(Gsf.DocMetaData meta, string name) {
         var val = meta.lookup(name);
         if (val == null) return null;
         // FIX: Use 'get_val()' method
         return val.get_val();
    }

    private string format_date(GLib.Value? val) {
        if (val == null) return "-";
        
        if (val.holds(typeof(string))) {
            string s = val.get_string();
            if (s.contains("T")) return s.replace("T", " ");
            return s;
        }
        return "-";
    }

    public void save_metadata() {
        var dialog = new AlertDialog("Legacy Office Metadata is Read-Only.");
        dialog.show(null);
    }
}