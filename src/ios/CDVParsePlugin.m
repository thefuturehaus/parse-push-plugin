#import "CDVParsePlugin.h"
#import <Cordova/CDV.h>
#import <Parse/Parse.h>
#import <objc/runtime.h>
#import <objc/message.h>

@implementation CDVParsePlugin
@synthesize pushOpen, ecb;

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

- (void)setUserToInstallation:(CDVInvokedUrlCommand*) command
{
    NSDictionary *args = [command.arguments objectAtIndex:0];
    
    NSString *userID = [args objectForKey:@"userID"];
    NSString *sessionToken = [args objectForKey:@"sessionToken"];
    
    if (userID != nil){
        [PFUser becomeInBackground:sessionToken block:^(PFUser *user, NSError *error) {
            if (user != nil) {
                PFInstallation *currentInstallation = [PFInstallation currentInstallation];
                currentInstallation[@"user"] = user;
                [currentInstallation saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                    CDVPluginResult* pluginResult = nil;
                    if (succeeded) {
                        // The object has been saved.
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                    } else {
                        // There was a problem, check error.description
                        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
                    }
                    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                }];
            }else{
                CDVPluginResult* pluginResult = nil;
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error.localizedDescription];
                [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            }
        }];
    }
}

//MARK: UNUserNotificationCenterDelegate
-(void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler{
    //Called when a notification is delivered to a foreground app.
    //NSLog( @"Handle push from foreground" );
    NSLog(@"Userinfo: %@", notification.request.content.userInfo);
    
    completionHandler(UNNotificationPresentationOptionAlert);
    
    [self jsCallback:notification.request.content.userInfo withAction:ecb];
}
-(void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)())completionHandler{
    //NSLog( @"Handle push from background or closed" );
    NSLog(@"Userinfo %@",response.notification.request.content.userInfo);
    
    completionHandler();
    [self jsCallback:response.notification.request.content.userInfo withAction:pushOpen];
    
    [self trackingPushOpen:response.notification.request.content.userInfo];
}

-(void)trackingPushOpen: (NSDictionary*)userInfo {
    NSLog(@"TRACKING PUSHES AND APP OPENS");
    [PFPush handlePush:userInfo];
    [PFAnalytics trackAppOpenedWithRemoteNotificationPayload:userInfo];
    NSLog(@"applicationIconBadgeNumber %ld",[UIApplication sharedApplication].applicationIconBadgeNumber);
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    PFInstallation *currentInstallation = [PFInstallation currentInstallation];
    currentInstallation.badge = 0;
    [currentInstallation saveInBackground];
}

-(void)jsCallback:(NSDictionary *)userInfo withAction:(NSString *)pnAction{
    
    NSString* jsString = [NSString stringWithFormat:@"%@(%@);", pnAction, [self getJson:userInfo]];
    
    AppDelegate* myAppDelegate = (AppDelegate*)[[UIApplication sharedApplication]delegate];
    
    if ([myAppDelegate.viewController.webView respondsToSelector:@selector(stringByEvaluatingJavaScriptFromString:)]) {
        // Cordova-iOS pre-4
        [myAppDelegate.viewController.webView performSelectorOnMainThread:@selector(stringByEvaluatingJavaScriptFromString:) withObject:jsString waitUntilDone:NO];
    } else {
        // Cordova-iOS 4+
        [myAppDelegate.viewController.webView performSelectorOnMainThread:@selector(evaluateJavaScript:completionHandler:) withObject:jsString waitUntilDone:NO];
    }
}

-(NSString *) getJson:(NSDictionary *) data {
    NSError *error;
    NSData *jsonData;
    if (data != nil) {
        jsonData = [NSJSONSerialization dataWithJSONObject:data
                                                   options:(NSJSONWritingOptions)
                    (NSJSONWritingPrettyPrinted)
                                                     error:&error];
    }else{
        jsonData = nil;
    }
    
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
    MethodSwizzle([self class], @selector(init));
    MethodSwizzle([self class], @selector(application:didFinishLaunchingWithOptions:));
    MethodSwizzle([self class], @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:));
    MethodSwizzle([self class], @selector(application:didReceiveRemoteNotification:));
}

- (id)getParsePluginInstance
{
    return [self.viewController getCommandInstance:@"ParsePlugin"];
    
}

- (id)swizzled_init
{
    // setup observer to handle notification on cold-start
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLaunchViaNotification:)
                                                 name:@"UIApplicationDidFinishLaunchingNotification" object:nil];
    return [self swizzled_init];
}


- (void)didLaunchViaNotification:(NSNotification *)notification
{
    [self performSelector:@selector(showPushAlert:) withObject:notification afterDelay:5];
}

- (void)showPushAlert:(id) object
{
    NSNotification *notification = (NSNotification *) object;
    
    if(notification.userInfo){
        NSDictionary *content = [notification.userInfo objectForKey:@"UIApplicationLaunchOptionsRemoteNotificationKey"];
        
        CDVParsePlugin *pluginInstance = [self getParsePluginInstance];
        [pluginInstance jsCallback:content withAction:pluginInstance.pushOpen];
        [pluginInstance trackingPushOpen:content];
    }
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
