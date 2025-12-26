#ifndef __GST_HELPERS_H__
#define __GST_HELPERS_H__

#include <glib-object.h>

G_BEGIN_DECLS

GBytes* thunar_extract_first_attachment(const char* path, char** out_filename, char** out_mime);

G_END_DECLS

#endif /* __GST_HELPERS_H__ */