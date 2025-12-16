using Gtk;
using Poppler;
using Cairo;

public class PdfHandler : GLib.Object, FileHandler {
    private const int MAX_FONTS = 25;
    private File file;
    private Poppler.Document? doc;
    
    private GLib.List<string> font_list;

    public PdfHandler(File f) {
        this.file = f;
        this.font_list = new GLib.List<string>();
        
        try {
            this.doc = new Poppler.Document.from_file(file.get_uri(), null);
            scan_fonts();
        } catch (GLib.Error e) {
            warning("PDF Load Error: %s", e.message);
        }
    }

    public string get_page_title() {
        return _("PDF Properties");
    }

    public Widget get_properties_panel() {
        var grid = new Grid();
        grid.column_spacing = 12;
        grid.row_spacing = 6;
        
        int row = 0;
        
        UiHelper.add_section_header(grid, ref row, _("General Info"));

        string title_str = (doc != null) ? (doc.get_title() ?? "-") : "-";
        string author_str = (doc != null) ? (doc.get_author() ?? "-") : "-";
        string subject_str = (doc != null) ? (doc.get_subject() ?? "-") : "-";
        string keywords_str = (doc != null) ? (doc.get_keywords() ?? "-") : "-";

        UiHelper.create_label_row(grid, ref row, _("Title:"), title_str);
        UiHelper.create_label_row(grid, ref row, _("Author:"), author_str);
        UiHelper.create_label_row(grid, ref row, _("Subject:"), subject_str);
        UiHelper.create_label_row(grid, ref row, _("Keywords:"), keywords_str);
        
        UiHelper.add_separator(grid, ref row);
        UiHelper.add_section_header(grid, ref row, _("Technical Details"));

        string creator_str = (doc != null) ? (doc.get_creator() ?? "-") : "-";
        string producer_str = (doc != null) ? (doc.get_producer() ?? "-") : "-";
        long c_date = (doc != null) ? doc.get_creation_date() : 0;
        long m_date = (doc != null) ? doc.get_modification_date() : 0;
        string pdf_ver = (doc != null) ? doc.get_pdf_version_string() : _("Unknown");
        string is_sec = (doc != null) ? _("No (Open)") : _("Encrypted"); 

        string size_str = "Unknown";
        if (doc != null && doc.get_n_pages() > 0) {
            double page_w, page_h;
            doc.get_page(0).get_size(out page_w, out page_h);
            int mm_w = (int)(page_w * 25.4 / 72.0);
            int mm_h = (int)(page_h * 25.4 / 72.0);
            size_str = "%d x %d mm".printf(mm_w, mm_h);
        }
        string pages_str = (doc != null) ? "%d".printf(doc.get_n_pages()) : "0";

        UiHelper.create_label_row(grid, ref row, _("Creator:"), creator_str);
        UiHelper.create_label_row(grid, ref row, _("Producer:"), producer_str);
        UiHelper.create_label_row(grid, ref row, _("Created:"), get_date_string(c_date));
        UiHelper.create_label_row(grid, ref row, _("Modified:"), get_date_string(m_date));
        UiHelper.create_label_row(grid, ref row, _("PDF Version:"), pdf_ver);
        UiHelper.create_label_row(grid, ref row, _("Security:"), is_sec);
        UiHelper.create_label_row(grid, ref row, _("Paper Size:"), size_str);
        UiHelper.create_label_row(grid, ref row, _("Pages:"), pages_str);
        
        // 4. Fonts Section (Rich List)
        if (font_list.length() > 0) {
            UiHelper.add_separator(grid, ref row);
            UiHelper.add_section_header(grid, ref row, _("Embedded Fonts"));
            
            // Pass 'true' to enable markup parsing in UiHelper
            UiHelper.create_list_row(grid, ref row, _("Font List:"), font_list, true);
        } else {
             UiHelper.add_separator(grid, ref row);
             UiHelper.create_label_row(grid, ref row, _("Fonts:"), _("None found"));
        }

        return grid;
    }

    private void scan_fonts() {
        if (doc == null) return;
        
        var info = new Poppler.FontInfo(doc);
        Poppler.FontsIter iter;
        
        if (!info.scan(doc.get_n_pages(), out iter)) return;
        
        int count = 0;
        do {
            unowned string? fname = iter.get_name();
            if (fname == null) fname = _("Unnamed");
            
            // 1. Escape Name (IMPORTANT for Pango Markup)
            string safe_name = Markup.escape_text(fname);
            
            // 2. Get Type
            string type = get_font_type_name(iter.get_font_type());
            
            // 3. Format: Bullet + Bold Name + NewLine + Small Type
            // Example: • Arial
            //            TrueType
            string display = "• <b>%s</b>\n  <span size='small' fgcolor='#888888'>%s</span>".printf(safe_name, type);
            
            // 4. Add to list (avoid exact string duplicates)
            bool exists = false;
            foreach (string s in font_list) {
                if (s == display) { exists = true; break; }
            }
            if (!exists) font_list.append(display);

            count++;
            if (count >= MAX_FONTS) {
                font_list.append("<i>%s</i>".printf(_("... and more")));
                break;
            }
        } while (iter.next());
    }

    private string get_font_type_name(Poppler.FontType type) {
        switch (type) {
            case Poppler.FontType.TYPE1: return "Type 1";
            case Poppler.FontType.TYPE1C: return "Type 1 (CFF)";
            case Poppler.FontType.TYPE1COT: return "Type 1 (OT)";
            case Poppler.FontType.TRUETYPE: return "TrueType";
            case Poppler.FontType.TRUETYPEOT: return "TrueType (OT)";
            case Poppler.FontType.CID_TYPE2: return "CID TrueType";
            case Poppler.FontType.CID_TYPE2OT: return "CID TrueType (OT)";
            default: return _("Unknown");
        }
    }

    private string get_date_string(long timestamp) {
        if (timestamp <= 0) return "-";

        var dt = new DateTime.from_unix_local(timestamp);
        return dt.format("%Y-%m-%d %H:%M");
    }
}