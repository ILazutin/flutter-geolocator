import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:uuid/uuid.dart';

/// An implementation of [GeolocatorPlatform] that uses method channels.
class GeolocatorAndroid extends GeolocatorPlatform {
  /// The method channel used to interact with the native platform.
  static const _methodChannel =
      MethodChannel('flutter.baseflow.com/geolocator_android');

  /// The event channel used to receive [Position] updates from the native
  /// platform.
  static const _eventChannel =
      EventChannel('flutter.baseflow.com/geolocator_updates_android');

  /// The event channel used to receive [LocationServiceStatus] updates from the
  /// native platform.
  static const _serviceStatusEventChannel =
      EventChannel('flutter.baseflow.com/geolocator_service_updates_android');

  /// Registers this class as the default instance of [GeolocatorPlatform].
  static void registerWith() {
    GeolocatorPlatform.instance = GeolocatorAndroid();
  }

  /// On Android devices you can set [forcedLocationManager]
  /// to true to force the plugin to use the [LocationManager] to determine the
  /// position instead of the [FusedLocationProviderClient]. On iOS this is
  /// ignored.
  bool forcedLocationManager = false;

  Stream<Position>? _positionStream;
  Stream<ServiceStatus>? _serviceStatusStream;

  final Uuid _uuid = const Uuid();

  bool _bgHandlerInitialized = false;

  @override
  Future<LocationPermission> checkPermission() async {
    try {
      // ignore: omit_local_variable_types
      final int permission =
          await _methodChannel.invokeMethod('checkPermission');

      return permission.toLocationPermission();
    } on PlatformException catch (e) {
      final error = _handlePlatformException(e);

      throw error;
    }
  }

  @override
  Future<LocationPermission> requestPermission() async {
    try {
      // ignore: omit_local_variable_types
      final int permission =
          await _methodChannel.invokeMethod('requestPermission');

      return permission.toLocationPermission();
    } on PlatformException catch (e) {
      final error = _handlePlatformException(e);

      throw error;
    }
  }

