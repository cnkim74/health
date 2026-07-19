#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

CAP_PLUGIN(OauthPlugin, "Oauth",
  CAP_PLUGIN_METHOD(authenticate, CAPPluginReturnPromise);
)
