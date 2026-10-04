using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.WatchUi as WatchUi;

class GravityWellApp extends App.AppBase {

	function initialize() {
		AppBase.initialize();
	 }

	function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
		return [ new GravityWellView() ];
	}
}

// kak: filetype=c
