using Gtk;
using GExiv2;
using TMP.Utils;

/**
 * Thunar-Metadata-Properties package.
 * Thunar plugin to add more detailed properties pages for a wide range of file types.
 */
namespace TMP {

    /**
    * Image File Handler implementing FileHandler interface.
    */
    public class ImageHandler : GLib.Object, FileHandler {
        private File file;
        private GExiv2.Metadata? metadata;
        private Grid grid;

        /**
        * Constructor: Load the image metadata.
        * @param f The GLib.File representing the image file.
        */
        public ImageHandler(File f) {
            this.file = f;
            
            // DEBUG: Force print to verify constructor started
            debug_print(_("ImageHandler: Init started for %s\n"), f.get_uri());
            stdout.flush();

            try {
                this.metadata = new GExiv2.Metadata();
                this.metadata.open_path(file.get_path());
            } catch (Error e) {
                // Silence error for non-image files (like XCF or text files renamed as jpg)
                this.metadata = null;
            }
        }

        /**
        * Get the title for the property page.
        * @return A string representing the page title.
        */
        public string get_page_title() {
            return _("Image Properties");
        }

        /**
        * Get the properties panel widget for the image file.
        * @return A Gtk.Widget containing the properties panel.
        */
        public Widget get_properties_panel() {
            this.grid = new Grid();
            grid.column_spacing = 12;
            grid.row_spacing = 6;
            
            int row = 0;

            UiHelper.add_section_header(grid, ref row, _("Image Metadata"));

            if (metadata != null) {
                build_basic_info(ref row);
                build_camera_data(ref row);
                build_advanced_photo_data(ref row); // New Section
                build_gps_data(ref row);
                build_iptc_data(ref row);
            } else {
                string msg = file.get_basename().down().has_suffix(".xcf") 
                    ? _("GIMP XCF metadata not supported.") 
                    : _("No metadata found or format unsupported.");
                UiHelper.create_label_row(grid, ref row, _("Status:"), msg);
            }

            return grid;
        }

        /**
        * Build the basic image information section.
        * @param row The current row index.
        */
        private void build_basic_info(ref int row) {
            int w = metadata.get_pixel_width();
            int h = metadata.get_pixel_height();
            string dim_str = (w > 0 && h > 0) ? _("%d x %d pixels").printf(w, h) : _("Unknown");
            
            string mime = metadata.get_mime_type();
            
            string date = get_tag_label("Exif.Image.DateTime");
            if (date == "-") date = get_tag_label("Exif.Photo.DateTimeOriginal");

            string color_space = get_tag_label("Exif.Photo.ColorSpace");
            if (color_space == "1") color_space = _("sRGB");
            else if (color_space == "65535") color_space = _("Uncalibrated");

            UiHelper.create_label_row(grid, ref row, _("Dimensions:"), dim_str);
            UiHelper.create_label_row(grid, ref row, _("Format:"), mime);
            UiHelper.create_label_row(grid, ref row, _("Date Taken:"), date);
            UiHelper.create_label_row(grid, ref row, _("Color Space:"), color_space);
            UiHelper.create_label_row(grid, ref row, _("Orientation:"), get_orientation_string());
        }

        /**
        * Build the camera data section.
        * @param row The current row index.
        */
        private void build_camera_data(ref int row) {
            string make = get_tag_label("Exif.Image.Make");
            string model = get_tag_label("Exif.Image.Model");
            
            if (make == "-" && model == "-") return;

            UiHelper.add_separator(grid, ref row);
            UiHelper.add_section_header(grid, ref row, _("Camera Data"));

            UiHelper.create_label_row(grid, ref row, _("Camera Make:"), make);
            UiHelper.create_label_row(grid, ref row, _("Camera Model:"), model);
            
            string lens = get_tag_label("Exif.Photo.LensModel");
            if (lens == "-") lens = get_tag_label("Exif.CanonCs.LensType");
            if (lens != "-") UiHelper.create_label_row(grid, ref row, _("Lens:"), lens);
        }

        /**
        * Build the advanced photo data section.
        * @param row The current row index.
        */
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
            UiHelper.add_section_header(grid, ref row, _("Exposure Settings"));

            if (aperture != "-") UiHelper.create_label_row(grid, ref row, _("Aperture:"), format_aperture(aperture));
            if (exposure != "-") UiHelper.create_label_row(grid, ref row, _("Exposure:"), format_exposure_time(exposure));
            if (iso != "-")      UiHelper.create_label_row(grid, ref row, _("ISO Speed:"), iso);
            if (program != "-")  UiHelper.create_label_row(grid, ref row, _("Exposure Program:"), program);
            if (metering != "-") UiHelper.create_label_row(grid, ref row, _("Metering Mode:"), metering);
            
            // Focal Length logic
            if (focal != "-") {
                string val = _("%s mm").printf(focal);
                if (focal35 != "-" && focal35 != "0") {
                    val += " " + _("(35mm equiv: %s mm)").printf(focal35);
                }
                UiHelper.create_label_row(grid, ref row, _("Focal Length:"), val);
            }

            if (flash != "-")    UiHelper.create_label_row(grid, ref row, _("Flash:"), flash);
            if (wb != "-")       UiHelper.create_label_row(grid, ref row, _("White Balance:"), wb);
        }

        /**
        * Build the GPS data section.
        * @param row The current row index.
        */
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
                UiHelper.add_section_header(grid, ref row, _("GPS Location"));
                
