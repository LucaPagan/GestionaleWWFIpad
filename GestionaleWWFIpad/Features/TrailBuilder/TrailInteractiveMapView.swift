import SwiftUI
import UIKit
import CoreLocation

// MARK: - TrailInteractiveMapView

struct TrailInteractiveMapView: UIViewRepresentable {
    let imageName: String
    let allPOIs: [POI]
    let trailSteps: [TrailDraftStep]
    var selectedPOIId: UUID? = nil
    
    let onTapMap: (CGPoint) -> Void
    let onTapPOI: (POI) -> Void
    
    // Path Tracing
    var isTracingMode: Bool = false
    var tracingStartPOIId: UUID? = nil
    var tracingEndPOIId: UUID? = nil
    var onPathCaptured: (String) -> Void = { _ in }

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
        
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.delegate = context.coordinator
        container.addGestureRecognizer(pan)
        context.coordinator.panGesture = pan

        // Tracing Layer (Active)
        let tracingLayer = CAShapeLayer()
        tracingLayer.strokeColor = UIColor.systemBlue.cgColor
        tracingLayer.lineWidth = 6.0
        tracingLayer.fillColor = nil
        tracingLayer.lineJoin = .round
        tracingLayer.lineCap = .round
        container.layer.addSublayer(tracingLayer)
        context.coordinator.tracingLayer = tracingLayer

