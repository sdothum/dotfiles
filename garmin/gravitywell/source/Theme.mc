using Toybox.Graphics;

class Theme {
	static const BACKGROUND_COLOR = Graphics.COLOR_WHITE;

	// Initial shades only. We will tune these from simulator/watch images.
	static const MINUTE_TICK_COLOR = 0xD8D8D8;
	static const FIVE_TICK_COLOR   = 0xB8B8B8;

	static const MINUTE_TICK_WIDTH = 1;
	static const FIVE_TICK_WIDTH   = 3;

	// Equal radial length for every tick.
	static const TICK_LENGTH = 5;
}

// kak: filetype=c
