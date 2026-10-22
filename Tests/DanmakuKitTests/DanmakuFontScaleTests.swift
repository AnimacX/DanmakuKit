import XCTest
@testable import DanmakuKit

@MainActor
final class DanmakuFontScaleTests: XCTestCase {
    func testUpdatesAllTrackTypesAndRedrawsValueModelsWhilePlayingOrPaused() throws {
        for playing in [true, false] {
            let view = makeView()
            let delegate = AppearanceDelegate()
            view.delegate = delegate
            view.play()
            if !playing { view.pause() }

            for type in [DanmakuCellType.floating, .top, .bottom] {
                view.sync(danmaku: AppearanceModel(type: type), at: 0.25)
            }
            XCTAssertEqual(delegate.cells.count, 3)
            let originalFrames = delegate.cells.map(\.realFrame)
            view.fontScale = 1.5
            XCTAssertEqual(view.status, playing ? .play : .pause)
            for (cell, originalFrame) in zip(delegate.cells, originalFrames) {
                let model = try XCTUnwrap(cell.model as? AppearanceModel)
                XCTAssertEqual(model.fontSize, 20)
                XCTAssertEqual(model.fontScale, 1.5)
                XCTAssertEqual(cell.bounds.size, model.size)
                XCTAssertEqual(cell.isPaused, !playing)
                XCTAssertEqual(cell.frame.midY, originalFrame.midY, accuracy: 0.001)
                if model.type == .floating {
                    XCTAssertEqual(cell.frame.minX, originalFrame.minX, accuracy: 0.001)
                } else {
                    XCTAssertEqual(cell.frame.midX, view.bounds.midX, accuracy: 0.001)
                }
#if os(macOS)
                cell.layer?.displayIfNeeded()
#else
                cell.layer.displayIfNeeded()
#endif
                XCTAssertEqual(cell.renderedFontSize, 30)
                XCTAssertEqual(model.track, 0)
            }
            XCTAssertEqual(delegate.displayCount, 3)
            XCTAssertEqual(delegate.endCount, 0)
            view.stop()
        }
    }

    func testIndividuallyPausedFloatingCellStaysPausedAndCanResume() throws {
        let view = makeView()
        let delegate = AppearanceDelegate()
        view.delegate = delegate
        view.play()
        let model = AppearanceModel(type: .floating)
        view.sync(danmaku: model, at: 0.4)
        let cell = try XCTUnwrap(delegate.cells.first)
        XCTAssertTrue(view.pause(model))
        let originalFrame = cell.realFrame

        view.fontScale = 1.5
        view.fontScale = 2

        XCTAssertEqual(view.status, .play)
        XCTAssertTrue(cell.isPaused)
        XCTAssertEqual(cell.frame.minX, originalFrame.minX, accuracy: 0.001)
        XCTAssertEqual(cell.bounds.size, CGSize(width: 240, height: 80))
        XCTAssertTrue(view.play(model))
        XCTAssertFalse(cell.isPaused)
        view.stop()
    }

    func testVerticalCellKeepsItsOriginalExpiryAnimationAndPauseState() throws {
        let view = makeView()
        let delegate = AppearanceDelegate()
        view.delegate = delegate
        view.play()
        let model = AppearanceModel(type: .top)
        view.sync(danmaku: model, at: 0.6)
        let cell = try XCTUnwrap(delegate.cells.first)
        XCTAssertTrue(view.pause(model))
#if os(macOS)
        let animation = cell.layer?.animation(forKey: TOP_ANIMATION_KEY)
        let timeOffset = cell.layer?.timeOffset
#else
        let animation = cell.layer.animation(forKey: TOP_ANIMATION_KEY)
#endif

        view.fontScale = 1.5

        XCTAssertTrue(cell.isPaused)
#if os(macOS)
        XCTAssertEqual(cell.layer?.animation(forKey: TOP_ANIMATION_KEY)?.beginTime, animation?.beginTime)
        XCTAssertEqual(cell.layer?.timeOffset, timeOffset)
#else
        XCTAssertEqual(cell.layer.animation(forKey: TOP_ANIMATION_KEY)?.beginTime, animation?.beginTime)
#endif
        XCTAssertTrue(view.play(model))
        XCTAssertFalse(cell.isPaused)
        view.stop()
    }

    @available(iOS 14.0, tvOS 14.0, *)
    func testSwiftUICoordinatorKeepsScaleSetBeforeViewCreation() {
        let coordinator = DanmakuViewAdapter.Coordinator()
        coordinator.fontScale = 2
        let view = coordinator.makeView()
        XCTAssertEqual(view.fontScale, 2)
        XCTAssertEqual(coordinator.fontScale, 2)
        XCTAssertEqual(view.status, .stop)
    }

