import Toybox.Application;
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Screen-based flashlight. Connect IQ does not expose the Fenix 8 LED,
// so the display is lit at full backlight in white or red.
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
		}
	}
}

class FlashlightDelegate extends WatchUi.BehaviorDelegate {

	hidden var _view as FlashlightView;

	function initialize(view as FlashlightView) {
		BehaviorDelegate.initialize();
		_view = view;
	}

	function onTap(evt as WatchUi.ClickEvent) as Boolean {
		_view.toggleColor();
		return true;
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
