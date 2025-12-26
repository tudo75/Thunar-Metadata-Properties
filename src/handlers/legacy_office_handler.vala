using Gtk;
using Gsf;
using TMP.Utils;

/**
 * Thunar-Metadata-Properties package.
 * Thunar plugin to add more detailed properties pages for a wide range of file types.
 */
namespace TMP {

    /**
     * LegacyOfficeHandler class to read metadata from OLE2-based Office files.
     */
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

        /**
         * Constructor: Load the OLE2 document and parse metadata.
         * @param f The GLib.File representing the Office file.
         */
        public LegacyOfficeHandler(File f) {
            this.file = f;

            // DEBUG: Force print to verify constructor started
            debug_print(_("LegacyOfficeHandler: Init started for %s\n"), f.get_uri());
            stdout.flush();

            parse_document();
        }

        /**
        * Get the title for the property page.
        * @return A string representing the page title.
        */
        public string get_page_title() {
            return _("Document Properties");
        }

        /**
         * Get the properties panel widget for the Office file.
         * @return A Gtk.Widget containing the properties panel.
         */
        public Widget get_properties_panel() {
            this.grid = new Grid();
            grid.column_spacing = 12;
            grid.row_spacing = 6;
            
            int row = 0;

            UiHelper.add_section_header(grid, ref row, _("Legacy Office Metadata"));

            if (!is_supported) {
                UiHelper.create_label_row(grid, ref row, _("Status:"), status_message);
            } else {
                UiHelper.create_label_row(grid, ref row, _("Title:"), m_title);
                UiHelper.create_label_row(grid, ref row, _("Subject:"), m_subject);
                UiHelper.create_label_row(grid, ref row, _("Keywords:"), m_keywords);
                UiHelper.create_label_row(grid, ref row, _("Comments:"), m_comments);

                UiHelper.add_separator(grid, ref row);
                UiHelper.add_section_header(grid, ref row, _("Authoring"));

                UiHelper.create_label_row(grid, ref row, _("Author:"), m_author);
                UiHelper.create_label_row(grid, ref row, _("Last Saved By:"), m_last_author);
                UiHelper.create_label_row(grid, ref row, _("Created:"), m_created);
                UiHelper.create_label_row(grid, ref row, _("Modified:"), m_modified);
                UiHelper.create_label_row(grid, ref row, _("Application:"), m_app_name);

                UiHelper.add_separator(grid, ref row);
                UiHelper.add_section_header(grid, ref row, _("Statistics"));
                
                if (m_page_count != "-") UiHelper.create_label_row(grid, ref row, _("Page Count:"), m_page_count);
                if (m_word_count != "-") UiHelper.create_label_row(grid, ref row, _("Word Count:"), m_word_count);
                if (m_char_count != "-") UiHelper.create_label_row(grid, ref row, _("Char Count:"),  m_char_count);
                if (m_security != "-")   UiHelper.create_label_row(grid, ref row, _("Security:"), m_security);
            }

            return grid;
        }

        /**
         * Parse the OLE2 document and extract metadata.
         */
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
                status_message = _("Failed to read OLE2 file: %s").printf(e.message);
            }
        }

        /**
         * Helper method to get a property value as string.
         * @param meta The Gsf.DocMetaData object.
         * @param name The property name.
         * @return The property value as string, or "-" if not found.
         */
        private string get_prop(Gsf.DocMetaData meta, string name) {
            var val = meta.lookup(name);
            if (val == null) return "-";
            
            // FIX: Use 'get_val()' method instead of 'value' property
            // The Vala binding for gsf_doc_prop_get_val is `get_val()`
            GLib.Value? gval = val.get_val();
            
            if (gval == null) return "-";

            if (gval.holds(typeof(string))) return gval.get_string();
            if (gval.holds(typeof(uint))) return "%u".printf(gval.get_uint());
            if (gval.holds(typeof(int))) return "%d".printf(gval.get_int());
            if (gval.holds(typeof(long))) return "%ld".printf(gval.get_long());
            if (gval.holds(typeof(ulong))) return "%lu".printf(gval.get_ulong());
            
            return "-";
        }
        
        /**
         * Helper method to get a property value as a GLib.Value.
         * @param meta The Gsf.DocMetaData object.
         * @param name The property name.
         * @return The property value as GLib.Value, or null if not found.
         */
        private GLib.Value? get_prop_val(Gsf.DocMetaData meta, string name) {
            var val = meta.lookup(name);
            if (val == null) return null;
            // The Vala binding for gsf_doc_prop_get_val is `get_val()`
            return val.get_val();
        }

        /**
         * Helper method to format a GLib.Value containing a date into a string.
         * @param val The GLib.Value containing the date.
         * @return The formatted date string, or "-" if null or unparseable.
         */
        private string format_date(GLib.Value? val) {
            if (val == null) return "-";
            
            if (val.holds(typeof(string))) {
                string s = val.get_string();
                if (s.contains("T")) return s.replace("T", " ");
                return s;
            }
            return "-";
        }
    }

}