        DispatchQueue.main.async {
            context.coordinator.setupLayout(in: scrollView, image: img)
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateMarkersAndLines(in: scrollView)
        
        // Show/Hide tracing HUD
        context.coordinator.updateTracingUI()
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate, UIDragInteractionDelegate {
        var parent: TrailInteractiveMapView
        weak var containerView: UIView?
        weak var imageView: UIImageView?
        weak var linesLayer: CAShapeLayer?
        weak var tracingLayer: CAShapeLayer?
        weak var tapGesture: UITapGestureRecognizer?
        weak var panGesture: UIPanGestureRecognizer?
        
        private var activePathPoints: [CGPoint] = []
        private var tracingHUD: UIView?

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
            
            // 1. Draw Step Paths (Complex Geometry)
            // Clean old path layers
            container.layer.sublayers?.filter { $0.name == "StepPath" }.forEach { $0.removeFromSuperlayer() }
            
            for step in parent.trailSteps {
                guard let geom = step.pathGeometry, !geom.isEmpty else { continue }
                let coords = PolylineCodec.decode(geom)
                let stepPath = UIBezierPath()
                let points = coords.map { CGPoint(x: $0.latitude * imageSize.width, y: $0.longitude * imageSize.height) }
                
                if let first = points.first {
                    stepPath.move(to: first)
                    for i in 1..<points.count {
                        stepPath.addLine(to: points[i])
                    }
                }
                
                let stepLayer = CAShapeLayer()
                stepLayer.name = "StepPath"
                stepLayer.path = stepPath.cgPath
                stepLayer.strokeColor = UIColor(Color("WWFGreen")).withAlphaComponent(0.58).cgColor
                stepLayer.lineWidth = 3.2 / currentScale
                stepLayer.fillColor = nil
                stepLayer.lineJoin = .round
                stepLayer.lineCap = .round
                stepLayer.lineDashPattern = [
                    NSNumber(value: Double(9 / currentScale)),
                    NSNumber(value: Double(8 / currentScale))
                ]
                stepLayer.shadowColor = UIColor(Color("WWFGreen")).cgColor
                stepLayer.shadowRadius = 3 / currentScale
                stepLayer.shadowOpacity = 0.18
                stepLayer.shadowOffset = .zero
                container.layer.insertSublayer(stepLayer, at: 1) // Below markers

                let glowLayer = CAShapeLayer()
                glowLayer.name = "StepPath"
                glowLayer.path = stepPath.cgPath
                glowLayer.fillColor = nil
                glowLayer.strokeColor = UIColor(Color("WWFGreen")).withAlphaComponent(0.13).cgColor
                glowLayer.lineWidth = 9 / currentScale
                glowLayer.lineJoin = .round
                glowLayer.lineCap = .round
                container.layer.insertSublayer(glowLayer, below: stepLayer)
            }

            // 2. Draw Markers
            let targetScreenDiameter: CGFloat = 44
            let markerDiameter = targetScreenDiameter / currentScale

            let positions: [(poi: POI, center: CGPoint)] = parent.allPOIs.map { poi in
                let cx = poi.x * imageSize.width
                let cy = poi.y * imageSize.height
                return (poi, CGPoint(x: cx, y: cy))
            }

            container.subviews
                .filter { $0 is TrailPOIMarkerView }
                .forEach { $0.removeFromSuperview() }

            for entry in positions {
                let poi = entry.poi
                let center = entry.center
                
                // Highlight if it's in the steps or explicitly selected
                let stepIndex = parent.trailSteps.firstIndex(where: { $0.poi?.id == poi.id })
                let isTracingActivePOI = parent.isTracingMode && (poi.id == parent.tracingStartPOIId || poi.id == parent.tracingEndPOIId)
                let isSelected = parent.isTracingMode ? isTracingActivePOI : (stepIndex != nil || poi.id == parent.selectedPOIId)

                let markerView = TrailPOIMarkerView(
                    poi: poi,
                    isSelected: isSelected,
                    stepIndex: stepIndex,
                    markerDiameter: markerDiameter,
                    zoomScale: currentScale,
                    labelAbove: false // Simplified for trail builder
                )

                let markerHeight = markerDiameter * 1.34
                let labelHeight: CGFloat = 20 / currentScale
                let labelGap: CGFloat = 5 / currentScale
                let totalW = max(markerDiameter * 3, 80 / currentScale)
                let totalH = markerHeight + labelGap + labelHeight

                markerView.frame = CGRect(
                    x: center.x - totalW / 2,
                    y: center.y - markerHeight,
                    width: totalW,
                    height: totalH
                )

                markerView.isUserInteractionEnabled = !parent.isTracingMode
                if !parent.isTracingMode {
                    markerView.onTap = { [weak self] in
                        self?.parent.onTapPOI(poi)
                    }
                    
                    // Add drag interaction only outside path tracing. In tracing mode the map
                    // must behave like a freehand canvas, even when starting near a POI.
                    let drag = UIDragInteraction(delegate: self)
                    markerView.addInteraction(drag)
                    markerView.accessibilityIdentifier = poi.id.uuidString
                }

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
            guard !parent.isTracingMode else { return }
            guard let imageView = imageView else { return }
            let location = gesture.location(in: imageView)
            let normX = location.x / imageView.frame.width
            let normY = location.y / imageView.frame.height
            guard normX >= 0, normX <= 1, normY >= 0, normY <= 1 else { return }
            parent.onTapMap(CGPoint(x: normX, y: normY))
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if parent.isTracingMode {
                return gestureRecognizer === panGesture
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            parent.isTracingMode
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === tapGesture, other is UIPanGestureRecognizer { return true }
            return false
        }
        
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard parent.isTracingMode, let imageView = imageView else { return }
            
            let location = gesture.location(in: imageView)
            let imageSize = imageView.frame.size
            
            switch gesture.state {
            case .began:
                activePathPoints = [location]
                tracingLayer?.path = nil
                tracingLayer?.isHidden = false
            case .changed:
                // Only add point if it's far enough from the last one (lightweight)
                if let last = activePathPoints.last {
                    let dist = hypot(location.x - last.x, location.y - last.y)
                    if dist > 5.0 / (parent.isTracingMode ? 2.0 : 1.0) { // Precision threshold
                        activePathPoints.append(location)
                        updateTracingPath()
                    }
                }
            case .ended:
                finishTracing(imageSize: imageSize)
            default:
                activePathPoints = []
                tracingLayer?.path = nil
            }
        }
        
        private func updateTracingPath() {
            let path = UIBezierPath()
            if let first = activePathPoints.first {
                path.move(to: first)
                for i in 1..<activePathPoints.count {
                    path.addLine(to: activePathPoints[i])
                }
            }
            tracingLayer?.path = path.cgPath
        }
        
        private func finishTracing(imageSize: CGSize) {
            guard activePathPoints.count > 1 else { return }
            
            // Convert to normalized coordinates for storage
            let coords = activePathPoints.map { pt in
                CLLocationCoordinate2D(
                    latitude: Double(pt.x / imageSize.width),
                    longitude: Double(pt.y / imageSize.height)
                )
            }
            
            let encoded = PolylineCodec.encode(coords)
            parent.onPathCaptured(encoded)
            
            activePathPoints = []
            tracingLayer?.path = nil
            tracingLayer?.isHidden = true
        }
        
        func updateTracingUI() {
            guard let container = containerView?.superview else { return }
            
            if parent.isTracingMode {
                if tracingHUD == nil {
                    let hud = createTracingHUD()
                    container.addSubview(hud)
                    tracingHUD = hud
                    
                    NSLayoutConstraint.activate([
                        hud.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                        hud.topAnchor.constraint(equalTo: container.topAnchor, constant: 100)
                    ])
                }
                panGesture?.isEnabled = true
                tapGesture?.isEnabled = false
                // Disable scrolling during tracing
                if let scrollView = container as? UIScrollView {
                    scrollView.isScrollEnabled = false
                }
            } else {
                tracingHUD?.removeFromSuperview()
                tracingHUD = nil
                panGesture?.isEnabled = false
                tapGesture?.isEnabled = true
                if let scrollView = container as? UIScrollView {
                    scrollView.isScrollEnabled = true
                }
            }
        }
        
        private func createTracingHUD() -> UIView {
            let view = UIView()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
            view.layer.cornerRadius = 20
            
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = "🎨 TRACCIA IL PERCORSO TRA I PUNTI EVIDENZIATI IN GIALLO"
            label.textColor = .white
            label.font = .systemFont(ofSize: 14, weight: .bold)
            
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                label.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
                label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10)
            ])
            
