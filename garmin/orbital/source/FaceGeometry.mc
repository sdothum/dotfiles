
class FaceGeometry {
	var centerX;
	var centerY;
	var screenRadius;

	var tickCenterRadius;
	var tickInnerRadius;
	var tickOuterRadius;

	function initialize(dc) {
		var width = dc.getWidth();
		var height = dc.getHeight();
		var diameter;

		centerX = width / 2;
		centerY = height / 2;

		if (width < height) {
			diameter = width;
		} else {
			diameter = height;
		}

		screenRadius = diameter / 2;

		/*
		 * FR955 display: 260 x 260 pixels.
		 *
		 * Screen radius:       130
		 * Tick outer radius:   117
		 *
		 * The entire tick band has been moved
		 * inward by 2 pixels from the original
		 * outer radius of 119.
		 *
		 * All ticks share identical endpoints.
		 */

		tickOuterRadius = screenRadius - 13;
		tickInnerRadius = tickOuterRadius - Theme.TICK_LENGTH;

		tickCenterRadius =
			(tickOuterRadius + tickInnerRadius) / 2.0;
	}
}

// kak: filetype=c
