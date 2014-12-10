#import <Cordova/CDV.h>
#import "AppDelegate.h"

@interface CDVParsePlugin: CDVPlugin

- (void)getInstallationId: (CDVInvokedUrlCommand*)command;
- (void)getInstallationObjectId: (CDVInvokedUrlCommand*)command;
- (void)getSubscriptions: (CDVInvokedUrlCommand *)command;
- (void)subscribe: (CDVInvokedUrlCommand *)command;
- (void)unsubscribe: (CDVInvokedUrlCommand *)command;
- (void)getNotification: (CDVInvokedUrlCommand *)command;
- (void)handleBackgroundNotification:(NSDictionary *)notification;

@end

@interface AppDelegate (CDVParsePlugin)
@end
