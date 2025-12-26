using Gtk;
using Gdk;
using Cairo;
using Gst;

/**
 * Thunar-Metadata-Properties package.
 * Thunar plugin to add more detailed properties pages for a wide range of file types.
 * Utils package
 */
namespace TMP.Utils {

    /**
     * Converts a GStreamer Sample (used by Audio/Video tags) into a Gdk.Texture.
     * Extracts the buffer, creates a MemoryInputStream, loads a Pixbuf, then a Texture.
     * @param sample The Gst.Sample containing the image data.
     * @return A Gdk.Pixbuf if successful, null otherwise.
     */
    public Gdk.Pixbuf? pixbuf_from_sample(Gst.Sample sample) {
        Gst.Buffer? buf = sample.get_buffer();
        if (buf == null) {
            warning("Gst Sample buffer is null");
            return null;
        }

        Gst.MapInfo map;
        // Map the buffer for reading
        if (buf.map(out map, Gst.MapFlags.READ)) {
            Gdk.Pixbuf? pixbuf = null;
            try {
                // Create a generic input stream from the raw bytes
                // Note: new Bytes() copies data in some Vala versions, 
                // but usually creates a wrapper. 'from_bytes' is safe.
                var stream = new MemoryInputStream.from_bytes(new Bytes(map.data));
                
                // Create pixbuf directly from stream
                pixbuf = new Gdk.Pixbuf.from_stream(stream, null);
                
            } catch (GLib.Error e) {
                warning("Error converting image buffer: %s", e.message);
            } finally {
                // CRITICAL FIX: Ensure unmap happens exactly once, regardless of success/fail
                buf.unmap(map);
            }
            return pixbuf;
        }
        return null;
    }
}