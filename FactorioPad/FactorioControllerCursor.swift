import UIKit

final class FactorioControllerCursorView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        accessibilityElementsHidden = true

        let pointer = CAShapeLayer()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 1.5, y: 1.5))
        for point in [
            CGPoint(x: 16.5, y: 9.5), CGPoint(x: 10.5, y: 12),
            CGPoint(x: 13, y: 18.5), CGPoint(x: 9.5, y: 20),
            CGPoint(x: 6.5, y: 13.5), CGPoint(x: 2.5, y: 16)
        ] { path.addLine(to: point) }
        path.close()
        pointer.path = path.cgPath
        pointer.fillColor = UIColor(red: 0.93, green: 0.59, blue: 0.14, alpha: 1).cgColor
        pointer.strokeColor = UIColor(red: 0.18, green: 0.11, blue: 0.05, alpha: 1).cgColor
        pointer.lineWidth = 2.3
        pointer.lineJoin = .round
        pointer.lineCap = .round
        pointer.shadowColor = UIColor.black.cgColor
        pointer.shadowOpacity = 0.55
        pointer.shadowRadius = 1.2
        pointer.shadowOffset = CGSize(width: 1, height: 1)
        layer.addSublayer(pointer)

        let highlight = CAShapeLayer()
        let highlightPath = UIBezierPath()
        highlightPath.move(to: CGPoint(x: 4, y: 4))
        highlightPath.addLine(to: CGPoint(x: 12, y: 8.5))
        highlight.path = highlightPath.cgPath
        highlight.fillColor = UIColor.clear.cgColor
        highlight.strokeColor = UIColor(red: 1, green: 0.8, blue: 0.35, alpha: 0.75).cgColor
        highlight.lineWidth = 1
        highlight.lineCap = .round
        layer.addSublayer(highlight)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
