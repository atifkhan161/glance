import XCTest

final class GitHubHubFlowUITests: XCTestCase {
    func testGitHubHubViewShowsDescription() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))

        let tablesQuery = app.tables
        let githubCard = tablesQuery.staticTexts["Engineering"]
        XCTAssertTrue(githubCard.waitForExistence(timeout: 10))
        githubCard.tap()

        let repoList = app.staticTexts["TRENDING REPOS"]
        XCTAssertTrue(repoList.waitForExistence(timeout: 10))

        let descriptionText = app.staticTexts["The Swift Programming Language"]
        XCTAssertTrue(descriptionText.waitForExistence(timeout: 10), "Description should be visible in the GitHub hub view")
    }
}