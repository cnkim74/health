#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(GlucoseBlePlugin, "GlucoseBle",
  CAP_PLUGIN_METHOD(requestPerm, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(scanAndRead, CAPPluginReturnPromise);
)
