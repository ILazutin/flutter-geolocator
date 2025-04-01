#import <CoreLocation/CoreLocation.h>
#import "./include/geolocator_apple/GeolocatorPlugin.h"
#import "./include/geolocator_apple/GeolocatorPlugin_Test.h"
#import "./include/geolocator_apple/Constants/ErrorCodes.h"
#import "./include/geolocator_apple/Handlers/GeolocationHandler.h"
#import "./include/geolocator_apple/Handlers/PermissionHandler.h"
#import "./include/geolocator_apple/Handlers/PositionStreamHandler.h"
#import "./include/geolocator_apple/Utils/ActivityTypeMapper.h"
#import "./include/geolocator_apple/Utils/AuthorizationStatusMapper.h"
#import "./include/geolocator_apple/Utils/LocationAccuracyMapper.h"
#import "./include/geolocator_apple/Utils/LocationDistanceMapper.h"
#import "./include/geolocator_apple/Utils/LocationMapper.h"
#import "./include/geolocator_apple/Utils/PermissionUtils.h"
#import "./include/geolocator_apple/Handlers/LocationAccuracyHandler.h"
#import "./include/geolocator_apple/Handlers/LocationServiceStreamHandler.h"

@interface GeolocatorPlugin ()

@property(strong, nonatomic, nonnull) GeolocationHandler *geolocationHandler;

@property(strong, nonatomic, nonnull) LocationAccuracyHandler *locationAccuracyHandler;

@property(strong, nonatomic, nonnull) PermissionHandler *permissionHandler;

@property(strong, nonatomic) FlutterMethodChannel *backgroundChannel;

@property(strong, nonatomic) FlutterEngine *headlessRunner;

@property(strong, nonatomic, nonnull) NSUserDefaults *persistentState;

@property(strong, nonatomic, nonnull) NSObject<FlutterPluginRegistrar> *registrar;

@end

@implementation GeolocatorPlugin

static BOOL backgroundIsolateRun = NO;
static FlutterPluginRegistrantCallback registerPlugins = nil;

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  FlutterMethodChannel *methodChannel = [FlutterMethodChannel
                                         methodChannelWithName:@"flutter.baseflow.com/geolocator_apple"
                                         binaryMessenger:registrar.messenger];
  FlutterEventChannel *positionUpdatesEventChannel = [FlutterEventChannel
                                                      eventChannelWithName:@"flutter.baseflow.com/geolocator_updates_apple"
                                                      binaryMessenger:registrar.messenger];
  
  FlutterEventChannel *locationServiceUpdatesEventChannel = [FlutterEventChannel eventChannelWithName:@"flutter.baseflow.com/geolocator_service_updates_apple" binaryMessenger:registrar.messenger];
  
  GeolocatorPlugin *instance = [[GeolocatorPlugin alloc] init];
  [registrar addMethodCallDelegate:instance channel:methodChannel];
  
  instance.registrar = registrar;
  
  PositionStreamHandler *positionStreamHandler = [[PositionStreamHandler alloc] initWithGeolocationHandler:instance.createGeolocationHandler];
  [positionUpdatesEventChannel setStreamHandler:positionStreamHandler];
  
  LocationServiceStreamHandler *locationServiceStreamHandler = [[LocationServiceStreamHandler alloc] init];
  [locationServiceUpdatesEventChannel setStreamHandler:locationServiceStreamHandler];
  
  [instance initBackgroundChannel];
}

+ (void)setPluginRegistrantCallback:(FlutterPluginRegistrantCallback)callback {
  registerPlugins = callback;
}

- (GeolocationHandler *) createGeolocationHandler {
  if (!self.geolocationHandler) {
    self.geolocationHandler = [[GeolocationHandler alloc] init];
  }
  return self.geolocationHandler;
}

- (void) initBackgroundChannel {
  NSLog(@"STARTED INIT LOCATION BACKGROUND CHANNEL");

  self.persistentState = [NSUserDefaults standardUserDefaults];

//  self.headlessRunner = [[FlutterEngine alloc] initWithName:@"GeolocatorIsolate" project:nil allowHeadlessExecution:YES];
//  
//  self.backgroundChannel = [FlutterMethodChannel
//                                            methodChannelWithName:@"flutter.baseflow.com/background_geolocator_apple"
//                                            binaryMessenger:_headlessRunner];
//  [[self headlessRunner] addMethodCallDelegate:self channel:_backgroundChannel];
  
  NSLog(@"FINISHED INIT LOCATION BACKGROUND CHANNEL");
}

