using Gtk;
using Gst;
using Gst.PbUtils;
using Gst.Tag;
using TMP.Utils;

namespace TMP {

    /**
    * Wrapper C Extract the first attachment (image) from a media file using libavformat.
    * @param path The path to the media file.
    * @param filename Output parameter to receive the attachment filename.
    * @param mimetype Output parameter to receive the attachment MIME type.
    * @return GBytes containing the attachment data.
    */
    [CCode (cname = "thunar_extract_first_attachment")]
    extern GLib.Bytes? thunar_extract_first_attachment(string path, out string filename, out string mimetype);

    /**
    * Media File Handler implementing FileHandler interface.
    */
    public class MediaHandler : GLib.Object, FileHandler {
        private File file;
        private DiscovererInfo? info;
        private bool is_audio_only = false;
        private Grid grid;
        
        // Explicitly use GLib.List to avoid conflict with Gst.Tag.List
        private GLib.List<EmbeddedImage?> image_list; 

        /**
        * Struct to hold embedded image sample and label.
        */
        private struct EmbeddedImage {
            public Gst.Sample sample;
            public string label;
        }

        // Helper to resize pixbuf to max 250px height, maintaining aspect ratio
        /**
        * Scale a Gdk.Pixbuf to a maximum height while maintaining aspect ratio.
        * @param pix The Gdk.Pixbuf to scale.
        * @param max_height The maximum height to scale to.
        * @return The scaled Gdk.Pixbuf.
        */
        private Gdk.Pixbuf? scale_pixbuf_to_max_height(Gdk.Pixbuf pix, int max_height = 250) {
            if (pix == null) return null;
            
            int orig_height = pix.get_height();
            if (orig_height <= max_height) return pix; // Already small enough
            
            int orig_width = pix.get_width();
            int new_width = (orig_width * max_height) / orig_height;
            
            return pix.scale_simple(new_width, max_height, Gdk.InterpType.BILINEAR);
        }

        /**
        * Constructor: Analyze the media file using GStreamer Discoverer.
        * @param f The GLib.File representing the media file.
        */
        public MediaHandler(File f) {
            this.file = f;
                
            // DEBUG: Force print to verify constructor started
            debug_print(_("MediaHandler: Init started for %s\n"), f.get_uri());
            stdout.flush();
            
            if (!Gst.is_initialized()) {
                unowned string[]? args = null; 
                Gst.init(ref args); 
            }

            try {
                var discoverer = new Discoverer(5 * Gst.SECOND); 
                this.info = discoverer.discover_uri(file.get_uri());
                
                if (this.info != null) {
                    var streams = info.get_stream_list();
                    foreach (var s in streams) {
                        if (s is DiscovererVideoInfo) {
                            this.is_audio_only = false;
                            return;
                        }
                    }
                    this.is_audio_only = true;
                }
            } catch (Error e) {
                warning(_("Media Analysis Error: %s"), e.message);
            }
        }

        /**
        * Get the title for the property page.
        * @return A string representing the page title.
        */
        public string get_page_title() {
            return is_audio_only ? _("Audio Properties") : _("Video Properties");
        }

        /**
        * Get the properties panel widget for the media file.
        * @return A Gtk.Widget containing the properties panel.
        */
        public Widget get_properties_panel() {
            this.grid = new Grid();
            grid.column_spacing = 12;
            grid.row_spacing = 6;
            
            int row = 0;

            string header_text = is_audio_only ? _("<b>Audio Metadata</b>") : _("<b>Video Metadata</b>");
            UiHelper.add_section_header(grid, ref row, header_text);

            if (is_audio_only) build_audio_ui(ref row);
            else build_video_ui(ref row);

            display_embedded_images(ref row);

            return grid;
        }

