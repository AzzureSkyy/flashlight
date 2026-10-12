// Flashlight for Garmin Fenix 8 Solar 51mm
// Copyright (c) 2026 AzzureSkyy. All rights reserved.
// Author: AzzureSkyy - https://github.com/AzzureSkyy/flashlight

import Toybox.Application;
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// Controls the watch's built-in LED via Attention.setFlashlightMode (API 3.4.3+).
// Falls back to lighting the screen on devices without an LED.
const AUTHOR = "AzzureSkyy";

(:glance)
class FlashlightApp extends Application.AppBase {

	function initialize() {
		AppBase.initialize();
	}

	function getGlanceView() {
		return [ new FlashlightGlanceView() ];
	}

	hidden var _view as FlashlightView?;

	function getInitialView() {
		var view = new FlashlightView();
		_view = view;
		var dial = new FlashlightBarsView(view);
		return [ dial, new FlashlightBarsDelegate(dial, view) ];
	}

	function onStop(state as Dictionary?) as Void {
		if (_view != null) { _view.ledOff(); }
	}
}

class FlashlightView extends WatchUi.View {

	const LEVEL_NAMES = ["LOW", "MED", "HIGH"];

	var isRed as Boolean = false;
	var level as Number = 2;
	var isOn as Boolean = true;
	var strobe as Boolean = false;
	var hasLed as Boolean = false;
	var redOk as Boolean = false;
	var ledError as Boolean = false;
	var showHint as Boolean = true;
	hidden var _keepAlive as Timer.Timer?;
	hidden var _hintTimer as Timer.Timer?;
	hidden var _ledState as String? = null;
	hidden var _ledTimer as Timer.Timer?;
	var ledResult as Number = 0;

	function initialize() {
		View.initialize();
		hasLed = (Attention has :setFlashlightMode);
		redOk = hasLed && (Attention has :hasFlashlightColor)
			&& Attention.hasFlashlightColor(Attention.FLASHLIGHT_COLOR_RED);
		var store = Application.Storage;
		var l = store.getValue("level");
		if (l instanceof Number && l >= 0 && l < LEVEL_NAMES.size()) { level = l; }
	}

	function onShow() as Void {
		if (hasLed) {
			applyLed();
		} else {
			backlightOn();
			// Re-assert the backlight so it doesn't time out while in use.
			_keepAlive = new Timer.Timer();
			_keepAlive.start(method(:backlightOn), 4000, true);
		}
		flashHint();
	}

	function onHide() as Void {
		if (_keepAlive != null) { _keepAlive.stop(); _keepAlive = null; }
		if (_hintTimer != null) { _hintTimer.stop(); _hintTimer = null; }
		Application.Storage.setValue("level", level);
	}

	function ledOff() as Void {
		if (hasLed) {
			try {
				Attention.setFlashlightMode(Attention.FLASHLIGHT_MODE_OFF, null);
			} catch (e) {
			}
		}
	}

	function applyLed() as Void {
		if (!hasLed) { return; }
		var mode = !isOn ? Attention.FLASHLIGHT_MODE_OFF
			: (strobe ? Attention.FLASHLIGHT_MODE_STROBE : Attention.FLASHLIGHT_MODE_ON);
		try {
			var state = isRed + "|" + level + "|" + strobe;
			var changed = (_ledState != null && !state.equals(_ledState));
			_ledState = state;
			if (changed && mode != Attention.FLASHLIGHT_MODE_OFF) {
				// The LED ignores or fails changes while lit; switch off, then re-apply after a pause.
				Attention.setFlashlightMode(Attention.FLASHLIGHT_MODE_OFF, null);
				if (_ledTimer != null) { _ledTimer.stop(); }
				_ledTimer = new Timer.Timer();
				_ledTimer.start(method(:sendLed), 400, false);
				return;
			}
			sendLed();
		} catch (e) {
			ledError = true;
		}
	}

