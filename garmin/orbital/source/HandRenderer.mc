using Toybox.Graphics;
using Toybox.Math;

class HandRenderer {

	private var _hourRadius = 11;
	private var _minuteRadius = 6;
	// private var _hourWidth = 4;
	// private var _minuteWidth = 2;
	private var _tickClearance = 10;


	function draw(dc, geometry, hours, minutes) {
		var minuteAngle =
			(minutes * Math.PI * 2.0 / 60.0)
			- Math.PI / 2.0;

		var hourAngle =
			(((hours % 12) + minutes / 60.0)
			* Math.PI * 2.0 / 12.0)
			- Math.PI / 2.0;

		var tickRadius = geometry.tickCenterRadius - 2;

		// drawRing(
		// 	dc, geometry, hourAngle,
		// 	tickRadius - _hourRadius - _tickClearance,
		// 	_hourRadius, _hourWidth
		// );

		var hourOrbital =
		   tickRadius - _hourRadius - _tickClearance * 5 / 2 - _minuteRadius;

		var hourX = geometry.centerX +
		   Math.round(Math.cos(hourAngle) * hourOrbital);

		var hourY = geometry.centerY +
		   Math.round(Math.sin(hourAngle) * hourOrbital);

		// dc.setColor(0x000000, Theme.BACKGROUND_COLOR);
		// dc.fillCircle(hourX, hourY, _hourRadius);

		CircleRenderer.drawSmoothCircle(
			dc, hourX, hourY, _hourRadius, 0x000000
		);

		// drawRing(
		// 	dc, geometry, minuteAngle,
		// 	tickRadius - _minuteRadius - _tickClearance,
		// 	_minuteRadius, _minuteWidth
		// );

		var minuteOrbital =
			tickRadius - _minuteRadius - _tickClearance;

		var minuteX = geometry.centerX +
			Math.round(Math.cos(minuteAngle) * minuteOrbital);

		var minuteY = geometry.centerY +
			Math.round(Math.sin(minuteAngle) * minuteOrbital);

		// dc.setColor(0xFF0000, Theme.BACKGROUND_COLOR);
		// dc.fillCircle(minuteX, minuteY, _minuteRadius);

		CircleRenderer.drawSmoothCircle(
			dc, minuteX, minuteY, _minuteRadius, 0xFF0000
		);

		CircleRenderer.drawSmoothAnnulus(
			dc, minuteX, minuteY,
			_minuteRadius,
			2,          // Gap
			1,          // Ring width
			0xFF0000
		);

	}

	function drawRing(dc, geometry, angle,
							orbitalRadius, ringRadius, width) {
		var x = geometry.centerX +
			Math.round(Math.cos(angle) * orbitalRadius);

		var y = geometry.centerY +
			Math.round(Math.sin(angle) * orbitalRadius);

		dc.setColor(
			Graphics.COLOR_BLACK,
			Theme.BACKGROUND_COLOR
		);

		// Concentric outlines approximate the requested thickness.
		for (var i = 0; i < width; i += 1) {
			dc.drawCircle(x, y, ringRadius - i);
		}
	}
}

// kak: filetype=c
