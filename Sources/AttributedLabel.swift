//
//  Created by Pavel Sharanda on 18.10.17.
//  Copyright © 2017 Atributika. All rights reserved.
//
import Foundation

#if os(iOS)
    
import UIKit

public class AttributedLabel: UILabel {
    
    //MARK: - private properties
    private var detectionAreaButtons = [DetectionAreaButton]()
    
    //MARK: - public properties
    public var br_onClick: ((AttributedLabel, Detection)->Void)?
    
    public var br_isEnabled: Bool {
        set {
            detectionAreaButtons.forEach { $0.isUserInteractionEnabled = newValue  }
            state.isEnabled = newValue
        }
        get {
            return state.isEnabled
        }
    }
    
    public var br_attributedText: AttributedText? {
        set {
            state.attributedTextAndString = newValue.map { ($0, $0.attributedString) }
            setNeedsLayout()
        }
        get {
            return state.attributedTextAndString?.0
        }
    }
    
    //MARK: - init
    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    private func commonInit() {
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = true
    }
    
    //MARK: - overrides
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        detectionAreaButtons.forEach {
            $0.removeFromSuperview()
        }
        
        detectionAreaButtons.removeAll()
        
        if let (text, string) = state.attributedTextAndString {
            
            let inheritedString = string.withInherited(font: font, textAlignment: textAlignment)
            
            let textContainer = NSTextContainer(size: CGSize(width: bounds.size.width, height: bounds.size.height + 99))
            textContainer.lineBreakMode = lineBreakMode
            textContainer.maximumNumberOfLines = numberOfLines
            textContainer.lineFragmentPadding = 0
            
            let textStorage = NSTextStorage(attributedString: inheritedString)
            
            let layoutManager = NSLayoutManager()
            layoutManager.addTextContainer(textContainer)
            
            textStorage.addLayoutManager(layoutManager)
            
            let highlightableDetections = text.detections.filter { $0.style.typedAttributes[.highlighted] != nil }
            
            let usedRect = layoutManager.usedRect(for: textContainer)
            let dy = max(0, (bounds.height - usedRect.height)/2)
            highlightableDetections.forEach { detection in
                let nsrange = NSRange(detection.range, in: inheritedString.string)
                layoutManager.enumerateEnclosingRects(forGlyphRange: nsrange, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: textContainer, using: { (rect, stop) in
                    var finalRect = rect
                    finalRect.origin.y += dy
                    self.addDetectionAreaButton(frame: finalRect, detection: detection, text: String(inheritedString.string[detection.range]))
                })
            }
        }
    }
    
    //MARK: - DetectionAreaButton
    private class DetectionAreaButton: UIControl {
        
        var onHighlightChanged: ((DetectionAreaButton)->Void)?
        
        let detection: Detection
        init(detection: Detection) {
            self.detection = detection
            super.init(frame: .zero)
            self.isExclusiveTouch = true
        }
        
        override var isHighlighted: Bool {
            didSet {
                if (isHighlighted && isTracking) || !isHighlighted {
                    onHighlightChanged?(self)
                }
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let tapGestureRecognizer = gestureRecognizer as? UITapGestureRecognizer {
                if tapGestureRecognizer.numberOfTapsRequired == 1 && tapGestureRecognizer.numberOfTouchesRequired == 1 {
                    return false;
                }
            }
            return true;
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private func addDetectionAreaButton(frame: CGRect, detection: Detection, text: String) {
        let button = DetectionAreaButton(detection: detection)
        button.accessibilityLabel = text
        button.isAccessibilityElement = true
        button.accessibilityTraits = UIAccessibilityTraitButton
        button.isUserInteractionEnabled = state.isEnabled
        button.addTarget(self, action: #selector(handleDetectionAreaButtonClick), for: .touchUpInside)
        detectionAreaButtons.append(button)
        
        button.onHighlightChanged = { [weak self] in
            self?.state.detection = $0.isHighlighted ? $0.detection : nil
        }
        
        addSubview(button)
        button.frame = frame
    }
    
    @objc private func handleDetectionAreaButtonClick(_ sender: DetectionAreaButton) {
        br_onClick?(self, sender.detection)
    }
    
    //MARK: - state
    
    private struct State {
        var attributedTextAndString: (AttributedText, NSAttributedString)?
        var isEnabled: Bool
        var detection: Detection?
    }
    
    private var state: State = State(attributedTextAndString: nil, isEnabled: true, detection: nil) {
        didSet {
            update()
        }
    }
    
    private func update() {
        if let (text, string) = state.attributedTextAndString {
            
            if let detection = state.detection {
                let higlightedAttributedString = NSMutableAttributedString(attributedString: string)
                higlightedAttributedString.addAttributes(detection.style.highlightedAttributes, range: NSRange(detection.range, in: string.string))
                attributedText = higlightedAttributedString
            } else {
                if state.isEnabled {
                    attributedText = string
                } else {
                    attributedText = text.disabledAttributedString
                }
            }
        } else {
            attributedText = nil
        }
    }
}

extension NSAttributedString {
    
    fileprivate func withInherited(font: UIFont, textAlignment: NSTextAlignment) -> NSAttributedString {
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = textAlignment
        
        let inheritedAttributes = [NSAttributedStringKey.font: font as Any, NSAttributedStringKey.paragraphStyle: paragraphStyle as Any]
        let result = NSMutableAttributedString(string: string, attributes: inheritedAttributes)
        
        result.beginEditing()
        enumerateAttributes(in: NSMakeRange(0, length), options: .longestEffectiveRangeNotRequired, using: { (attributes, range, _) in
            result.addAttributes(attributes, range: range)
        })
        result.endEditing()
        
        return result
    }
}
    
#endif


