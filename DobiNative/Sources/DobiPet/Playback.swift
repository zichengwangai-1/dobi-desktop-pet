import AppKit
import AVFoundation
import CoreImage
import DobiCore

// Keep the last decoded frame during clip transitions to prevent blank flashes.
final class Playback {
    private let player = AVQueuePlayer()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let store: PetStore
    private weak var view: PetView?
    private var assets: [PetAction: AVURLAsset] = [:]
    private var actions: [ObjectIdentifier: PetAction] = [:]
    private var timer: Timer?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var stage: PetStage
    private var sound: NSSound?
    private(set) var renderedFrames = 0
    private var hasReportedFrame = false
    private var displayedItem: ObjectIdentifier?
    private var hasReportedFailure = false
    var onFailure: ((String) -> Void)?

    init(view: PetView, store: PetStore) {
        self.view = view; self.store = store; stage = store.stage()
        for action in PetAction.allCases { assets[action] = AVURLAsset(url: Assets.video(action)) }
        player.isMuted = true
        player.actionAtItemEnd = .advance
        player.automaticallyWaitsToMinimizeStalling = false
        sound = NSSound(contentsOf: Assets.root.appendingPathComponent("Sounds/bark.wav"), byReference: false)
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                             object: nil, queue: .main) { [weak self] note in
            guard let self, let item = note.object as? AVPlayerItem,
                  self.actions.removeValue(forKey: ObjectIdentifier(item)) != nil else { return }
            let newStage = self.store.stage()
            if newStage != self.stage {
                self.stage = newStage; self.startAmbient()
                print("event=growth stage=adult")
            } else { self.appendAmbient() }
        }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime,
                                                                 object: nil, queue: .main) { [weak self] note in
            guard let self, let item = note.object as? AVPlayerItem,
                  self.actions[ObjectIdentifier(item)] != nil else { return }
            self.onFailure?("视频播放失败：\(item.error?.localizedDescription ?? "未知错误")")
        }
        let renderTimer = Timer(timeInterval: 1.0/30.0, repeats: true) { [weak self] _ in self?.render() }
        RunLoop.main.add(renderTimer, forMode: .common)
        timer = renderTimer
    }
    func startAmbient() {
        player.pause(); player.removeAllItems(); actions.removeAll()
        stage = store.stage()
        for _ in 0..<3 { appendAmbient() }
        player.play()
    }
    private func enqueue(_ action: PetAction) {
        guard let asset = assets[action] else { return }
        let item = AVPlayerItem(asset: asset)
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        item.add(output)
        item.preferredForwardBufferDuration = 2
        actions[ObjectIdentifier(item)] = action
        player.insert(item, after: nil)
    }
    private func appendAmbient() {
        let previous = player.items().last.flatMap { actions[ObjectIdentifier($0)] }
        enqueue(PetAction.ambient(for: stage, excluding: previous))
    }
    func interact() {
        stage = store.stage()
        let action = PetAction.interaction(for: stage)
        player.pause(); player.removeAllItems(); actions.removeAll()
        enqueue(action)
        for _ in 0..<2 { appendAmbient() }
        player.play()
        sound?.stop()
        if stage == .adult && store.soundEnabled { sound?.play() }
        print("event=interaction action=\(action.rawValue)")
    }
    private func render() {
        guard let view, let item = player.currentItem,
              let output = item.outputs.first as? AVPlayerItemVideoOutput else { return }
        if item.status == .failed && !hasReportedFailure {
            hasReportedFailure = true
            onFailure?(item.error?.localizedDescription ?? "视频无法解码")
            return
        }
        let time = output.itemTime(forHostTime: CACurrentMediaTime())
        guard output.hasNewPixelBuffer(forItemTime: time),
              let buffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) else { return }
        let image = CIImage(cvPixelBuffer: buffer)
        guard let cg = context.createCGImage(image, from: image.extent) else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        view.layer?.contents = cg
        CATransaction.commit()
        renderedFrames += 1
        if !hasReportedFrame {
            hasReportedFrame = true
            CVPixelBufferLockBaseAddress(buffer, .readOnly)
            let address = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
            let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
            var alphaMin: UInt8 = 255, alphaMax: UInt8 = 0, clearPixels = 0
            for y in 0..<CVPixelBufferGetHeight(buffer) {
                for x in 0..<CVPixelBufferGetWidth(buffer) {
                    let a = address[y*rowBytes+x*4+3]
                    alphaMin = min(alphaMin, a); alphaMax = max(alphaMax, a)
                    if a == 0 { clearPixels += 1 }
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
            print("event=first_frame alphaMin=\(alphaMin) alphaMax=\(alphaMax) clearPixels=\(clearPixels) stage=\(stage.rawValue)")
        }
        let identity = ObjectIdentifier(item)
        if displayedItem != identity {
            displayedItem = identity
            print("event=clip action=\(actions[identity]?.rawValue ?? "unknown") renderedFrames=\(renderedFrames)")
        }
        // Pass clicks in the transparent margin through to the desktop.
        if !view.pointerDown, let window = view.window {
            let point = view.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
            let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
            let x = Int(point.x / view.bounds.width * CGFloat(w))
            let y = h - 1 - Int(point.y / view.bounds.height * CGFloat(h))
            var overDog = false
            if x >= 0 && y >= 0 && x < w && y < h {
                CVPixelBufferLockBaseAddress(buffer, .readOnly)
                let address = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
                overDog = address[y*CVPixelBufferGetBytesPerRow(buffer)+x*4+3] > 24
                CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
            }
            window.ignoresMouseEvents = !overDog
        }
    }
    func stop() {
        timer?.invalidate(); player.pause(); sound?.stop()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
    }
}
