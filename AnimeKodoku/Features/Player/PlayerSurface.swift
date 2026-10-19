import SwiftUI
import AVFoundation
import AVKit
#if os(iOS)
import UIKit

final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
struct PlayerSurface: UIViewRepresentable {
    var player: AVPlayer?
    var zoom: Bool
    func makeUIView(context: Context) -> PlayerLayerView { let view = PlayerLayerView(); view.backgroundColor = .black; return view }
    func updateUIView(_ view: PlayerLayerView, context: Context) { view.playerLayer.player = player; view.playerLayer.videoGravity = zoom ? .resizeAspectFill : .resizeAspect }
    static func dismantleUIView(_ view: PlayerLayerView, coordinator: ()) { view.playerLayer.player = nil }
}
#else
import AppKit

final class PlayerLayerView: NSView {
    let playerLayer = AVPlayerLayer()
    override init(frame: NSRect) { super.init(frame: frame); wantsLayer = true; layer = playerLayer }
    required init?(coder: NSCoder) { return nil }
    override func layout() { super.layout(); playerLayer.frame = bounds }
}
struct PlayerSurface: NSViewRepresentable {
    var player: AVPlayer?
    var zoom: Bool
    func makeNSView(context: Context) -> PlayerLayerView { PlayerLayerView(frame: .zero) }
    func updateNSView(_ view: PlayerLayerView, context: Context) { view.playerLayer.player = player; view.playerLayer.videoGravity = zoom ? .resizeAspectFill : .resizeAspect }
    static func dismantleNSView(_ view: PlayerLayerView, coordinator: ()) { view.playerLayer.player = nil }
}
#endif

#if os(iOS)
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView { AVRoutePickerView() }
    func updateUIView(_ view: AVRoutePickerView, context: Context) { }
}
#else
struct AirPlayButton: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView { AVRoutePickerView(frame: .zero) }
    func updateNSView(_ view: AVRoutePickerView, context: Context) { }
}
#endif
