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

thunar_dep = dependency('thunarx-3')

vapi_dir = meson.current_source_dir() / 'vapi'
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

# A Thunar plugin must be installed into a specific system folder to work.
# We ask the 'thunarx-3' dependency where that folder is.
# This ensures that even if your distro changes paths, the build script finds the right place.
extensions_dir = thunar_dep.get_variable('extensionsdir')
# Usually prints something like: /usr/lib/x86_64-linux-gnu/thunarx-3

dependencies = [
    thunar_dep,                                    # For Thunar Plugin Development
    dependency('gtk+-3.0'),                 # For UI, thunarx want gtk3 instead of gtk4
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

sources = files(
    'src/main.vala',
    'src/utils/ui_helper.vala',
    'src/utils/image_helper.vala',
    'src/handlers/file_handler.vala',
    'src/handlers/image_handler.vala',
    'src/handlers/pdf_handler.vala',
    'src/handlers/media_handler.vala',
#    'src/handlers/office_handler.vala',
#    'src/handlers/legacy_office_handler.vala'
)

shared_library(
  'thunar-metadata-properties',
  sources: sources,
  dependencies: dependencies,
  install: true,
  install_dir: extensions_dir, # Tells Meson to install it to the Thunar extensions folder
  name_prefix: '', # Prevents Meson from adding an extra 'lib' prefix if Thunar doesn't expect it (optional)
)

# 8 SUBDIR INCLUSIONS
subdir('po')
