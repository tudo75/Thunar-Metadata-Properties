using Gtk;
using Gdk;
using Cairo;
using Gst;

namespace ImageHelper {

    /**
     * Converts a GStreamer Sample (used by Audio/Video tags) into a Gdk.Texture.
     * Extracts the buffer, creates a MemoryInputStream, loads a Pixbuf, then a Texture.
     */
    public Gdk.Pixbuf? pixbuf_from_sample(Gst.Sample sample) {
        Gst.Buffer? buf = sample.get_buffer();
        if (buf == null) {
            print();
            return null;
        }

        Gst.MapInfo map;
        if (buf.map(out map, Gst.MapFlags.READ)) {
            try {
                var stream = new MemoryInputStream.from_bytes(new Bytes(map.data));
                var pixbuf = new Gdk.Pixbuf.from_stream(stream, null);
                buf.unmap(map);
                return pixbuf;
            } catch (GLib.Error e) {
                print(_("Error converting image buffer into a pixbuf object: %s"), e.message);
            }
            buf.unmap(map);
        }
        return null;
    }
}