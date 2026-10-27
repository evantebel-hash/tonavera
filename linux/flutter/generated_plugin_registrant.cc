//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <audiotags/audiotags_plugin.h>
#include <desktop_multi_window/desktop_multi_window_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) audiotags_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AudiotagsPlugin");
  audiotags_plugin_register_with_registrar(audiotags_registrar);
  g_autoptr(FlPluginRegistrar) desktop_multi_window_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "DesktopMultiWindowPlugin");
  desktop_multi_window_plugin_register_with_registrar(desktop_multi_window_registrar);
}