    @available(iOS 14.0, tvOS 14.0, *)
    func testSwiftUICoordinatorUpdatesDisplayedCells() throws {
        let coordinator = DanmakuViewAdapter.Coordinator()
        let view = coordinator.makeView()
        view.frame = CGRect(x: 0, y: 0, width: 480, height: 240)
        coordinator.recalculateTracks()
        let delegate = AppearanceDelegate()
        view.delegate = delegate
        coordinator.play()
        coordinator.shoot(danmaku: AppearanceModel(type: .floating))

        coordinator.fontScale = 1.5

        let cell = try XCTUnwrap(delegate.cells.first)
        XCTAssertEqual(cell.bounds.size, CGSize(width: 180, height: 60))
        XCTAssertEqual((cell.model as? AppearanceModel)?.fontSize, 20)
        XCTAssertEqual((cell.model as? AppearanceModel)?.fontScale, 1.5)
        coordinator.stop()
    }

    func testRedrawCancelsOlderAsyncImage() async throws {
        let layer = DanmakuAsyncLayer()
        layer.bounds.size = CGSize(width: 20, height: 20)
        let oldDrawStarted = expectation(description: "Old drawing started")
        let newDrawFinished = expectation(description: "New drawing finished")
        let oldDrawCancelled = expectation(description: "Old drawing cancelled")
        let releaseOldDraw = DispatchSemaphore(value: 0)
        defer { releaseOldDraw.signal() }
        layer.displaying = { _, size, _ in
            if size.width == 20 {
                oldDrawStarted.fulfill()
                _ = releaseOldDraw.wait(timeout: .now() + 5)
            }
        }
        layer.didDisplay = { _, finished in
            if finished {
                newDrawFinished.fulfill()
            } else {
                oldDrawCancelled.fulfill()
            }
        }

        layer.display()
        await fulfillment(of: [oldDrawStarted], timeout: 2)
        layer.bounds.size = CGSize(width: 30, height: 30)
        layer.setNeedsDisplay()
        layer.displayIfNeeded()
        releaseOldDraw.signal()
        await fulfillment(of: [oldDrawCancelled, newDrawFinished], timeout: 2, enforceOrder: true)

        let image = try XCTUnwrap(layer.contents) as! CGImage
        XCTAssertEqual(image.width, Int(30 * layer.contentsScale))
    }

    func testDifferentBaseSizesAndFutureShootAndSyncInheritScale() throws {
        let view = DanmakuView(frame: .zero)
        view.fontScale = 2
        view.trackHeight = 80
        view.frame = CGRect(x: 0, y: 0, width: 480, height: 240)
        view.recalculateTracks()
        let delegate = AppearanceDelegate()
        view.delegate = delegate
        view.pause()

        for (type, baseSize) in [(DanmakuCellType.floating, CGFloat(16)), (.top, 20), (.bottom, 24)] {
            view.shoot(danmaku: AppearanceModel(fontSize: baseSize, type: type))
            view.sync(danmaku: AppearanceModel(fontSize: baseSize, type: type), at: 0.25)
        }

        XCTAssertEqual(delegate.cells.count, 6)
        for cell in delegate.cells {
            let model = try XCTUnwrap(cell.model as? AppearanceModel)
            let baseSize: CGFloat = model.type == .floating ? 16 : (model.type == .top ? 20 : 24)
            XCTAssertEqual(model.fontSize, baseSize)
            XCTAssertEqual(model.fontScale, 2)
            XCTAssertEqual(cell.bounds.width, baseSize * 2 * 6)
        }

        for scale: CGFloat in [0.5, 1.5, 2, 1] {
            view.fontScale = scale
            for cell in delegate.cells {
                let model = try XCTUnwrap(cell.model as? AppearanceModel)
                XCTAssertEqual(cell.bounds.width, model.fontSize * scale * 6)
            }
        }
        XCTAssertEqual(delegate.displayCount, 6)
        XCTAssertEqual(delegate.endCount, 0)
        view.stop()
    }

    func testCanShootMeasuresCandidateAtCurrentScale() {
        let view = DanmakuView(frame: CGRect(x: 0, y: 0, width: 480, height: 60))
        view.trackHeight = 60
        view.fontScale = 2
        view.pause()
        view.sync(danmaku: AppearanceModel(type: .floating), at: 0.7)

        XCTAssertFalse(view.canShoot(danmaku: AppearanceModel(fontSize: 100, type: .floating)))
        view.stop()
    }

    func testReusedCellReceivesCurrentScaleAndNewBaseSize() throws {
        let view = DanmakuView(frame: CGRect(x: 0, y: 0, width: 480, height: 60))
        view.trackHeight = 60
        view.enableCellReusable = true
        view.fontScale = 2
        let delegate = AppearanceDelegate()
        view.delegate = delegate
        view.pause()
        view.shoot(danmaku: AppearanceModel(fontSize: 16, type: .floating))
        // No room: this cell enters the reuse pool without being displayed.
        view.shoot(danmaku: AppearanceModel(fontSize: 20, type: .floating))
        view.clean()
        view.fontScale = 0.5

        view.shoot(danmaku: AppearanceModel(fontSize: 24, type: .floating))

        XCTAssertEqual(delegate.reuseCount, 1)
        let cell = try XCTUnwrap(delegate.cells.last)
        let model = try XCTUnwrap(cell.model as? AppearanceModel)
        XCTAssertEqual(model.fontSize, 24)
        XCTAssertEqual(model.fontScale, 0.5)
        XCTAssertEqual(cell.bounds.size, CGSize(width: 72, height: 24))
        view.stop()
    }

