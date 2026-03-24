// File: workouttrackerUITests/Support/UITestSupport.swift
import XCTest
import UIKit

enum UITestLaunch {
    static func app(
        start: String,
        reset: Bool = true,
        seed: Bool = false,
        preferredContentSizeCategory: UIContentSizeCategory? = nil,
        disableAnimations: Bool = true,
        extraEnv: [String: String] = [:],
        extraArgs: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extraArgs

        if let preferredContentSizeCategory {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                preferredContentSizeCategory.rawValue
            ]
        }

        var env = app.launchEnvironment
        env["UITESTS"] = "1"
        env["UITESTS_START"] = start
        env["UITESTS_RESET"] = reset ? "1" : "0"
        env["UITESTS_SEED"] = seed ? "1" : "0"
        env["UITESTS_DISABLE_ANIMATIONS"] = disableAnimations ? "1" : "0"
        for (k, v) in extraEnv { env[k] = v }
        app.launchEnvironment = env
        return app
    }
}

extension XCUIApplication {
    func el(_ id: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: id).firstMatch
    }
}

extension XCTestCase {
    func attachUITestDebug(_ app: XCUIApplication,
                           name: String,
                           file: StaticString = #filePath,
                           line: UInt = #line) {
        let shot = XCUIScreen.main.screenshot()
        let a1 = XCTAttachment(screenshot: shot)
        a1.name = "\(name) screenshot"
        a1.lifetime = .keepAlways
        add(a1)

        let a2 = XCTAttachment(string: app.debugDescription)
        a2.name = "\(name) hierarchy"
        a2.lifetime = .keepAlways
        add(a2)
    }
}

@discardableResult
func tapNewActivityButton(_ app: XCUIApplication, timeout: TimeInterval = 6.0) -> Bool {
    let byId = app.descendants(matching: .any).matching(identifier: "timeline.newActivityButton").firstMatch
    if byId.waitForExistence(timeout: timeout) {
        if byId.isHittable { byId.tap() }
        else { byId.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        return true
    }

    let byLabel = app.descendants(matching: .any)
        .matching(NSPredicate(format: "label CONTAINS[c] %@", "New activity"))
        .firstMatch

    if byLabel.waitForExistence(timeout: 2.0) {
        byLabel.tap()
        return true
    }

    return false
}

func assertApproximatelyVerticallyCentered(
    _ element: XCUIElement,
    in app: XCUIApplication,
    tolerance: CGFloat = 140,
    debugName: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(
        element.waitForExistence(timeout: 6),
        "Expected element '\(debugName)' to exist before checking centering.",
        file: file,
        line: line
    )

    let window = app.windows.firstMatch
    XCTAssertTrue(
        window.waitForExistence(timeout: 2),
        "Expected app window for centering check.",
        file: file,
        line: line
    )

    let delta = abs(element.frame.midY - window.frame.midY)

    if delta > tolerance {
        let shot = XCUIScreen.main.screenshot()
        let screenshotAttachment = XCTAttachment(screenshot: shot)
        screenshotAttachment.name = "\(debugName) not centered screenshot"
        screenshotAttachment.lifetime = .keepAlways

        let hierarchyAttachment = XCTAttachment(string: app.debugDescription)
        hierarchyAttachment.name = "\(debugName) hierarchy"
        hierarchyAttachment.lifetime = .keepAlways

        XCTContext.runActivity(named: "Centering failure debug") { activity in
            activity.add(screenshotAttachment)
            activity.add(hierarchyAttachment)
        }
    }

    XCTAssertLessThanOrEqual(
        delta,
        tolerance,
        "Expected '\(debugName)' to be vertically near the middle of the screen. delta=\(delta), tolerance=\(tolerance)",
        file: file,
        line: line
    )
}
