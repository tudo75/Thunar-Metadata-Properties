using Gtk;
using Archive;
using Xml;
using TMP.Utils;

/**
 * Thunar-Metadata-Properties package.
 * Thunar plugin to add more detailed properties pages for a wide range of file types.
 */
namespace TMP {

    public class OfficeHandler : GLib.Object, FileHandler {
        private File file;
        private Grid grid;
        
        // Metadata Storage
        private string m_title = "-";
        private string m_subject = "-";
        private string m_creator = "-";
        private string m_keywords = "-";
        private string m_description = "-";
        private string m_last_modified_by = "-";
        private string m_revision = "-";
        private string m_created = "-";
        private string m_modified = "-";
        
        // Stats
        private string m_pages = "-";
        private string m_words = "-";
        private string m_application = "-";
        private string m_doc_type = "Unknown";

        // Custom Props
        private GLib.List<string> custom_keys;
        private GLib.List<string> custom_values;

        // Status
        private bool is_supported = true;
        private string status_message = "";

        public OfficeHandler(File f) {
            this.file = f;
            
            // DEBUG: Force print to verify constructor started
            debug_print(_("OfficeHandler: Init started for %s\n"), f.get_uri());
            stdout.flush();

            this.custom_keys = new GLib.List<string>();
            this.custom_values = new GLib.List<string>();
            
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

            UiHelper.add_section_header(grid, ref row, _("Office Metadata"));

            if (!is_supported) {
                UiHelper.create_label_row(grid, ref row, _("Status:"), status_message);
            } else {
                UiHelper.create_label_row(grid, ref row, _("Title:"), m_title);
                UiHelper.create_label_row(grid, ref row, _("Subject:"), m_subject);
                UiHelper.create_label_row(grid, ref row, _("Keywords:"), m_keywords);
                UiHelper.create_label_row(grid, ref row, _("Description:"), m_description);

                UiHelper.add_separator(grid, ref row);
                UiHelper.add_section_header(grid, ref row, _("Authoring"));

                UiHelper.create_label_row(grid, ref row, _("Creator:"), m_creator);
                UiHelper.create_label_row(grid, ref row, _("Last Modified By:"), m_last_modified_by);
                UiHelper.create_label_row(grid, ref row, _("Created:"), m_created);
                UiHelper.create_label_row(grid, ref row, _("Modified:"), m_modified);
                UiHelper.create_label_row(grid, ref row, _("Revision:"), m_revision);

                UiHelper.add_separator(grid, ref row);
                UiHelper.add_section_header(grid, ref row, _("Statistics"));

                UiHelper.create_label_row(grid, ref row, _("Document Type:"), m_doc_type);
                UiHelper.create_label_row(grid, ref row, _("Application:"), m_application);
                if (m_pages != "-") UiHelper.create_label_row(grid, ref row, _("Page Count:"), m_pages);
                if (m_words != "-") UiHelper.create_label_row(grid, ref row, _("Word Count:"), m_words);

                if (custom_keys.length() > 0) {
                    UiHelper.add_separator(grid, ref row);
                    UiHelper.add_section_header(grid, ref row, _("Custom Properties"));
                    for (uint i = 0; i < custom_keys.length(); i++) {
                        string key = custom_keys.nth_data(i);
                        string val = custom_values.nth_data(i);
                        UiHelper.create_label_row(grid, ref row, key + ":", val);
                    }
                }
            }

            return grid;
        }

        // --- Parsing Logic ---
        /**
         * Parse the Office document and extract metadata.
         */
        private void parse_document() {
            string fname = file.get_basename().down();

            // --- DEFENSIVE ZIP CHECK ---
            // Your file is likely a text/csv file named .xlsx
            // This check must pass or we set error and return.
            if (!is_valid_zip_header()) {
                debug_print(_("OfficeHandler: Invalid ZIP header detected.\n")); 
                is_supported = false;
                status_message = _("File is not a valid ZIP archive.\n(Likely a plain text/CSV file)");
                return;
            }

            var archive = new Archive.Read();
            archive.support_filter_all();
            archive.support_format_all(); 
            
            string? path = file.get_path();
            if (path == null) {
                is_supported = false;
                status_message = _("File path is invalid.");
                return;
            }

            int r = archive.open_filename(path, 10240);
            if (r != Archive.Result.OK) {
                debug_print(_("OfficeHandler: libarchive failed to open. Error: %d\n"), r);
                is_supported = false;
                status_message = _("Archive Error: %s").printf(archive.error_string());
                return;
            }

            if (fname.has_suffix("odt") || fname.has_suffix("ods") || fname.has_suffix("odp")) {
                m_doc_type = "OpenDocument";
                parse_opendocument(archive);
            } else {
                m_doc_type = "Office Open XML";
                parse_ooxml(archive);
            }
            
            archive.close();
        }

