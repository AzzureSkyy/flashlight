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

// Screen-based flashlight. Connect IQ does not expose the Fenix 8 LED,
// so the display is lit at full backlight in white or red.
const AUTHOR = "AzzureSkyy";

class FlashlightApp extends Application.AppBase {

	function initialize() {
		AppBase.initialize();
	}

	function getInitialView() {
		var view = new FlashlightView();
		return [ view, new FlashlightDelegate(view) ];
	}
}

class FlashlightView extends WatchUi.View {

	// Brightness steps (percent of full colour intensity).
	const LEVELS = [25, 50, 75, 100];

	var isRed as Boolean = false;
	var level as Number = 3;
	var showHint as Boolean = true;
	hidden var _keepAlive as Timer.Timer?;
	hidden var _hintTimer as Timer.Timer?;

	function initialize() {
		View.initialize();
		var store = Application.Storage;
		var r = store.getValue("red");
		var l = store.getValue("level");
		if (r instanceof Boolean) { isRed = r; }
		if (l instanceof Number && l >= 0 && l < LEVELS.size()) { level = l; }
	}

	function onShow() as Void {
		backlightOn();
		// Re-assert the backlight so it doesn't time out while in use.
		_keepAlive = new Timer.Timer();
		_keepAlive.start(method(:backlightOn), 4000, true);
		flashHint();
	}

	function onHide() as Void {
		if (_keepAlive != null) { _keepAlive.stop(); _keepAlive = null; }
		if (_hintTimer != null) { _hintTimer.stop(); _hintTimer = null; }
		Application.Storage.setValue("red", isRed);
		Application.Storage.setValue("level", level);
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
		isRed = !isRed;
		flashHint();
	}

	function setLevel(n as Number) as Void {
		level = n;
		backlightOn();
		flashHint();
	}

	function setRed(red as Boolean) as Void {
		isRed = red;
		flashHint();
	}

	function changeLevel(delta as Number) as Void {
		var n = level + delta;
		if (n < 0) { n = 0; }
		if (n >= LEVELS.size()) { n = LEVELS.size() - 1; }
		level = n;
		backlightOn();
		flashHint();
	}

