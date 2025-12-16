using Gtk;

public interface FileHandler : GLib.Object {    
    // Return the widget with form fields (Entries, Switches)
    public abstract Widget get_properties_panel();

    public abstract string get_page_title();
    
    // Static Factory
    public static FileHandler? create(File file) {
        try {
            // Query Content Type AND Display Name (for extension checking)
            FileInfo info = file.query_info(FileAttribute.STANDARD_CONTENT_TYPE + "," + FileAttribute.STANDARD_DISPLAY_NAME, 0);
            string content_type = info.get_content_type();
            string name = info.get_display_name().down();

            print(_("Factory: Opening '%s' (MIME: %s)\n"), name, content_type);
            
            if (content_type == "application/pdf") {
                return new PdfHandler(file);
            } else if (content_type.has_prefix("image/")) {
                return new ImageHandler(file);
            }else if (content_type.has_prefix("video/") || content_type.has_prefix("audio/")) {
                return new MediaHandler(file);
            }
            /*
             else if (
                // Extension Checks
                name.has_suffix(".docx") ||
                name.has_suffix(".xlsx") ||
                name.has_suffix(".pptx") ||
                name.has_suffix(".odt") || 
                name.has_suffix(".ods") ||
                name.has_suffix(".odp")
            ) {
                return new OfficeHandler(file);
            } else if (
                content_type == "application/msword" || 
                content_type == "application/vnd.ms-excel" ||
                content_type == "application/vnd.ms-powerpoint" ||
                name.has_suffix(".doc") || 
                name.has_suffix(".xls") || 
                name.has_suffix(".ppt")
            ) {
                return new LegacyOfficeHandler(file);
            }
            */
        } catch (GLib.Error e) {
            print(_("Error detecting type: %s\n"), e.message);
        }

        return null; // Fallback
    }
}