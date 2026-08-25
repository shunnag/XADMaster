#import <XCTest/XCTest.h>
#import <XADMaster/XADPath.h>
#import <XADMaster/XADString.h>

// Regression tests for -[XADPath canonicalPathComponentsWithEncodingName:].
// Upstream issue #192: the early return was inverted (!=NSNotFound instead of
// ==NSNotFound), so paths containing BOTH "." and ".." components — exactly the
// ones that need normalization — were returned unnormalized.
@interface XADPathTests : XCTestCase
@end

@implementation XADPathTests

- (void)testCanonicalComponentsNormalizePathWithBothDotAndDotDot {
    // The issue #192 case: "." and ".." both present used to skip normalization.
    XADPath *path = [XADPath pathWithStringComponents:@[ @"a", @".", @"b", @"..", @"c" ]];
    NSArray *expected = @[ @"a", @"c" ];

    XCTAssertEqualObjects([path canonicalPathComponentsWithEncodingName:XADUTF8StringEncodingName], expected);
}

- (void)testCanonicalComponentsDropSingleDots {
    XADPath *path = [XADPath pathWithStringComponents:@[ @"a", @".", @"b" ]];
    NSArray *expected = @[ @"a", @"b" ];

    XCTAssertEqualObjects([path canonicalPathComponentsWithEncodingName:XADUTF8StringEncodingName], expected);
}

- (void)testCanonicalComponentsDropResolvableDotDots {
    XADPath *path = [XADPath pathWithStringComponents:@[ @"a", @"..", @"b" ]];
    NSArray *expected = @[ @"b" ];

    XCTAssertEqualObjects([path canonicalPathComponentsWithEncodingName:XADUTF8StringEncodingName], expected);
}

- (void)testCanonicalComponentsKeepUnresolvableLeadingDotDot {
    // A leading ".." has no preceding component to cancel, so it is kept.
    XADPath *path = [XADPath pathWithStringComponents:@[ @"..", @"a" ]];
    NSArray *expected = @[ @"..", @"a" ];

    XCTAssertEqualObjects([path canonicalPathComponentsWithEncodingName:XADUTF8StringEncodingName], expected);
}

- (void)testCanonicalComponentsPassPlainPathsThrough {
    // No dot components: the early-return fast path must still return the raw list.
    XADPath *path = [XADPath pathWithStringComponents:@[ @"a", @"b" ]];
    NSArray *expected = @[ @"a", @"b" ];

    XCTAssertEqualObjects([path canonicalPathComponentsWithEncodingName:XADUTF8StringEncodingName], expected);
}

- (void)testCanonicallyEqualResolvesMixedDotPath {
    XADPath *mixed = [XADPath pathWithStringComponents:@[ @"a", @".", @"b", @"..", @"c" ]];
    XADPath *plain = [XADPath pathWithStringComponents:@[ @"a", @"c" ]];

    XCTAssertTrue([mixed isCanonicallyEqual:plain encodingName:XADUTF8StringEncodingName]);
}

@end
