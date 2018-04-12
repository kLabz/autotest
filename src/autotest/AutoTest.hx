package autotest;

#if enzyme
import enzyme.Enzyme.configure;
import enzyme.adapter.React16Adapter as Adapter;
import jsdom.Jsdom;
#end

@:build(autotest.IncludeTestsMacro.buildTests())
class AutoTest {
	#if enzyme
	static function __init__() {
		JsdomSetup.init();

		configure({
			adapter: new Adapter()
		});
	}
	#end
}
