//
//  ScrollableCanvas.swift
//  MaLiang_Example
//
//  Created by Harley.xk on 2018/5/2.
//  Copyright © 2018年 CocoaPods. All rights reserved.
//

import UIKit

open class ScrollableCanvas: Canvas {
    
    open override func setup() {
        super.setup()
        
        setupScrollIndicators()
        
        contentSize = bounds.size
        
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGestureRecognizer(_:)))
        addGestureRecognizer(pinchGesture)
        
        moveGesture = UIPanGestureRecognizer(target: self, action: #selector(handleMoveGestureRecognizer(_:)))
        moveGesture.minimumNumberOfTouches = 2
        addGestureRecognizer(moveGesture)
    }
    
    /// the max zoomScale of canvas, will cause redraw if the new value is less than current
    open var maxScale: CGFloat = 3 {
        didSet {
            if maxScale < zoom {
                self.zoom = maxScale
                self.scale = maxScale
                self.redraw()
            }
        }
    }
    
    /// the actural drawable size of canvas, may larger than current bounds
    /// contentSize must between bounds size and 5120x5120
    open var contentSize: CGSize = .zero {
        didSet {
            updateScrollIndicators()
        }
    }
    
    /// get snapthot image for the same size to content
    open override func snapshot() -> UIImage? {
        /// draw content in texture of the same size to content
        if contentSize == bounds.size {
            return super.snapshot()
        }
        
        /// create a new render target with same size to the content, for snapshoting
        let imageSize = contentSize * contentScaleFactor
        let snapshotTarget = RenderTarget(size: imageSize, device: device)
        redraw(on: snapshotTarget, display: false)
        snapshotTarget.commitCommands()
        if let texture = snapshotTarget.texture, let ciimage = CIImage(mtlTexture: texture, options: nil) {
            let context = CIContext() // Prepare for create CGImage
            let rect = CGRect(origin: .zero, size: imageSize)
            /// create cgimage that is savable, ciimage is downMirrored
            if let cgimg = context.createCGImage(ciimage.oriented(forExifOrientation: 4), from: rect) {
                return UIImage(cgImage: cgimg)
            }
        }
        return nil
    }
    
    private var pinchGesture: UIPinchGestureRecognizer!
    private var moveGesture: UIPanGestureRecognizer!
    
    private var currentZoomScale: CGFloat = 1
    private var offsetAnchor: CGPoint = .zero
    private var beginLocation: CGPoint = .zero
    
    @objc private func handlePinchGestureRecognizer(_ gesture: UIPinchGestureRecognizer) {
        let location = gesture.location(in: self)
        switch gesture.state {
        case .began:
            beginLocation = location
            offsetAnchor = location + contentOffset
            showScrollIndicators()
        case .changed:
            guard gesture.numberOfTouches >= 2 else {
                return
            }
            var scale = currentZoomScale * gesture.scale * gesture.scale
            scale = scale.between(min: 1, max: maxScale)
            self.zoom = scale
            self.scale = zoom
            let offset = offsetAnchor * (scale / currentZoomScale) - location
            contentOffset = offset.between(min: .zero, max: maxOffset)
            redraw()
            updateScrollIndicators()
        case .ended: fallthrough
        case .cancelled: fallthrough
        case .failed:
            currentZoomScale = zoom
            hidesScrollIndicators()
        default: break
        }
    }
    
    @objc private func handleMoveGestureRecognizer(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: self)
        switch gesture.state {
        case .began:
            offsetAnchor = location + contentOffset
            showScrollIndicators()
        case .changed:
            guard gesture.numberOfTouches >= 2 else {
                return
            }
            contentOffset = (offsetAnchor - location).between(min: .zero, max: maxOffset)
            redraw()
            updateScrollIndicators()
        default: hidesScrollIndicators()
        }
    }
    
    private var maxOffset: CGPoint {
        return CGPoint(x: contentSize.width * zoom - bounds.width, y: contentSize.height * zoom - bounds.height)
    }
    
    // MARK: - Scrolling Indicators
    
    /// show indicator while scrolling, like UIScrollView
    
    // defaults to true if width of contentSize is larger than bounds
    open var showHorizontalScrollIndicator = true
    
    // defaults to true if height of contentSize is larger than bounds
    open var showVerticalScrollIndicator = true
    
    private weak var horizontalScrollIndicator: UIView!
    private weak var verticalScrollIndicator: UIView!
    
    private func setupScrollIndicators() {
        
        // horizontal scroll indicator
        let horizontalScrollIndicator = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        horizontalScrollIndicator.layer.cornerRadius = 2
        horizontalScrollIndicator.clipsToBounds = true
        addSubview(horizontalScrollIndicator)
        self.horizontalScrollIndicator = horizontalScrollIndicator
        
        // vertical scroll indicator
        let verticalScrollIndicator = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        verticalScrollIndicator.layer.cornerRadius = 2
        verticalScrollIndicator.clipsToBounds = true
        addSubview(verticalScrollIndicator)
        self.verticalScrollIndicator = verticalScrollIndicator
    }
    
    private func updateScrollIndicators() {
        
        let showHorizontal = showHorizontalScrollIndicator && contentSize.width > bounds.width
        horizontalScrollIndicator?.isHidden = !showHorizontal
        if showHorizontal {
            updateHorizontalScrollIndicator()
        }
        
        let showVertical = showVerticalScrollIndicator && contentSize.height > bounds.height
        verticalScrollIndicator.isHidden = !showVertical
        if showVertical {
            updateVerticalScrollIndicator()
        }
    }
    
    private func updateHorizontalScrollIndicator() {
        let ratio = bounds.width / contentSize.width / zoom
        let offsetRatio = contentOffset.x / contentSize.width / zoom
        let width = bounds.width - 12
        let frame = CGRect(x: offsetRatio * width + 4, y: bounds.height - 6, width: width * ratio, height: 4)
        horizontalScrollIndicator.frame = frame
    }
    
    private func updateVerticalScrollIndicator() {
        let ratio = bounds.height / contentSize.height / zoom
        let offsetRatio = contentOffset.y / contentSize.height / zoom
        let height = bounds.height - 12
        let frame = CGRect(x: bounds.width - 6, y: height * offsetRatio + 4, width: 4, height: height * ratio)
        verticalScrollIndicator.frame = frame
    }
    
    private func showScrollIndicators() {
        horizontalScrollIndicator.alpha = 0.8
        verticalScrollIndicator.alpha = 0.8
    }
    
    private func hidesScrollIndicators() {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState], animations: {
            self.horizontalScrollIndicator.alpha = 0
            self.verticalScrollIndicator.alpha = 0
        })
    }
}
