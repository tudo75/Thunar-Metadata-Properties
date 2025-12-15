using Gtk;
using Gdk;
using Cairo;
using Gst;

namespace ImageHelper {

    /**
     * Converts a GStreamer Sample (used by Audio/Video tags) into a Gdk.Texture.
     * Extracts the buffer, creates a MemoryInputStream, loads a Pixbuf, then a Texture.
     */
    public Gdk.Texture? texture_from_sample(Gst.Sample sample) {
        Gst.Buffer? buf = sample.get_buffer();
        if (buf == null) return null;

        Gst.MapInfo map;
        if (buf.map(out map, Gst.MapFlags.READ)) {
            try {
                // Create input stream from raw bytes
                var stream = new MemoryInputStream.from_bytes(new Bytes(map.data));
                
                // Create Pixbuf from stream (handles JPEG/PNG/etc decoding)
                var pixbuf = new Gdk.Pixbuf.from_stream(stream, null);
                
                // Convert Pixbuf to Texture for GTK4
                var texture = Gdk.Texture.for_pixbuf(pixbuf);
                
                buf.unmap(map);
                return texture;
            } catch (GLib.Error e) {
                // Squelch errors for corrupt images
            }
            buf.unmap(map);
        }
        return null;
    }
}