        /**
        * Build the UI for audio properties.
        * @param row The current row in the grid.
        */
        private void build_audio_ui(ref int row) {
            string main_title="-", main_artist="-", album="-", genre="-", album_artist="-", date="-";
            uint track = 0;
            extract_tags_loose(out main_title, out main_artist, out album, out genre, out album_artist, out track, out date);
            string track_str = (track > 0) ? "%u".printf(track) : "-";

            UiHelper.create_label_row(grid, ref row, _("Main Title:"), main_title);
            UiHelper.create_label_row(grid, ref row, _("Artist:"), main_artist);
            UiHelper.create_label_row(grid, ref row, _("Album:"), album);
            UiHelper.create_label_row(grid, ref row, _("Track:"), track_str);
            UiHelper.create_label_row(grid, ref row, _("Genre:"), genre);
            UiHelper.create_label_row(grid, ref row, _("Date:"), date);
            
            UiHelper.add_separator(grid, ref row);
            UiHelper.add_section_header(grid, ref row, _("Technical Details"));

            string codec = "-", channels = "-", rate = "-", bitrate = "-", br_mode="-", lang = "-";
            var a_stream = get_first_stream<DiscovererAudioInfo>();
            if (a_stream != null) parse_audio_stream(a_stream, out codec, out channels, out rate, out bitrate, out br_mode, out lang);

            UiHelper.create_label_row(grid, ref row, _("Container:"), get_container_name());
            UiHelper.create_label_row(grid, ref row, _("Duration:"), get_duration_string());
            UiHelper.create_label_row(grid, ref row, _("Codec:"), codec);
            UiHelper.create_label_row(grid, ref row, _("Bitrate:"), bitrate);
            UiHelper.create_label_row(grid, ref row, _("Bitrate Mode:"), br_mode);
            UiHelper.create_label_row(grid, ref row, _("Sample Rate:"), rate);
            UiHelper.create_label_row(grid, ref row, _("Channels:"), channels);
            UiHelper.create_label_row(grid, ref row, _("Language:"), lang);
        }

        /**
        * Build the UI for video properties.
        * @param row The current row in the grid.
        */
        private void build_video_ui(ref int row) {
            string main_title="-", main_artist="-", album="-", genre="-", aa="-", date="-";
            uint trk=0;
            extract_tags_strict_container(out main_title, out main_artist, out album, out genre, out aa, out trk, out date);

            UiHelper.create_label_row(grid, ref row, _("File Title:"), main_title);
            if (main_artist != "-") UiHelper.create_label_row(grid, ref row, _("Artist:"), main_artist);
            if (date != "-") UiHelper.create_label_row(grid, ref row, _("Date:"), date);
            UiHelper.create_label_row(grid, ref row, _("Container:"), get_container_name());
            UiHelper.create_label_row(grid, ref row, _("Duration:"), get_duration_string());

            var video_streams = get_streams<DiscovererVideoInfo>();
            int v_idx = 1;
            foreach (var v in video_streams) {
                UiHelper.add_separator(grid, ref row);
                string header = (video_streams.length() > 1) ? _("Video Stream %d").printf(v_idx++) : _("Video Stream");
                UiHelper.add_section_header(grid, ref row, header);

                string v_title = get_tag_string(v.get_tags(), Gst.Tags.TITLE) ?? "-";
                if (v_title != "-") UiHelper.create_label_row(grid, ref row, _("Stream Title:"), v_title);

                string v_codec="-", res="-", fps="-", v_bitrate="-", br_mode="-", fr_mode="-", v_lang="-";
                parse_video_stream(v, out v_codec, out res, out fps, out fr_mode, out v_bitrate, out br_mode, out v_lang);

                UiHelper.create_label_row(grid, ref row, _("Codec:"), v_codec);
                UiHelper.create_label_row(grid, ref row, _("Resolution:"), res);
                UiHelper.create_label_row(grid, ref row, _("Framerate:"), fps);
                UiHelper.create_label_row(grid, ref row, _("Frame Mode:"), fr_mode);
                UiHelper.create_label_row(grid, ref row, _("Bitrate:"), v_bitrate);
                UiHelper.create_label_row(grid, ref row, _("Bitrate Mode:"), br_mode);
                if (v_lang != "-") UiHelper.create_label_row(grid, ref row, _("Language:"), v_lang);
            }

            var audio_streams = get_streams<DiscovererAudioInfo>();
            int a_idx = 1;
            foreach (var a in audio_streams) {
                UiHelper.add_separator(grid, ref row);
                string header = (audio_streams.length() > 1) ? _("Audio Stream %d").printf(a_idx++) : _("Audio Stream");
                UiHelper.add_section_header(grid, ref row, header);

                string a_title = get_tag_string(a.get_tags(), Gst.Tags.TITLE) ?? "-";
                if (a_title != "-") UiHelper.create_label_row(grid, ref row, _("Stream Title:"), a_title);

                string a_codec="-", a_chans="-", a_rate="-", a_bitrate="-", br_mode="-", a_lang="-";
                parse_audio_stream(a, out a_codec, out a_chans, out a_rate, out a_bitrate, out br_mode, out a_lang);

                UiHelper.create_label_row(grid, ref row, _("Codec:"), a_codec);
                UiHelper.create_label_row(grid, ref row, _("Language:"), a_lang);
                UiHelper.create_label_row(grid, ref row, _("Channels:"), a_chans);
                UiHelper.create_label_row(grid, ref row, _("Sample Rate:"), a_rate);
                UiHelper.create_label_row(grid, ref row, _("Bitrate Mode:"), br_mode);
            }

            var sub_streams = get_streams<DiscovererSubtitleInfo>();
            if (sub_streams.length() > 0) {
                UiHelper.add_separator(grid, ref row);
                UiHelper.add_section_header(grid, ref row, _("Subtitles"));
                int s_idx = 1;
                foreach (var s in sub_streams) {
                    string s_title = get_tag_string(s.get_tags(), Gst.Tags.TITLE) ?? "-";
                    string s_lang_code = get_tag_string(s.get_tags(), Gst.Tags.LANGUAGE_CODE) ?? "-";
                    string s_lang = (s_lang_code != "-") ? s_lang_code.up() : _("Unknown");
                    string display_val = (s_title != "-") ? _("%s (%s)").printf(s_title, s_lang) : s_lang;
                    UiHelper.create_label_row(grid, ref row, _("Track %d:").printf(s_idx++), display_val);
                }
            }
        }

