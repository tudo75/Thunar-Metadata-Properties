/* thunarx.vapi corrected for Vala usage */

[CCode (cprefix = "Thunarx", gir_namespace = "Thunarx", gir_version = "3.0", lower_case_cprefix = "thunarx_")]
namespace Thunarx {
    [CCode (cheader_filename = "thunarx/thunarx.h", copy_function = "g_boxed_copy", free_function = "g_boxed_free", type_id = "thunarx_file_info_list_get_type ()")]
    [Compact]
    public class FileInfoList {
        public static GLib.List<Thunarx.FileInfo> copy (GLib.List<Thunarx.FileInfo> file_infos);
        public static void free (GLib.List<Thunarx.FileInfo> file_infos);
    }

    [CCode (cheader_filename = "thunarx/thunarx.h", type_id = "thunarx_menu_get_type ()")]
    public class Menu : GLib.Object {
        [CCode (has_construct_function = false)]
        public Menu ();
        public void append_item (Thunarx.MenuItem item);
        public GLib.List<Thunarx.MenuItem> get_items ();
        public void prepend_item (Thunarx.MenuItem item);
    }

    [CCode (cheader_filename = "thunarx/thunarx.h", type_id = "thunarx_menu_item_get_type ()")]
    public class MenuItem : GLib.Object {
        [CCode (has_construct_function = false)]
        public MenuItem (string name, string label, string tooltip, string? icon);
        public bool get_sensitive ();
        public static void list_free (GLib.List<Thunarx.MenuItem> items);
        public void set_menu (Thunarx.Menu menu);
        public void set_sensitive (bool sensitive);
        [NoAccessorMethod]
        public string icon { owned get; set; }
        [NoAccessorMethod]
        public string label { owned get; set; }
        [NoAccessorMethod]
        public Thunarx.Menu menu { owned get; set; }
        [NoAccessorMethod]
        public string name { owned get; construct; }
        [NoAccessorMethod]
        public bool priority { get; set; }
        public bool sensitive { get; set; }
        [NoAccessorMethod]
        public string tooltip { owned get; set; }
        [HasEmitter]
        public virtual signal void activate ();
    }

    [CCode (cheader_filename = "thunarx/thunarx.h", type_id = "thunarx_property_page_get_type ()")]
    public class PropertyPage : Gtk.Bin, Atk.Implementor, Gtk.Buildable {
        [CCode (has_construct_function = false, type = "GtkWidget*")]
        public PropertyPage (string label);
        public unowned string get_label ();
        public unowned Gtk.Widget get_label_widget ();
        public void set_label (string label);
        public void set_label_widget (Gtk.Widget label_widget);
        [CCode (has_construct_function = false, type = "GtkWidget*")]
        public PropertyPage.with_label_widget (Gtk.Widget label_widget);
        public string label { get; set; }
        public Gtk.Widget label_widget { get; set; }
    }

    [CCode (cheader_filename = "thunarx/thunarx.h", type_id = "thunarx_provider_factory_get_type ()")]
    public class ProviderFactory : GLib.Object {
        [CCode (has_construct_function = false)]
        protected ProviderFactory ();
        public static Thunarx.ProviderFactory get_default ();
        public GLib.List<GLib.Object> list_providers (GLib.Type type);
    }

    [CCode (cheader_filename = "thunarx/thunarx.h", type_id = "thunarx_provider_module_get_type ()")]
    public class ProviderModule : GLib.TypeModule, GLib.TypePlugin, Thunarx.ProviderPlugin {
        [CCode (has_construct_function = false)]
        public ProviderModule (string filename);
        public void list_types (GLib.Type types, int n_types);
    }

    [CCode (cheader_filename = "thunarx/thunarx.h", type_id = "thunarx_renamer_get_type ()")]
    public abstract class Renamer : Gtk.Box, Atk.Implementor, Gtk.Buildable, Gtk.Orientable {
        [CCode (has_construct_function = false)]
        protected Renamer ();
        public unowned string get_help_url ();
        public virtual GLib.List<Thunarx.MenuItem> get_menu_items (Gtk.Window window, GLib.List<Thunarx.FileInfo> files);
        public virtual void load (GLib.HashTable<void*,void*> settings);
        public virtual string process (Thunarx.FileInfo file, string text, uint index);
        public virtual void save (GLib.HashTable<void*,void*> settings);
        public void set_help_url (string help_url);
        public string help_url { get; set; }
        public string name { get; construct; }
        [HasEmitter]
        public virtual signal void changed ();
    }

