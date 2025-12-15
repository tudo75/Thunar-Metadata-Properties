using Gtk;
using GExiv2;

public class ImageHandler : GLib.Object, FileHandler {
    private File file;
    private GExiv2.Metadata? metadata;
    private Grid grid;

    public ImageHandler(File f) {
        this.file = f;
        try {
            this.metadata = new GExiv2.Metadata();
            this.metadata.open_path(file.get_path());
        } catch (Error e) {
            // Silence error for non-image files (like XCF or text files renamed as jpg)
            this.metadata = null;
        }
    }

    public Widget get_main_view() {
        string path = file.get_path();
        string lower_path = path.down();

        // GTK4 cannot render XCF natively
        if (lower_path.has_suffix(".xcf")) {
            return create_placeholder_view("image-x-generic", "GIMP XCF Image\n(Preview Unavailable)");
        }

        var picture = new Picture.for_filename(path);
        picture.can_shrink = true;
        picture.content_fit = ContentFit.CONTAIN;
        return create_box_wrapper(picture);
    }

    private Widget create_box_wrapper(Widget content) {
        var box = new Box(Gtk.Orientation.VERTICAL, 6);
        box.valign = Align.CENTER;
        box.halign = Align.CENTER;
        
        content.vexpand = true;
        content.hexpand = true;
        box.append(content);

        var name_lbl = new Label(file.get_basename());
        name_lbl.add_css_class("title-2");
        name_lbl.wrap = true;
        name_lbl.max_width_chars = 30;
        name_lbl.justify = Justification.CENTER;
        box.append(name_lbl);
        return box;
    }

    private Widget create_placeholder_view(string icon_name, string text) {
        var icon = new Gtk.Image.from_icon_name(icon_name);
        icon.pixel_size = 128;
        icon.add_css_class("dim-label");
        
        var box = new Box(Gtk.Orientation.VERTICAL, 6);
        box.valign = Align.CENTER;
        box.halign = Align.CENTER;
        box.append(icon);
        
        var lbl = new Label(text);
        lbl.justify = Justification.CENTER;
        box.append(lbl);
        
        var name_lbl = new Label(file.get_basename());
        name_lbl.add_css_class("title-2");
        name_lbl.margin_top = 10;
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

        UiHelper.add_section_header(grid, ref row, "Image Metadata");

        if (metadata != null) {
            build_basic_info(ref row);
            build_camera_data(ref row);
            build_advanced_photo_data(ref row); // New Section
            build_gps_data(ref row);
            build_iptc_data(ref row);
        } else {
            string msg = file.get_basename().down().has_suffix(".xcf") 
                ? "GIMP XCF metadata not supported." 
                : "No metadata found or format unsupported.";
            UiHelper.create_label_row(grid, ref row, "Status:", msg);
        }

        box.append(grid);
        var spacer = new Label(""); spacer.vexpand = true; box.append(spacer);
        scroll.child = box;
        return scroll;
    }

    private void build_basic_info(ref int row) {
        int w = metadata.get_pixel_width();
        int h = metadata.get_pixel_height();
        string dim_str = (w > 0 && h > 0) ? "%d x %d pixels".printf(w, h) : "Unknown";
        
        string mime = metadata.get_mime_type();
        
        string date = get_tag_label("Exif.Image.DateTime");
        if (date == "-") date = get_tag_label("Exif.Photo.DateTimeOriginal");

        string color_space = get_tag_label("Exif.Photo.ColorSpace");
        if (color_space == "1") color_space = "sRGB";
        else if (color_space == "65535") color_space = "Uncalibrated";

        UiHelper.create_label_row(grid, ref row, "Dimensions:", dim_str);
        UiHelper.create_label_row(grid, ref row, "Format:", mime);
        UiHelper.create_label_row(grid, ref row, "Date Taken:", date);
        UiHelper.create_label_row(grid, ref row, "Color Space:", color_space);
        UiHelper.create_label_row(grid, ref row, "Orientation:", get_orientation_string());
    }

