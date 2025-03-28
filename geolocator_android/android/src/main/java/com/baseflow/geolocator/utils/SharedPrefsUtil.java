package com.baseflow.geolocator.utils;

import android.content.Context;
import android.content.SharedPreferences;

public class SharedPrefsUtil {
  private static final String SHARED_PREFS_FILE_NAME = "background_location_tracker";

  private static final String KEY_CALLBACK_HANDLER = "background.location.tracker.manager.CALLBACK_DISPATCHER_HANDLE_KEY";
  private static final String KEY_CALLBACK_USER_HANDLER = "background.location.tracker.manager.CALLBACK_USER_DISPATCHER_HANDLE_KEY";
  private static final String KEY_IS_TRACKING = "background.location.tracker.manager.IS_TRACKING";
  private static final String KEY_LOGGING_ENABED = "background.location.tracker.manager.LOGGIN_ENABLED";
  private static final String KEY_TRACKING_INTERVAL = "background.location.tracker.manager.TRACKING_INTERVAL";
  private static final String KEY_DISTANCE_FILTER = "background.location.tracker.manager.DISTANCE_FILTER";

  private static final String KEY_NOTIFICATION_BODY = "background.location.tracker.manager.NOTIFICATION_BODY";
  private static final String KEY_NOTIFICATION_ICON = "background.location.tracker.manager.NOTIFICATION_ICON";
  private static final String KEY_NOTIFICATION_LOCATION_UPDATES_ENABLED = "background.location.tracker.manager.ENABLE_NOTIFICATION_LOCATION_UPDATES";
  private static final String KEY_CANCEL_TRACKING_ACTION_TEXT = "background.location.tracker.manager.ENABLE_CANCEL_TRACKING_TEXT";
  private static final String KEY_CANCEL_TRACKING_ACTION_ENABLED = "background.location.tracker.manager.ENABLE_CANCEL_TRACKING_ACTION";

  private static SharedPreferences prefs(Context ctx) {
    return ctx.getSharedPreferences(SHARED_PREFS_FILE_NAME, Context.MODE_PRIVATE);
  }

  public static void saveCallbackDispatcherHandleKey(Context ctx, long callbackHandle) {
    prefs(ctx).edit()
      .putLong(KEY_CALLBACK_HANDLER, callbackHandle)
      .apply();
  }

  public static long getCallbackHandle(Context ctx) {
    return prefs(ctx).getLong(KEY_CALLBACK_HANDLER, -1L);
  }

  public static boolean hasCallbackHandle(Context ctx) {
    return prefs(ctx).contains(KEY_CALLBACK_HANDLER);
  }

  public static void saveCallbackUserDispatcherHandleKey(Context ctx, long callbackHandle) {
    prefs(ctx).edit()
      .putLong(KEY_CALLBACK_USER_HANDLER, callbackHandle)
      .apply();
  }

  public static long getCallbackUserHandler(Context ctx) {
    return prefs(ctx).getLong(KEY_CALLBACK_USER_HANDLER, -1L);
  }

  public static void saveIsTracking(Context ctx, boolean isTracking) {
    prefs(ctx).edit()
      .putBoolean(KEY_IS_TRACKING, isTracking)
      .apply();
  }

  public static boolean isTracking(Context ctx) {
    return ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).getBoolean(KEY_IS_TRACKING, false);
  }

  public static void saveLoggingEnabled(Context ctx, boolean isTracking) {
    SharedPreferences.Editor editor = ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).edit();
    editor.putBoolean(KEY_LOGGING_ENABED, isTracking);
    editor.apply();
  }

  public static void saveTrackingInterval(Context ctx, long interval) {
    SharedPreferences.Editor editor = ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).edit();
    editor.putLong(KEY_TRACKING_INTERVAL, interval);
    editor.apply();
  }

  public static void saveDistanceFilter(Context ctx, float filter) {
    SharedPreferences.Editor editor = ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).edit();
    editor.putFloat(KEY_DISTANCE_FILTER, filter);
    editor.apply();
  }

  public static boolean isLoggingEnabled(Context ctx) {
    return ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).getBoolean(KEY_LOGGING_ENABED, false);
  }

  public static long trackingInterval(Context ctx) {
    return ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).getLong(KEY_TRACKING_INTERVAL, 10000);
  }

  public static float distanceFilter(Context ctx) {
    return ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).getFloat(KEY_DISTANCE_FILTER, 0.0f);
  }

  public static void saveNotificationConfig(Context ctx, String notificationBody, String notificationIcon, String cancelTrackingActionText, boolean enableNotificationLocationUpdates, boolean enableCancelTrackingAction) {
    SharedPreferences.Editor editor = ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).edit();
    editor.putString(KEY_NOTIFICATION_BODY, notificationBody);
    editor.putString(KEY_NOTIFICATION_ICON, notificationIcon);
    editor.putString(KEY_CANCEL_TRACKING_ACTION_TEXT, cancelTrackingActionText);
    editor.putBoolean(KEY_NOTIFICATION_LOCATION_UPDATES_ENABLED, enableNotificationLocationUpdates);
    editor.putBoolean(KEY_CANCEL_TRACKING_ACTION_ENABLED, enableCancelTrackingAction);
    editor.apply();
  }

  public static String getNotificationBody(Context ctx) {
    return ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).getString(KEY_NOTIFICATION_BODY, "Background tracking active. Tap to open.");
  }

  public static String getNotificationIcon(Context ctx) {
    return ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).getString(KEY_NOTIFICATION_ICON, null);
  }

  public static String getCancelTrackingActionText(Context ctx) {
    return ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).getString(KEY_CANCEL_TRACKING_ACTION_TEXT, "Stop Tracking");
  }

  public static boolean isNotificationLocationUpdatesEnabled(Context ctx) {
    return ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).getBoolean(KEY_NOTIFICATION_LOCATION_UPDATES_ENABLED, false);
  }

  public static boolean isCancelTrackingActionEnabled(Context ctx) {
    return ctx.getSharedPreferences("prefs", Context.MODE_PRIVATE).getBoolean(KEY_CANCEL_TRACKING_ACTION_ENABLED, false);
  }
}