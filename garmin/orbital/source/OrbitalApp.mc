using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.WatchUi as WatchUi;

class OrbitalApp extends App.AppBase {

	function initialize() {
		AppBase.initialize();
	 }

	function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
		return [ new OrbitalView() ];
	}
}

// kak: filetype=c