            return view
        }
        
        // MARK: - UIDragInteractionDelegate
        
        func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
            guard !parent.isTracingMode else { return [] }
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

        let markerHeight = markerDiameter * 1.34
        let circleCenterX = rect.midX
        let radius = markerDiameter * 0.43
        let circleCenterY = radius + markerDiameter * 0.07
        let tip = CGPoint(x: circleCenterX, y: markerHeight)

        if isSelected {
            let selectionPadding = 5 / zoomScale
            ctx.setStrokeColor(UIColor(Color("WWFGreen")).withAlphaComponent(0.72).cgColor)
            ctx.setLineWidth(2.5 / zoomScale)
            ctx.addArc(center: CGPoint(x: circleCenterX, y: circleCenterY), radius: radius + selectionPadding, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.strokePath()

            ctx.setFillColor(UIColor(Color("WWFGreen")).withAlphaComponent(0.12).cgColor)
            ctx.addArc(center: CGPoint(x: circleCenterX, y: circleCenterY), radius: radius + selectionPadding * 1.8, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.fillPath()
        }

        ctx.setShadow(offset: CGSize(width: 0, height: 2.5 / zoomScale), blur: 5 / zoomScale, color: UIColor.black.withAlphaComponent(0.24).cgColor)
        let fillColor = isSelected ? UIColor(Color("WWFGreen")) : UIColor(poi.type.color).withAlphaComponent(0.86)
        ctx.setFillColor(fillColor.cgColor)

        let pinPath = UIBezierPath()
        pinPath.move(to: CGPoint(x: circleCenterX - radius, y: circleCenterY))
        pinPath.addCurve(
            to: CGPoint(x: circleCenterX, y: circleCenterY - radius),
            controlPoint1: CGPoint(x: circleCenterX - radius, y: circleCenterY - radius * 0.56),
            controlPoint2: CGPoint(x: circleCenterX - radius * 0.56, y: circleCenterY - radius)
        )
        pinPath.addCurve(
            to: CGPoint(x: circleCenterX + radius, y: circleCenterY),
            controlPoint1: CGPoint(x: circleCenterX + radius * 0.56, y: circleCenterY - radius),
            controlPoint2: CGPoint(x: circleCenterX + radius, y: circleCenterY - radius * 0.56)
        )
        pinPath.addCurve(
            to: CGPoint(x: circleCenterX + radius * 0.58, y: circleCenterY + radius * 0.78),
            controlPoint1: CGPoint(x: circleCenterX + radius, y: circleCenterY + radius * 0.36),
            controlPoint2: CGPoint(x: circleCenterX + radius * 0.82, y: circleCenterY + radius * 0.62)
        )
        pinPath.addCurve(
            to: tip,
            controlPoint1: CGPoint(x: circleCenterX + radius * 0.42, y: markerHeight * 0.72),
            controlPoint2: CGPoint(x: circleCenterX + radius * 0.16, y: markerHeight * 0.88)
        )
        pinPath.addCurve(
            to: CGPoint(x: circleCenterX - radius * 0.58, y: circleCenterY + radius * 0.78),
            controlPoint1: CGPoint(x: circleCenterX - radius * 0.16, y: markerHeight * 0.88),
            controlPoint2: CGPoint(x: circleCenterX - radius * 0.42, y: markerHeight * 0.72)
        )
        pinPath.addCurve(
            to: CGPoint(x: circleCenterX - radius, y: circleCenterY),
            controlPoint1: CGPoint(x: circleCenterX - radius * 0.82, y: circleCenterY + radius * 0.62),
            controlPoint2: CGPoint(x: circleCenterX - radius, y: circleCenterY + radius * 0.36)
        )
        pinPath.close()
        pinPath.fill()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.72).cgColor)
        ctx.setLineWidth(1.4 / zoomScale)
        pinPath.stroke()

        let medallionRadius = radius * 0.58
        ctx.setFillColor(UIColor(red: 1.0, green: 0.992, blue: 0.965, alpha: 1).cgColor)
        ctx.addArc(center: CGPoint(x: circleCenterX, y: circleCenterY), radius: medallionRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.fillPath()

        let iconPtSize = max(8, (targetScreenDiameter * 0.35) / zoomScale)
        let config = UIImage.SymbolConfiguration(pointSize: iconPtSize, weight: .semibold)
        if let icon = UIImage(systemName: poi.type.icon, withConfiguration: config)?.withTintColor(UIColor(red: 0.102, green: 0.200, blue: 0.126, alpha: 1), renderingMode: .alwaysOriginal) {
            let iconSize = icon.size
            let iconOrigin = CGPoint(x: circleCenterX - iconSize.width / 2, y: circleCenterY - iconSize.height / 2)
            icon.draw(in: CGRect(origin: iconOrigin, size: iconSize))
        }

        // Number badge if it's a step
        if let idx = stepIndex {
            let badgeRadius = radius * 0.45
            let badgeCenter = CGPoint(x: circleCenterX + radius * 0.7, y: circleCenterY - radius * 0.7)
            ctx.setShadow(offset: CGSize(width: 0, height: 1 / zoomScale), blur: 2 / zoomScale, color: UIColor.black.withAlphaComponent(0.22).cgColor)
            ctx.setFillColor(UIColor(red: 0.102, green: 0.200, blue: 0.126, alpha: 1).cgColor)
            ctx.addArc(center: badgeCenter, radius: badgeRadius, startAngle: 0, endAngle: .pi*2, clockwise: false)
            ctx.fillPath()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            
            let font = UIFont.systemFont(ofSize: 12 / zoomScale, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
            let str = "\(idx + 1)" as NSString
            let size = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: badgeCenter.x - size.width/2, y: badgeCenter.y - size.height/2), withAttributes: attrs)
        }

        let labelFontSize = targetLabelFontSize / zoomScale
        let paddingH = targetLabelPaddingH / zoomScale
        let paddingV = targetLabelPaddingV / zoomScale
        let labelGap = 4 / zoomScale

        let font = UIFont.systemFont(ofSize: labelFontSize, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(red: 0.102, green: 0.200, blue: 0.126, alpha: 1)]
        let label = poi.name as NSString

        let maxLabelWidth = rect.width - paddingH * 2
        var labelSize = label.size(withAttributes: attrs)
        labelSize.width = min(labelSize.width, maxLabelWidth)

        let bgWidth = labelSize.width + paddingH * 2
        let bgHeight = labelSize.height + paddingV * 2
        let bgX = circleCenterX - bgWidth / 2
        let bgY = markerHeight + labelGap

        let bgRect = CGRect(x: bgX, y: bgY, width: bgWidth, height: bgHeight)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: bgRect.height / 2)

        UIColor(red: 1.0, green: 0.992, blue: 0.965, alpha: 0.92).setFill()
        bgPath.fill()
        UIColor(Color("WWFGreen")).withAlphaComponent(0.28).setStroke()
        bgPath.lineWidth = 1 / zoomScale
        bgPath.stroke()

        let textRect = CGRect(x: bgRect.origin.x + paddingH, y: bgRect.origin.y + paddingV, width: labelSize.width, height: labelSize.height)
        label.draw(with: textRect, options: [.truncatesLastVisibleLine, .usesLineFragmentOrigin], attributes: attrs, context: nil)
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitRadius = (markerDiameter / 2) + 12
        let center = CGPoint(x: bounds.midX, y: markerDiameter * 0.5)
        let dx = point.x - center.x
        let dy = point.y - center.y
        return (dx * dx + dy * dy) <= (hitRadius * hitRadius)
    }
}
