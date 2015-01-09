Phonegap Parse.com Plugin
=========================

Phonegap 3.x plugin for Parse.com push service.

[Parse.com's](http://parse.com) Javascript API has no mechanism to register a device for or receive push notifications, which
makes it fairly useless for PN in Phonegap/Cordova. This plugin bridges the gap by leveraging native Parse.com SDKs
to register/receive PNs and allow a few essential methods to be accessible from Javascript. 

For Android, Parse SDK v1.8.0 is used. This means GCM support and no more background process `PushService` unnecessarily
taps device battery to duplicate what GCM already provides.

This plugin exposes the four native Android API push services to JS:
* **register**( options, successCB, errorCB )   -- register the device + a JS event callback (when a PN is received)
* **getInstallationId**( successCB, errorCB )
* **getSubscriptions**( successCB, errorCB )
* **subscribe**( channel, successCB, errorCB )
* **unsubscribe**( channel, successCB, errorCB )

Installation
------------

Pick one of these two commands:

```
phonegap local plugin add https://github.com/cookys/parse-push-plugin
cordova plugin add https://github.com/cookys/parse-push-plugin
```

####Android devices

Now uses 1.8.0 SDK

##### Android devices without Google Cloud Messaging:
If you only care about GCM devices, you're good to go. Move on to the [Usage](#usage) section. 

The automatic setup above does not work for non-GCM devices. To support them, the `ParseBroadcastReceiver`
must be setup to work properly. My guess is this receiver takes care of establishing a persistent connection that will
handle push notifications without GCM. Follow these steps for `ParseBroadcastReceiver` setup:

1. Add the following to your AndroidManifest.xml, inside the `<application>` tag
    ```xml
    <receiver android:name="com.parse.ParseBroadcastReceiver">
       <intent-filter>
          <action android:name="android.intent.action.BOOT_COMPLETED" />
          <action android:name="android.intent.action.USER_PRESENT" />
       </intent-filter>
    </receiver>
    ```
    
2. Add the following permission to AndroidManifest.xml, as a sibling of the `<application>` tag
    ```xml
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    ```
On the surface, step 1 & 2 should be enough. However, when one of the actions `BOOT_COMPLETED` or
`USER_PRESENT` (on screen unlock) occurs, `ParseBroadastReceiver` gets invoked well before your Javascript
code or this plugin's Java code gets a chance to call `Parse.initialize()`. The Parse SDK then barfs, causing
your app to crash. Continue with steps 3 & 4 to fix this.

3. Phonegap/Cordova doesn't seem to define its own android.app.Application, it only defines an android Activity.
We'll need to define an application class to override the default `onCreate` behavior and call `Parse.initialize()`
so the crash described above does not occur. In your application's Java source path, e.g., `platforms/android/src/com/example/app`, create a file
named MainApplication.java and define it this way
    ```java
    package com.example.app;  //REPLACE THIS WITH YOUR package name

    import android.app.Application;
    import com.parse.Parse;

    public class MainApplication extends Application {
	    @Override
        public void onCreate() {
            super.onCreate();
            Parse.initialize(this, "YOUR_PARSE_APPID", "YOUR_PARSE_CLIENT_KEY");
            //ParseInstallation.getCurrentInstallation().saveInBackground();
        }
    }
    ```
4. The final step is to register MainApplication in AndroidManifest.xml so it's used instead of the default.
In the `<application>` tag, add the attribute `android:name="MainApplication"`. Obviously, you don't have
to name your application class this way, but you have to use the same name in 3 and 4. 

####iOS device

Now uses 1.6.1 SDK


##### Add this to your AppDelegates didFinishLaunchingWithOptions
```objective-c

[Parse setApplicationId:@"Your Application ID" clientKey:@"Your Client Key"];

//-- Set Notification
if ([application respondsToSelector:@selector(isRegisteredForRemoteNotifications)])
{
       // iOS 8 Notifications
       [application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];

       [application registerForRemoteNotifications];
}
else
{
      // iOS < 8 Notifications
      [application registerForRemoteNotificationTypes:
                 (UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound)];
}
return YES;
    
```

####Windows Phone 8 device

Now uses 1.3.2 SDK

Get your APP_ID and .NET_KEY from [Parse.com quickstart](https://www.parse.com/apps/quickstart#parse_push/windows_phone/existing) and add them below initialization code at ```App()``` in `App.xaml.cs`.
```c#
            // Parse initialization
            ParseClient.Initialize("APP_ID", ".NET_KEY");

            this.Startup += async (sender, args) =>
            {
                ParseAnalytics.TrackAppOpens(RootFrame);
                await ParseInstallation.CurrentInstallation.SaveAsync();
            };
```
The notification toast on WP8 won't show up when your app is in forground. To quickly fix that, this plugin will auto add a callback to pop a messagebox after calling ``` parsePlugin.subscribe ```.

Usage
-----
Once the device is ready, call ```parsePlugin.register()```. This will register the device with Parse, you should see this reflected in your Parse control panel.
You can optionally specify an event callback to be invoked when a push notification is received.
After successful registration, you can call any of the other available methods.

```javascript
<script type="text/javascript">
	parsePlugin.register({
	appId:"PARSE_APPID", clientKey:"PARSE_CLIENT_KEY", ecb:"onNotification"}, 
	function() {
		alert('successfully registered device!');
		doWhatever();
	}, function(e) {
		alert('error registering device: ' + e);
	});
	
	function doWhatever(){
	    parsePlugin.getInstallationId(function(id) {
		    alert(id);
	    }, function(e) {
		    alert('error');
	    });
	    
	    parsePlugin.getSubscriptions(function(subscriptions) {
		    alert(subscriptions);
	    }, function(e) {
		    alert('error');
	    });
	
	    parsePlugin.subscribe('SampleChannel', function() {
		    alert('OK');
	    }, function(e) {
		    alert('error');
	    });
	
	    parsePlugin.unsubscribe('SampleChannel', function(msg) {
		    alert('OK');
	    }, function(e) {
		    alert('error');
	    });
	}
	
	function onNotification(pnObj){
    	alert("received pn: " + JSON.stringify(pnObj));
	}
</script>
```

Silent Notifications
--------------------
For Android, a silent notification can be sent if you omit the `title` and `alert` fields in the
JSON payload. If you register an **ecb** as shown above, it will still be invoked and you can
do whatever processing needed on the other fields of the payload.


Compatibility
-------------
Phonegap > 3.0.0