- (void) setGeolocationHandlerOverride:(GeolocationHandler *)geolocationHandler {
  self.geolocationHandler = geolocationHandler;
}

- (LocationAccuracyHandler *) createLocationAccuracyHandler {
  if (!self.locationAccuracyHandler) {
    self.locationAccuracyHandler = [[LocationAccuracyHandler alloc] init];
  }
  return self.locationAccuracyHandler;
}

- (void) setLocationAccuracyHandlerOverride:(LocationAccuracyHandler *)locationAccuracyHandler {
  self.locationAccuracyHandler = locationAccuracyHandler;
}

- (PermissionHandler *) createPermissionHandler {
  if (!self.permissionHandler) {
    self.permissionHandler = [[PermissionHandler alloc] init];
  }
  return self.permissionHandler;
}

- (void) setPermissionHandlerOverride:(PermissionHandler *)permissionHandler {
  self.permissionHandler = permissionHandler;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([@"checkPermission" isEqualToString:call.method]) {
    [self onCheckPermission:result];
  } else if ([@"requestPermission" isEqualToString:call.method]) {
    [self onRequestPermission:result];
  } else if ([@"isLocationServiceEnabled" isEqualToString:call.method]) {
    [self onIsLocationServiceEnabled:result];
  } else if ([@"getLastKnownPosition" isEqualToString:call.method]) {
    [self onGetLastKnownPosition:result];
  } else if ([@"getCurrentPosition" isEqualToString:call.method]) {
    [self onGetCurrentPositionWithArguments:call.arguments
                                     result:result];
  } else if([@"getLocationAccuracy" isEqualToString:call.method]) {
    [[self createLocationAccuracyHandler] getLocationAccuracyWithResult:result];
  } else if([@"requestTemporaryFullAccuracy" isEqualToString:call.method]) {
    NSString* purposeKey = (NSString *)call.arguments[@"purposeKey"];
    [[self createLocationAccuracyHandler] requestTemporaryFullAccuracyWithResult:result
                                                                   purposeKey:purposeKey];
  } else if ([@"openAppSettings" isEqualToString:call.method]) {
    [self openSettings:result];
  } else if ([@"openLocationSettings" isEqualToString:call.method]) {
    [self openSettings:result];
  } else if ([@"Geolocator#startTracking" isEqualToString:call.method]) {
    [self startTracking:call.arguments
                 result:result];
  } else if ([@"Geolocator#stopTracking" isEqualToString:call.method]) {
    [self stopTracking:result];
  } else if ([@"GeolocatorBackground#initialized" isEqualToString:call.method]) {
//    [self sendTrackingData:result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)startTracking:(id _Nullable)arguments
               result:(FlutterResult)result {
  NSLog(@"got START TRACKING IN BACKGROUND");
  __weak typeof(self) weakSelf = self;

  int64_t callbackHandle = [arguments[@"pluginCallbackHandle"] longLongValue];
  [self setCallbackDispatcherHandle:callbackHandle];
  
  int64_t userCallback = [arguments[@"userCallbackHandle"] longLongValue];
  [self setUserCallbackDispatcherHandle:userCallback];
  
  CLLocationAccuracy accuracy = [LocationAccuracyMapper toCLLocationAccuracy:(NSNumber *)arguments[@"accuracy"]];
  CLLocationDistance distanceFilter = [LocationDistanceMapper toCLLocationDistance:(NSNumber *)arguments[@"distanceFilter"]];
  NSNumber* pauseLocationUpdatesAutomatically = arguments[@"pauseLocationUpdatesAutomatically"];
  CLActivityType activityType = [ActivityTypeMapper toCLActivityType:(NSNumber *)arguments[@"activityType"]];
  NSNumber* allowBackgroundLocationUpdates = arguments[@"allowBackgroundLocationUpdates"];

  NSNumber* showBackgroundLocationIndicator = arguments[@"showBackgroundLocationIndicator"];
  
  [[weakSelf geolocationHandler] startListeningWithDesiredAccuracy:accuracy
                                                    distanceFilter:distanceFilter
                                 pauseLocationUpdatesAutomatically:pauseLocationUpdatesAutomatically && [pauseLocationUpdatesAutomatically boolValue]
                                   showBackgroundLocationIndicator:showBackgroundLocationIndicator && [showBackgroundLocationIndicator boolValue]
                                                      activityType:activityType
                                    allowBackgroundLocationUpdates:[allowBackgroundLocationUpdates boolValue]
                                                     resultHandler:^(CLLocation *location) {
    [weakSelf onLocationDidChange: location];
  }
                                                      errorHandler:^(NSString *errorCode, NSString *errorDescription){
    [weakSelf onLocationFailureWithErrorCode:errorCode
                            errorDescription:errorDescription];
  }];
  result(@(YES));
}

- (void)stopTracking:(FlutterResult) result {
  NSLog(@"got STOP TRACKING IN BACKGROUND");
  [_geolocationHandler stopListening];
  result(@(YES));
}

- (void)onLocationDidChange:(CLLocation *_Nullable)location {
  NSLog(@"LOCATION BACKGROUND UPDATE HANDLED:"
        "Location description: %@", [location description]);

//  if (!self.backgroundChannel) return;
  
  int64_t callbackHandle = [self getCallbackDispatcherHandle];
  
  FlutterCallbackInformation *info = [FlutterCallbackCache lookupCallbackInformation:callbackHandle];
  NSAssert(info != nil, @"failed to find callback");
  NSString *entrypoint = info.callbackName;
  NSString *uri = info.callbackLibraryPath;
  
  self.headlessRunner = [[FlutterEngine alloc] initWithName:@"GeolocatorIsolate" project:nil allowHeadlessExecution:YES];
  
  self.backgroundChannel = [FlutterMethodChannel
                                            methodChannelWithName:@"flutter.baseflow.com/background_geolocator_apple"
                            binaryMessenger:[_headlessRunner binaryMessenger]];
//  _registrar messenger
  
  [_headlessRunner runWithEntrypoint:entrypoint libraryURI:uri];
  
  if (!backgroundIsolateRun) {
    registerPlugins(_headlessRunner);
  }
  //Надо разделить на 2 метода - подписка на менеджера локаций и старт бэк-сервиса. Старт бэк-сервиса дергать отсюда и из application:didLaunch...
//  [_registrar addMethodCallDelegate:self channel:_backgroundChannel];
//  GeneratedPluginRegistrant.register(with: self)
  [_backgroundChannel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
    if ([@"GeolocatorBackground#initialized" isEqualToString:call.method]) {
      [self sendTrackingData:location
                      result:result];
    }
    // This method is invoked on the UI thread.
    // TODO
  }];
  
  NSLog(@"LOCATION BACKGROUND: onLocationDidChange finished");
//  if (callbackHandle != 0 && _backgroundChannel != nil) {
//    NSLog(@"LOCATION BACKGROUND UPDATE HANDLED:"
//          "we are in the callbackHandle condition");
//
//    int64_t userCallback = [self getUserCallbackDispatcherHandle];
//    
//    NSMutableDictionary *result = [[NSMutableDictionary alloc]initWithCapacity:2];
//    [result setObject:@(userCallback) forKey: @"userCallbackHandle"];
//    [result setObject:[LocationMapper toDictionary:location] forKey: @"position"];
//    [_backgroundChannel
//         invokeMethod:@"GeolocatorBackground#onLocation"
//          arguments:result];
//    }
  backgroundIsolateRun:YES;
}

- (void)sendTrackingData:(CLLocation *_Nullable)location
                  result:(FlutterResult) result {
  NSLog(@"LOCATION BACKGROUND UPDATE HANDLED:"
        "we are in the sendTrackingData handler");
  
  int64_t userCallback = [self getUserCallbackDispatcherHandle];
  
  NSMutableDictionary *response = [[NSMutableDictionary alloc]initWithCapacity:2];
  [response setObject:@(userCallback) forKey: @"userCallbackHandle"];
//  CLLocation *location = [[self geolocationHandler] getLastKnownPosition];
  [response setObject:[LocationMapper toDictionary:location] forKey: @"position"];
  [_backgroundChannel
   invokeMethod:@"GeolocatorBackground#onLocation"
   arguments:response];
  result(@(YES));
}

- (void)onLocationFailureWithErrorCode:(NSString *_Nonnull)errorCode
                      errorDescription:(NSString *_Nonnull)errorDescription {
  NSLog(@"LOCATION BACKGROUND UPDATE FAILURE:"
        "Error reason: %@"
        "Error description: %@", errorCode, errorDescription);
}

//- (BOOL)application:(UIApplication *)application
//    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
//  // Check to see if we're being launched due to a location event.
//  if (launchOptions[UIApplicationLaunchOptionsLocationKey] != nil) {
//    // Restart the headless service.
////    [self startGeofencingService:[self getCallbackDispatcherHandle]];
//  }
//
//  // Note: if we return NO, this vetos the launch of the application.
//  return YES;
//}


- (void)onCheckPermission:(FlutterResult) result {
  CLAuthorizationStatus status = [[self createPermissionHandler] checkPermission];
  result([AuthorizationStatusMapper toDartIndex:status]);
}

- (void)onRequestPermission:(FlutterResult)result {
  [[self createPermissionHandler]
   requestPermission:^(CLAuthorizationStatus status) {
    result([AuthorizationStatusMapper toDartIndex:status]);
  }
   errorHandler:^(NSString *errorCode, NSString *errorDescription) {
    result([FlutterError errorWithCode: errorCode
                               message: errorDescription
                               details: nil]);
  }];
}

- (void)onIsLocationServiceEnabled:(FlutterResult)result {
  dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    BOOL isEnabled = [CLLocationManager locationServicesEnabled];
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        result([NSNumber numberWithBool:isEnabled]);
    });
  });
}