        /**
         * Checks if the file has a valid ZIP header (PK signature).
         * This is a defensive check to prevent libarchive from trying to parse
         * non-ZIP files that might have an Office extension (e.g., a .xlsx CSV file).
         * @return True if the file has a valid ZIP header, false otherwise.
         */
        private bool is_valid_zip_header() {
            try {
                var dis = new DataInputStream(file.read());
                uint8[] header = new uint8[2];
                size_t bytes_read;
                dis.read_all(header, out bytes_read);
                // PK signature check (0x50 0x4B)
                return (bytes_read == 2 && header[0] == 0x50 && header[1] == 0x4B);
            } catch (GLib.Error e) { 
                debug_print(_("OfficeHandler: Zip Check Failed: %s\n"), e.message);
                return false; 
            }
        }

        /**
         * Parse OOXML (Office Open XML) format to extract metadata.
         * @param archive The Archive.Read object representing the opened ZIP archive.
         */
        private void parse_ooxml(Archive.Read archive) {
            unowned Archive.Entry entry;
            debug_print("OfficeHandler: Scanning OOXML entries...\n");
            stdout.flush();
            
            while (archive.next_header(out entry) == Archive.Result.OK) {
                string name = entry.pathname();
                
                // Use 'contains' for robustness against absolute paths or backslashes
                if (name.contains("docProps/core.xml")) {
                    debug_print("Found Core: %s\n", name);
                    parse_ooxml_core(read_entry_to_string(archive, entry));
                }
                else if (name.contains("docProps/app.xml")) {
                    debug_print("Found App: %s\n", name);
                    parse_ooxml_app(read_entry_to_string(archive, entry));
                }
                else if (name.contains("docProps/custom.xml")) {
                    debug_print("Found Custom: %s\n", name);
                    parse_ooxml_custom(read_entry_to_string(archive, entry));
                }
            }
        }

        /**
         * Parses the core.xml file from an OOXML archive to extract common document properties.
         * @param xml_content The XML content of the core.xml file as a string.
         */
        private void parse_ooxml_core(string xml_content) {
            var doc = Parser.parse_memory(xml_content, xml_content.length);
            if (doc == null) return;
            
            var ctx = new XPath.Context(doc);
            ctx.register_ns("cp", "http://schemas.openxmlformats.org/package/2006/metadata/core-properties");
            ctx.register_ns("dc", "http://purl.org/dc/elements/1.1/");
            ctx.register_ns("dcterms", "http://purl.org/dc/terms/");

            m_title = get_xpath_val(ctx, "//dc:title");
            m_subject = get_xpath_val(ctx, "//dc:subject");
            m_creator = get_xpath_val(ctx, "//dc:creator");
            m_description = get_xpath_val(ctx, "//dc:description");
            m_keywords = get_xpath_val(ctx, "//cp:keywords");
            m_last_modified_by = get_xpath_val(ctx, "//cp:lastModifiedBy");
            m_revision = get_xpath_val(ctx, "//cp:revision");
            m_created = format_iso_date(get_xpath_val(ctx, "//dcterms:created"));
            m_modified = format_iso_date(get_xpath_val(ctx, "//dcterms:modified"));
        }

        /**
         * Parses the app.xml file from an OOXML archive to extract extended document properties
         * like application name, page count, and word count.
         * @param xml_content The XML content of the app.xml file as a string.
         */
        private void parse_ooxml_app(string xml_content) {
            var doc = Parser.parse_memory(xml_content, xml_content.length);
            if (doc == null) return;
            
            var ctx = new XPath.Context(doc);
            ctx.register_ns("ep", "http://schemas.openxmlformats.org/officeDocument/2006/extended-properties");

            m_application = get_xpath_val(ctx, "//ep:Application");
            m_pages = get_xpath_val(ctx, "//ep:Pages");
            if (m_pages == "-") m_pages = get_xpath_val(ctx, "//ep:Slides");
            m_words = get_xpath_val(ctx, "//ep:Words");
        }
        
        /**
         * Parses the custom.xml file from an OOXML archive to extract custom document properties.
         * @param xml_content The XML content of the custom.xml file as a string.
         */

