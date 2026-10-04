using Toybox.Graphics;
using Toybox.Math;

class HandRenderer {

	private var _hourRadius = 11;
	private var _minuteRadius = 6;
	// private var _hourWidth = 4;
	// private var _minuteWidth = 2;
	private var _tickClearance = 10;

	private var _secondaryRadius = 3;
	private var _secondaryGap = 3;
	private var _secondaryLagMinutes = 18;

	private var _minuteSecondaryRadius = 4;
	private var _minuteSecondaryGap = 36;
	private var _minuteSecondaryLeadMinutes = 24;

	private function drawGravityWell(
		dc, cx, cy, angle, radius, color
	) {
		var extension = 15;
		var buried = 5;
		var startWidth = 4.0;
		var curvature = 2.25;

		var cosA = Math.cos(angle);
		var sinA = Math.sin(angle);

		var red   = (color >> 16) & 0xFF;
		var green = (color >> 8) & 0xFF;
		var blue  = color & 0xFF;

		var halfExtent = 5;

		// lx is measured relative to the nominal circle edge.
		// Negative values are buried beneath the hour circle.
		for (var lx = -buried;
			  lx <= extension + 1;
			  lx += 1) {

			// Only the exposed part participates in tapering.
			var exposed = lx.toFloat();

			if (exposed < 0.0) {
				exposed = 0.0;
			}

			var t = exposed / extension;

			if (t > 1.0) {
				t = 1.0;
			}

			var remaining = 1.0 - t;

			var halfWidth =
				startWidth *
				Math.pow(remaining, curvature);

			for (var ly = -halfExtent;
				  ly <= halfExtent;
				  ly += 1) {

				var absY = ly.toFloat();

				if (absY < 0.0) {
					absY = -absY;
				}

				var coverage =
					halfWidth + 0.5 - absY;

				// Antialias the outer tip.
				var endCoverage =
					extension + 0.5 - exposed;

				if (endCoverage < coverage) {
					coverage = endCoverage;
				}

				if (coverage <= 0.0) {
					continue;
				}

				if (coverage > 1.0) {
					coverage = 1.0;
				}

				var r = Math.round(
					255 - (255 - red) * coverage
				).toNumber();

				var g = Math.round(
					255 - (255 - green) * coverage
				).toNumber();

				var b = Math.round(
					255 - (255 - blue) * coverage
				).toNumber();

				var pixelColor =
					(r << 16) | (g << 8) | b;

				dc.setColor(pixelColor, 0xFFFFFF);

				// Right-hand arm.
				var axial =
					radius + lx;

				var sx =
					axial * cosA - ly * sinA;

				var sy =
					axial * sinA + ly * cosA;

				dc.drawPoint(
					Math.round(cx + sx).toNumber(),
					Math.round(cy + sy).toNumber()
				);

				// Left-hand arm.
				//
				// This is equivalent to side = -1 in the
				// original renderer. ly remains unchanged.
				axial = -axial;

				sx =
					axial * cosA - ly * sinA;

				sy =
					axial * sinA + ly * cosA;

				dc.drawPoint(
					Math.round(cx + sx).toNumber(),
					Math.round(cy + sy).toNumber()
				);
			}
		}
	}

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

		var hourInterstellar =
		   tickRadius - _hourRadius - _tickClearance * 5 / 2 - _minuteRadius;

		var hourX = geometry.centerX +
		   Math.round(Math.cos(hourAngle) * hourInterstellar);

		var hourY = geometry.centerY +
		   Math.round(Math.sin(hourAngle) * hourInterstellar);

		// dc.setColor(0x000000, Theme.BACKGROUND_COLOR);
		// dc.fillCircle(hourX, hourY, _hourRadius);

		// CircleRenderer.drawSmoothCircle(
		// 	dc, hourX, hourY, _hourRadius, 0x000000
		// );

		// Curved tapered extensions behind the hour dot.
		var wellAngle =
			hourAngle + Math.PI / 2.0;

		drawGravityWell(
			dc,
			hourX,
			hourY,
			wellAngle,
			_hourRadius,
			0x000000
		);

		// Existing hour dot drawn over the attachment points.
		CircleRenderer.drawSmoothCircle(
			dc,
			hourX,
			hourY,
			_hourRadius,
			0x000000
		);

		// var secondaryOffset =
		// 	_hourRadius +
		// 	_secondaryGap +
		// 	_secondaryRadius;

		// // Move outward from the hour dot toward the bezel.
		// var secondaryX =
		// 	hourX +
		// 	Math.round(
		// 		Math.cos(hourAngle) * secondaryOffset
		// 	);

		// var secondaryY =
		// 	hourY +
		// 	Math.round(
		// 		Math.sin(hourAngle) * secondaryOffset
		// 	);

		// CircleRenderer.drawSmoothCircle(
		// 	dc,
		// 	secondaryX,
		// 	secondaryY,
		// 	_secondaryRadius,
		// 	0x000000
		// );


		// drawRing(
		// 	dc, geometry, minuteAngle,
		// 	tickRadius - _minuteRadius - _tickClearance,
		// 	_minuteRadius, _minuteWidth
		// );

		var minuteInterstellar =
			tickRadius - _minuteRadius - _tickClearance;

		var minuteX = geometry.centerX +
			Math.round(Math.cos(minuteAngle) * minuteInterstellar);

		var minuteY = geometry.centerY +
			Math.round(Math.sin(minuteAngle) * minuteInterstellar);

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

		// Decorative inner minute satellite.
		var minuteSecondaryOrbit =
			minuteInterstellar -
			_minuteRadius -
			_minuteSecondaryGap -
			_minuteSecondaryRadius;

		var minuteSecondaryAngle =
			minuteAngle +
			(_minuteSecondaryLeadMinutes *
			 Math.PI * 2.0 / 60.0);

		var minuteSecondaryX =
			geometry.centerX +
			Math.round(
				Math.cos(minuteSecondaryAngle) *
				minuteSecondaryOrbit
			);

		var minuteSecondaryY =
			geometry.centerY +
			Math.round(
				Math.sin(minuteSecondaryAngle) *
				minuteSecondaryOrbit
			);

		CircleRenderer.drawSmoothCircle(
			dc,
			minuteSecondaryX,
			minuteSecondaryY,
			_minuteSecondaryRadius,
			0xFF0000
		);

		// gravity well planet (above minute orbit)

		var secondaryOrbit =
			hourInterstellar +
			_hourRadius +
			_secondaryGap +
			_secondaryRadius;

		var secondaryAngle =
			hourAngle -
			(_secondaryLagMinutes *
			 Math.PI * 2.0 / (12.0 * 60.0));

		var secondaryX =
			geometry.centerX +
			Math.round(
				Math.cos(secondaryAngle) * secondaryOrbit
			);

		var secondaryY =
			geometry.centerY +
			Math.round(
				Math.sin(secondaryAngle) * secondaryOrbit
			);

		CircleRenderer.drawSmoothCircle(
			dc,
			secondaryX,
			secondaryY,
			_secondaryRadius,
			0x000000
		);

	}

	function drawRing(dc, geometry, angle,
							gravitywellRadius, ringRadius, width) {
		var x = geometry.centerX +
			Math.round(Math.cos(angle) * gravitywellRadius);

		var y = geometry.centerY +
			Math.round(Math.sin(angle) * gravitywellRadius);

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
