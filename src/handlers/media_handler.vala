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
            warning(_("Media Analysis Error: %s"), e.message);
        }
    }

    public string get_page_title() {
        return is_audio_only ? _("Audio Properties") : _("Video Properties");
    }

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
            UiHelper.add_section_header(grid, ref row, _("Embedded Images"));

            foreach (var img_struct in image_list) {
                var pixbuf = ImageHelper.pixbuf_from_sample(img_struct.sample);
                if (pixbuf != null) {
                    var img = new Gtk.Image();
                    img.set_from_pixbuf(pixbuf);
                    img.height_request = 250;
                    img.valign = Align.START;
                    img.halign = Align.START;

                    var lbl = new Label("<b>%s</b>".printf(img_struct.label));
                    lbl.valign = Align.START;
                    lbl.xalign = 1.0f;
                    lbl.use_markup = true;
                    lbl.wrap = true;
                    lbl.max_width_chars = 20;

                    grid.attach(lbl, 0, row, 1, 1);
                    grid.attach(img, 1, row, 1, 1);
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
                image_list.append({ s, get_image_label(s, _("Cover Art")) });
            }
        }
        
        len = t.get_tag_size(Gst.Tags.PREVIEW_IMAGE);
        for (uint i = 0; i < len; i++) {
            Gst.Sample? s = null;
                if (t.get_sample(Gst.Tags.PREVIEW_IMAGE, out s) && s != null) {
                image_list.append({ s, _("Preview Image") });
            }
        }
    }

    private string get_image_label(Gst.Sample sample, string default_label) {
        unowned Gst.Structure? s_info = sample.get_info();
        if (s_info == null) return default_label;

        Gst.Tag.ImageType type_enum;
        if (s_info.get_enum("image-type", typeof(Gst.Tag.ImageType), out type_enum)) {
                 switch (type_enum) {
                     case Gst.Tag.ImageType.FRONT_COVER: return _("Front Cover");
                     case Gst.Tag.ImageType.BACK_COVER: return _("Back Cover");
                     case Gst.Tag.ImageType.LEAFLET_PAGE: return _("Leaflet Page");
                     case Gst.Tag.ImageType.MEDIUM: return _("Medium / Disc");
                     case Gst.Tag.ImageType.LEAD_ARTIST: return _("Lead Artist");
                     case Gst.Tag.ImageType.ARTIST: return _("Artist");
                     case Gst.Tag.ImageType.CONDUCTOR: return _("Conductor");
                     case Gst.Tag.ImageType.BAND_ORCHESTRA: return _("Band / Orchestra");
                     case Gst.Tag.ImageType.COMPOSER: return _("Composer");
                     case Gst.Tag.ImageType.LYRICIST: return _("Lyricist");
                     case Gst.Tag.ImageType.RECORDING_LOCATION: return _("Recording Location");
                     case Gst.Tag.ImageType.DURING_RECORDING: return _("During Recording");
                     case Gst.Tag.ImageType.DURING_PERFORMANCE: return _("During Performance");
                     case Gst.Tag.ImageType.VIDEO_CAPTURE: return _("Video Capture");
                     case Gst.Tag.ImageType.FISH: return _("Fish / Icon");
                     case Gst.Tag.ImageType.ILLUSTRATION: return _("Illustration");
                     case Gst.Tag.ImageType.BAND_ARTIST_LOGO: return _("Band / Artist Logo");
                     case Gst.Tag.ImageType.PUBLISHER_STUDIO_LOGO: return _("Publisher / Studio Logo");
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
            fps = _("%.2f fps").printf((double)n / d);
            fr_mode = (n == 0) ? _("Variable (VFR)") : _("Constant (CFR)");
        } else {
            fr_mode = _("Variable (VFR)");
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
        if (tags == null) return _("Constant (CBR)");
        uint min_br = 0, max_br = 0;
        bool has_min = tags.get_uint(Gst.Tags.MINIMUM_BITRATE, out min_br);
        bool has_max = tags.get_uint(Gst.Tags.MAXIMUM_BITRATE, out max_br);
        if (has_min && has_max && min_br != max_br) return _("Variable (VBR)");
        uint nominal = 0;
        if (tags.get_uint(Gst.Tags.NOMINAL_BITRATE, out nominal)) return _("Variable (VBR)");
        return _("Constant (CBR)");
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