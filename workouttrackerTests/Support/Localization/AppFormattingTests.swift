import XCTest
@testable import workouttracker

final class AppFormattingTests: XCTestCase {
    func test_duration_shortValues_usePositionalClockStyle() {
        let locale = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(AppFormatting.duration(seconds: 5, locale: locale), "0:05")
        XCTAssertEqual(AppFormatting.duration(seconds: 65, locale: locale), "1:05")
    }

    func test_duration_crossesMinuteAndHourBoundaries() {
        let locale = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(AppFormatting.duration(seconds: 59, locale: locale), "0:59")
        XCTAssertEqual(AppFormatting.duration(seconds: 60, locale: locale), "1:00")
        XCTAssertEqual(AppFormatting.duration(seconds: 3661, locale: locale), "1:01:01")
    }

    func test_shortDuration_formatsPresetFriendlyLabels() {
        let locale = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(AppFormatting.shortDuration(seconds: 30, locale: locale), "30s")
        XCTAssertEqual(AppFormatting.shortDuration(seconds: 60, locale: locale), "1m")
        XCTAssertEqual(AppFormatting.shortDuration(seconds: 90, locale: locale), "1m 30s")
    }

    func test_shortDuration_usesLocalizedCatalogStrings_forSpanishLocale() {
        let locale = Locale(identifier: "es_MX")

        XCTAssertEqual(AppFormatting.shortDuration(seconds: 30, locale: locale), "30 s")
        XCTAssertEqual(AppFormatting.shortDuration(seconds: 60, locale: locale), "1 min")
        XCTAssertEqual(AppFormatting.shortDuration(seconds: 90, locale: locale), "1 min 30 s")
    }

    func test_decimal_respectsFractionDigitCap() {
        let locale = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(AppFormatting.decimal(12, maxFractionDigits: 1, locale: locale), "12")
        XCTAssertEqual(AppFormatting.decimal(12.25, maxFractionDigits: 1, locale: locale), "12.2")
        XCTAssertEqual(AppFormatting.decimal(12.25, maxFractionDigits: 2, locale: locale), "12.25")
    }

    func test_monthDayAndDateRange_returnLocaleAwareOutput() {
        let locale = Locale(identifier: "en_US_POSIX")
        let start = Date(timeIntervalSince1970: 1_713_398_400) // 2024-04-19 00:00:00 UTC
        let end = Date(timeIntervalSince1970: 1_713_484_800)   // 2024-04-20 00:00:00 UTC

        XCTAssertFalse(AppFormatting.monthDay(start, locale: locale).isEmpty)
        XCTAssertTrue(AppFormatting.dateRange(start: start, end: end, locale: locale).contains("–"))
    }

    func test_dateTimeHelpers_returnNonEmptyLocaleSafeOutput() {
        let locale = Locale(identifier: "en_US_POSIX")
        let date = Date(timeIntervalSince1970: 1_713_456_789)

        XCTAssertFalse(AppFormatting.date(date, locale: locale).isEmpty)
        XCTAssertFalse(AppFormatting.time(date, locale: locale).isEmpty)
        XCTAssertFalse(AppFormatting.dateTime(date, locale: locale).isEmpty)
    }
}