- (void)onGetLastKnownPosition:(FlutterResult)result {
  if (![[self createPermissionHandler] hasPermission]) {
    result([FlutterError errorWithCode: GeolocatorErrorPermissionDenied
                               message:@"User denied permissions to access the device's location."
                               details:nil]);
    return;
  }
  
  CLLocation *location = [self.createGeolocationHandler getLastKnownPosition];
  result([LocationMapper toDictionary:location]);
}

- (void)onGetCurrentPositionWithArguments:(id _Nullable)arguments
                                   result:(FlutterResult)result {
  if (![[self createPermissionHandler] hasPermission]) {
    result([FlutterError errorWithCode: GeolocatorErrorPermissionDenied
                               message:@"User denied permissions to access the device's location."
                               details:nil]);
    return;
  }
  
  CLLocationAccuracy accuracy = [LocationAccuracyMapper toCLLocationAccuracy:(NSNumber *)arguments[@"accuracy"]];
  GeolocationHandler *geolocationHandler = [self createGeolocationHandler];
  
  [geolocationHandler requestPositionWithDesiredAccuracy:accuracy
                                           resultHandler:^(CLLocation *location) {
    result([LocationMapper toDictionary:location]);
  }
                                            errorHandler:^(NSString *errorCode, NSString *errorDescription){
    result([FlutterError errorWithCode: errorCode
                               message: errorDescription
                               details: nil]);
  }];
}


