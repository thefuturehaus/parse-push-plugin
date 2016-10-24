#import <Cordova/CDV.h>
#import "AppDelegate.h"
#import <UserNotifications/UserNotifications.h>

@interface CDVParsePlugin: CDVPlugin <UNUserNotificationCenterDelegate>

- (void)getInstallationId: (CDVInvokedUrlCommand*)command;
- (void)register: (CDVInvokedUrlCommand *)command;
- (void)getInstallationObjectId: (CDVInvokedUrlCommand*)command;
- (void)getSubscriptions: (CDVInvokedUrlCommand *)command;
- (void)subscribe: (CDVInvokedUrlCommand *)command;
- (void)unsubscribe: (CDVInvokedUrlCommand *)command;
// - (void)getNotification: (CDVInvokedUrlCommand *)command;
// - (void)handleBackgroundNotification:(NSDictionary *)notification;
@end


@interface AppDelegate (CDVParsePlugin)
@end