    private void build_camera_data(ref int row) {
        string make = get_tag_label("Exif.Image.Make");
        string model = get_tag_label("Exif.Image.Model");
        
        if (make == "-" && model == "-") return;

        UiHelper.add_separator(grid, ref row);
        UiHelper.add_section_header(grid, ref row, "Camera Data");

        UiHelper.create_label_row(grid, ref row, "Camera Make:", make);
        UiHelper.create_label_row(grid, ref row, "Camera Model:", model);
        
        string lens = get_tag_label("Exif.Photo.LensModel");
        if (lens == "-") lens = get_tag_label("Exif.CanonCs.LensType");
        if (lens != "-") UiHelper.create_label_row(grid, ref row, "Lens:", lens);
    }

    // New detailed photo data matching Thunar-APR level of detail
    private void build_advanced_photo_data(ref int row) {
        string iso = get_tag_label("Exif.Photo.ISOSpeedRatings");
        string aperture = get_tag_label("Exif.Photo.FNumber");
        string exposure = get_tag_label("Exif.Photo.ExposureTime");
        string focal = get_tag_label("Exif.Photo.FocalLength");
        string focal35 = get_tag_label("Exif.Photo.FocalLengthIn35mmFilm");
        string flash = get_flash_string();
        string wb = get_white_balance_string();
        string metering = get_metering_mode_string();
        string program = get_exposure_program_string();

        if (iso == "-" && aperture == "-" && exposure == "-") return;

        UiHelper.add_separator(grid, ref row);
        UiHelper.add_section_header(grid, ref row, "Exposure Settings");

        if (aperture != "-") UiHelper.create_label_row(grid, ref row, "Aperture:", format_aperture(aperture));
        if (exposure != "-") UiHelper.create_label_row(grid, ref row, "Exposure:", format_exposure_time(exposure));
        if (iso != "-")      UiHelper.create_label_row(grid, ref row, "ISO Speed:", iso);
        if (program != "-")  UiHelper.create_label_row(grid, ref row, "Exposure Program:", program);
        if (metering != "-") UiHelper.create_label_row(grid, ref row, "Metering Mode:", metering);
        
        // Focal Length logic
        if (focal != "-") {
            string val = focal + " mm";
            if (focal35 != "-" && focal35 != "0") {
                val += " (35mm equiv: %s mm)".printf(focal35);
            }
            UiHelper.create_label_row(grid, ref row, "Focal Length:", val);
        }

        if (flash != "-")    UiHelper.create_label_row(grid, ref row, "Flash:", flash);
        if (wb != "-")       UiHelper.create_label_row(grid, ref row, "White Balance:", wb);
    }

    private void build_gps_data(ref int row) {
        double lat = 0.0, lon = 0.0, alt = 0.0;
        bool has_gps = false;
        
        try {
            if (metadata.try_get_gps_longitude(out lon) && metadata.try_get_gps_latitude(out lat)) {
                has_gps = true;
            }
            metadata.try_get_gps_altitude(out alt);
        } catch (Error e) {}

        if (has_gps) {
            UiHelper.add_separator(grid, ref row);
            UiHelper.add_section_header(grid, ref row, "GPS Location");
            
            UiHelper.create_label_row(grid, ref row, "Latitude:", "%.6f".printf(lat));
            UiHelper.create_label_row(grid, ref row, "Longitude:", "%.6f".printf(lon));
            if (alt != 0) UiHelper.create_label_row(grid, ref row, "Altitude:", "%.1f meters".printf(alt));
        }
    }

    private void build_iptc_data(ref int row) {
        string artist = get_tag_label("Exif.Image.Artist");
        if (artist == "-") artist = get_tag_label("Iptc.Application2.Byline");
        
        string copyright = get_tag_label("Exif.Image.Copyright");
        if (copyright == "-") copyright = get_tag_label("Iptc.Application2.Copyright");
        
        string desc = get_tag_label("Exif.Image.ImageDescription");
        if (desc == "-") desc = get_tag_label("Iptc.Application2.Caption");
        
        string software = get_tag_label("Exif.Image.Software");

        if (artist == "-" && copyright == "-" && desc == "-" && software == "-") return;

        UiHelper.add_separator(grid, ref row);
        UiHelper.add_section_header(grid, ref row, "Authoring &amp; Description");

        if (artist != "-")    UiHelper.create_label_row(grid, ref row, "Artist/Creator:", artist);
        if (copyright != "-") UiHelper.create_label_row(grid, ref row, "Copyright:", copyright);
        if (desc != "-")      UiHelper.create_label_row(grid, ref row, "Description:", desc);
        if (software != "-")  UiHelper.create_label_row(grid, ref row, "Software:", software);
    }

