
using Toybox.Graphics;
using Toybox.System;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi as WatchUi;

class DateRenderer {
	private var _font;

	function initialize() {
		_font = WatchUi.loadResource(Rez.Fonts.DateFont);
	}

	function draw(dc, geometry) {
		var today = Gregorian.info(
			Time.now(),
			Time.FORMAT_SHORT
		);

		var days = [
			"Sun", "Mon", "Tue", "Wed",
			"Thu", "Fri", "Sat"
		];

		var label =
			days[today.day_of_week - 1] + " " + today.day;

		var color =
			System.getSystemStats().battery <= 20
			? Graphics.COLOR_RED
			: Graphics.COLOR_BLACK;

		dc.setColor(color, Theme.BACKGROUND_COLOR);

		dc.drawText(
			geometry.centerX,
			geometry.centerY - 3,
			_font,
			label,
			Graphics.TEXT_JUSTIFY_CENTER |
			Graphics.TEXT_JUSTIFY_VCENTER
		);
	}
}

// kak: filetype=c
