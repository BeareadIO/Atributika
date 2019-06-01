//
//  Detection.swift
//  Atributika
//
//  Created by Pavel Sharanda on 21.02.17.
//  Copyright © 2017 psharanda. All rights reserved.
//

import Foundation

public struct Tag {
    public let name: String
    public let attributes: [String: String]
}

public struct TagInfo {
    public let tag: Tag
    public let range: Range<String.Index>
    public let level: Int
}

public enum TagType {
    case start
    case end
}

public struct TagTransformer {
    
    public let tagName: String
    public let tagType: TagType
    public let transform: (Tag) -> String
    
    public init(tagName: String, tagType: TagType, replaceValue: String) {
        self.tagName = tagName
        self.tagType = tagType
        self.transform = { _ in replaceValue }
    }
    
    public init(tagName: String, tagType: TagType, transform: @escaping (Tag) -> String) {
        self.tagName = tagName
        self.tagType = tagType
        self.transform = transform
    }
    
    public static var brTransformer: TagTransformer {
        return TagTransformer(tagName: "br", tagType: .start , replaceValue: "\n")
    }
}

extension String {
    
    private func parseTag(_ tagString: String, parseAttributes: Bool) -> Tag? {
        let tagScanner = Scanner(string: tagString)
        
        guard let tagName = tagScanner.scanCharacters(from: CharacterSet.alphanumerics) else {
            return nil
        }
        
        var attrubutes = [String: String]()
        
        while parseAttributes && !tagScanner.isAtEnd {
            
            guard let name = tagScanner.scanUpTo("=") else {
                break
            }
            
            guard tagScanner.scanString("=") != nil else {
                break
            }
            
            let startsFromSingleQuote = (tagScanner.scanString("'") != nil)
            if !startsFromSingleQuote {
                guard tagScanner.scanString("\"") != nil else {
                    break
                }
            }
            
            let quote = startsFromSingleQuote ? "'" : "\""
            
            let value = tagScanner.scanUpTo(quote) ?? ""
            
            guard tagScanner.scanString(quote) != nil else {
                break
            }
            
            attrubutes[name] = value.replacingOccurrences(of: "&quot;", with: "\"")
        }
        
        return Tag(name: tagName, attributes: attrubutes)
    }
    
    public func detectTags(_ tags: [Style] = [], transformers: [TagTransformer] = []) -> (string: String, tagsInfo: [TagInfo]) {
        
        struct TagInfoInternal {
            public let tag: Tag
            public let rangeStart: Int
            public let rangeEnd: Int
            public let level: Int
        }
        
        let scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = nil
        var resultString = String()
        var tagsResult = [TagInfoInternal]()
        var tagsStack = [(Tag, Int, Int)]()
        
        while !scanner.isAtEnd {
            
            if let textString = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: "<")) {
                resultString += textString
            } else {
                if scanner.scanString("<") != nil {
                    
                    if scanner.isAtEnd {
                        resultString += "<"
                    } else {
                        let nextChar = (scanner.string as NSString).substring(with: NSRange(location: scanner.scanLocation, length: 1))
                        let allTagNames = tags.map { $0.name } + transformers.map { $0.tagName }
                        let markupEndCharReg = try! NSRegularExpression(pattern: "^\\s*(\\S+?)[ >]")
                        let result = markupEndCharReg.firstMatch(in: scanner.string, range: NSRange(location: scanner.scanLocation, length: scanner.string.utf16.count - scanner.scanLocation))
                        
                        if nextChar == "/" || (result != nil && allTagNames.contains((scanner.string as NSString).substring(with: result!.range(at: 1)))) {
                            let tagType = scanner.scanString("/") == nil ? TagType.start : TagType.end
                            if let tagString = scanner.scanUpTo(">") {
                                
                                if scanner.scanString(">") != nil {
                                    if let tag = parseTag(tagString, parseAttributes: tagType == .start ) {
                                        
                                        let resultTextEndIndex = resultString.count
                                        
                                        if let transformer = transformers.first(where: {
                                            $0.tagName.lowercased() == tag.name.lowercased() && $0.tagType == tagType
                                        }) {
                                            resultString += transformer.transform(tag)
                                        }
                                        
                                        if tagType == .start {
                                            tagsStack.append((tag, resultTextEndIndex, (tagsStack.last?.2 ?? -1) + 1))
                                        } else {
                                            for (index, (tagInStack, startIndex, level)) in tagsStack.enumerated().reversed() {
                                                if tagInStack.name.lowercased() == tag.name.lowercased() {
                                                    tagsResult.append(TagInfoInternal(tag: tagInStack, rangeStart: startIndex, rangeEnd: resultTextEndIndex, level: level))
                                                    tagsStack.remove(at: index)
                                                    break
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    resultString += "<"
                                    resultString += tagString
                                }
                            }
                        } else {
                            resultString += "<"
                        }
                    }
                }
            }
        }
        
        return (resultString, tagsResult.map { TagInfo(tag: $0.tag, range: resultString.index(resultString.startIndex, offsetBy: $0.rangeStart)..<resultString.index(resultString.startIndex, offsetBy: $0.rangeEnd), level: $0.level) })
    }
    
    public func detectHashTags() -> [Range<String.Index>] {
        
        return detect(regex: "[#]\\w\\S*\\b")
    }
    
    public func detectMentions() -> [Range<String.Index>] {
        
        return detect(regex: "[@]\\w\\S*\\b")
    }
    
    public func detect(regex: String, options: NSRegularExpression.Options = []) -> [Range<String.Index>] {
        
        var ranges = [Range<String.Index>]()
        
        let dataDetector = try? NSRegularExpression(pattern: regex, options: options)
        dataDetector?.enumerateMatches(in: self, options: [], range: NSMakeRange(0, (self as NSString).length), using: { (result, flags, _) in
            if let r = result, let range = Range(r.range, in: self) {
                ranges.append(range)
            }
        })
        
        return ranges
    }
    
    public func detect(textCheckingTypes: NSTextCheckingResult.CheckingType) -> [Range<String.Index>] {
        
        var ranges = [Range<String.Index>]()
        
        let dataDetector = try? NSDataDetector(types: textCheckingTypes.rawValue)
        dataDetector?.enumerateMatches(in: self, options: [], range: NSMakeRange(0, (self as NSString).length), using: { (result, flags, _) in
            if let r = result, let range = Range(r.range, in: self) {
                ranges.append(range)
            }
        })
        return ranges
    }
}