    // --- Helpers ---

    private string get_tag_label(string tag) {
        try {
            string? val = metadata.try_get_tag_string(tag);
            return (val != null && val.strip() != "") ? val : "-";
        } catch (Error e) { return "-"; }
    }

    private string format_aperture(string raw) {
        if (raw.contains("/")) {
            string[] parts = raw.split("/");
            if (parts.length == 2) {
                double num = double.parse(parts[0]);
                double den = double.parse(parts[1]);
                if (den != 0) return "f/%.1f".printf(num / den);
            }
        }
        return "f/" + raw;
    }

    // Logic similar to Thunar-APR to show 1/60 instead of 0.0166
    private string format_exposure_time(string raw) {
        // Raw usually comes as "1/60" or "10/600" or "0.0166"
        if (raw.contains("/")) return raw + " sec"; // Already formatted fraction
        
        double val = double.parse(raw);
        if (val == 0) return raw;

        if (val < 1.0) {
            // Convert decimal to 1/x
            int denom = (int)(1.0 / val + 0.5); // Round to nearest int
            return "1/%d sec".printf(denom);
        }
        return raw + " sec";
    }

    private string get_flash_string() {
        try {
            long val = metadata.try_get_tag_long("Exif.Photo.Flash");
            bool fired = (val & 0x1) != 0;
            if (!fired) return "Did not fire";
            
            var sb = new StringBuilder("Fired");
            if ((val & 0x6) == 0x4) sb.append(", return detected");
            else if ((val & 0x6) == 0x2) sb.append(", return not detected");
            if ((val & 0x18) == 0x18) sb.append(", auto");
            else if ((val & 0x18) == 0x10) sb.append(", manual");
            if ((val & 0x40) != 0) sb.append(", red-eye reduction");
            return sb.str;
        } catch (Error e) { return "-"; }
    }

    private string get_white_balance_string() {
        string val = get_tag_label("Exif.Photo.WhiteBalance");
        if (val == "0") return "Auto";
        if (val == "1") return "Manual";
        return val;
    }

    private string get_orientation_string() {
        string val = get_tag_label("Exif.Image.Orientation");
        switch (val) {
            case "1": return "Top-left (Normal)";
            case "2": return "Top-right (Mirrored)";
            case "3": return "Bottom-right (180°)";
            case "4": return "Bottom-left (V-Flip)";
            case "5": return "Left-top (Transpose)";
            case "6": return "Right-top (90° CW)";
            case "7": return "Right-bottom (Transverse)";
            case "8": return "Left-bottom (90° CCW)";
            default: return val == "-" ? "Normal" : val;
        }
    }

    private string get_exposure_program_string() {
        try {
            long val = metadata.try_get_tag_long("Exif.Photo.ExposureProgram");
            switch (val) {
                case 0: return "Not defined";
                case 1: return "Manual";
                case 2: return "Normal program";
                case 3: return "Aperture priority";
                case 4: return "Shutter priority";
                case 5: return "Creative program";
                case 6: return "Action program";
                case 7: return "Portrait mode";
                case 8: return "Landscape mode";
                default: return "Unknown (%ld)".printf(val);
            }
        } catch (Error e) { return "-"; }
    }

    private string get_metering_mode_string() {
        try {
            long val = metadata.try_get_tag_long("Exif.Photo.MeteringMode");
            switch (val) {
                case 0: return "Unknown";
                case 1: return "Average";
                case 2: return "CenterWeightedAverage";
                case 3: return "Spot";
                case 4: return "MultiSpot";
                case 5: return "Pattern";
                case 6: return "Partial";
                case 255: return "Other";
                default: return "Unknown (%ld)".printf(val);
            }
        } catch (Error e) { return "-"; }
    }

    public void save_metadata() {
        var dialog = new AlertDialog("Image Metadata is Read-Only.");
        dialog.show(null);
    }
}