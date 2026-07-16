#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(HealthActivityPlugin, "HealthActivity",
  CAP_PLUGIN_METHOD(isAvailable, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(requestAuth, CAPPluginReturnPromise);
  CAP_PLUGIN_METHOD(getTodayActivity, CAPPluginReturnPromise);
)
