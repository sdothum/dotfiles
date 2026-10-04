using Toybox.Application as App;
using Toybox.Lang as Lang;
using Toybox.WatchUi as WatchUi;

class InterstellarApp extends App.AppBase {

	function initialize() {
		AppBase.initialize();
	 }

	function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
		return [ new InterstellarView() ];
	}
}

// kak: filetype=c
