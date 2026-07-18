#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(WatchBridgePlugin, "WatchBridge",
  CAP_PLUGIN_METHOD(isReachable, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(updateContext, CAPPluginReturnPromise);
)
