#import "CDVParsePlugin.h"
#import <Cordova/CDV.h>
#import <Parse/Parse.h>
#import <objc/runtime.h>
#import <objc/message.h>


@implementation CDVParsePlugin

NSString *ecb;
NSString *pushOpen;

- (void)register: (CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSDictionary *args = [command.arguments objectAtIndex:0];

    NSString *appId = [args objectForKey:@"appId"];
    NSString *server = [args objectForKey:@"server"];
    NSString *clientKey = [args objectForKey:@"clientKey"];
    ecb = [args objectForKey:@"ecb"];
    pushOpen = [args objectForKey:@"pushOpen"];

    if (appId != nil && appId != nil && clientKey != nil && server != nil) {
        [Parse initializeWithConfiguration:[ParseClientConfiguration configurationWithBlock:^(id<ParseMutableClientConfiguration> configuration) {
            configuration.applicationId = appId;
            configuration.clientKey = clientKey;
            configuration.server = server;
        }]];
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    }else{
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"arguments cant be null"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getInstallationId:(CDVInvokedUrlCommand*) command
{
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        NSString *installationId = currentInstallation.installationId;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:installationId];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getInstallationObjectId:(CDVInvokedUrlCommand*) command
{
    [self.commandDelegate runInBackground:^{
        CDVPluginResult* pluginResult = nil;
        PFInstallation *currentInstallation = [PFInstallation currentInstallation];
        NSString *objectId = currentInstallation.objectId;
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:objectId];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void)getSubscriptions: (CDVInvokedUrlCommand *)command
{
    NSArray *channels = [PFInstallation currentInstallation].channels;
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:channels];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)subscribe: (CDVInvokedUrlCommand *)command
{
    if (IsAtLeastiOSVersion(@"10.0")) {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionSound | UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler:^(BOOL granted, NSError * _Nullable error){
            if( !error ){
                [[UIApplication sharedApplication] registerForRemoteNotifications];
            }
        }];
    } else if (IsAtLeastiOSVersion(@"8.0")) {
        if ([[UIApplication sharedApplication] respondsToSelector:@selector(registerUserNotificationSettings:)]) {
            UIUserNotificationSettings *settings =  [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
            [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
            [[UIApplication sharedApplication] registerForRemoteNotifications];
        }
    }

    CDVPluginResult* pluginResult = nil;
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    NSString *channel = [command.arguments objectAtIndex:0];
    [currentInstallation addUniqueObject:channel forKey:@"channels"];
    [currentInstallation saveInBackground];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)unsubscribe: (CDVInvokedUrlCommand *)command
{
    CDVPluginResult* pluginResult = nil;
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    NSString *channel = [command.arguments objectAtIndex:0];
    [currentInstallation removeObject:channel forKey:@"channels"];
    [currentInstallation saveInBackground];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}



//MARK: UNUserNotificationCenterDelegate

-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler{
    //Called when a notification is delivered to a foreground app.
    //NSLog( @"Handle push from foreground" );
    NSLog(@"Userinfo: %@", notification.request.content.userInfo);
    
    completionHandler(UNNotificationPresentationOptionAlert);
    NSString* jsString = [NSString stringWithFormat:@"%@(%@);", ecb, [self getJson:notification.request.content.userInfo]];
    
    AppDelegate* myAppDelegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    
    if ([myAppDelegate.viewController.webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
        // Cordova-iOS pre-4
        [myAppDelegate.viewController.webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:jsString waitUntilDone:NO];
    } else {
        // Cordova-iOS 4+
        [myAppDelegate.viewController.webView performSelectorOnMainThread:@selector(evaluateJavaScript:completionHandler:) withObject:jsString waitUntilDone:NO];
    }
}
-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)())completionHandler{
    //NSLog( @"Handle push from background or closed" );
    NSLog(@"Userinfo %@",response.notification.request.content.userInfo);
    
    completionHandler();
    NSString* jsString = [NSString stringWithFormat:@"%@(%@);", pushOpen, [self getJson:response.notification.request.content.userInfo]];
    
    AppDelegate* myAppDelegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    
    if ([myAppDelegate.viewController.webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
        // Cordova-iOS pre-4
        [myAppDelegate.viewController.webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:jsString waitUntilDone:NO];
    } else {
        // Cordova-iOS 4+
        [myAppDelegate.viewController.webView performSelectorOnMainThread:@selector(evaluateJavaScript:completionHandler:) withObject:jsString waitUntilDone:NO];
    }
    NSLog(@"TRACKING PUSHES AND APP OPENS");
    [PFPush handlePush:response.notification.request.content.userInfo];
    [PFAnalytics trackAppOpenedWithRemoteNotificationPayload:response.notification.request.content.userInfo];
    NSLog(@"applicationIconBadgeNumber %ld",[UIApplication sharedApplication].applicationIconBadgeNumber);
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    currentInstallation.badge = 0;
    [currentInstallation saveInBackground];
}



-(NSString *) getJson:(NSDictionary *) data {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data
                                                       options:(NSJSONWritingOptions)    (NSJSONWritingPrettyPrinted)
                                                         error:&error];
    if (! jsonData) {
        NSLog(@"getJson: error: %@", error.localizedDescription);
        return @"{}";
    } else {
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }
}




@end

@implementation AppDelegate (CDVParsePlugin)

void MethodSwizzle(Class c, SEL originalSelector) {
    NSString *selectorString = NSStringFromSelector(originalSelector);
    SEL newSelector = NSSelectorFromString([@"swizzled_" stringByAppendingString:selectorString]);
    SEL noopSelector = NSSelectorFromString([@"noop_" stringByAppendingString:selectorString]);
    Method originalMethod, newMethod, noop;
    originalMethod = class_getInstanceMethod(c, originalSelector);
    newMethod = class_getInstanceMethod(c, newSelector);
    noop = class_getInstanceMethod(c, noopSelector);
    if (class_addMethod(c, originalSelector, method_getImplementation(newMethod), method_getTypeEncoding(newMethod))) {
        class_replaceMethod(c, newSelector, method_getImplementation(originalMethod) ?: method_getImplementation(noop), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, newMethod);
    }
}

+ (void)load
{
    //MethodSwizzle([self class], @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:));
    MethodSwizzle([self class], @selector(application:didReceiveRemoteNotification:));
}

//MARK: Remote notifiations functions

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)newDeviceToken
{
    NSLog(@"didRegisterForRemoteNotificationsWithDeviceToken: %@", newDeviceToken);
    // Store the deviceToken in the current installation and save it to Parse.
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    [currentInstallation setDeviceTokenFromData:newDeviceToken];
    [currentInstallation saveInBackground];
}


@end
