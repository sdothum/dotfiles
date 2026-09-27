
using Toybox.Graphics;
using Toybox.Math;
using Toybox.Lang;

class CircleRenderer {

	// Each cache entry stores a radius, color, interior spans
	// and antialiased edge pixels.
	static var _cache as Lang.Array<Lang.Dictionary> = [];

	static function drawSmoothCircle(dc, cx, cy, radius, color) {
		var pattern = getPattern(radius, color);

		var spans = pattern[:spans]
			as Lang.Array<Lang.Array<Lang.Number>>;

		var edges = pattern[:edges]
			as Lang.Array<Lang.Array<Lang.Number>>;

		dc.setPenWidth(1);
		dc.setColor(color, 0xFFFFFF);

		// Draw the solid interior using horizontal spans.
		for (var i = 0; i < spans.size(); i += 1) {
		   var span = spans[i];

		   dc.drawLine(
		      cx + span[0],
		      cy + span[1],
		      cx + span[2],
		      cy + span[1]
		   );
		}

		// Draw the precomputed antialiased perimeter.
		var previousColor = -1;

		for (var i = 0; i < edges.size(); i += 1) {
			var pixel = edges[i];

			if (pixel[2] != previousColor) {
				dc.setColor(pixel[2], 0xFFFFFF);
				previousColor = pixel[2];
			}

			dc.drawPoint(cx + pixel[0], cy + pixel[1]);
		}
	}

static function getPattern(radius, color) as Lang.Dictionary {
	for (var i = 0; i < _cache.size(); i += 1) {
			var entry = _cache[i];

			if (entry[:radius] == radius &&
				 entry[:color] == color) {
				return entry;
			}
		}

		var spans = [] as Lang.Array<Lang.Array<Lang.Number>>;
		var edges = [] as Lang.Array<Lang.Array<Lang.Number>>;

		var red = (color >> 16) & 0xFF;
		var green = (color >> 8) & 0xFF;
		var blue = color & 0xFF;

		var extent = radius + 1;

		for (var y = -extent; y <= extent; y += 1) {
			var spanStart = null;
			var spanEnd = null;

			for (var x = -extent; x <= extent; x += 1) {
				var distance = Math.sqrt(x * x + y * y);
				var coverage = radius + 0.5 - distance;

				if (coverage <= 0) {
					continue;
				}

				if (coverage >= 1) {
					// Fully covered pixel.
					if (spanStart == null) {
						spanStart = x;
					}

					spanEnd = x;
					continue;
				}

				// Partially covered perimeter pixel.
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

				edges.add([x, y, pixelColor]);
			}

			if (spanStart != null) {
				spans.add([spanStart, y, spanEnd]);
			}
		}

		var pattern = {
			:radius => radius,
			:color => color,
			:spans => spans,
			:edges => edges
		};

		_cache.add(pattern);

		return pattern;
	}


	static var _ringCache as Lang.Array<Lang.Dictionary> = [];

	static function drawSmoothAnnulus(
		dc, cx, cy, radius, gap, width, color
	) {
		var pattern = getRingPattern(radius, gap, width, color);
		var pixels = pattern[:pixels]
			as Lang.Array<Lang.Array<Lang.Number>>;

		var previousColor = -1;

		for (var i = 0; i < pixels.size(); i += 1) {
			var pixel = pixels[i];

			if (pixel[2] != previousColor) {
				dc.setColor(pixel[2], 0xFFFFFF);
				previousColor = pixel[2];
			}

			dc.drawPoint(
				(cx + pixel[0]).toNumber(),
				(cy + pixel[1]).toNumber()
			);
		}
	}

	static function getRingPattern(
		radius, gap, width, color
	) as Lang.Dictionary {

		for (var i = 0; i < _ringCache.size(); i += 1) {
			var entry = _ringCache[i];

			if (entry[:radius] == radius &&
				 entry[:gap] == gap &&
				 entry[:width] == width &&
				 entry[:color] == color) {
				return entry;
			}
		}

		var pixels = [] as Lang.Array<Lang.Array<Lang.Number>>;

		var red = (color >> 16) & 0xFF;
		var green = (color >> 8) & 0xFF;
		var blue = color & 0xFF;

		// The inner boundary is outside the existing dot.
		var innerRadius = radius + gap;
		var outerRadius = innerRadius + width;
		var extent = outerRadius + 1;

		for (var y = -extent; y <= extent; y += 1) {
			for (var x = -extent; x <= extent; x += 1) {

				var distance = Math.sqrt(x * x + y * y);

				// Antialias both boundaries independently.
				var outerCoverage =
					outerRadius + 0.5 - distance;

				var innerCoverage =
					innerRadius + 0.5 - distance;

				if (outerCoverage <= 0) {
					continue;
				}

				if (outerCoverage > 1) {
					outerCoverage = 1;
				}

				if (innerCoverage < 0) {
					innerCoverage = 0;
				}

				if (innerCoverage > 1) {
					innerCoverage = 1;
				}

				var coverage =
					outerCoverage - innerCoverage;

				if (coverage <= 0) {
					continue;
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

				pixels.add([x, y, pixelColor]);
			}
		}

		var pattern = {
			:radius => radius,
			:gap => gap,
			:width => width,
			:color => color,
			:pixels => pixels
		};

		_ringCache.add(pattern);

		return pattern;
	}


}

// kak: filetype=c