  @override
  Future<bool> isLocationServiceEnabled() async => _methodChannel
      .invokeMethod<bool>('isLocationServiceEnabled')
      .then((value) => value ?? false);

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    try {
      final parameters = <String, dynamic>{
        'forceLocationManager': forceLocationManager,
      };

      final positionMap =
          await _methodChannel.invokeMethod('getLastKnownPosition', parameters);

      return positionMap != null ? AndroidPosition.fromMap(positionMap) : null;
    } on PlatformException catch (e) {
      final error = _handlePlatformException(e);

      throw error;
    }
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async {
    final int accuracy =
        await _methodChannel.invokeMethod('getLocationAccuracy');
    return LocationAccuracyStatus.values[accuracy];
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
    String? requestId,
  }) async {
    requestId = requestId ?? _uuid.v4();

    try {
      Future<dynamic> positionFuture;

      final Duration? timeLimit = locationSettings?.timeLimit;

      positionFuture = _methodChannel.invokeMethod(
        'getCurrentPosition',
        {
          ...?locationSettings?.toJson(),
          'requestId': requestId,
        },
      );

      if (timeLimit != null) {
        positionFuture = positionFuture.timeout(timeLimit);
      }

      final positionMap = await positionFuture;
      return AndroidPosition.fromMap(positionMap);
    } on TimeoutException {
      final parameters = <String, dynamic>{
        'requestId': requestId,
      };
      _methodChannel.invokeMethod(
        'cancelGetCurrentPosition',
        parameters,
      );
      rethrow;
    } on PlatformException catch (e) {
      final error = _handlePlatformException(e);

      throw error;
    }
  }

  @override
  Stream<ServiceStatus> getServiceStatusStream() {
    if (_serviceStatusStream != null) {
      return _serviceStatusStream!;
    }
    var serviceStatusStream =
        _serviceStatusEventChannel.receiveBroadcastStream();

    _serviceStatusStream = serviceStatusStream
        .map((dynamic element) => ServiceStatus.values[element as int])
        .handleError((error) {
      _serviceStatusStream = null;
      if (error is PlatformException) {
        error = _handlePlatformException(error);
      }
      throw error;
    });

    return _serviceStatusStream!;
  }

  @override
  Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    if (_positionStream != null) {
      return _positionStream!;
    }
    var originalStream = _eventChannel.receiveBroadcastStream(
      locationSettings?.toJson(),
    );
    var positionStream = _wrapStream(originalStream);

    var timeLimit = locationSettings?.timeLimit;

    if (timeLimit != null) {
      positionStream = positionStream.timeout(
        timeLimit,
        onTimeout: (s) {
          _positionStream = null;
          s.addError(TimeoutException(
            'Time limit reached while waiting for position update.',
            timeLimit,
          ));
          s.close();
        },
      );
    }

    _positionStream = positionStream
        .map<Position>((dynamic element) =>
            AndroidPosition.fromMap(element.cast<String, dynamic>()))
        .handleError(
      (error) {
        if (error is PlatformException) {
          error = _handlePlatformException(error);
        }
        throw error;
      },
    );
    return _positionStream!;
  }

  Stream<dynamic> _wrapStream(Stream<dynamic> incoming) {
    return incoming.asBroadcastStream(onCancel: (subscription) {
      subscription.cancel();
      _positionStream = null;
    });
  }

  @override
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) async {
    try {
      final int status = await _methodChannel.invokeMethod(
        'requestTemporaryFullAccuracy',
        <String, dynamic>{
          'purposeKey': purposeKey,
        },
      );
      return LocationAccuracyStatus.values[status];
    } on PlatformException catch (e) {
      final error = _handlePlatformException(e);
      throw error;
    }
  }

  @override
  Future<bool> openAppSettings() async => _methodChannel
      .invokeMethod<bool>('openAppSettings')
      .then((value) => value ?? false);

  @override
  Future<bool> openLocationSettings() async => _methodChannel
      .invokeMethod<bool>('openLocationSettings')
      .then((value) => value ?? false);

  Exception _handlePlatformException(PlatformException exception) {
    switch (exception.code) {
      case 'ACTIVITY_MISSING':
        return ActivityMissingException(exception.message);
      case 'LOCATION_SERVICES_DISABLED':
        return const LocationServiceDisabledException();
      case 'LOCATION_SUBSCRIPTION_ACTIVE':
        return const AlreadySubscribedException();
      case 'PERMISSION_DEFINITIONS_NOT_FOUND':
        return PermissionDefinitionsNotFoundException(exception.message);
      case 'PERMISSION_DENIED':
        return PermissionDeniedException(exception.message);
      case 'PERMISSION_REQUEST_IN_PROGRESS':
        return PermissionRequestInProgressException(exception.message);
      case 'LOCATION_UPDATE_FAILURE':
        return PositionUpdateException(exception.message);
      default:
        return exception;
    }
  }

  @override
  Future<void> startTracking({
    required BackgroundPositionUpdatesHandler handler,
    LocationSettings? locationSettings,
  }) async {
    if (!_bgHandlerInitialized) {
      _bgHandlerInitialized = true;
      final CallbackHandle bgHandle = PluginUtilities.getCallbackHandle(
        _geolocatorCallbackDispatcher,
      )!;
      final CallbackHandle userHandle =
          PluginUtilities.getCallbackHandle(handler)!;
      await _methodChannel.invokeMapMethod('Geolocator#startTracking', {
        'pluginCallbackHandle': bgHandle.toRawHandle(),
        'userCallbackHandle': userHandle.toRawHandle(),
        'locationSettings': locationSettings?.toJson(),
      });
    }
  }

  @override
  Future<void> stopTracking() async {
    await _methodChannel.invokeMethod('Geolocator#stopTracking');
  }
}

@pragma('vm:entry-point')
void _geolocatorCallbackDispatcher() {
  // Initialize state necessary for MethodChannels.
  WidgetsFlutterBinding.ensureInitialized();

  const backgroundChannel =
      MethodChannel('flutter.baseflow.com/background_geolocator_android');

  // This is where we handle background events from the native portion of the plugin.
  backgroundChannel.setMethodCallHandler((MethodCall call) async {
    if (call.method == 'GeolocatorBackground#onLocation') {
      final CallbackHandle handle =
          CallbackHandle.fromRawHandle(call.arguments['userCallbackHandle']);

      // PluginUtilities.getCallbackFromHandle performs a lookup based on the
      // callback handle and returns a tear-off of the original callback.
      final closure = PluginUtilities.getCallbackFromHandle(handle)!
          as BackgroundPositionUpdatesHandler;

      try {
        Map<String, dynamic> positionMap =
            Map<String, dynamic>.from(call.arguments['position']);
        final Position position = AndroidPosition.fromMap(positionMap);
        await closure(position);
      } catch (e) {
        // ignore: avoid_print
        print(
            'Geolocator Android: An error occurred in your background handler:');
        // ignore: avoid_print
        print(e);
      }
    } else {
      throw UnimplementedError('${call.method} has not been implemented');
    }
  });

  // Once we've finished initializing, let the native portion of the plugin
  // know that it can start scheduling alarms.
  backgroundChannel.invokeMethod<void>('GeolocatorBackground#initialized');
}