        /**
        * Display embedded images in the grid.
        * @param row The current row in the grid.
        */
        private void display_embedded_images(ref int row) {
            if (info == null) return;

            this.image_list = new GLib.List<EmbeddedImage?>();

            // Extract images from container tags
            var root = info.get_stream_info();
            if (root != null) {
                gather_images_generic(root.get_tags());
            }
            
            // Extract images from stream tags
            foreach (var s in info.get_stream_list()) {
                gather_images_generic(s.get_tags());
            }

            // 3. UI Display Logic
            // If no images found via Gst tags, try container-level attachments (Matroska, MP4, M4A)
            if (image_list.length() == 0) {
                try {
                    string fname = null;
                    string mime = null;
                    var bytes = thunar_extract_first_attachment(this.file.get_path(), out fname, out mime);
                    if (bytes != null) {
                        var stream = new MemoryInputStream.from_bytes(bytes);
                        var pix = new Gdk.Pixbuf.from_stream(stream, null);
                        if (pix != null) {
                            // Resize to max 250px height for efficient memory usage
                            pix = scale_pixbuf_to_max_height(pix, 250);
                            
                            UiHelper.add_separator(grid, ref row);
                            UiHelper.add_section_header(grid, ref row, _("Embedded Images"));

                            var img = new Gtk.Image();
                            img.set_from_pixbuf(pix);
                            img.valign = Align.START;
                            img.halign = Align.START;

                            var lbl_text = (fname != null) ? fname : _("Attachment");
                            var lbl = new Label("<b>%s</b>".printf(lbl_text));
                            lbl.valign = Align.START;
                            lbl.halign = Align.END;
                            lbl.use_markup = true;
                            lbl.wrap = true;
                            lbl.max_width_chars = 20;

                            grid.attach(lbl, 0, row, 1, 1);
                            grid.attach(img, 1, row, 2, 1);
                            row++;
                        }
                    }
                } catch (Error e) {
                    debug_print(_("Attachment extraction failed: %s\n"), e.message);
                }
            }

            if (image_list.length() > 0) {
                UiHelper.add_separator(grid, ref row);
                UiHelper.add_section_header(grid, ref row, _("Embedded Images"));

                foreach (var img_struct in image_list) {
                    var pixbuf = TMP.Utils.pixbuf_from_sample(img_struct.sample);
                    if (pixbuf != null) {
                        // Resize to max 250px height for efficient memory usage
                        pixbuf = scale_pixbuf_to_max_height(pixbuf, 250);
                        
                        var img = new Gtk.Image();
                        img.set_from_pixbuf(pixbuf);
                        img.valign = Align.START;
                        img.halign = Align.START;

                        var lbl = new Label("<b>%s</b>".printf(img_struct.label));
                        lbl.valign = Align.START;
                        lbl.halign = Align.END;
                        lbl.use_markup = true;
                        lbl.wrap = true;
                        lbl.max_width_chars = 20;

                        grid.attach(lbl, 0, row, 1, 1);
                        grid.attach(img, 1, row, 2, 1);
                        row++;
                    } else {
                        debug_print(_("WARNING: Sample found for '%s' but failed to create Pixbuf.\n"), img_struct.label);
                    }
                }
            } else {
                debug_print(_("\n--- RESULT: No images added to image_list ---\n"));
            }
        }

