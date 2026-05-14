package com.orion;

import org.qtproject.qt5.android.bindings.QtActivity;
import android.os.Bundle;
import android.util.Log;
import android.view.Window;
import android.view.WindowManager;

public class MainActivity extends QtActivity
{
	private static final String TAG = "Orion";
	private static MainActivity instance = null;
	private static boolean keepScreenOn = false;

	/**Native C++ method calls*/

	/**Activity callbacks*/
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		logMsg("Created MainActivity");
		instance = this;
		applyKeepScreenOn();
	}

	@Override
	protected void onDestroy() {
		if (instance == this)
			instance = null;

		super.onDestroy();
	}

	/**Screen-on methods called by the C++ power manager*/
	public static void setPlaybackScreenOn() {
		setKeepScreenOn(true);
	}

	public static void clearPlaybackScreenOn() {
		setKeepScreenOn(false);
	}

	private static void setKeepScreenOn(boolean enabled) {
		keepScreenOn = enabled;

		final MainActivity activity = instance;
		if (activity == null) {
			logMsg("MainActivity not ready, deferred keep-screen-on=" + enabled);
			return;
		}

		activity.runOnUiThread(new Runnable() {
			@Override
			public void run() {
				activity.applyKeepScreenOn();
			}
		});
	}

	private void applyKeepScreenOn() {
		Window window = getWindow();
		if (window == null)
			return;

		if (keepScreenOn)
			window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
		else
			window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

		logMsg("keep-screen-on=" + keepScreenOn);
	}

	/**Logger*/
	public static void logMsg(String msg)  {
		Log.w(TAG, msg);
	}
}
