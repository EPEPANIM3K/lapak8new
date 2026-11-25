//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <app_links/app_links_plugin_c_api.h>
#include <file_selector_windows/file_selector_windows.h>
<<<<<<< HEAD
#include <flutter_secure_storage_windows/flutter_secure_storage_windows_plugin.h>
=======
#include <url_launcher_windows/url_launcher_windows.h>
>>>>>>> c4d3b6adf1f29467316add0189fb5d57a0cafedd

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AppLinksPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AppLinksPluginCApi"));
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
<<<<<<< HEAD
  FlutterSecureStorageWindowsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterSecureStorageWindowsPlugin"));
=======
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
>>>>>>> c4d3b6adf1f29467316add0189fb5d57a0cafedd
}
