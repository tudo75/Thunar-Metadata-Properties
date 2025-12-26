project(
        'com.github.tudo75.thunar-metadata-properties',
        ['vala', 'c'],
        version: '0.0.1',
      )

# Configure gettext for translations handling
i18n = import('i18n')
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

# Use the C compiler to locate the math library
cc = meson.get_compiler('c')
math_dep = cc.find_library('m', required : false)

# Find FFmpeg libraries via pkg-config/dependency to extract compile/link args
# Do NOT put these dependencies into the `dependencies` list passed to the
# Vala build step, otherwise valac will try to treat them as Vala packages.
# Accept a range of versions to avoid breakage when system has different FFmpeg versions
ff_avformat_dep = dependency('libavformat', version: '>=58', required: true)
ff_avutil_dep = dependency('libavutil', version: '>=56', required: true)
ffmpeg_c_args = []
ffmpeg_link_args = []

thunar_dep = dependency('thunarx-3')

vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

# A Thunar plugin must be installed into a specific system folder to work.
# We ask the 'thunarx-3' dependency where that folder is.
# This ensures that even if your distro changes paths, the build script finds the right place.
extensions_dir = thunar_dep.get_variable('extensionsdir')
# Usually prints something like: /usr/lib/x86_64-linux-gnu/thunarx-3

dependencies = [
    thunar_dep,                          # For Thunar Plugin Development
    dependency('gtk+-3.0'),                        # For UI, thunarx want gtk3 instead of gtk4
    dependency('glib-2.0'),
    dependency('gobject-2.0'),
    dependency('poppler-glib'),             # For PDFs
    dependency('gexiv2'),                   # For Images
    dependency('gstreamer-1.0'),            # For Audio/Video 
    dependency('gstreamer-pbutils-1.0'),
    dependency('gstreamer-video-1.0'),
    dependency('gstreamer-audio-1.0'),
    dependency('gstreamer-tag-1.0'),
    dependency('libarchive'),               # For Office (Zip extraction)
    dependency('libxml-2.0'),               # For Office (XML parsing)
    dependency('libgsf-1'),                 # For Legacy Office  
    math_dep
]

vala_sources = files(
  'src/main.vala',
  'src/utils/ui_helper.vala',
  'src/utils/image_helper.vala',
  'src/handlers/file_handler.vala',
  'src/handlers/image_handler.vala',
  'src/handlers/pdf_handler.vala',
  'src/handlers/media_handler.vala',
  'src/handlers/office_handler.vala',
  'src/handlers/legacy_office_handler.vala',

)

c_sources = files(
  'src/utils/gst_helpers.c',
  'src/utils/gst_helpers.h',
)

sources = vala_sources + c_sources

# Build a small static C library for the gst helpers so we can attach
# the FFmpeg dependencies only to this C target (avoids passing them to valac)
gst_helpers_src = [ 'src/utils/gst_helpers.c' ]
gst_helpers_deps = [ ff_avformat_dep, ff_avutil_dep, dependency('glib-2.0'), dependency('gobject-2.0') ]
gst_helpers = static_library('gst_helpers', gst_helpers_src, dependencies: gst_helpers_deps)

shared_library(
  'thunar-metadata-properties',
  sources: sources,
  dependencies: dependencies,
  link_with: gst_helpers,
  install: true,
  install_dir: extensions_dir, # Tells Meson to install it to the Thunar extensions folder
  name_prefix: '', # Prevents Meson from adding an extra 'lib' prefix if Thunar doesn't expect it (optional)
)

# SUBDIR INCLUSIONS
subdir('po')

valadoc = find_program('valadoc', required : false)
if valadoc.found()
    custom_target('documentation valadoc',
        input : vala_sources,
        output : 'doc',
        command : [
            valadoc,
            '-o', '../@OUTPUT@',
            '--verbose',
            '--force',
            '--internal',
            '--private',
            '--use-svg-images',
            '--package-name', meson.project_name(),
            '--package-version', meson.project_version(),
            '--vapidir', vapi_dir,
            '--pkg', 'thunarx-3',
            '--pkg', 'gtk+-3.0',
            '--pkg', 'glib-2.0',
            '--pkg', 'gobject-2.0',
            '--pkg', 'poppler-glib',
            '--pkg', 'gexiv2',
            '--pkg', 'gstreamer-1.0',
            '--pkg', 'gstreamer-pbutils-1.0',
            '--pkg', 'gstreamer-video-1.0',
            '--pkg', 'gstreamer-audio-1.0',
            '--pkg', 'gstreamer-tag-1.0',
            '--pkg', 'libarchive',
            '--pkg', 'libxml-2.0',
            '--pkg', 'libgsf-1',
            '@INPUT@'
        ],
        build_by_default : false
    )
endif