        /**
        * Gather embedded images from a Gst.TagList by checking all tags for Gst.Sample values.
        * @param t The Gst.TagList to search for samples.
        */
        private void gather_images_generic(Gst.TagList? t) {
            if (t == null) return;
            
                // Iterate over every single tag in the list
                t.foreach((list, tag_name) => {
                    // Check if this tag holds a Gst.Sample (which is how images are stored)
                    uint size = list.get_tag_size(tag_name);
                    
                    for (uint i = 0; i < size; i++) {
                        Gst.Sample? s = null;

                        // Prefer explicit Gst::Sample values (common for many tag implementations)
                        if (list.get_sample_index(tag_name, i, out s) && s != null) {
                            if (is_valid_image(s)) {
                                string label = tag_name; // Use the tag name (e.g., "image", "attachment") as label

                                // Try to get a better filename label if possible
                                unowned Gst.Structure? info_str = s.get_info();
                                if (info_str != null && info_str.has_field("filename")) {
                                    label = info_str.get_string("filename");
                                }

                                image_list.append({ s, label });
                                debug_print(_("SUCCESS: Added image from tag '%s' (index %u)\n"), tag_name, i);
                            } else {
                                debug_print(_("IGNORED: Tag '%s' is a Sample but not a valid image.\n"), tag_name);                        }
                        }
                    }
                });
        }

        /**
        * Check if a Gst.Sample likely contains image data.
        * @param s The Gst.Sample to check.
        * @return True if the sample appears to be an image, false otherwise.
        */
        private bool is_valid_image(Gst.Sample s) {
            // 1. Check Buffer Caps (Standard for MP3/M4A)
            unowned Gst.Caps? caps = s.get_caps();
            if (caps != null && caps.get_size() > 0) {
                unowned Gst.Structure str = caps.get_structure(0);
                string name = str.get_name();
                debug_print(_("    [Check] Caps Name: %s\n"), name);
                if (name.has_prefix("image/")) return true;
            } else {
                debug_print(_("    [Check] Caps are null or empty.\n"));
            }
            // 2. Check Sample Info (MKV attachments / MP4 atoms often hide metadata here)
            unowned Gst.Structure? info = s.get_info();
            if (info != null) {
                // Check a variety of possible mime-field names
                string[] mime_fields = { "mimetype", "mime", "mime-type", "content-type" };
                foreach (var f in mime_fields) {
                    if (info.has_field(f)) {
                        string mime = info.get_string(f);
                        debug_print(_("    [Check] Info Mime (%s): %s\n"), f, mime);
                        if (mime != null && mime.has_prefix("image/")) return true;
                    }
                }

                // If filename is present, infer image from extension
                if (info.has_field("filename")) {
                    string? fname_raw = info.get_string("filename");
                    if (fname_raw != null) {
                        string fname = (string) fname_raw;
                        fname = fname.down();
                        if (fname.has_suffix(".jpg") || fname.has_suffix(".jpeg") || fname.has_suffix(".png") || fname.has_suffix(".gif") || fname.has_suffix(".webp") || fname.has_suffix(".bmp")) {
                            debug_print(_("    [Check] Filename suggests image: %s\n"), fname);
                            return true;
                        }
                    }
                }
            }
            return false;
        }

