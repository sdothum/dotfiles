using Toybox.Graphics;
using Toybox.Math;

class HandRenderer {

	private var _hourRadius = 13;
	private var _hourGap = 24;
	private var _hourOuterGap = 2;
	private var _hourOuterWidth = 1;
	private var _minuteRadius = 6;
	private var _minuteGap = 18;
	private var _minuteInnerGap = 3;
	private var _minuteInnerWidth = 1;
	// private var _minuteOuterGap = 4;
	// private var _minuteOuterWidth = 1;
	private var _secondsRadius = 5;
	private var _secondsTickGap = 3;
	private var _secondsColor = 0xff0000;

	private var _extension = 31;
	private var _gravityPull = 13;
	private var _wellWidth = 6.0;
	private var _wellCurvarture = 4.00;
	private var _steepness = 4.0;
	private var _influence = 30.0;

	private var _secondaryRadius = 5;
	private var _secondaryGap = 12;
	private var _secondaryLagMinutes = 0;

	// private var _tertiaryRadius = 2;
	// private var _tertiaryGap = 24;
	// private var _tertiaryLagMinutes = 0;

	private var _minuteSecondaryRadius = 3;
	private var _minuteSecondaryGap = -33;
	private var _minuteSecondaryLeadMinutes = 0;

	function proximityValue(minuteAngle, hourAngle, maxValue, rangeDegrees) {
		var delta = minuteAngle - hourAngle;

		if (delta < 0.0) {
			delta = -delta;
		}

		if (delta > Math.PI) {
			delta = 2.0 * Math.PI - delta;
		}

		var range = rangeDegrees * Math.PI / 180.0;

		if (delta >= range) {
			return 0.0;
		}

		var t = 1.0 - delta / range;
		var steepness = _steepness;

		return maxValue *
			(Math.pow(2.718281828459045, steepness * t) - 1.0) /
			(Math.pow(2.718281828459045, steepness) - 1.0);
	}

	private function drawGravityWell(
		dc, cx, cy, angle, radius, color
	) {
		var buried = 5;
		var extension = _extension + buried;
		var startWidth = _wellWidth;
		var curvature = _wellCurvarture;

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

		var hourInterstellar =
		   tickRadius - _hourRadius - _minuteGap - _minuteRadius - _hourGap;

		var hourX = geometry.centerX +
		   Math.round(Math.cos(hourAngle) * hourInterstellar);

		var hourY = geometry.centerY +
		   Math.round(Math.sin(hourAngle) * hourInterstellar);

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

		CircleRenderer.drawSmoothAnnulus(
			dc, hourX, hourY,
			_hourRadius,
			_hourOuterGap,
			_hourOuterWidth,
			0x000000
		);

		// gravity well planet

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

		// var tertiaryOrbit =
		// 	hourInterstellar +
		// 	_hourRadius +
		// 	_tertiaryGap +
		// 	_tertiaryRadius;

		// var tertiaryAngle =
		// 	hourAngle -
		// 	(_tertiaryLagMinutes *
		// 	 Math.PI * 2.0 / (12.0 * 60.0));

		// var tertiaryX =
		// 	geometry.centerX +
		// 	Math.round(
		// 		Math.cos(tertiaryAngle) * tertiaryOrbit
		// 	);

		// var tertiaryY =
		// 	geometry.centerY +
		// 	Math.round(
		// 		Math.sin(tertiaryAngle) * tertiaryOrbit
		// 	);

		// CircleRenderer.drawSmoothCircle(
		// 	dc,
		// 	tertiaryX,
		// 	tertiaryY,
		// 	_tertiaryRadius,
		// 	0x000000
		// );

		var gravityPull = proximityValue(minuteAngle, hourAngle, _gravityPull, _influence );

		var minuteInterstellar =
			// tickRadius - _minuteRadius - _minuteGap;
			tickRadius - _minuteRadius - _minuteGap - gravityPull;

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
			_minuteInnerGap,
			_minuteInnerWidth,
			0xFF0000
		);

		// CircleRenderer.drawSmoothAnnulus(
		// 	dc, minuteX, minuteY,
		// 	_minuteRadius,
		// 	_minuteOuterGap,
		// 	_minuteOuterWidth,
		// 	0xFF0000
		// );

		// Decorative inner minute satellite.
		var minuteSecondaryOrbit =
			minuteInterstellar + gravityPull -
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

	}

	function drawSeconds(dc, geometry, seconds) {
		var secondsAngle =
			(seconds * Math.PI * 2.0 / 60.0)
			- Math.PI / 2.0;

		var secondsOrbit =
			geometry.tickCenterRadius +
			_secondsTickGap +
			_secondsRadius;

		var secondsX =
			geometry.centerX +
			Math.round(
				Math.cos(secondsAngle) * secondsOrbit
			);

		var secondsY =
			geometry.centerY +
			Math.round(
				Math.sin(secondsAngle) * secondsOrbit
			);

		CircleRenderer.drawSmoothCircle(
			dc,
			secondsX,
			secondsY,
			_secondsRadius,
			_secondsColor
		);
	}

}

// kak: filetype=c
