using Gtk;
using Gst;
using Gst.PbUtils;
using Gst.Tag;

public class MediaHandler : GLib.Object, FileHandler {
    private File file;
    private DiscovererInfo? info;
    private bool is_audio_only = false;
    private Grid grid;
    
    // Explicitly use GLib.List to avoid conflict with Gst.Tag.List
    private GLib.List<EmbeddedImage?> image_list; 

    private struct EmbeddedImage {
        public Gst.Sample sample;
        public string label;
    }

    public MediaHandler(File f) {
        this.file = f;
        
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
            warning("Media Analysis Error: %s", e.message);
        }
    }

    public Widget get_main_view() {
        var box = new Box(Orientation.VERTICAL, 6);
        box.valign = Align.CENTER;
        box.halign = Align.CENTER;

        string icon_name = is_audio_only ? "audio-x-generic" : "video-x-generic";
        var icon = new Gtk.Image.from_icon_name(icon_name);
        
        icon.pixel_size = 128;
        icon.add_css_class("dim-label");
        
        box.append(icon);
        var name_lbl = new Label(file.get_basename());
        name_lbl.add_css_class("title-2");
        name_lbl.wrap = true;
        name_lbl.max_width_chars = 30;
        name_lbl.justify = Justification.CENTER;
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

        string header_text = is_audio_only ? "<b>Audio Metadata</b>" : "<b>Video Metadata</b>";
        UiHelper.add_section_header(grid, ref row, header_text);

        if (is_audio_only) build_audio_ui(ref row);
        else build_video_ui(ref row);

        display_embedded_images(ref row);

        box.append(grid);
        var spacer = new Label(""); spacer.vexpand = true; box.append(spacer);
        scroll.child = box;
        return scroll;
    }

    private void build_audio_ui(ref int row) {
        string main_title="-", main_artist="-", album="-", genre="-", album_artist="-", date="-";
        uint track = 0;
        extract_tags_loose(out main_title, out main_artist, out album, out genre, out album_artist, out track, out date);
        string track_str = (track > 0) ? "%u".printf(track) : "-";

        UiHelper.create_label_row(grid, ref row, "Main Title:", main_title);
        UiHelper.create_label_row(grid, ref row, "Artist:", main_artist);
        UiHelper.create_label_row(grid, ref row, "Album:", album);
        UiHelper.create_label_row(grid, ref row, "Track:", track_str);
        UiHelper.create_label_row(grid, ref row, "Genre:", genre);
        UiHelper.create_label_row(grid, ref row, "Date:", date);
        
        UiHelper.add_separator(grid, ref row);
        UiHelper.add_section_header(grid, ref row, "Technical Details");

        string codec = "-", channels = "-", rate = "-", bitrate = "-", br_mode="-", lang = "-";
        var a_stream = get_first_stream<DiscovererAudioInfo>();
        if (a_stream != null) parse_audio_stream(a_stream, out codec, out channels, out rate, out bitrate, out br_mode, out lang);

        UiHelper.create_label_row(grid, ref row, "Container:", get_container_name());
        UiHelper.create_label_row(grid, ref row, "Duration:", get_duration_string());
        UiHelper.create_label_row(grid, ref row, "Codec:", codec);
        UiHelper.create_label_row(grid, ref row, "Bitrate:", bitrate);
        UiHelper.create_label_row(grid, ref row, "Bitrate Mode:", br_mode);
        UiHelper.create_label_row(grid, ref row, "Sample Rate:", rate);
        UiHelper.create_label_row(grid, ref row, "Channels:", channels);
        UiHelper.create_label_row(grid, ref row, "Language:", lang);
    }

    private void build_video_ui(ref int row) {
        string main_title="-", main_artist="-", album="-", genre="-", aa="-", date="-";
        uint trk=0;
        extract_tags_strict_container(out main_title, out main_artist, out album, out genre, out aa, out trk, out date);

        UiHelper.create_label_row(grid, ref row, "File Title:", main_title);
        if (main_artist != "-") UiHelper.create_label_row(grid, ref row, "Artist:", main_artist);
        if (date != "-") UiHelper.create_label_row(grid, ref row, "Date:", date);
        UiHelper.create_label_row(grid, ref row, "Container:", get_container_name());
        UiHelper.create_label_row(grid, ref row, "Duration:", get_duration_string());

        var video_streams = get_streams<DiscovererVideoInfo>();
        int v_idx = 1;
        foreach (var v in video_streams) {
            UiHelper.add_separator(grid, ref row);
            string header = (video_streams.length() > 1) ? "Video Stream %d".printf(v_idx++) : "Video Stream";
            UiHelper.add_section_header(grid, ref row, header);

            string v_title = get_tag_string(v.get_tags(), Gst.Tags.TITLE) ?? "-";
            if (v_title != "-") UiHelper.create_label_row(grid, ref row, "Stream Title:", v_title);

            string v_codec="-", res="-", fps="-", v_bitrate="-", br_mode="-", fr_mode="-", v_lang="-";
            parse_video_stream(v, out v_codec, out res, out fps, out fr_mode, out v_bitrate, out br_mode, out v_lang);

            UiHelper.create_label_row(grid, ref row, "Codec:", v_codec);
            UiHelper.create_label_row(grid, ref row, "Resolution:", res);
            UiHelper.create_label_row(grid, ref row, "Framerate:", fps);
            UiHelper.create_label_row(grid, ref row, "Frame Mode:", fr_mode);
            UiHelper.create_label_row(grid, ref row, "Bitrate:", v_bitrate);
            UiHelper.create_label_row(grid, ref row, "Bitrate Mode:", br_mode);
            if (v_lang != "-") UiHelper.create_label_row(grid, ref row, "Language:", v_lang);
        }

        var audio_streams = get_streams<DiscovererAudioInfo>();
        int a_idx = 1;
        foreach (var a in audio_streams) {
            UiHelper.add_separator(grid, ref row);
            string header = (audio_streams.length() > 1) ? "Audio Stream %d".printf(a_idx++) : "Audio Stream";
            UiHelper.add_section_header(grid, ref row, header);

            string a_title = get_tag_string(a.get_tags(), Gst.Tags.TITLE) ?? "-";
            if (a_title != "-") UiHelper.create_label_row(grid, ref row, "Stream Title:", a_title);

            string a_codec="-", a_chans="-", a_rate="-", a_bitrate="-", br_mode="-", a_lang="-";
            parse_audio_stream(a, out a_codec, out a_chans, out a_rate, out a_bitrate, out br_mode, out a_lang);

            UiHelper.create_label_row(grid, ref row, "Codec:", a_codec);
            UiHelper.create_label_row(grid, ref row, "Language:", a_lang);
            UiHelper.create_label_row(grid, ref row, "Channels:", a_chans);
            UiHelper.create_label_row(grid, ref row, "Sample Rate:", a_rate);
            UiHelper.create_label_row(grid, ref row, "Bitrate Mode:", br_mode);
        }

        var sub_streams = get_streams<DiscovererSubtitleInfo>();
        if (sub_streams.length() > 0) {
            UiHelper.add_separator(grid, ref row);
            UiHelper.add_section_header(grid, ref row, "Subtitles");
            int s_idx = 1;
            foreach (var s in sub_streams) {
                string s_title = get_tag_string(s.get_tags(), Gst.Tags.TITLE) ?? "-";
                string s_lang_code = get_tag_string(s.get_tags(), Gst.Tags.LANGUAGE_CODE) ?? "-";
                string s_lang = (s_lang_code != "-") ? s_lang_code.up() : "Unknown";
                string display_val = (s_title != "-") ? "%s (%s)".printf(s_title, s_lang) : s_lang;
                UiHelper.create_label_row(grid, ref row, "Track %d:".printf(s_idx++), display_val);
            }
        }
    }

    private void display_embedded_images(ref int row) {
        if (info == null) return;

        this.image_list = new GLib.List<EmbeddedImage?>();

        // FIX: Replaced deprecated info.get_tags() with info.get_stream_info().get_tags()
        // Container tags (often where covers live in MKV/M4A)
        var root = info.get_stream_info();
        if (root != null) {
             gather_images_from_tags(root.get_tags());
        }
        
        // Also check individual streams (ID3 tags in MP3 are sometimes attached to the audio stream)
        foreach (var s in info.get_stream_list()) {
            gather_images_from_tags(s.get_tags());
        }

        if (image_list.length() > 0) {
            UiHelper.add_separator(grid, ref row);
            UiHelper.add_section_header(grid, ref row, "Embedded Images");

            foreach (var img_struct in image_list) {
                var texture = ImageHelper.texture_from_sample(img_struct.sample);
                if (texture != null) {
                    var pic = new Picture.for_paintable(texture);
                    pic.can_shrink = true;
                    pic.content_fit = ContentFit.CONTAIN;
                    pic.height_request = 250; 
                    pic.halign = Align.START;
                    
                    var lbl = new Label(img_struct.label);
                    lbl.valign = Align.START;
                    lbl.xalign = 1.0f;
                    lbl.add_css_class("heading"); 
                    lbl.wrap = true; 
                    lbl.max_width_chars = 20;

                    grid.attach(lbl, 0, row, 1, 1);
                    grid.attach(pic, 1, row, 1, 1);
                    row++;
                }
            }
        }
    }

    private void gather_images_from_tags(Gst.TagList? t) {
        if (t == null) return;
        
        uint len = t.get_tag_size(Gst.Tags.IMAGE);
        for (uint i = 0; i < len; i++) {
            Gst.Sample? s = null;
            if (t.get_sample(Gst.Tags.IMAGE, out s) && s != null) {
                image_list.append({ s, get_image_label(s, "Cover Art") });
            }
        }
        
        len = t.get_tag_size(Gst.Tags.PREVIEW_IMAGE);
        for (uint i = 0; i < len; i++) {
            Gst.Sample? s = null;
            if (t.get_sample(Gst.Tags.PREVIEW_IMAGE, out s) && s != null) {
                image_list.append({ s, "Preview Image" });
            }
        }
    }

    private string get_image_label(Gst.Sample sample, string default_label) {
        unowned Gst.Structure? s_info = sample.get_info();
        if (s_info == null) return default_label;

        Gst.Tag.ImageType type_enum;
        if (s_info.get_enum("image-type", typeof(Gst.Tag.ImageType), out type_enum)) {
             switch (type_enum) {
                case Gst.Tag.ImageType.FRONT_COVER: return "Front Cover";
                case Gst.Tag.ImageType.BACK_COVER: return "Back Cover";
                case Gst.Tag.ImageType.LEAFLET_PAGE: return "Leaflet Page";
                case Gst.Tag.ImageType.MEDIUM: return "Medium / Disc";
                case Gst.Tag.ImageType.LEAD_ARTIST: return "Lead Artist";
                case Gst.Tag.ImageType.ARTIST: return "Artist";
                case Gst.Tag.ImageType.CONDUCTOR: return "Conductor";
                case Gst.Tag.ImageType.BAND_ORCHESTRA: return "Band / Orchestra";
                case Gst.Tag.ImageType.COMPOSER: return "Composer";
                case Gst.Tag.ImageType.LYRICIST: return "Lyricist";
                case Gst.Tag.ImageType.RECORDING_LOCATION: return "Recording Location";
                case Gst.Tag.ImageType.DURING_RECORDING: return "During Recording";
                case Gst.Tag.ImageType.DURING_PERFORMANCE: return "During Performance";
                case Gst.Tag.ImageType.VIDEO_CAPTURE: return "Video Capture";
                case Gst.Tag.ImageType.FISH: return "Fish / Icon";
                case Gst.Tag.ImageType.ILLUSTRATION: return "Illustration";
                case Gst.Tag.ImageType.BAND_ARTIST_LOGO: return "Band / Artist Logo";
                case Gst.Tag.ImageType.PUBLISHER_STUDIO_LOGO: return "Publisher / Studio Logo";
                default: break;
             }
        }
        
        string? desc = s_info.get_string("description");
        if (desc != null && desc != "") return desc;

        string? fname = s_info.get_string("filename");
        if (fname != null && fname != "") return fname;

        return default_label;
    }

    // --- Helpers (Same as before) ---
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
    
    private string? get_tag_string(Gst.TagList? tags, string tag_name) {
        if (tags == null) return null;
        string? val = null;
        if (tags.get_string(tag_name, out val)) return val;
        return null;
    }

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
            fps = "%.2f fps".printf((double)n / d);
            fr_mode = (n == 0) ? "Variable (VFR)" : "Constant (CFR)";
        } else {
            fr_mode = "Variable (VFR)";
        }
        uint br_val = v.get_bitrate();
        if (br_val > 0) bitrate = "%u kbps".printf(br_val / 1000);
        br_mode = detect_bitrate_mode(v.get_tags(), br_val);
    }

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

    private string detect_bitrate_mode(Gst.TagList? tags, uint current_bitrate) {
        if (tags == null) return "Constant (CBR)";
        uint min_br = 0, max_br = 0;
        bool has_min = tags.get_uint(Gst.Tags.MINIMUM_BITRATE, out min_br);
        bool has_max = tags.get_uint(Gst.Tags.MAXIMUM_BITRATE, out max_br);
        if (has_min && has_max && min_br != max_br) return "Variable (VBR)";
        uint nominal = 0;
        if (tags.get_uint(Gst.Tags.NOMINAL_BITRATE, out nominal)) return "Variable (VBR)";
        return "Constant (CBR)";
    }

    private GLib.List<T> get_streams<T>() {
        var list = new GLib.List<T>();
        if (info == null) return list;
        foreach (var s in info.get_stream_list()) {
            if (s is T) list.append((T)s);
        }
        return list;
    }
    
    private T? get_first_stream<T>() {
        if (info == null) return null;
        foreach (var s in info.get_stream_list()) {
            if (s is T) return (T)s;
        }
        return null;
    }

    private string get_readable_codec(Gst.Structure structure) {
        string raw = structure.get_name();
        switch (raw) {
            case "video/x-h264": return "H.264 (AVC)";
            case "video/x-h265": return "H.265 (HEVC)";
            case "video/x-vp8":  return "VP8";
            case "video/x-vp9":  return "VP9";
            case "video/x-av1":  return "AV1";
            case "video/x-theora": return "Theora";
            case "video/x-xvid":   return "Xvid (MPEG-4 Part 2)";
            case "video/x-divx":   return "DivX (MPEG-4 Part 2)";
            case "video/mpeg":
                int ver = 0;
                if (structure.get_int("mpegversion", out ver)) {
                    if (ver == 4) return "MPEG-4 Part 2 (Xvid/DivX)";
                    if (ver == 2) return "MPEG-2 Video";
                    if (ver == 1) return "MPEG-1 Video";
                }
                return "MPEG Video";
            case "video/x-raw":  return "Raw Video";
            case "audio/mpeg":
                int ver = 0;
                if (structure.get_int("mpegversion", out ver)) {
                    if (ver == 4) return "AAC (MPEG-4 Audio)";
                    if (ver == 2) return "MPEG-2 Audio";
                    if (ver == 1) return "MP3 (MPEG-1 Audio)";
                }
                return "MPEG Audio";
            case "audio/x-aac":     return "AAC Audio";
            case "audio/mp4a-latm": return "AAC (LATM)";
            case "audio/x-vorbis":  return "Vorbis";
            case "audio/x-opus":    return "Opus";
            case "audio/x-flac":    return "FLAC";
            case "audio/x-wav":     return "WAV / PCM";
            case "audio/ac3":       return "Dolby Digital (AC-3)";
            case "audio/eac3":      return "Dolby Digital Plus (E-AC-3)";
            case "subpicture/x-dvd": return "DVD Subtitles";
            case "subpicture/x-pgs": return "Bluray PGS";
            case "subtitle/x-kate": return "Kate Subtitles";
            case "text/x-raw":      return "Text Subtitles";
            default: return raw.replace("video/x-", "").replace("audio/x-", "").replace("subpicture/x-", "").up();
        }
    }

    private string get_container_name() {
        if (info == null) return "Unknown";
        var stream_info = info.get_stream_info();
        if (stream_info == null) return "Unknown";
        var caps = stream_info.get_caps();
        if (caps == null || caps.get_size() == 0) return "Unknown";
        string raw_caps = caps.get_structure(0).get_name();

        switch (raw_caps) {
            case "video/x-matroska": return "Matroska (MKV)";
            case "video/quicktime":  return "QuickTime / MP4";
            case "video/mp4":        return "MPEG-4 Part 14";
            case "video/x-msvideo":  return "AVI";
            case "application/ogg":  return "Ogg Container";
            case "application/x-id3":return "MP3 (ID3 Tagged)";
            case "audio/x-wav":      return "WAV Audio";
            case "audio/x-flac":     return "FLAC Audio";
            default: return raw_caps.replace("video/x-", "").replace("application/", "").up();
        }
    }

    private string get_duration_string() {
        if (info == null) return "00:00";
        double secs = (double)info.get_duration() / 1000000000.0;
        int h = (int)(secs / 3600);
        int m = (int)((secs % 3600) / 60);
        int s = (int)(secs % 60);
        if (h > 0) return "%d:%02d:%02d".printf(h, m, s);
        return "%02d:%02d".printf(m, s);
    }

    public void save_metadata() {
        var dialog = new AlertDialog("Metadata is Read-Only.");
        dialog.show(null);
    }
}