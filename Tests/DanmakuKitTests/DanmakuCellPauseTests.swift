import XCTest
@testable import DanmakuKit

@MainActor
final class DanmakuCellPauseTests: XCTestCase {

    func testFloatingAndVerticalCellsReportPauseAndPlayState() throws {
        for type in [
            DanmakuCellType.floating,
            DanmakuCellType.top,
            DanmakuCellType.bottom,
        ] {
            let view = DanmakuView(
                frame: CGRect(x: 0, y: 0, width: 480, height: 240)
            )
            let delegate = CapturingDelegate()
            view.delegate = delegate
            view.trackHeight = 40
            view.play()

            let model = TestCellModel(type: type)
            view.shoot(danmaku: model)
            let cell = try XCTUnwrap(delegate.cell)

            XCTAssertFalse(cell.isPaused, "\(type) should be playing after shoot")
            XCTAssertTrue(view.pause(model))
            XCTAssertTrue(cell.isPaused, "\(type) should be paused after pause(model)")
            XCTAssertTrue(view.play(model))
            XCTAssertFalse(cell.isPaused, "\(type) should be playing after play(model)")

            view.stop()
        }
    }

#if canImport(UIKit)
    func testFloatingCellTogglesAtPresentationPosition() throws {
        let view = DanmakuView(
            frame: CGRect(x: 0, y: 0, width: 480, height: 240)
        )
        let delegate = CapturingDelegate()
        view.delegate = delegate
        view.trackHeight = 40
        view.play()

        let model = TestCellModel(type: .floating)
        view.shoot(danmaku: model)
        let cell = try XCTUnwrap(delegate.cell)
        CATransaction.flush()
        let presentation = try XCTUnwrap(cell.layer.presentation())
        let point = CGPoint(x: presentation.frame.midX, y: presentation.frame.midY)

        view.handleToggle(at: point)
        XCTAssertEqual(delegate.toggleCount, 1)
        view.handleToggle(at: point)
        XCTAssertEqual(delegate.stopToggleCount, 1)

        view.stop()
    }
#endif
}

private final class CapturingDelegate: DanmakuViewDelegate {
    var cell: DanmakuCell?
    var toggleCount = 0
    var stopToggleCount = 0

    func danmakuView(
        _ danmakuView: DanmakuView,
        willDisplay danmaku: DanmakuCell
    ) {
        cell = danmaku
    }

    func danmakuView(
        _ danmakuView: DanmakuView,
        didToggled danmaku: DanmakuCell
    ) {
        toggleCount += 1
    }

    func danmakuView(
        _ danmakuView: DanmakuView,
        stopToggled danmaku: DanmakuCell
    ) {
        stopToggleCount += 1
    }
}

private final class TestCellModel: DanmakuCellModel {
    let cellClass: DanmakuCell.Type = DanmakuCell.self
    let size = CGSize(width: 180, height: 40)
    var track: UInt?
    let displayTime: Double = 60
    let type: DanmakuCellType
    let identifier = UUID().uuidString

    init(type: DanmakuCellType) {
        self.type = type
    }

    func isEqual(to cellModel: DanmakuCellModel) -> Bool {
        identifier == cellModel.identifier
    }
}