        // --- Helpers ---
        /**
        * Extract common tags strictly from the container-level stream info.
        * @param title Output parameter for title.
        * @param artist Output parameter for artist.
        * @param album Output parameter for album.
        * @param genre Output parameter for genre.
        * @param album_artist Output parameter for album artist.
        * @param track Output parameter for track number.
        * @param date Output parameter for date.
        */
        private void extract_tags_strict_container(out string title, out string artist, out string album, 
                                        out string genre, out string album_artist, 
                                        out uint track, out string date) {
            title = "-"; artist = "-"; album = "-"; genre = "-";
            album_artist = "-"; track = 0; date = "-";
            if (info == null) return;
            var root_info = info.get_stream_info();
            if (root_info != null) {
                parse_common_tags(root_info.get_tags(), ref title, ref artist, ref album, ref genre, ref album_artist, ref track, ref date);
            }
        }

        /**
        * Extract common tags loosely from container and all streams.
        * @param title Output parameter for title.
        * @param artist Output parameter for artist.
        * @param album Output parameter for album.
        * @param genre Output parameter for genre.
        * @param album_artist Output parameter for album artist.
        * @param track Output parameter for track number.
        * @param date Output parameter for date.
        */
        private void extract_tags_loose(out string title, out string artist, out string album, 
                                        out string genre, out string album_artist, 
                                        out uint track, out string date) {
            title = "-"; artist = "-"; album = "-"; genre = "-";
            album_artist = "-"; track = 0; date = "-";
            if (info == null) return;
            
            // FIX: Use container tags first (replaced info.get_tags())
            var root_info = info.get_stream_info();
            if (root_info != null) {
                parse_common_tags(root_info.get_tags(), ref title, ref artist, ref album, ref genre, ref album_artist, ref track, ref date);
            }
            
            // Fallback: Check streams if main title is missing
            foreach (var s in info.get_stream_list()) {
                parse_common_tags(s.get_tags(), ref title, ref artist, ref album, ref genre, ref album_artist, ref track, ref date);
            }
        }

        /**
        * Parse common tags from a Gst.TagList into provided references.
        * @param tags The Gst.TagList to parse.
        * @param t Reference for title.
        * @param a Reference for artist.
        * @param al Reference for album.
        * @param g Reference for genre.
        * @param aa Reference for album artist.
        * @param trk Reference for track number.
        * @param d Reference for date.
        */
        private void parse_common_tags(Gst.TagList? tags, ref string t, ref string a, ref string al, ref string g, ref string aa, ref uint trk, ref string d) {
            if (tags == null) return;
            string? val = null;
            if (t == "-" && tags.get_string(Gst.Tags.TITLE, out val)) t = val;
            if (a == "-" && tags.get_string(Gst.Tags.ARTIST, out val)) a = val;
            if (al == "-" && tags.get_string(Gst.Tags.ALBUM, out val)) al = val;
            if (g == "-" && tags.get_string(Gst.Tags.GENRE, out val)) g = val;
            if (aa == "-" && tags.get_string(Gst.Tags.ALBUM_ARTIST, out val)) aa = val;
            uint u_val = 0;
            if (trk == 0 && tags.get_uint(Gst.Tags.TRACK_NUMBER, out u_val)) trk = u_val;
            Gst.DateTime? dt = null;
            if (d == "-" && tags.get_date_time(Gst.Tags.DATE_TIME, out dt)) {
                d = "%04d-%02d-%02d".printf(dt.get_year(), dt.get_month(), dt.get_day());
            }
        }

        /**
        * Get a string value for a specific tag from a Gst.TagList.
        * @param tags The Gst.TagList to search.
        * @param tag_name The name of the tag to retrieve.
        * @return The string value of the tag, or null if not found.
        */
        private string? get_tag_string(Gst.TagList? tags, string tag_name) {
            if (tags == null) return null;
            string? val = null;
            if (tags.get_string(tag_name, out val)) return val;
            return null;
        }

