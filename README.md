# AutoTest

AutoTest is a lib for use with [`buddy`][buddy], allowing you to have test
suites anywhere in your project and not having to maintain a "root test suite"
referencing them all.

It works by gathering all files ending with `Tests.hx` in your sources (but not
your libs nor haxe std) and adding them to a buddy suite used as main.

AutoTest declares `-main` itself, do not add it to your `test.hxml`.

## Specific behavior

### Enzyme integration

When used with [`enzyme`][enzyme], it will initialize `Jsdom` and
`React16Adapter` in the main class `__init__`. This cannot be disabled atm but
could become configurable if needed.

### Redux test coverage (experimental)

When used with redux and `-D redux_test_coverage`, AutoTest will add a new test
suite at the end, trying to make sure you test some specific things, by naively
checking if each of these classes have a corresponding `XTests.hx` file beside
it. It will *not* check that this is a proper test suite (this would fail at
tests compile-time anyway), nor that this test suite is complete in any way.

You can configure the packages (as directories) it should be looking into with
the following compilation flags:

 * `-D redux_reducer_pack`, default value being `store/reducer`
 * `-D redux_middleware_pack`, default value being `store/middleware`
 * `-D redux_thunk_pack`, default value being `store/thunk`
 * `-D redux_selector_pack`, default value being `store/selector`

Example output:

```
[... see previous example output ...]
Tests coverage
  All 1 middlewares should have test suites (FAILED)
    No test suite for: MyMiddleware
  All 1 reducers should have test suites (Passed)
  All 1 selectors should have test suites (Passed)
  All 1 thunks should have test suites (Passed)
17 specs, 1 failures, 0 pending
```

[buddy]: https://github.com/ciscoheat/buddy
[enzyme]: https://github.com/kLabz/haxe-enzyme
