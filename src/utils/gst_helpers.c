#include "gst_helpers.h"
#include <libavformat/avformat.h>
#include <libavutil/dict.h>
#include <libavutil/avutil.h>

/**
 * thunar_extract_first_attachment: Extract the first attachment from a media file using FFmpeg.
 *
 * @param path The path to the media file.
 * @param out_filename (optional) Pointer to store the filename of the attachment.
 * @param out_mime (optional) Pointer to store the MIME type of the attachment.
 *
 * @return A GBytes containing the attachment data, or NULL if no attachment found. 
 */
GBytes* thunar_extract_first_attachment(const char* path, char** out_filename, char** out_mime) {
    if (!path) return NULL;

    avformat_network_init();
    AVFormatContext *fmt = NULL;
    if (avformat_open_input(&fmt, path, NULL, NULL) < 0) {
        g_print("[C-DEBUG] avformat_open_input failed for %s\n", path);
        return NULL;
    }

    if (avformat_find_stream_info(fmt, NULL) < 0) {
        g_print("[C-DEBUG] avformat_find_stream_info failed\n");
        avformat_close_input(&fmt);
        return NULL;
    }

    for (unsigned i = 0; i < fmt->nb_streams; i++) {
        AVStream *st = fmt->streams[i];
        // Many demuxers place attachments into streams with attached_pic
        if (st->attached_pic.size > 0 && st->attached_pic.data) {
            // copy data into GBytes
            GBytes *bytes = g_bytes_new(st->attached_pic.data, st->attached_pic.size);

            // metadata: filename / mimetype
            AVDictionaryEntry *tag = NULL;
            if (out_filename) *out_filename = NULL;
            if (out_mime) *out_mime = NULL;
            tag = av_dict_get(st->metadata, "filename", NULL, 0);
            if (tag && out_filename) *out_filename = g_strdup(tag->value);
            tag = av_dict_get(st->metadata, "mimetype", NULL, 0);
            if (tag && out_mime) *out_mime = g_strdup(tag->value);

            avformat_close_input(&fmt);
            return bytes;
        }

        // Some containers expose attachments as codec type ATTACHMENT
        if (st->codecpar && st->codecpar->codec_type == AVMEDIA_TYPE_ATTACHMENT) {
            // try to read codec extradata or attached_pic
            if (st->attached_pic.size > 0 && st->attached_pic.data) {
                GBytes *bytes = g_bytes_new(st->attached_pic.data, st->attached_pic.size);
                AVDictionaryEntry *tag = NULL;
                if (out_filename) *out_filename = NULL;
                if (out_mime) *out_mime = NULL;
                tag = av_dict_get(st->metadata, "filename", NULL, 0);
                if (tag && out_filename) *out_filename = g_strdup(tag->value);
                tag = av_dict_get(st->metadata, "mimetype", NULL, 0);
                if (tag && out_mime) *out_mime = g_strdup(tag->value);
                avformat_close_input(&fmt);
                return bytes;
            }
        }
    }

    avformat_close_input(&fmt);
    return NULL;
}