        /**
        * Parse video stream details into output parameters.
        * @param v The DiscovererVideoInfo to parse.
        * @param codec Output parameter for codec.
        * @param res Output parameter for resolution.
        * @param fps Output parameter for framerate.
        * @param fr_mode Output parameter for frame mode.
        * @param bitrate Output parameter for bitrate.
        * @param br_mode Output parameter for bitrate mode.
        * @param lang Output parameter for language.
        */
        private void parse_video_stream(DiscovererVideoInfo v, out string codec, out string res, out string fps, 
                                    out string fr_mode, out string bitrate, out string br_mode, out string lang) {
            codec="-"; res="-"; fps="-"; fr_mode="-"; bitrate="-"; br_mode="-"; lang="-";
            
            lang = get_tag_string(v.get_tags(), Gst.Tags.LANGUAGE_CODE) ?? "-";
            if (lang != "-") lang = lang.up();

            var caps = v.get_caps();
            if (caps != null && caps.get_size() > 0) {
                codec = get_readable_codec(caps.get_structure(0));
            }
            res = "%u x %u".printf(v.get_width(), v.get_height());
            
            uint n = v.get_framerate_num();
            uint d = v.get_framerate_denom();
            if (d > 0) {
                fps = _("%.2f fps").printf((double)n / d);
                fr_mode = (n == 0) ? _("Variable (VFR)") : _("Constant (CFR)");
            } else {
                fr_mode = _("Variable (VFR)");
            }
            uint br_val = v.get_bitrate();
            if (br_val > 0) bitrate = "%u kbps".printf(br_val / 1000);
            br_mode = detect_bitrate_mode(v.get_tags(), br_val);
        }

        /**
        * Parse audio stream details into output parameters.
        * @param a The DiscovererAudioInfo to parse.
        * @param codec Output parameter for codec.
        * @param channels Output parameter for channels.
        * @param rate Output parameter for sample rate.
        * @param bitrate Output parameter for bitrate.
        * @param br_mode Output parameter for bitrate mode.
        * @param lang Output parameter for language.
        */
        private void parse_audio_stream(DiscovererAudioInfo a, out string codec, out string channels, out string rate, 
                                    out string bitrate, out string br_mode, out string lang) {
            codec="-"; channels="-"; rate="-"; bitrate="-"; br_mode="-"; lang="-";
            
            lang = get_tag_string(a.get_tags(), Gst.Tags.LANGUAGE_CODE) ?? "-";
            if (lang != "-") lang = lang.up();

            var caps = a.get_caps();
            if (caps != null && caps.get_size() > 0) {
                codec = get_readable_codec(caps.get_structure(0));
            }
            channels = "%u".printf(a.get_channels());
            rate = "%u Hz".printf(a.get_sample_rate());
            uint br_val = a.get_bitrate();
            if (br_val > 0) bitrate = "%u kbps".printf(br_val / 1000);
            br_mode = detect_bitrate_mode(a.get_tags(), br_val);
        }

        /**
        * Detect the bitrate mode for an audio stream.
        * @param tags The Gst.TagList associated with the audio stream.
        * @param current_bitrate The current bitrate of the stream.
        * @return The detected bitrate mode.
        */
        private string detect_bitrate_mode(Gst.TagList? tags, uint current_bitrate) {
            if (tags == null) return _("Constant (CBR)");
            uint min_br = 0, max_br = 0;
            bool has_min = tags.get_uint(Gst.Tags.MINIMUM_BITRATE, out min_br);
            bool has_max = tags.get_uint(Gst.Tags.MAXIMUM_BITRATE, out max_br);
            if (has_min && has_max && min_br != max_br) return _("Variable (VBR)");
            uint nominal = 0;
            if (tags.get_uint(Gst.Tags.NOMINAL_BITRATE, out nominal)) return _("Variable (VBR)");
            return _("Constant (CBR)");
        }

        /**
        * Get a list of streams of a specific type from the media info.
        * @param T The type of stream to retrieve.
        * @return A GLib.List of streams of type T.
        */
        private GLib.List<T> get_streams<T>() {
            var list = new GLib.List<T>();
            if (info == null) return list;
            foreach (var s in info.get_stream_list()) {
                if (s is T) list.append((T)s);
            }
            return list;
        }

