// Flashlight glance - Copyright (c) 2026 AzzureSkyy
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Animated glance: flashlight blinks off -> white -> off -> red.
(:glance)
class FlashlightGlanceView extends WatchUi.GlanceView {

	hidden var _frame as Number = 0;
	hidden var _timer as Timer.Timer?;

	function initialize() {
		GlanceView.initialize();
	}

	function onShow() as Void {
		_timer = new Timer.Timer();
		// Garmin recommends glance updates stay at or under 1 Hz.
		_timer.start(method(:tick), 1000, true);
	}

	function onHide() as Void {
		if (_timer != null) { _timer.stop(); _timer = null; }
	}

	function tick() as Void {
		_frame = (_frame + 1) % 4;
		WatchUi.requestUpdate();
	}

	function onUpdate(dc as Graphics.Dc) as Void {
		var h = dc.getHeight();
		var cy = h / 2;
		var on = (_frame % 2) == 1;
		var beamColor = (_frame == 3) ? Graphics.COLOR_RED : Graphics.COLOR_WHITE;

		dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
		dc.clear();

		// Body: handle on the left, head pointing right.
		var bx = 4;
		dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
		dc.fillRectangle(bx, cy - 5, 18, 10);
		dc.fillPolygon([[bx + 18, cy - 5], [bx + 26, cy - 10], [bx + 26, cy + 10], [bx + 18, cy + 5]]);
		dc.setColor(on ? beamColor : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
		dc.fillRectangle(bx + 7, cy - 2, 4, 4);

		// Beam.
		if (on) {
			dc.setColor(beamColor, Graphics.COLOR_TRANSPARENT);
			dc.fillPolygon([[bx + 27, cy - 10], [bx + 50, cy - 17], [bx + 50, cy + 17], [bx + 27, cy + 10]]);
		}

		dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
		dc.drawText(bx + 58, cy, Graphics.FONT_GLANCE, "FLASHLIGHT",
			Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
	}
}
