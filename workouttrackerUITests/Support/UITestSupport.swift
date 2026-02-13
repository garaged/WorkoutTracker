// File: workouttrackerUITests/Support/UITestSupport.swift
import XCTest

enum UITestLaunch {
    static func app(
        start: String,
        reset: Bool = true,
        seed: Bool = false,
        extraEnv: [String: String] = [:],
        extraArgs: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"] + extraArgs

        var env = app.launchEnvironment
        env["UITESTS"] = "1"
        env["UITESTS_START"] = start
        env["UITESTS_RESET"] = reset ? "1" : "0"
        env["UITESTS_SEED"] = seed ? "1" : "0"
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
    // RENAMED: attachDebug -> attachUITestDebug
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
    // Prefer identifier if you have one
    let byId = app.descendants(matching: .any).matching(identifier: "timeline.newActivityButton").firstMatch
    if byId.waitForExistence(timeout: timeout) {
        if byId.isHittable { byId.tap() }
        else { byId.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        return true
    }

    // Fallback: label search
    let byLabel = app.descendants(matching: .any)
        .matching(NSPredicate(format: "label CONTAINS[c] %@", "New activity"))
        .firstMatch

    if byLabel.waitForExistence(timeout: 2.0) {
        byLabel.tap()
        return true
    }

    return false
}
