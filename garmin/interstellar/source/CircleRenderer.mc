
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
		var innerRadius = radius + gap;
		var outerRadius = innerRadius + width;

		if (innerRadius < 0.0 || width <= 0.0) {
			return;
		}

		var outerAA = outerRadius + 0.5;
		var innerAA = innerRadius - 0.5;

		var outerSquared = outerAA * outerAA;
		var innerSquared = innerAA * innerAA;

		var extent = Math.ceil(outerAA).toNumber();

		var red = (color >> 16) & 0xFF;
		var green = (color >> 8) & 0xFF;
		var blue = color & 0xFF;

		var previousColor = -1;

		for (var y = -extent; y <= extent; y += 1) {
			var yy = y * y;

			if (yy >= outerSquared) {
				continue;
			}

			// Largest X coordinate potentially covered.
			var outerX = Math.ceil(
				Math.sqrt(outerSquared - yy)
			).toNumber();

			// Smallest positive X coordinate potentially covered.
			var innerX = 0;

			if (yy < innerSquared) {
				innerX = Math.floor(
					Math.sqrt(innerSquared - yy)
				).toNumber();
			}

			// Draw both sides, avoiding duplicate x=0.
			for (var side = -1; side <= 1; side += 2) {
				for (var ax = innerX; ax <= outerX; ax += 1) {
					if (side == 1 && ax == 0) {
						continue;
					}

					var x = side * ax;
					var distance = Math.sqrt(x * x + yy);

					var outerCoverage =
						outerRadius + 0.5 - distance;

					var innerCoverage =
						innerRadius + 0.5 - distance;

					if (outerCoverage <= 0.0) {
						continue;
					}

					if (outerCoverage > 1.0) {
						outerCoverage = 1.0;
					}

					if (innerCoverage < 0.0) {
						innerCoverage = 0.0;
					}

					if (innerCoverage > 1.0) {
						innerCoverage = 1.0;
					}

					var coverage =
						outerCoverage - innerCoverage;

					if (coverage <= 0.0) {
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

					if (pixelColor != previousColor) {
						dc.setColor(pixelColor, 0xFFFFFF);
						previousColor = pixelColor;
					}

					dc.drawPoint(
						(cx + x).toNumber(),
						(cy + y).toNumber()
					);
				}
			}
		}
	}

}

// kak: filetype=c
