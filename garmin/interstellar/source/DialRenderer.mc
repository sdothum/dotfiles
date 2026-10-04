
using Toybox.Graphics;
using Toybox.Math;
using Toybox.WatchUi as WatchUi;

class DialRenderer {

	private var _fourFont;
	private var _eightFont;
	private var _twelveFont;

	function initialize() {
		_fourFont = WatchUi.loadResource(Rez.Fonts.DialFour);
		_eightFont = WatchUi.loadResource(Rez.Fonts.DialEight);
		_twelveFont = WatchUi.loadResource(Rez.Fonts.DialTwelve);
	}

	function draw(dc, geometry) {
		// Draw numerals first so ticks appear over them.
		drawNumerals(dc, geometry);
		drawTicks(dc, geometry);
	}

	function drawTicks(dc, geometry) {

		// Move all ticks 2 pixels toward the center.
		var innerRadius = geometry.tickInnerRadius - 2;
		var outerRadius = geometry.tickOuterRadius - 2;
		var centerRadius = geometry.tickCenterRadius - 2;

		for (var minute = 0; minute < 60; minute += 1) {

			// Reserve numeral positions and their immediate neighbors.
			if (minute == 0  ||
				 minute == 1  ||
				 minute == 19 ||
				 minute == 20 ||
				 minute == 21 ||
				 minute == 39 ||
				 minute == 40 ||
				 minute == 41 ||
				 minute == 59) {
				continue;
			}

			var angle =
				((minute * Math.PI * 2.0) / 60.0)
				- (Math.PI / 2.0);

			var cosAngle = Math.cos(angle);
			var sinAngle = Math.sin(angle);

			var isFiveMinute = ((minute % 5) == 0);

			dc.setColor(
				Graphics.COLOR_BLACK,
				Theme.BACKGROUND_COLOR
			);

			// Diagonal five-minute markers remain dots.
			if (isFiveMinute &&
				 minute != 15 &&
				 minute != 30 &&
				 minute != 45) {

				var dotX =
					geometry.centerX +
					Math.round(cosAngle * centerRadius);

				var dotY =
					geometry.centerY +
					Math.round(sinAngle * centerRadius);

				// dc.fillCircle(dotX, dotY, 3);

				CircleRenderer.drawSmoothCircle(
					dc, dotX, dotY, 3, 0x000000
				);
				continue;
			}

			// Extend 15/30/45 ticks 1 additional pixel inward.
			var thisInnerRadius = innerRadius;

			if (minute == 15 ||
				 minute == 30 ||
				 minute == 45) {
				thisInnerRadius -= 2;
			}

			var innerX =
				geometry.centerX +
				Math.round(cosAngle * thisInnerRadius);

			var innerY =
				geometry.centerY +
				Math.round(sinAngle * thisInnerRadius);

			var outerX =
				geometry.centerX +
				Math.round(cosAngle * outerRadius);

			var outerY =
				geometry.centerY +
				Math.round(sinAngle * outerRadius);

			dc.setPenWidth(
				isFiveMinute
					? Theme.FIVE_TICK_WIDTH
					: Theme.MINUTE_TICK_WIDTH
			);

			dc.drawLine(
				innerX,
				innerY,
				outerX,
				outerY
			);
		}

		dc.setPenWidth(1);
	}

	function drawNumerals(dc, geometry) {

		dc.setColor(
			Graphics.COLOR_BLACK,
			Theme.BACKGROUND_COLOR
		);

		// Move all three numerals 2 pixels inward.
		// var radius = geometry.tickCenterRadius - 2;
		var radius = geometry.tickCenterRadius - 4;

		// 12 o'clock
		dc.drawText(
			geometry.centerX,
			geometry.centerY - radius,
			_twelveFont,
			"12",
			Graphics.TEXT_JUSTIFY_CENTER |
			Graphics.TEXT_JUSTIFY_VCENTER
		);

		// 4 o'clock
		dc.drawText(
			geometry.centerX +
				Math.round(Math.cos(Math.PI / 6.0) * radius),
			geometry.centerY +
				Math.round(Math.sin(Math.PI / 6.0) * radius),
			_fourFont,
			"4",
			Graphics.TEXT_JUSTIFY_CENTER |
			Graphics.TEXT_JUSTIFY_VCENTER
		);

		// 8 o'clock
		dc.drawText(
			geometry.centerX +
				Math.round(Math.cos(5.0 * Math.PI / 6.0) * radius),
			geometry.centerY +
				Math.round(Math.sin(5.0 * Math.PI / 6.0) * radius),
			_eightFont,
			"8",
			Graphics.TEXT_JUSTIFY_CENTER |
			Graphics.TEXT_JUSTIFY_VCENTER
		);
	}
}

// kak: filetype=c