        /**
        * Get the first stream of a specific type from the media info.
        * @param T The type of stream to retrieve.
        * @return The first stream of type T, or null if not found.
        */
        private T? get_first_stream<T>() {
            if (info == null) return null;
            foreach (var s in info.get_stream_list()) {
                if (s is T) return (T)s;
            }
            return null;
        }

        /**
        * Convert a Gst.Structure codec name to a human-readable format.
        * @param structure The Gst.Structure containing codec information.
        * @return A human-readable codec name.
        */
        private string get_readable_codec(Gst.Structure structure) {
            string raw = structure.get_name();
            switch (raw) {
                case "video/x-h264": return _("H.264 (AVC)");
                case "video/x-h265": return _("H.265 (HEVC)");
                case "video/x-vp8":  return _("VP8");
                case "video/x-vp9":  return _("VP9");
                case "video/x-av1":  return _("AV1");
                case "video/x-theora": return _("Theora");
                case "video/x-xvid":   return _("Xvid (MPEG-4 Part 2)");
                case "video/x-divx":   return _("DivX (MPEG-4 Part 2)");
                case "video/mpeg":
                    int ver = 0;
                    if (structure.get_int("mpegversion", out ver)) {
                        if (ver == 4) return _("MPEG-4 Part 2 (Xvid/DivX)");
                        if (ver == 2) return _("MPEG-2 Video");
                        if (ver == 1) return _("MPEG-1 Video");
                    }
                    return _("MPEG Video");
                case "video/x-raw":  return _("Raw Video");
                case "audio/mpeg":
                    int ver = 0;
                    if (structure.get_int("mpegversion", out ver)) {
                        if (ver == 4) return _("AAC (MPEG-4 Audio)");
                        if (ver == 2) return _("MPEG-2 Audio");
                        if (ver == 1) return _("MP3 (MPEG-1 Audio)");
                    }
                    return _("MPEG Audio");
                case "audio/x-aac":     return _("AAC Audio");
                case "audio/mp4a-latm": return _("AAC (LATM)");
                case "audio/x-vorbis":  return _("Vorbis");
                case "audio/x-opus":    return _("Opus");
                case "audio/x-flac":    return _("FLAC");
                case "audio/x-wav":     return _("WAV / PCM");
                case "audio/ac3":       return _("Dolby Digital (AC-3)");
                case "audio/eac3":      return _("Dolby Digital Plus (E-AC-3)");
                case "subpicture/x-dvd": return _("DVD Subtitles");
                case "subpicture/x-pgs": return _("Bluray PGS");
                case "subtitle/x-kate": return _("Kate Subtitles");
                case "text/x-raw":      return _("Text Subtitles");
                default: return raw.replace("video/x-", "").replace("audio/x-", "").replace("subpicture/x-", "").up();
            }
        }

        private string get_container_name() {
            if (info == null) return _("Unknown");
            var stream_info = info.get_stream_info();
            if (stream_info == null) return _("Unknown");
            var caps = stream_info.get_caps();
            if (caps == null || caps.get_size() == 0) return _("Unknown");
            string raw_caps = caps.get_structure(0).get_name();

            switch (raw_caps) {
                case "video/x-matroska": return _("Matroska (MKV)");
                case "video/quicktime":  return _("QuickTime / MP4");
                case "video/mp4":        return _("MPEG-4 Part 14");
                case "video/x-msvideo":  return _("AVI");
                case "application/ogg":  return _("Ogg Container");
                case "application/x-id3":return _("MP3 (ID3 Tagged)");
                case "audio/x-wav":      return _("WAV Audio");
                case "audio/x-flac":     return _("FLAC Audio");
                default: return raw_caps.replace("video/x-", "").replace("application/", "").up();
            }
        }

        /**
        * Get the duration of the media file as a formatted string.
        * @return A string representing the duration in HH:MM:SS or MM:SS format.
        */
        private string get_duration_string() {
            if (info == null) return "00:00";
            double secs = (double)info.get_duration() / 1000000000.0;
            int h = (int)(secs / 3600);
            int m = (int)((secs % 3600) / 60);
            int s = (int)(secs % 60);
            if (h > 0) return "%d:%02d:%02d".printf(h, m, s);
            return "%02d:%02d".printf(m, s);
        }
    }

}