    func testScalingPreservesRemainingFloatingDuration() throws {
        let view = makeView()
        let delegate = AppearanceDelegate()
        view.delegate = delegate
        view.play()
        let model = AppearanceModel(type: .floating)
        view.sync(danmaku: model, at: 0.4)
        let cell = try XCTUnwrap(delegate.cells.first)
#if os(macOS)
        let original = try XCTUnwrap(cell.layer?.animation(forKey: FLOATING_ANIMATION_KEY))
#else
        let original = try XCTUnwrap(cell.layer.animation(forKey: FLOATING_ANIMATION_KEY))
#endif

        view.fontScale = 2
#if os(macOS)
        let updated = try XCTUnwrap(cell.layer?.animation(forKey: FLOATING_ANIMATION_KEY))
#else
        let updated = try XCTUnwrap(cell.layer.animation(forKey: FLOATING_ANIMATION_KEY))
#endif
        XCTAssertEqual(updated.duration, original.duration, accuracy: 0.1)
        XCTAssertTrue(view.pause(model))
        let elapsed = cell.animationTime
        view.fontScale = 0.5
        XCTAssertEqual(cell.animationTime, elapsed, accuracy: 0.001)
        XCTAssertTrue(view.play(model))
#if os(macOS)
        let resumed = try XCTUnwrap(cell.layer?.animation(forKey: FLOATING_ANIMATION_KEY))
#else
        let resumed = try XCTUnwrap(cell.layer.animation(forKey: FLOATING_ANIMATION_KEY))
#endif
        XCTAssertEqual(resumed.duration, model.displayTime - elapsed, accuracy: 0.001)
        view.stop()
    }

    func testNonTextModelsKeepTheirSizeAndAnimation() throws {
        let view = makeView()
        let delegate = AppearanceDelegate()
        view.delegate = delegate
        view.play()
        view.shoot(danmaku: ImageAppearanceModel())
        let cell = try XCTUnwrap(delegate.cells.first)
#if os(macOS)
        let animation = cell.layer?.animation(forKey: FLOATING_ANIMATION_KEY)
#else
        let animation = cell.layer.animation(forKey: FLOATING_ANIMATION_KEY)
#endif
        view.fontScale = 2
        XCTAssertEqual(cell.bounds.size, CGSize(width: 40, height: 40))
#if os(macOS)
        XCTAssertEqual(cell.layer?.animation(forKey: FLOATING_ANIMATION_KEY)?.beginTime, animation?.beginTime)
#else
        XCTAssertEqual(cell.layer.animation(forKey: FLOATING_ANIMATION_KEY)?.beginTime, animation?.beginTime)
#endif
        view.stop()
    }

    private func makeView() -> DanmakuView {
        let view = DanmakuView(frame: CGRect(x: 0, y: 0, width: 480, height: 240))
        view.trackHeight = 60
        return view
    }

}

private final class AppearanceDelegate: DanmakuViewDelegate {
    var cells: [AppearanceCell] = []
    var displayCount = 0
    var endCount = 0
    var reuseCount = 0

    func danmakuView(_ danmakuView: DanmakuView, dequeueReusable danmaku: DanmakuCell) {
        reuseCount += 1
    }

    func danmakuView(_ danmakuView: DanmakuView, willDisplay danmaku: DanmakuCell) {
        cells.append(danmaku as! AppearanceCell)
        displayCount += 1
    }

    func danmakuView(_ danmakuView: DanmakuView, didEndDisplaying danmaku: DanmakuCell) {
        endCount += 1
    }
}

private struct AppearanceModel: DanmakuFontScalable {
    let fontSize: CGFloat
    var fontScale: CGFloat = 1
    var size: CGSize { CGSize(width: fontSize * fontScale * 6, height: fontSize * fontScale * 2) }
    var cellClass: DanmakuCell.Type { AppearanceCell.self }
    var track: UInt?
    let displayTime: Double = 60
    let type: DanmakuCellType
    let identifier = UUID().uuidString

    init(fontSize: CGFloat = 20, type: DanmakuCellType) {
        self.fontSize = fontSize
        self.type = type
    }

    func isEqual(to cellModel: DanmakuCellModel) -> Bool {
        identifier == cellModel.identifier
    }
}

private struct ImageAppearanceModel: DanmakuCellModel {
    let size = CGSize(width: 40, height: 40)
    var cellClass: DanmakuCell.Type { AppearanceCell.self }
    var track: UInt?
    let displayTime: Double = 60
    let type: DanmakuCellType = .floating
    let identifier = UUID().uuidString

    func isEqual(to cellModel: DanmakuCellModel) -> Bool {
        identifier == cellModel.identifier
    }
}

final class AppearanceCell: DanmakuCell {
    var renderedFontSize: CGFloat?

    required init(frame: CGRect) {
        super.init(frame: frame)
        displayAsync = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func displaying(_ context: CGContext, _ size: CGSize, _ isCancelled: Bool) {
        if let model = model as? AppearanceModel {
            renderedFontSize = model.fontSize * model.fontScale
        }
    }
}
