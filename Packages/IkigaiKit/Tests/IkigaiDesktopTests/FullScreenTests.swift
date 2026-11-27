import CoreGraphics
import Testing
@testable import IkigaiDesktop

struct FullScreenTests {
    let display = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func aWindowCoveringTheDisplayCounts() {
        #expect(FullScreen.covers(display: display, windows: [display]))
        #expect(FullScreen.covers(display: display, windows: [CGRect(x: -0.5, y: 0, width: 1512.5, height: 982)]))
    }

    @Test func partialOrOtherDisplayWindowsDoNot() {
        #expect(!FullScreen.covers(display: display, windows: [CGRect(x: 0, y: 25, width: 1512, height: 900)]))
        #expect(!FullScreen.covers(display: display, windows: [CGRect(x: 1512, y: 0, width: 2560, height: 1440)]))
        #expect(!FullScreen.covers(display: display, windows: []))
    }
}
