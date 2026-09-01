/*
 * Minimal libass stubs for MPV-Win-AVC (no subtitle/OSD rendering).
 * Satisfies linker on Windows; call sites are disabled or no-op.
 */

#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stddef.h>

#include "ass.h"
#include "ass_types.h"

static ASS_Track *new_empty_track(void)
{
    ASS_Track *track = calloc(1, sizeof(ASS_Track));
    if (track) {
        track->PlayResX = 384;
        track->PlayResY = 288;
        track->track_type = TRACK_TYPE_ASS;
    }
    return track;
}

int ass_library_version(void)
{
    return LIBASS_VERSION;
}

ASS_Library *ass_library_init(void)
{
    return (ASS_Library *)1;
}

void ass_library_done(ASS_Library *priv)
{
    (void)priv;
}

void ass_set_fonts_dir(ASS_Library *priv, const char *fonts_dir)
{
    (void)priv;
    (void)fonts_dir;
}

void ass_set_extract_fonts(ASS_Library *priv, int extract)
{
    (void)priv;
    (void)extract;
}

void ass_set_style_overrides(ASS_Library *priv, char **list)
{
    (void)priv;
    (void)list;
}

void ass_process_force_style(ASS_Track *track)
{
    (void)track;
}

void ass_set_message_cb(ASS_Library *priv,
                        void (*msg_cb)(int, const char *, va_list, void *),
                        void *data)
{
    (void)priv;
    (void)msg_cb;
    (void)data;
}

ASS_Renderer *ass_renderer_init(ASS_Library *priv)
{
    (void)priv;
    return (ASS_Renderer *)1;
}

void ass_renderer_done(ASS_Renderer *priv)
{
    (void)priv;
}

void ass_set_frame_size(ASS_Renderer *priv, int w, int h)
{
    (void)priv;
    (void)w;
    (void)h;
}

void ass_set_storage_size(ASS_Renderer *priv, int w, int h)
{
    (void)priv;
    (void)w;
    (void)h;
}

void ass_set_shaper(ASS_Renderer *priv, ASS_ShapingLevel level)
{
    (void)priv;
    (void)level;
}

void ass_set_margins(ASS_Renderer *priv, int t, int b, int l, int r)
{
    (void)priv;
    (void)t;
    (void)b;
    (void)l;
    (void)r;
}

void ass_set_use_margins(ASS_Renderer *priv, int use)
{
    (void)priv;
    (void)use;
}

void ass_set_pixel_aspect(ASS_Renderer *priv, double par)
{
    (void)priv;
    (void)par;
}

void ass_set_aspect_ratio(ASS_Renderer *priv, double dar, double sar)
{
    (void)priv;
    (void)dar;
    (void)sar;
}

void ass_set_font_scale(ASS_Renderer *priv, double font_scale)
{
    (void)priv;
    (void)font_scale;
}

void ass_set_hinting(ASS_Renderer *priv, ASS_Hinting ht)
{
    (void)priv;
    (void)ht;
}

void ass_set_line_spacing(ASS_Renderer *priv, double line_spacing)
{
    (void)priv;
    (void)line_spacing;
}

void ass_set_line_position(ASS_Renderer *priv, double line_position)
{
    (void)priv;
    (void)line_position;
}

void ass_get_available_font_providers(ASS_Library *priv,
                                      ASS_DefaultFontProvider **providers,
                                      size_t *size)
{
    (void)priv;
    if (providers)
        *providers = NULL;
    if (size)
        *size = 0;
}

void ass_set_fonts(ASS_Renderer *priv, const char *default_font,
                   const char *default_family, int font_provider,
                   const char *config, int update)
{
    (void)priv;
    (void)default_font;
    (void)default_family;
    (void)font_provider;
    (void)config;
    (void)update;
}

void ass_set_selective_style_override_enabled(ASS_Renderer *priv, int bits)
{
    (void)priv;
    (void)bits;
}

void ass_set_selective_style_override(ASS_Renderer *priv, ASS_Style *style)
{
    (void)priv;
    (void)style;
}

int ass_fonts_update(ASS_Renderer *priv)
{
    (void)priv;
    return 0;
}

void ass_set_cache_limits(ASS_Renderer *priv, int glyph_max, int bitmap_max_size)
{
    (void)priv;
    (void)glyph_max;
    (void)bitmap_max_size;
}

ASS_Image *ass_render_frame(ASS_Renderer *priv, ASS_Track *track,
                            long long now, int *detect_change)
{
    (void)priv;
    (void)track;
    (void)now;
    if (detect_change)
        *detect_change = 0;
    return NULL;
}

ASS_Track *ass_new_track(ASS_Library *priv)
{
    (void)priv;
    return new_empty_track();
}

int ass_track_set_feature(ASS_Track *track, ASS_Feature feature, int enable)
{
    (void)track;
    (void)feature;
    (void)enable;
    return 0;
}

void ass_free_track(ASS_Track *track)
{
    free(track);
}

int ass_alloc_style(ASS_Track *track)
{
    (void)track;
    return -1;
}

int ass_alloc_event(ASS_Track *track)
{
    (void)track;
    return -1;
}

void ass_free_style(ASS_Track *track, int sid)
{
    (void)track;
    (void)sid;
}

void ass_free_event(ASS_Track *track, int eid)
{
    (void)track;
    (void)eid;
}

void ass_process_data(ASS_Track *track, char *data, int size)
{
    (void)track;
    (void)data;
    (void)size;
}

void ass_process_codec_private(ASS_Track *track, char *data, int size)
{
    (void)track;
    (void)data;
    (void)size;
}

void ass_process_chunk(ASS_Track *track, char *data, int size,
                       long long timecode, long long duration)
{
    (void)track;
    (void)data;
    (void)size;
    (void)timecode;
    (void)duration;
}

void ass_set_check_readorder(ASS_Track *track, int check_readorder)
{
    (void)track;
    (void)check_readorder;
}

void ass_flush_events(ASS_Track *track)
{
    (void)track;
}

ASS_Track *ass_read_file(ASS_Library *library, char *fname, char *codepage)
{
    (void)library;
    (void)fname;
    (void)codepage;
    return NULL;
}

ASS_Track *ass_read_memory(ASS_Library *library, char *buf,
                           size_t bufsize, char *codepage)
{
    (void)library;
    (void)buf;
    (void)bufsize;
    (void)codepage;
    return NULL;
}

int ass_read_styles(ASS_Track *track, char *fname, char *codepage)
{
    (void)track;
    (void)fname;
    (void)codepage;
    return -1;
}

void ass_add_font(ASS_Library *library, const char *name, const char *data,
                  int data_size)
{
    (void)library;
    (void)name;
    (void)data;
    (void)data_size;
}

void ass_clear_fonts(ASS_Library *library)
{
    (void)library;
}

long long ass_step_sub(ASS_Track *track, long long now, int movement)
{
    (void)track;
    (void)now;
    (void)movement;
    return 0;
}
