package com.baseflow.geolocator;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.app.Notification;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.location.Location;
import android.net.wifi.WifiManager;
import android.os.Binder;
import android.os.Build;
import android.os.IBinder;
import android.os.PowerManager;
import android.util.Log;

import androidx.annotation.Nullable;

import com.baseflow.geolocator.errors.ErrorCodes;
import com.baseflow.geolocator.location.BackgroundNotification;
import com.baseflow.geolocator.location.ForegroundNotificationOptions;
import com.baseflow.geolocator.location.GeolocationManager;
import com.baseflow.geolocator.location.GeolocatorBackgroundManager;
import com.baseflow.geolocator.location.LocationClient;
import com.baseflow.geolocator.location.LocationOptions;

public class GeolocatorBackgroundLocationService extends Service {
  private static final String TAG = "FlutterGeolocator";
  private static final int ONGOING_NOTIFICATION_ID = 75416;
  private static final String CHANNEL_ID = "geolocator_channel_01";
  private final String WAKELOCK_TAG = "GeolocatorLocationService:Wakelock";
  private final String WIFILOCK_TAG = "GeolocatorLocationService:WifiLock";
  private final LocalBinder binder = new LocalBinder(this);
  // Service is foreground
  private boolean isForeground = false;
  private int connectedEngines = 0;
  @Nullable private Activity activity = null;
  @Nullable private GeolocationManager geolocationManager = null;
  @Nullable private LocationClient locationClient;

  @Nullable private PowerManager.WakeLock wakeLock = null;
  @Nullable private WifiManager.WifiLock wifiLock = null;

  @Nullable private BackgroundNotification backgroundNotification = null;

  @Override
  public void onCreate() {
    super.onCreate();
    Log.d(TAG, "Creating background service.");
  }

  @Override
  public int onStartCommand(Intent intent, int flags, int startId) {
    return START_STICKY;
  }

  @Nullable
  @Override
  public IBinder onBind(Intent intent) {
    Log.d(TAG, "Binding to location service from background.");
    return binder;
  }

  @Override
  public boolean onUnbind(Intent intent) {
    Log.d(TAG, "Unbinding from location service from background.");
    return super.onUnbind(intent);
  }

  @Override
  public void onDestroy() {
    Log.d(TAG, "Destroying background location service.");

    stopLocationService();
    disableBackgroundMode();
    geolocationManager = null;
    backgroundNotification = null;

    Log.d(TAG, "Destroyed background location service.");
    super.onDestroy();
  }

  public void flutterEngineConnected() {
    connectedEngines++;
    Log.d(TAG, "Flutter engine connected from background. Connected engine count " + connectedEngines);
  }

  public void flutterEngineDisconnected() {

    connectedEngines--;
    Log.d(TAG, "Flutter engine disconnected from background. Connected engine count " + connectedEngines);
  }

  public void startLocationService(
      boolean forceLocationManager,
      LocationOptions locationOptions) {

    if (geolocationManager != null) {
      locationClient =
          geolocationManager.createLocationClient(
              this.getApplicationContext(),
              Boolean.TRUE.equals(forceLocationManager),
              locationOptions);

      geolocationManager.startPositionUpdates(
          locationClient,
          activity,
          (Location location) -> {
            GeolocatorBackgroundManager.sendLocation(this.getApplicationContext(), location);
          },
          (ErrorCodes errorCodes) ->
              Log.e(TAG, errorCodes.toDescription()));
    }
  }

  public void stopLocationService() {
    Log.d(TAG, "Stopping background location service.");
    if (locationClient != null && geolocationManager != null) {
      geolocationManager.stopPositionUpdates(locationClient);
    }
  }

  public void enableBackgroundMode(ForegroundNotificationOptions options) {
    if (backgroundNotification != null) {
      Log.d(TAG, "Background service already in foreground mode.");
      changeNotificationOptions(options);
    } else {
      Log.d(TAG, "Start background service in foreground mode.");

      backgroundNotification =
          new BackgroundNotification(
              this.getApplicationContext(), CHANNEL_ID, ONGOING_NOTIFICATION_ID, options);
      backgroundNotification.updateChannel(options.getNotificationChannelName());
      Notification notification = backgroundNotification.build();
      startForeground(ONGOING_NOTIFICATION_ID, notification);
      isForeground = true;
    }
    obtainWakeLocks(options);
  }

  @SuppressWarnings("deprecation")
  public void disableBackgroundMode() {
    Log.d(TAG, "Stop background service in foreground.");
    stopForeground(Service.STOP_FOREGROUND_REMOVE);
    releaseWakeLocks();
    isForeground = false;
    backgroundNotification = null;
    stopSelf();
  }

  public void changeNotificationOptions(ForegroundNotificationOptions options) {
    if (backgroundNotification != null) {
      backgroundNotification.updateOptions(options, isForeground);
      obtainWakeLocks(options);
    }
  }

  public void setActivity(@Nullable Activity activity) {
    this.activity = activity;
  }

  public void setGeolocationManager(@Nullable GeolocationManager geolocationManager) {
      this.geolocationManager = geolocationManager;
  }

  private void releaseWakeLocks() {
    if (wakeLock != null && wakeLock.isHeld()) {
      wakeLock.release();
      wakeLock = null;
    }
    if (wifiLock != null && wifiLock.isHeld()) {
      wifiLock.release();
      wifiLock = null;
    }
  }

  @SuppressLint("WakelockTimeout")
  private void obtainWakeLocks(ForegroundNotificationOptions options) {
    releaseWakeLocks();
    if (options.isEnableWakeLock()) {
      PowerManager powerManager =
          (PowerManager) getApplicationContext().getSystemService(Context.POWER_SERVICE);
      if (powerManager != null) {
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKELOCK_TAG);
        wakeLock.setReferenceCounted(false);
        wakeLock.acquire();
      }
    }
    if (options.isEnableWifiLock()) {
      WifiManager wifiManager =
          (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
      if (wifiManager != null) {
        wifiLock = wifiManager.createWifiLock(getWifiLockType(), WIFILOCK_TAG);
        wifiLock.setReferenceCounted(false);
        wifiLock.acquire();
      }
    }
  }

  @SuppressWarnings("deprecation")
  private int getWifiLockType() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
      return WifiManager.WIFI_MODE_FULL_HIGH_PERF;
    }
    return WifiManager.WIFI_MODE_FULL_LOW_LATENCY;
  }

  class LocalBinder extends Binder {
    private final GeolocatorBackgroundLocationService locationService;

    LocalBinder(GeolocatorBackgroundLocationService locationService) {
      this.locationService = locationService;
    }

    public GeolocatorBackgroundLocationService getLocationService() {
      return locationService;
    }
  }
}
