import SwiftUI
import UIKit

// MARK: - TrailInteractiveMapView

struct TrailInteractiveMapView: UIViewRepresentable {
    let imageName: String
    let allPOIs: [POI]
    let trailSteps: [TrailDraftStep]
    var selectedPOIId: UUID? = nil
    
    let onTapMap: (CGPoint) -> Void
    let onTapPOI: (POI) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .black
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.decelerationRate = .normal
        scrollView.minimumZoomScale = 0.5
        scrollView.maximumZoomScale = 8.0

        let container = UIView()
        container.backgroundColor = .clear
        context.coordinator.containerView = container
        scrollView.addSubview(container)

        // Map Image
        guard let img = UIImage(named: imageName) else { return scrollView }
        let imageView = UIImageView(image: img)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        container.addSubview(imageView)
        context.coordinator.imageView = imageView
        
        // Lines layer
        let linesLayer = CAShapeLayer()
        linesLayer.strokeColor = UIColor(Color("WWFGreen")).cgColor
        linesLayer.lineWidth = 4.0
        linesLayer.fillColor = nil
        linesLayer.lineJoin = .round
        linesLayer.lineCap = .round
        linesLayer.shadowColor = UIColor.black.cgColor
        linesLayer.shadowOffset = CGSize(width: 0, height: 2)
        linesLayer.shadowOpacity = 0.5
        linesLayer.shadowRadius = 4
        container.layer.addSublayer(linesLayer)
        context.coordinator.linesLayer = linesLayer

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.delegate = context.coordinator
        container.addGestureRecognizer(tap)
        context.coordinator.tapGesture = tap

        DispatchQueue.main.async {
            context.coordinator.setupLayout(in: scrollView, image: img)
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateMarkersAndLines(in: scrollView)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate, UIDragInteractionDelegate {
        var parent: TrailInteractiveMapView
        weak var containerView: UIView?
        weak var imageView: UIImageView?
        weak var linesLayer: CAShapeLayer?
        weak var tapGesture: UITapGestureRecognizer?

        init(_ parent: TrailInteractiveMapView) {
            self.parent = parent
        }

        func setupLayout(in scrollView: UIScrollView, image: UIImage) {
            guard let container = containerView,
                  let imageView = imageView else { return }

            let screenW = scrollView.bounds.width
            let screenH = scrollView.bounds.height
            guard screenW > 0, screenH > 0 else { return }
            
            let imgRatio = image.size.height / image.size.width
            let mapW = screenW
            let mapH = mapW * imgRatio

            imageView.frame = CGRect(x: 0, y: 0, width: mapW, height: mapH)
            container.frame = CGRect(x: 0, y: 0, width: mapW, height: mapH)
            scrollView.contentSize = CGSize(width: mapW, height: mapH)

            let scaleToFitH = screenH / mapH
            let initialScale = min(1.0, scaleToFitH)
            scrollView.minimumZoomScale = max(0.3, min(initialScale, 0.8))
            scrollView.zoomScale = initialScale

            let scaledH = mapH * initialScale
            let offsetY = max(0, scaledH - screenH)
            scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: false)
            
            updateMarkersAndLines(in: scrollView)
        }
        
        func updateMarkersAndLines(in scrollView: UIScrollView) {
            guard let container = containerView, let imageView = imageView else { return }
            let imageSize = imageView.frame.size
            guard imageSize.width > 0 else { return }

            let currentScale = scrollView.zoomScale
            
            // 1. Draw Lines
            if let linesLayer = linesLayer {
                linesLayer.lineWidth = 4.0 / currentScale
                let path = UIBezierPath()
                
                let stepPositions = parent.trailSteps.compactMap { step -> CGPoint? in
                    guard let poi = step.poi else { return nil }
                    return CGPoint(x: poi.x * imageSize.width, y: poi.y * imageSize.height)
                }
                
                if !stepPositions.isEmpty {
                    path.move(to: stepPositions[0])
                    for i in 1..<stepPositions.count {
                        path.addLine(to: stepPositions[i])
                    }
                }
                linesLayer.path = path.cgPath
            }

            // 2. Draw Markers
            let targetScreenDiameter: CGFloat = 40
            let markerDiameter = targetScreenDiameter / currentScale

            var positions: [(poi: POI, center: CGPoint)] = parent.allPOIs.map { poi in
                let cx = poi.x * imageSize.width
                let cy = poi.y * imageSize.height
                return (poi, CGPoint(x: cx, y: cy))
            }

            container.subviews
                .filter { $0 is TrailPOIMarkerView }
                .forEach { $0.removeFromSuperview() }

            for (index, entry) in positions.enumerated() {
                let poi = entry.poi
                let center = entry.center
                
                // Highlight if it's in the steps or explicitly selected
                let stepIndex = parent.trailSteps.firstIndex(where: { $0.poi?.id == poi.id })
                let isSelected = stepIndex != nil || poi.id == parent.selectedPOIId

                let markerView = TrailPOIMarkerView(
                    poi: poi,
                    isSelected: isSelected,
                    stepIndex: stepIndex,
                    markerDiameter: markerDiameter,
                    zoomScale: currentScale,
                    labelAbove: false // Simplified for trail builder
                )

                let labelHeight: CGFloat = 18 / currentScale
                let labelGap: CGFloat = 4 / currentScale
                let totalW = max(markerDiameter * 3, 80 / currentScale)
                let totalH = markerDiameter + labelGap + labelHeight

                markerView.frame = CGRect(
                    x: center.x - totalW / 2,
                    y: center.y - markerDiameter / 2,
                    width: totalW,
                    height: totalH
                )

                markerView.onTap = { [weak self] in
                    self?.parent.onTapPOI(poi)
                }
                
                // Add drag interaction
                let drag = UIDragInteraction(delegate: self)
                markerView.addInteraction(drag)
                // Store POI UUID for drag session
                markerView.accessibilityIdentifier = poi.id.uuidString

                container.addSubview(markerView)
            }
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            containerView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView)
            updateMarkersAndLines(in: scrollView)
        }

