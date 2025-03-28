package com.baseflow.geolocator.location;

import android.content.Context;
import android.location.Location;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import com.baseflow.geolocator.utils.SharedPrefsUtil;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.embedding.engine.loader.FlutterLoader;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.FlutterCallbackInformation;

public class GeolocatorBackgroundManager {
  private static final String TAG = GeolocatorBackgroundManager.class.getSimpleName();
  private static final String BACKGROUND_CHANNEL_NAME = "flutter.baseflow.com/background_geolocator_android";

  private static final FlutterLoader flutterLoader = new FlutterLoader();

  private static FlutterEngine getInitializedFlutterEngine(Context ctx) {
    Log.d("BackgroundManager", "Creating new engine");

    return new FlutterEngine(ctx);
  }

  public static void sendLocation(Context ctx, Location location) {
    Log.d(TAG, "Location: " + location.getLatitude() + ": " + location.getLongitude());
    FlutterEngine engine = getInitializedFlutterEngine(ctx);

    MethodChannel backgroundChannel = new MethodChannel(engine.getDartExecutor(), BACKGROUND_CHANNEL_NAME);
    backgroundChannel.setMethodCallHandler((call, result) -> {
      handleInitialized(call, result, ctx, backgroundChannel, location, engine);
    });

    if (!flutterLoader.initialized()) {
      flutterLoader.startInitialization(ctx);
    }
    flutterLoader.ensureInitializationCompleteAsync(ctx, null, new Handler(Looper.getMainLooper()), () -> {
      long callbackHandle = SharedPrefsUtil.getCallbackHandle(ctx);
      FlutterCallbackInformation callbackInfo = FlutterCallbackInformation.lookupCallbackInformation(callbackHandle);
      String dartBundlePath = flutterLoader.findAppBundlePath();
      engine.getDartExecutor().executeDartCallback(new DartExecutor.DartCallback(ctx.getAssets(), dartBundlePath, callbackInfo));
    });
  }

  private static void handleInitialized(MethodCall call, MethodChannel.Result result, Context ctx, MethodChannel channel, Location location, FlutterEngine engine) {
    Map<String, Object> data = new HashMap<>();

    Map<String, Object> position = LocationMapper.toHashMap(location);
    data.put("position", position);

    long callbackHandle = SharedPrefsUtil.getCallbackUserHandler(ctx);
    data.put("userCallbackHandle", callbackHandle);

    channel.invokeMethod("GeolocatorBackground#onLocation", data, new MethodChannel.Result() {
      @Override
      public void success(Object result) {
        Log.d(TAG, "Got success, destroy engine!");
        engine.destroy();
      }

      @Override
      public void error(@NonNull String errorCode, String errorMessage, Object errorDetails) {
        Log.d(TAG, "Got error, destroy engine! " + errorCode + " - " + errorMessage + " : " + errorDetails);
        engine.destroy();
      }

      @Override
      public void notImplemented() {
        Log.d(TAG, "Got not implemented, destroy engine!");
        engine.destroy();
      }
    });
  }
}