	function sendLed() as Void {
		var bright = [Attention.FLASHLIGHT_BRIGHTNESS_LOW,
			Attention.FLASHLIGHT_BRIGHTNESS_MEDIUM,
			Attention.FLASHLIGHT_BRIGHTNESS_HIGH];
		var mode = !isOn ? Attention.FLASHLIGHT_MODE_OFF
			: (strobe ? Attention.FLASHLIGHT_MODE_STROBE : Attention.FLASHLIGHT_MODE_ON);
		try {
			var opts = isRed
				? { :color => Attention.FLASHLIGHT_COLOR_RED }
				: { :color => Attention.FLASHLIGHT_COLOR_WHITE, :brightness => bright[level] };
			var res = Attention.setFlashlightMode(mode, opts);
			ledResult = res;
			ledError = (res != Attention.FLASHLIGHT_RESULT_SUCCESS);
		} catch (e) {
			ledResult = -1;
			ledError = true;
		}
		WatchUi.requestUpdate();
	}

	function toggleOn() as Void {
		isOn = !isOn;
		applyLed();
		flashHint();
	}

	function setStrobe(s as Boolean) as Void {
		strobe = s;
		isOn = true;
		applyLed();
		flashHint();
	}

	function backlightOn() as Void {
		if (Attention has :backlight) {
			try {
				Attention.backlight(true);
			} catch (e) {
				// Backlight may be throttled by the system; ignore.
			}
		}
	}

	function flashHint() as Void {
		showHint = true;
		if (_hintTimer != null) { _hintTimer.stop(); }
		_hintTimer = new Timer.Timer();
		_hintTimer.start(method(:hideHint), 2500, false);
		WatchUi.requestUpdate();
	}

	function hideHint() as Void {
		showHint = false;
		WatchUi.requestUpdate();
	}

	function toggleColor() as Void {
		setRed(!isRed);
	}

	function setLevel(n as Number) as Void {
		level = n;
		isRed = false;
		isOn = true;
		applyLed();
		if (!hasLed) { backlightOn(); }
		flashHint();
	}

	function setRed(red as Boolean) as Void {
		if (red && hasLed && !redOk) { red = false; }
		isRed = red;
		isOn = true;
		applyLed();
		flashHint();
	}

	function changeLevel(delta as Number) as Void {
		var n = level + delta;
		if (n < 0) { n = 0; }
		if (n >= LEVEL_NAMES.size()) { n = LEVEL_NAMES.size() - 1; }
		setLevel(n);
	}

	function statusText() as String {
		if (!isOn) { return "OFF"; }
		return (isRed ? "RED" : "WHITE " + LEVEL_NAMES[level]) + (strobe ? " STROBE" : "");
	}

	function onUpdate(dc as Graphics.Dc) as Void {
		var w = dc.getWidth();
		var h = dc.getHeight();
		var fg = Graphics.COLOR_WHITE;
		if (hasLed) {
			// LED does the lighting; keep the screen dark to save battery.
			dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
			dc.clear();
			var ring = !isOn ? Graphics.COLOR_DK_GRAY : (isRed ? Graphics.COLOR_RED : Graphics.COLOR_YELLOW);
			dc.setColor(ring, Graphics.COLOR_TRANSPARENT);
			dc.setPenWidth(6);
			dc.drawCircle(w / 2, h / 2, w / 2 - 8);
		} else {
			var v = isOn ? (255 * (level + 2)) / 4 : 0;
			var color = isRed ? (v << 16) : ((v << 16) | (v << 8) | v);
			dc.setColor(color, color);
			dc.clear();
			if (isOn && !isRed && level >= 1) { fg = Graphics.COLOR_BLACK; }
		}

		dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
		dc.drawText(w / 2, h / 2 - 40, Graphics.FONT_MEDIUM, statusText(),
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
		if (ledError) {
			dc.drawText(w / 2, h / 2 - 10, Graphics.FONT_XTINY, "LED unavailable",
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
		}

		if (showHint) {
			dc.drawText(w / 2, h / 2 + 10, Graphics.FONT_XTINY, "Tap: white / red  START: on/off",
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			dc.drawText(w / 2, h / 2 + 35, Graphics.FONT_XTINY, "Swipe up/down: brightness",
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			dc.drawText(w / 2, h / 2 + 60, Graphics.FONT_XTINY, "Double tap / hold: dial",
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			dc.drawText(w / 2, h - 30, Graphics.FONT_XTINY, "by " + AUTHOR,
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
		}
	}
}
