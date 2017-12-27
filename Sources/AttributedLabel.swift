//
//  Created by Pavel Sharanda on 18.10.17.
//  Copyright © 2017 Atributika. All rights reserved.
//
import Foundation

#if os(iOS)
    
import UIKit

public class AttributedLabel: UILabel {
    
    //MARK: - private properties
    private var interactiveAreas = [(CGRect, Detection)]()
    
    //MARK: - public properties
    public var br_onClick: ((AttributedLabel, Detection)->Void)?
    
    public var br_isEnabled: Bool {
        set {
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
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleDetectionAreaTap(_:)))
        self.addGestureRecognizer(tap)
    }
    
    //MARK: - overrides
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        interactiveAreas.removeAll()
        
        if let (text, string) = state.attributedTextAndString {
            
            let inheritedString = string.withInherited(font: font, textAlignment: textAlignment)
            
            let textContainer = NSTextContainer(size: bounds.size)
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
                    self.interactiveAreas.append((finalRect, detection))
                })
            }
        }
    }
    
    @objc private func handleDetectionAreaTap(_ sender: UITapGestureRecognizer) {
        for area in interactiveAreas {
            let isInteractiveArea = area.0.contains(sender.location(in: self))
            if isInteractiveArea {
                br_onClick?(self, area.1)
                break
            }
        }
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
    
    func withInherited(font: UIFont, textAlignment: NSTextAlignment) -> NSAttributedString {
        
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