    [CCode (cheader_filename = "thunarx/thunarx.h", type_id = "thunarx_file_info_get_type ()")]
    public interface FileInfo : GLib.Object {
        public abstract GLib.FileInfo get_file_info ();
        public abstract GLib.FileInfo get_filesystem_info ();
        public abstract GLib.File get_location ();
        public abstract string get_mime_type ();
        public abstract string get_name ();
        public abstract string get_parent_uri ();
        public abstract string get_uri ();
        public abstract string get_uri_scheme ();
        public abstract bool has_mime_type (string mime_type);
        public abstract bool is_directory ();
        [HasEmitter]
        public virtual signal void changed ();
        [HasEmitter]
        public virtual signal void renamed ();
    }

    /* 
       FIXED: Added missing virtual methods to MenuProvider 
       Essential for Context Menus
    */
    /* FIXED: Changed Gtk.Window to Gtk.Widget to match C header signature */
    [CCode (cheader_filename = "thunarx/thunarx.h", type_id = "thunarx_menu_provider_get_type ()")]
    public interface MenuProvider : GLib.Object {
        public abstract GLib.List<Thunarx.MenuItem> get_file_menu_items (Gtk.Widget window, GLib.List<Thunarx.FileInfo> files);
        public abstract GLib.List<Thunarx.MenuItem> get_folder_menu_items (Gtk.Widget window, Thunarx.FileInfo folder);
        public abstract GLib.List<Thunarx.MenuItem> get_dnd_menu_items (Gtk.Widget window, Thunarx.FileInfo folder, GLib.List<Thunarx.FileInfo> files);
    }

    /* 
       FIXED: Added missing virtual method to PreferencesProvider 
       Essential for Thunar settings integration
    */
    [CCode (cheader_filename = "thunarx/thunarx.h", type_id = "thunarx_preferences_provider_get_type ()")]
    public interface PreferencesProvider : GLib.Object {
        public abstract GLib.List<Thunarx.MenuItem> get_menu_items (Gtk.Window window);
    }

    /* 
       FIXED: Added missing virtual method to PropertyPageProvider 
       Essential for adding tabs to file properties
    */
    [CCode (cheader_filename = "thunarx/thunarx.h", type_id = "thunarx_property_page_provider_get_type ()")]
    public interface PropertyPageProvider : GLib.Object {
        public abstract GLib.List<Thunarx.PropertyPage> get_pages (GLib.List<Thunarx.FileInfo> files);
    }

    [CCode (cheader_filename = "thunarx/thunarx.h", type_id = "thunarx_provider_plugin_get_type ()")]
    public interface ProviderPlugin : GLib.Object {
        public abstract void add_interface (GLib.Type instance_type, GLib.Type interface_type, GLib.InterfaceInfo interface_info);
        public abstract bool get_resident ();
        public abstract GLib.Type register_enum (string name, GLib.EnumValue const_static_values);
        public abstract GLib.Type register_flags (string name, GLib.FlagsValue const_static_values);
        public abstract GLib.Type register_type (GLib.Type type_parent, string type_name, GLib.TypeInfo type_info, GLib.TypeFlags type_flags);
        public abstract void set_resident (bool resident);
        public abstract bool resident { get; set; }
    }

    /* 
       FIXED: Added missing virtual method to RenamerProvider 
       Essential for Bulk Rename extensions
    */
    [CCode (cheader_filename = "thunarx/thunarx.h", type_id = "thunarx_renamer_provider_get_type ()")]
    public interface RenamerProvider : GLib.Object {
        public abstract GLib.List<Thunarx.Renamer> get_renamers ();
    }

    [CCode (cheader_filename = "thunarx/thunarx.h", cname = "THUNARX_FILESYSTEM_INFO_NAMESPACE")]
    public const string FILESYSTEM_INFO_NAMESPACE;
    [CCode (cheader_filename = "thunarx/thunarx.h", cname = "THUNARX_FILE_INFO_NAMESPACE")]
    public const string FILE_INFO_NAMESPACE;
    [CCode (cheader_filename = "thunarx/thunarx.h", cname = "THUNARX_MAJOR_VERSION")]
    public const int MAJOR_VERSION;
    [CCode (cheader_filename = "thunarx/thunarx.h", cname = "THUNARX_MICRO_VERSION")]
    public const int MICRO_VERSION;
    [CCode (cheader_filename = "thunarx/thunarx.h", cname = "THUNARX_MINOR_VERSION")]
    public const int MINOR_VERSION;
    [CCode (cheader_filename = "thunarx/thunarx.h")]
    public static unowned string check_version (uint required_major, uint required_minor, uint required_micro);
    [CCode (cheader_filename = "thunarx/thunarx.h")]
    [Version (replacement = "FileInfoList.copy")]
    public static GLib.List<Thunarx.FileInfo> file_info_list_copy (GLib.List<Thunarx.FileInfo> file_infos);
    [CCode (cheader_filename = "thunarx/thunarx.h")]
    [Version (replacement = "FileInfoList.free")]
    public static void file_info_list_free (GLib.List<Thunarx.FileInfo> file_infos);
}
