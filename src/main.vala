using Thunarx;
using Gtk;
using GLib;

/**
 * Thunar-Metadata-Properties package.
 * Thunar plugin to add more detailed properties pages for a wide range of file types.
 */
namespace TMP {

    public class ThunarMetadataProperties : GLib.Object, Thunarx.PropertyPageProvider{

        /**
        * Add property page to the file property widget.
        * 
        * @param files The selected files and/or folders on which you right click.
        * @return A list of property pages.
        *
        * @since 0.0.1
        */
        public GLib.List<Thunarx.PropertyPage> get_pages (GLib.List<Thunarx.FileInfo> files) {
            var pages = new GLib.List<Thunarx.PropertyPage> (); 

            if (files != null && files.length () > 0) {
                var page = new Thunarx.PropertyPage ("");
                page.set_border_width (12);
                var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
                var vscroll = new Gtk.ScrolledWindow (null, null);
                
                var fileinfo = files.nth_data (0);
                var file = fileinfo.get_location ();
                var current_handler = FileHandler.create(file);
                if (current_handler != null) {
                    page.set_label (current_handler.get_page_title());
                    Gtk.Widget grid = current_handler.get_properties_panel();
                    vbox.add (grid);
                    
                    vscroll.add (vbox);
                    page.add (vscroll);
                    page.show_all ();
                    pages.append (page);
                }
            }

            return pages;
        }
    }

    /* --- REGISTRATION BOILERPLATE --- */

    [CCode (cname = "thunar_extension_initialize")]
    public void extension_initialize (Thunarx.ProviderPlugin plugin) {
        // Force the extension to stay in memory.
        // Thunar often unloads extensions if they don't explicitly say "I am resident".
        plugin.set_resident (true);
    }

    [CCode (cname = "thunar_extension_shutdown")]
    public void extension_shutdown () {
    }

    [CCode (cname = "thunar_extension_list_types")]
    public void extension_list_types (out Type[] types) {
        types = new Type[] { typeof (ThunarMetadataProperties) };
    }

}
