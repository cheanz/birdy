import UIKit

extension UIImage {
    func resizeKeepingAspect(maxSide: CGFloat) -> UIImage {
        let maxSide = maxSide
        let w = size.width
        let h = size.height
        let scale = min(1.0, maxSide / max(w, h))
        if scale >= 1.0 { return self }
        let newSize = CGSize(width: w * scale, height: h * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized ?? self
    }
}