        private func centerContent(in scrollView: UIScrollView) {
            guard let container = containerView else { return }
            let boundsSize = scrollView.bounds.size
            var frameToCenter = container.frame

            frameToCenter.origin.x = frameToCenter.size.width < boundsSize.width
                ? (boundsSize.width - frameToCenter.size.width) / 2 : 0
            frameToCenter.origin.y = frameToCenter.size.height < boundsSize.height
                ? (boundsSize.height - frameToCenter.size.height) / 2 : 0
            container.frame = frameToCenter
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let imageView = imageView else { return }
            let location = gesture.location(in: imageView)
            let normX = location.x / imageView.frame.width
            let normY = location.y / imageView.frame.height
            guard normX >= 0, normX <= 1, normY >= 0, normY <= 1 else { return }
            parent.onTapMap(CGPoint(x: normX, y: normY))
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === tapGesture, other is UIPanGestureRecognizer { return true }
            return false
        }
        
        // MARK: - UIDragInteractionDelegate
        
        func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
            guard let view = interaction.view, let idString = view.accessibilityIdentifier else { return [] }
            let provider = NSItemProvider(object: idString as NSString)
            let item = UIDragItem(itemProvider: provider)
            item.localObject = idString
            return [item]
        }
    }
}

// MARK: - TrailPOIMarkerView

final class TrailPOIMarkerView: UIView {
    var onTap: (() -> Void)?
    let poi: POI
    private let isSelected: Bool
    private let stepIndex: Int?
    private let markerDiameter: CGFloat
    private let zoomScale: CGFloat
    private let labelAbove: Bool

    private let targetScreenDiameter: CGFloat = 40
    private let targetLabelFontSize: CGFloat = 10
    private let targetLabelPaddingH: CGFloat = 6
    private let targetLabelPaddingV: CGFloat = 3