        private void parse_ooxml_custom(string xml_content) {
            var doc = Parser.parse_memory(xml_content, xml_content.length);
            if (doc == null) return;
            
            var ctx = new XPath.Context(doc);
            ctx.register_ns("op", "http://schemas.openxmlformats.org/officeDocument/2006/custom-properties");
            ctx.register_ns("vt", "http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes");

            var result = ctx.eval_expression("//op:property");
            if (result != null && result->nodesetval != null) {
                int len = result->nodesetval->length();
                for (int i = 0; i < len; i++) {
                    var node = result->nodesetval->item(i);
                    string? key = node->get_prop("name");
                    if (key == null) continue;

                    string? val = null;
                    if (node->children != null) val = node->children->get_content();
                    
                    if (val != null) {
                        custom_keys.append(key);
                        custom_values.append(val);
                    }
                }
            }
        }

        /**
         * Parses an OpenDocument Format (ODF) archive to extract metadata.
         * It specifically looks for the 'meta.xml' file within the archive.
         * @param archive The Archive.Read object representing the opened ODF archive.
         */
        private void parse_opendocument(Archive.Read archive) {
            unowned Archive.Entry entry;
            while (archive.next_header(out entry) == Archive.Result.OK) {
                if (entry.pathname() == "meta.xml") {
                    parse_odf_meta(read_entry_to_string(archive, entry));
                    break;
                }
            }
        }
        
        /**
         * Parses the meta.xml file from an OpenDocument archive to extract document properties.
         * @param xml_content The XML content of the meta.xml file as a string.
         */
        private void parse_odf_meta(string xml_content) {
            var doc = Parser.parse_memory(xml_content, xml_content.length);
            if (doc == null) return;
            
            var ctx = new XPath.Context(doc);
            ctx.register_ns("dc", "http://purl.org/dc/elements/1.1/");
            ctx.register_ns("meta", "urn:oasis:names:tc:opendocument:xmlns:meta:1.0");

            m_title = get_xpath_val(ctx, "//dc:title");
            m_subject = get_xpath_val(ctx, "//dc:subject");
            m_creator = get_xpath_val(ctx, "//dc:creator");
            m_description = get_xpath_val(ctx, "//dc:description");
            m_application = get_xpath_val(ctx, "//meta:generator");
            m_created = format_iso_date(get_xpath_val(ctx, "//meta:creation-date"));
            m_modified = format_iso_date(get_xpath_val(ctx, "//dc:date"));
            m_revision = get_xpath_val(ctx, "//meta:editing-cycles");
            
            var pages_obj = ctx.eval_expression("//meta:document-statistic/@meta:page-count");
            if (pages_obj != null && pages_obj->nodesetval != null && pages_obj->nodesetval->length() > 0) {
                m_pages = pages_obj->nodesetval->item(0)->children->content;
            }
            var words_obj = ctx.eval_expression("//meta:document-statistic/@meta:word-count");
            if (words_obj != null && words_obj->nodesetval != null && words_obj->nodesetval->length() > 0) {
                m_words = words_obj->nodesetval->item(0)->children->content;
            }
        }

        // --- Helpers ---
        /**
         * Reads the content of an Archive.Entry into a string.
         * @param archive The Archive.Read object.
         * @param entry The Archive.Entry to read.
         * @return The content of the entry as a string.
         */
        private string read_entry_to_string(Archive.Read archive, Archive.Entry entry) {
            int64 size = entry.size();
            if (size <= 0) return "";
            uint8[] buffer = new uint8[size + 1];
            archive.read_data(buffer);
            buffer[size] = 0;
            return (string)buffer;
        }

        /**
         * Helper method to get a property value as string using XPath.
         * @param ctx The XPath.Context object.
         * @param query The XPath query string.
         * @return The property value as string, or "-" if not found.
         */
        private string get_xpath_val(XPath.Context ctx, string query) {
            var obj = ctx.eval_expression(query);
            if (obj == null || obj->nodesetval == null || obj->nodesetval->length() == 0) {
                return "-";
            }
            string? val = obj->nodesetval->item(0)->get_content();
            return (val != null && val.strip() != "") ? val : "-";
        }

        /**
         * Formats an ISO 8601 date string into a more human-readable format.
         * @param iso The ISO 8601 date string.
         * @return The formatted date string, or "-" if the input is invalid.
         */
        private string format_iso_date(string iso) {
            if (iso == "-") return "-";
            var dt = new DateTime.from_iso8601(iso, new TimeZone.local());
            if (dt != null) return dt.format("%Y-%m-%d %H:%M");
            return iso;
        }
    }

}