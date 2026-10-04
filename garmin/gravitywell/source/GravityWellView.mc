using Toybox.Graphics as Gfx;
using Toybox.WatchUi as WatchUi;

class GravityWellView extends WatchUi.WatchFace {

	private var _geometry;
	private var _dial;

	private var _hands;
	private var _date;

	function initialize() {
		WatchFace.initialize();

		_geometry = null;
		_dial = new DialRenderer();
		_hands = new HandRenderer();
		_date = new DateRenderer();
	}

	function onLayout(dc) {
		_geometry = new FaceGeometry(dc);
	}

	function onShow() {
	}

	function onHide() {
	}

	function onEnterSleep() {
	}

	function onExitSleep() {
	}

	function onUpdate(dc) {
		if (_geometry == null) {
			_geometry = new FaceGeometry(dc);
		}

		dc.setColor(
			Gfx.COLOR_BLACK,
			Theme.BACKGROUND_COLOR
		);
		dc.clear();

		_dial.draw(dc, _geometry);

		var clock = System.getClockTime();

		_hands.draw(
			dc,
			_geometry,
			clock.hour,
			clock.min
		);

		_date.draw(dc, _geometry);
	}
}

// kak: filetype=c
