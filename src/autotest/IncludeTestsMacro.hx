package autotest;

import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import sys.FileSystem as FS;

using StringTools;
using haxe.macro.Tools;

typedef CoverageData = {
	total:Int,
	untested:Array<String>
}

typedef SuitesData = {
	suites:Array<String>,
	#if (redux && redux_test_coverage)
	reduxCoverage:ReduxCoverage
	#end
}

#if (redux && redux_test_coverage)
typedef ReduxCoverage = {
	reducer:CoverageData,
	middleware:CoverageData,
	thunk:CoverageData,
	selector:CoverageData
}
#end

class IncludeTestsMacro {
	static var dotReg = ~/(\.)/g;
	static var hxExt = ~/(\.hx$)/;

	#if (redux && redux_test_coverage)
	static var reducerPack:String = "store/reducer";
	static var middlewarePack:String = "store/middleware";
	static var thunkPack:String = "store/thunk";
	static var selectorPack:String = "store/selector";
	#end

	// Will include all tests suites whose name ends with "Tests"
	public static function buildTests() {
		var fields = Context.getBuildFields();

		var testSuite = Compiler.getDefine('autotest_suite');
		if (testSuite != null && StringTools.trim(testSuite) != "") {
			return makeTestSuiteProxy(fields, testSuite);
		}

		var path = extractPath();
		if (path == null) Context.error('Could not find the sources directory', Context.currentPos());

		#if (redux && redux_test_coverage)
		handleReduxConfig();
		#end

		var suites = [];
		var suitesData = extractTestSuites(path, path, {
			suites: [],
			#if (redux && redux_test_coverage)
			reduxCoverage: {
				reducer: {total: 0, untested: []},
				middleware: {total: 0, untested: []},
				thunk: {total: 0, untested: []},
				selector: {total: 0, untested: []}
			}
			#end
		});

		for (s in suitesData.suites) suites.push(extractExpr(path, s));

		#if (redux && redux_test_coverage)
		addReduxCoverage(suites, suitesData);
		#end

		Context.defineType({
			name: 'TestSuites',
			pack: ['autotest'],
			params: [],
			fields: [],
			meta: null,
			isExtern: null,
			kind: TDClass(
				null,
				[{
					name: 'Buddy',
					pack: ['buddy'],
					params: [
						TPExpr({expr: EArrayDecl(suites), pos: Context.currentPos()})
					],
					sub: null
				}],
				false
			),
			pos: Context.currentPos()
		});

		fields.push({
			name: 'main',
			kind: FFun({
				args: [],
				params: null,
				ret: null,
				expr: macro TestSuites.main()
			}),
			access: [APublic, AStatic],
			doc: null,
			meta: null,
			pos: Context.currentPos()
		});

		return fields;
	}

	static function makeTestSuiteProxy(fields:Array<Field>, suite:String):Array<Field> {
		return fields.concat((macro class {
			public static function main() {
				$p{suite.split(".")}.main();
			}
		}).fields);
	}

	static function extractPath():String {
		var clsPath = Context.getClassPath();
		for (c in clsPath) {
			var t = c.trim();
			if (t.length > 0 && t.charAt(0) != "#" && t.charAt(0) != "/")
				return c;
		}

		return null;
	}

	static function extractExpr(base:String, path:String):Expr {
		if (path.startsWith(base)) {
			path = path.substring(base.length, path.length - 3);
			path = ~/\//g.replace(path, '.');

			return macro $p{path.split('.')};
		}

		Context.error('Invalid test suite: $path', Context.currentPos());
		return macro null;
	}

	static function extractTestSuites(root:String, dir:String, data:SuitesData):SuitesData {
		if (FS.isDirectory(dir)) {
			var entries = FS.readDirectory(dir);

			for (entry in entries) {
				var path = dir + entry;

				if (FS.isDirectory(path)) {
					extractTestSuites(root, path + '/', data);
				} else {
					if (entry.length > 8 && entry.endsWith('Tests.hx')) {
						data.suites.push(path);
					#if (redux && redux_test_coverage)
					} else if (entry.endsWith('.hx')) {
						var target:Null<CoverageData> = switch(dir.replace(root, '')) {
							case p if (p == reducerPack): data.reduxCoverage.reducer;
							case p if (p == middlewarePack): data.reduxCoverage.middleware;
							case p if (p == thunkPack): data.reduxCoverage.thunk;
							case p if (p == selectorPack): data.reduxCoverage.selector;
							default: null;
						};

						if (target != null) {
							target.total++;
							if (!FS.exists(dir + hxExt.replace(entry, 'Tests.hx')))
								target.untested.push(hxExt.replace(entry, ''));
						}
					#end
					}
				}
			}
		}

		return data;
	}

	#if (redux && redux_test_coverage)
	static function handleReduxConfig():Void {
		reducerPack = tryOverride(reducerPack, Compiler.getDefine('redux_reducer_pack'));
		middlewarePack = tryOverride(middlewarePack, Compiler.getDefine('redux_middleware_pack'));
		thunkPack = tryOverride(thunkPack, Compiler.getDefine('redux_thunk_pack'));
		selectorPack = tryOverride(selectorPack, Compiler.getDefine('redux_selector_pack'));
	}

	static function tryOverride(current:String, defined:String):String {
		if (defined != null) return dotReg.replace(defined, "/");
		return current;
	}

	static function addReduxCoverage(suites:Array<Expr>, suitesData:SuitesData):Void {
		var tests = [];
		tests.push(generateCoverage(suitesData.reduxCoverage.middleware, "middleware"));
		tests.push(generateCoverage(suitesData.reduxCoverage.reducer, "reducer"));
		tests.push(generateCoverage(suitesData.reduxCoverage.selector, "selector"));
		tests.push(generateCoverage(suitesData.reduxCoverage.thunk, "thunk"));

		Context.defineType(macro class CoverageTests extends buddy.BuddySuite {
			public function new() {
				describe("Redux test coverage", {
					$a{tests};
				});
			}
		});

		suites.push(macro CoverageTests);
	}

	static function generateCoverage(coverage:CoverageData, id:String):Expr {
		if (coverage.total > 1) id += "s";
		var def = 'All ${coverage.total} ${id} should have test suites';

		if (coverage.untested.length == 0) {
			return generatePassingCase(def);
		} else {
			var fail = 'No test suite for: ${coverage.untested.join(", ")}';
			return generateFailingCase(def, fail);
		}
	}
	#end

	static function generatePassingCase(def:String):Expr {
		return macro it($v{def}, {
			buddy.SuitesRunner.currentTest(true, '', []);
		});
	}

	static function generateFailingCase(def:String, message:String):Expr {
		return macro it($v{def}, {
			buddy.SuitesRunner.currentTest(false, $v{message}, []);
		});
	}
}
