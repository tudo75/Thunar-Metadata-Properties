using Gtk;

/**
 * Thunar-Metadata-Properties package.
 * Thunar plugin to add more detailed properties pages for a wide range of file types.
 */
namespace TMP {

    // Debug helper: read environment variable directly in function
    /**
    * Print debug messages if THUNAR_METADATA_DEBUG is set to "1" or "true".
    * @param format The format string.
    * @param ... Arguments for the format string.
    */
    private static void debug_print(string format, ...) {
        string? debug_env = GLib.Environment.get_variable("THUNAR_METADATA_DEBUG");
        bool debug_enabled = (debug_env != null && (debug_env == "1" || debug_env.down() == "true"));
        
        if (debug_enabled) {
            var args = va_list();
            debug_print(format.vprintf(args));
        }
    }

    /**
    * Interface for file handlers that provide property pages for different file types.
    */
    public interface FileHandler : GLib.Object {    
        // Return the widget with form fields (Entries, Switches)
        /**
        * Get the properties panel widget for the file type.
        * @return A Gtk.Widget containing the properties panel.
        */
        public abstract Widget get_properties_panel();

        /**
        * Get the title for the property page.
        * @return A string representing the page title.
        */
        public abstract string get_page_title();
        
        // Static Factory
        /**
        * Factory method to create appropriate FileHandler based on file type.
        * @param file The GLib.File to create a handler for.
        * @return An instance of FileHandler if a suitable handler is found, null otherwise.
        */
        public static FileHandler? create(File file) {
            try {
                // Query Content Type AND Display Name (for extension checking)
                FileInfo info = file.query_info(FileAttribute.STANDARD_CONTENT_TYPE + "," + FileAttribute.STANDARD_DISPLAY_NAME, 0);
                string content_type = info.get_content_type();
                string name = info.get_display_name().down();

                debug_print(_("Factory: Opening '%s' (MIME: %s)\n"), name, content_type);
                
                if (content_type == "application/pdf") {
                    return new PdfHandler(file);
                } else if (content_type.has_prefix("image/")) {
                    return new ImageHandler(file);
                }else if (content_type.has_prefix("video/") || content_type.has_prefix("audio/")) {
                    return new MediaHandler(file);
                }
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
            } catch (GLib.Error e) {
                debug_print(_("Error detecting type: %s\n"), e.message);
            }

            return null; // Fallback
        }
    }

}