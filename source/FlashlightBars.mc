// Flashlight for Garmin Fenix 8 Solar 51mm
// Copyright (c) 2026 AzzureSkyy. All rights reserved.

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

// Four stacked bars like the built-in flashlight: HIGH, MED, LOW (white) and RED.
// Tapping or pressing START on a bar turns that setting on; doing it on the lit bar turns the light off.
class FlashlightBarsView extends WatchUi.View {

	const LABELS = ["HIGH", "MED", "LOW", "RED"];
	const RED_BAR = 3;

	hidden var _light as FlashlightView;
	var selected as Number = 0;

	function initialize(light as FlashlightView) {
		View.initialize();
		_light = light;
		selected = 2 - light.level;
	}

	function onShow() as Void {
		_light.onShow();
		WatchUi.requestUpdate();
	}

	function onHide() as Void {
		_light.onHide();
	}

	function count() as Number {
		return LABELS.size();
	}

	function isActive(i as Number) as Boolean {
		if (!_light.isOn) { return false; }
		if (i == RED_BAR) { return _light.isRed; }
		return !_light.isRed && _light.level == 2 - i;
	}

	// Used while sliding: switches to bar i but never turns the light off.
	function slideTo(i as Number) as Void {
		if (i < 0 || i == RED_BAR || isActive(i)) { return; }
		selected = i;
		_light.setLevel(2 - i);
		WatchUi.requestUpdate();
	}

	function apply(i as Number) as Void {
		selected = i;
		if (isActive(i)) {
			_light.toggleOn();
		} else if (i == RED_BAR) {
			_light.setRed(true);
		} else {
			_light.setLevel(2 - i);
		}
		WatchUi.requestUpdate();
	}

	// Arc i centre angle (degrees, 0 = 3 o'clock, counter-clockwise): HIGH top-left, MED top-right, LOW bottom-right, RED bottom-left.
	const CENTERS = [135, 45, -45, 225];
	const HALF_SPAN = 43;

	function hitTest(x as Number, y as Number, w as Number, h as Number) as Number {
		var dx = x - w / 2;
		var dy = h / 2 - y;
		if (dx * dx + dy * dy < (w / 6) * (w / 6)) { return -1; }
		var deg = Math.toDegrees(Math.atan2(dy, dx));
		if (deg < 0) { deg += 360.0; }
		// Quadrants: 0-90 MED, 90-180 HIGH, 180-270 RED, 270-360 LOW.
		if (deg < 90) { return 1; }
		if (deg < 180) { return 0; }
		if (deg < 270) { return 3; }
		return 2;
	}

	function onUpdate(dc as Graphics.Dc) as Void {
		var w = dc.getWidth();
		var h = dc.getHeight();
		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
		dc.clear();

		var cx = w / 2;
		var cy = h / 2;
		var pen = w / 9;
		var r = cx - pen / 2 - 2;
		for (var i = 0; i < LABELS.size(); i++) {
			var red = (i == RED_BAR);
			var on = isActive(i);
			var c = CENTERS[i];
			if (i == selected) {
				dc.setPenWidth(pen + 8);
				dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
				dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, c - HALF_SPAN - 1, c + HALF_SPAN + 1);
			}
			var fill = red ? (on ? Graphics.COLOR_RED : Graphics.COLOR_DK_RED)
				: (on ? Graphics.COLOR_WHITE : Graphics.COLOR_DK_GRAY);
			dc.setPenWidth(pen);
			dc.setColor(fill, Graphics.COLOR_TRANSPARENT);
			dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, c - HALF_SPAN, c + HALF_SPAN);
			var a = Math.toRadians(c);
			var lr = r - pen - 18;
			dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
			dc.drawText(cx + (lr * Math.cos(a)).toNumber(), cy - (lr * Math.sin(a)).toNumber(), Graphics.FONT_XTINY, LABELS[i],
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
		}

		dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
		dc.drawText(cx, cy, Graphics.FONT_SMALL, _light.statusText(),
			Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

		if (_light.ledError) {
			dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
			dc.drawText(w / 2, h - 30, Graphics.FONT_XTINY, "ERR " + _light.ledResult,
				Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
		}
	}
}

class FlashlightBarsDelegate extends WatchUi.BehaviorDelegate {

	hidden var _bars as FlashlightBarsView;
	hidden var _light as FlashlightView;

	function initialize(bars as FlashlightBarsView, light as FlashlightView) {
		BehaviorDelegate.initialize();
		_bars = bars;
		_light = light;
	}

	function onTap(evt as WatchUi.ClickEvent) as Boolean {
		var xy = evt.getCoordinates();
		var s = System.getDeviceSettings();
		var i = _bars.hitTest(xy[0], xy[1], s.screenWidth, s.screenHeight);
		if (i >= 0) { _bars.apply(i); }
		return true;
	}

	// Sliding a finger across the white bars switches between LOW, MED and HIGH.
	function onDrag(evt as WatchUi.DragEvent) as Boolean {
		if (evt.getType() == WatchUi.DRAG_TYPE_STOP) { return true; }
		var xy = evt.getCoordinates();
		var s = System.getDeviceSettings();
		_bars.slideTo(_bars.hitTest(xy[0], xy[1], s.screenWidth, s.screenHeight));
		return true;
	}

	// START applies the highlighted bar; UP/DOWN move the highlight.
	function onKey(evt as WatchUi.KeyEvent) as Boolean {
		if (evt.getKey() == WatchUi.KEY_ENTER) {
			_bars.apply(_bars.selected);
			return true;
		}
		return BehaviorDelegate.onKey(evt);
	}

	function onSelect() as Boolean {
		return true;
	}

	function onPreviousPage() as Boolean {
		_bars.selected = (_bars.selected + _bars.count() - 1) % _bars.count();
		WatchUi.requestUpdate();
		return true;
	}

	function onNextPage() as Boolean {
		_bars.selected = (_bars.selected + 1) % _bars.count();
		WatchUi.requestUpdate();
		return true;
	}

	function onMenu() as Boolean {
		return true;
	}

	function onSwipe(evt as WatchUi.SwipeEvent) as Boolean {
		return true;
	}

	function onBack() as Boolean {
		_light.ledOff();
		return false;
	}
}