- (void)openSettings:(FlutterResult)result {
#if TARGET_OS_OSX
  NSString *urlString = @"x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices";
  BOOL success = [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
  result([[NSNumber alloc] initWithBool:success]);
#else
  [[UIApplication sharedApplication]
   openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
   options:[[NSDictionary alloc] init]
   completionHandler:^(BOOL success) {
    result([[NSNumber alloc] initWithBool:success]);
  }];
#endif
}

- (int64_t)getCallbackDispatcherHandle {
  id handle = [_persistentState objectForKey:@"callback_dispatcher_handle"];
  if (handle == nil) {
    return 0;
  }
  return [handle longLongValue];
}

- (void)setCallbackDispatcherHandle:(int64_t)handle {
  [_persistentState setObject:[NSNumber numberWithLongLong:handle]
                       forKey:@"callback_dispatcher_handle"];
}

- (int64_t)getUserCallbackDispatcherHandle {
  id handle = [_persistentState objectForKey:@"user_callback_handle"];
  if (handle == nil) {
    return 0;
  }
  return [handle longLongValue];
}

- (void)setUserCallbackDispatcherHandle:(int64_t)handle {
  [_persistentState setObject:[NSNumber numberWithLongLong:handle]
                       forKey:@"user_callback_handle"];
}

@end