                UiHelper.create_label_row(grid, ref row, _("Latitude:"), "%.6f".printf(lat));
                UiHelper.create_label_row(grid, ref row, _("Longitude:"), "%.6f".printf(lon));
                if (alt != 0) UiHelper.create_label_row(grid, ref row, _("Altitude:"), _("%.1f meters").printf(alt));
            }
        }

        /**
        * Build the IPTC data section.
        * @param row The current row index.
        */
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
            UiHelper.add_section_header(grid, ref row, _("Authoring &amp; Description"));

            if (artist != "-")    UiHelper.create_label_row(grid, ref row, _("Artist/Creator:"), artist);
            if (copyright != "-") UiHelper.create_label_row(grid, ref row, _("Copyright:"), copyright);
            if (desc != "-")      UiHelper.create_label_row(grid, ref row, _("Description:"), desc);
            if (software != "-")  UiHelper.create_label_row(grid, ref row, _("Software:"), software);
        }

        // --- Helpers ---
        /**
        * Get the string value of a metadata tag, or "-" if not found.
        * @param tag The metadata tag name.
        * @return The tag value as a string, or "-" if not found.
        */
        private string get_tag_label(string tag) {
            try {
                string? val = metadata.try_get_tag_string(tag);
                return (val != null && val.strip() != "") ? val : "-";
            } catch (Error e) { return "-"; }
        }

        /**
        * Format aperture value from raw to human-readable.
        * @param raw The raw aperture value (e.g., "28/10").
        * @return A formatted string (e.g., "f/2.8").
        */
        private string format_aperture(string raw) {
            if (raw.contains("/")) {
                string[] parts = raw.split("/");
                if (parts.length == 2) {
                    double num = double.parse(parts[0]);
                    double den = double.parse(parts[1]);
                    if (den != 0) return _("f/%.1f").printf(num / den);
                }
            }
            return _("f/") + raw;
        }

        /**
        * Format exposure time value from raw to human-readable.
        * Logic similar to Thunar-APR to show 1/60 instead of 0.0166
        * @param raw The raw exposure time value (e.g., "1/60" or "0.0166").
        * @return A formatted string (e.g., "1/60 sec" or "0.0166 sec").
        */
        private string format_exposure_time(string raw) {
            // Raw usually comes as "1/60" or "10/600" or "0.0166"
            if (raw.contains("/")) return _("%s sec").printf(raw); // Already formatted fraction
            
            double val = double.parse(raw);
            if (val == 0) return raw;

            if (val < 1.0) {
                // Convert decimal to 1/x
                int denom = (int)(1.0 / val + 0.5); // Round to nearest int
                return _("1/%d sec").printf(denom);
            }
            return _("%s sec").printf(raw);
        }

        /**
        * Get a human-readable flash description.
        * @return A string describing the flash status.
        */
        private string get_flash_string() {
            try {
                long val = metadata.try_get_tag_long("Exif.Photo.Flash");
                bool fired = (val & 0x1) != 0;
                if (!fired) return _("Did not fire");
                
                var sb = new StringBuilder(_("Fired"));
                if ((val & 0x6) == 0x4) sb.append(_(", return detected"));
                else if ((val & 0x6) == 0x2) sb.append(_(", return not detected"));
                if ((val & 0x18) == 0x18) sb.append(_(", auto"));
                else if ((val & 0x18) == 0x10) sb.append(_(", manual"));
                if ((val & 0x40) != 0) sb.append(_(", red-eye reduction"));
                return sb.str;
            } catch (Error e) { return "-"; }
        }

        /**
        * Get a human-readable white balance description.
        * @return A string describing the white balance.
        */
        private string get_white_balance_string() {
            string val = get_tag_label("Exif.Photo.WhiteBalance");
            if (val == "0") return _("Auto");
            if (val == "1") return _("Manual");
            return val;
        }

        /**
        * Get a human-readable orientation description.
        * @return A string describing the orientation.
        */
        private string get_orientation_string() {
            string val = get_tag_label("Exif.Image.Orientation");
            switch (val) {
                case "1": return _("Top-left (Normal)");
                case "2": return _("Top-right (Mirrored)");
                case "3": return _("Bottom-right (180°)");
                case "4": return _("Bottom-left (V-Flip)");
                case "5": return _("Left-top (Transpose)");
                case "6": return _("Right-top (90° CW)");
                case "7": return _("Right-bottom (Transverse)");
                case "8": return _("Left-bottom (90° CCW)");
                default: return val == "-" ? _("Normal") : val;
            }
        }

        /**
        * Get a human-readable exposure program description.
        * @return A string describing the exposure program.
        */
        private string get_exposure_program_string() {
            try {
                long val = metadata.try_get_tag_long("Exif.Photo.ExposureProgram");
                switch (val) {
                    case 0: return _("Not defined");
                    case 1: return _("Manual");
                    case 2: return _("Normal program");
                    case 3: return _("Aperture priority");
                    case 4: return _("Shutter priority");
                    case 5: return _("Creative program");
                    case 6: return _("Action program");
                    case 7: return _("Portrait mode");
                    case 8: return _("Landscape mode");
                    default: return _("Unknown (%ld)").printf(val);
                }
            } catch (Error e) { return "-"; }
        }

        /**
        * Get a human-readable metering mode description.
        * @return A string describing the metering mode.
        */
        private string get_metering_mode_string() {
            try {
                long val = metadata.try_get_tag_long("Exif.Photo.MeteringMode");
                switch (val) {
                    case 0: return _("Unknown");
                    case 1: return _("Average");
                    case 2: return _("CenterWeightedAverage");
                    case 3: return _("Spot");
                    case 4: return _("MultiSpot");
                    case 5: return _("Pattern");
                    case 6: return _("Partial");
                    case 255: return _("Other");
                    default: return _("Unknown (%ld)").printf(val);
                }
            } catch (Error e) { return "-"; }
        }
    }

}