	function onUpdate(dc as Graphics.Dc) as Void {
		var v = (255 * LEVELS[level]) / 100;
		var color = isRed ? (v << 16) : ((v << 16) | (v << 8) | v);
		dc.setColor(color, color);
		dc.clear();

		if (showHint) {
			var w = dc.getWidth();
			var h = dc.getHeight();
			var fg = (!isRed && LEVELS[level] >= 50) ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
			dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
			dc.drawText(w / 2, h / 2 - 40, Graphics.FONT_MEDIUM,
				(isRed ? "RED " : "WHITE ") + LEVELS[level] + "%",
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
			dc.drawText(w / 2, h / 2 + 10, Graphics.FONT_XTINY, "Tap: white / red",
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

class FlashlightDelegate extends WatchUi.BehaviorDelegate {

	hidden var _view as FlashlightView;
	hidden var _tapTimer as Timer.Timer?;

	function initialize(view as FlashlightView) {
		BehaviorDelegate.initialize();
		_view = view;
	}

	// A single tap toggles colour; a second tap within 350 ms opens the dial instead.
	function onTap(evt as WatchUi.ClickEvent) as Boolean {
		if (_tapTimer != null) {
			_tapTimer.stop();
			_tapTimer = null;
			openDial();
		} else {
			_tapTimer = new Timer.Timer();
			_tapTimer.start(method(:singleTap), 350, false);
		}
		return true;
	}

	function singleTap() as Void {
		_tapTimer = null;
		_view.toggleColor();
	}

	function onHold(evt as WatchUi.ClickEvent) as Boolean {
		openDial();
		return true;
	}

	function onMenu() as Boolean {
		openDial();
		return true;
	}

	function openDial() as Void {
		var dial = new FlashlightDialView(_view);
		WatchUi.pushView(dial, new FlashlightDialDelegate(dial), WatchUi.SLIDE_IMMEDIATE);
	}

	function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
		var d = evt.getDirection();
		if (d == WatchUi.SWIPE_UP) { _view.changeLevel(1); return true; }
		if (d == WatchUi.SWIPE_DOWN) { _view.changeLevel(-1); return true; }
		return false;
	}

	// Buttons work too: START toggles colour, UP/DOWN change brightness.
	function onSelect() as Boolean {
		_view.toggleColor();
		return true;
	}

	function onPreviousPage() as Boolean {
		_view.changeLevel(1);
		return true;
	}

	function onNextPage() as Boolean {
		_view.changeLevel(-1);
		return true;
	}
}

// Circular dial: 25/50/75/100% around the ring plus White and Red.
class FlashlightDialView extends WatchUi.View {

	const LABELS = ["25", "50", "75", "100", "RED", "WHITE"];

	hidden var _light as FlashlightView;
	var selected as Number = 0;

	function initialize(light as FlashlightView) {
		View.initialize();
		_light = light;
		selected = light.level;
	}

	function count() as Number {
		return LABELS.size();
	}

	// Segment i is centred at angle i*60 degrees, starting at the top, clockwise.
	function segmentCenter(i as Number, cx as Number, cy as Number, r as Number) as Array<Number> {
		var a = Math.toRadians(i * 360.0 / LABELS.size() - 90.0);
		return [cx + (r * Math.cos(a)).toNumber(), cy + (r * Math.sin(a)).toNumber()];
	}

	function hitTest(x as Number, y as Number, w as Number, h as Number) as Number {
		var dx = x - w / 2;
		var dy = y - h / 2;
		if (dx * dx + dy * dy < (w / 5) * (w / 5)) { return -1; }
		var deg = Math.toDegrees(Math.atan2(dy, dx)) + 90.0;
		deg += 30.0;
		while (deg < 0) { deg += 360.0; }
		return ((deg / 60.0).toNumber()) % LABELS.size();
	}

	function apply(i as Number) as Void {
		if (i < 4) {
			_light.setLevel(i);
		} else {
			_light.setRed(i == 4);
		}
	}

	function isActive(i as Number) as Boolean {
		if (i < 4) { return _light.level == i; }
		return _light.isRed == (i == 4);
	}

	function onUpdate(dc as Graphics.Dc) as Void {
		var w = dc.getWidth();
		var h = dc.getHeight();
		var cx = w / 2;
		var cy = h / 2;
		var r = (w * 36) / 100;
		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
		dc.clear();

		dc.setPenWidth(3);
		dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
		dc.drawCircle(cx, cy, r);

		var bubble = w / 9;
		for (var i = 0; i < LABELS.size(); i++) {
			var p = segmentCenter(i, cx, cy, r);
			var fill = Graphics.COLOR_DK_GRAY;
			if (i == 4) { fill = Graphics.COLOR_DK_RED; }
			if (isActive(i)) { fill = (i == 4) ? Graphics.COLOR_RED : Graphics.COLOR_YELLOW; }
			dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
			dc.fillCircle(p[0], p[1], bubble);
			if (i == selected) {
				dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
				dc.drawCircle(p[0], p[1], bubble + 4);
			}
			dc.setColor(isActive(i) && i != 4 ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.drawText(p[0], p[1], Graphics.FONT_XTINY, LABELS[i],
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
		}

		dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
		dc.drawText(cx, cy, Graphics.FONT_TINY, "DONE",
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
		dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
		dc.drawText(cx, cy + 28, Graphics.FONT_XTINY, AUTHOR,
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
	}
}

class FlashlightDialDelegate extends WatchUi.BehaviorDelegate {

	hidden var _dial as FlashlightDialView;

	function initialize(dial as FlashlightDialView) {
		BehaviorDelegate.initialize();
		_dial = dial;
	}

	function onTap(evt as WatchUi.ClickEvent) as Boolean {
		var xy = evt.getCoordinates();
		var s = System.getDeviceSettings();
		var i = _dial.hitTest(xy[0], xy[1], s.screenWidth, s.screenHeight);
		if (i < 0) {
			WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
		} else {
			_dial.selected = i;
			_dial.apply(i);
			WatchUi.requestUpdate();
		}
		return true;
	}

	// UP/DOWN rotate the highlight round the ring, START applies it.
	function onPreviousPage() as Boolean {
		_dial.selected = (_dial.selected + _dial.count() - 1) % _dial.count();
		WatchUi.requestUpdate();
		return true;
	}

	function onNextPage() as Boolean {
		_dial.selected = (_dial.selected + 1) % _dial.count();
		WatchUi.requestUpdate();
		return true;
	}

	function onSelect() as Boolean {
		_dial.apply(_dial.selected);
		WatchUi.requestUpdate();
		return true;
	}

	function onMenu() as Boolean {
		WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
		return true;
	}
}