    init(poi: POI, isSelected: Bool, stepIndex: Int?, markerDiameter: CGFloat, zoomScale: CGFloat, labelAbove: Bool) {
        self.poi = poi
        self.isSelected = isSelected
        self.stepIndex = stepIndex
        self.markerDiameter = markerDiameter
        self.zoomScale = zoomScale
        self.labelAbove = labelAbove
        super.init(frame: .zero)
        backgroundColor = .clear
        isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onTap?() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let circleCenterX = rect.midX
        let circleCenterY = markerDiameter / 2
        let radius = markerDiameter / 2

        if isSelected {
            let selectionPadding = 5 / zoomScale
            ctx.setStrokeColor(UIColor.systemYellow.cgColor)
            ctx.setLineWidth(3.0 / zoomScale)
            ctx.addArc(center: CGPoint(x: circleCenterX, y: circleCenterY), radius: radius + selectionPadding, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.strokePath()
        }

        ctx.setShadow(offset: CGSize(width: 0, height: 2 / zoomScale), blur: 4 / zoomScale, color: UIColor.black.withAlphaComponent(0.4).cgColor)
        let fillColor = UIColor(poi.type.color)
        ctx.setFillColor(fillColor.cgColor)
        ctx.addArc(center: CGPoint(x: circleCenterX, y: circleCenterY), radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.4).cgColor)
        ctx.setLineWidth(1 / zoomScale)
        ctx.addArc(center: CGPoint(x: circleCenterX, y: circleCenterY), radius: radius - 0.5 / zoomScale, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()

        // Number badge if it's a step
        if let idx = stepIndex {
            let badgeRadius = radius * 0.45
            let badgeCenter = CGPoint(x: circleCenterX + radius * 0.7, y: circleCenterY - radius * 0.7)
            ctx.setFillColor(UIColor.systemBlue.cgColor)
            ctx.addArc(center: badgeCenter, radius: badgeRadius, startAngle: 0, endAngle: .pi*2, clockwise: false)
            ctx.fillPath()
            
            let font = UIFont.systemFont(ofSize: 12 / zoomScale, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
            let str = "\(idx + 1)" as NSString
            let size = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: badgeCenter.x - size.width/2, y: badgeCenter.y - size.height/2), withAttributes: attrs)
        } else {
            // Icon if not a step (or both, but icon is small)
            let iconPtSize = max(8, (targetScreenDiameter * 0.35) / zoomScale)
            let config = UIImage.SymbolConfiguration(pointSize: iconPtSize, weight: .semibold)
            if let icon = UIImage(systemName: poi.type.icon, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let iconSize = icon.size
                let iconOrigin = CGPoint(x: circleCenterX - iconSize.width / 2, y: circleCenterY - iconSize.height / 2)
                icon.draw(in: CGRect(origin: iconOrigin, size: iconSize))
            }
        }

        let labelFontSize = targetLabelFontSize / zoomScale
        let paddingH = targetLabelPaddingH / zoomScale
        let paddingV = targetLabelPaddingV / zoomScale
        let labelGap = 4 / zoomScale

        let font = UIFont.systemFont(ofSize: labelFontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let label = poi.name as NSString

        let maxLabelWidth = rect.width - paddingH * 2
        var labelSize = label.size(withAttributes: attrs)
        labelSize.width = min(labelSize.width, maxLabelWidth)

        let bgWidth = labelSize.width + paddingH * 2
        let bgHeight = labelSize.height + paddingV * 2
        let bgX = circleCenterX - bgWidth / 2
        let bgY = circleCenterY + radius + labelGap

        let bgRect = CGRect(x: bgX, y: bgY, width: bgWidth, height: bgHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: bgRect.height / 2)

        UIColor.black.withAlphaComponent(0.72).setFill()
        bgPath.fill()

        let textRect = CGRect(x: bgRect.origin.x + paddingH, y: bgRect.origin.y + paddingV, width: labelSize.width, height: labelSize.height)
        label.draw(with: textRect, options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin], attributes: attrs, context: nil)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitRadius = (markerDiameter / 2) + 12
        let center = CGPoint(x: bounds.midX, y: markerDiameter / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        return (dx * dx + dy * dy) <= (hitRadius * hitRadius)
    }
}
