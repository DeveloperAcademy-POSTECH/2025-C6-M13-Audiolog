//
//  OrderedSet.swift
//  Audiolog
//
//  Created by 성현 on 11/11/25.
//

import Foundation

struct OrderedSet {
    private(set) var storage: [String] = []
    private let caseInsensitive: Bool

    init(_ arr: [String], caseInsensitive: Bool) {
        self.caseInsensitive = caseInsensitive
        if caseInsensitive {
            var seen = Set<String>()
            for s in arr {
                let key = s.lowercased()
                if !seen.contains(key) {
                    storage.append(s)
                    seen.insert(key)
                }
            }
        } else {
            storage = Array(NSOrderedSet(array: arr)) as? [String] ?? arr
        }
    }

    mutating func bumpToFront(_ new: String) {
        let key = caseInsensitive ? new.lowercased() : new
        storage.removeAll { (caseInsensitive ? $0.lowercased() : $0) == key }
        storage.insert(new, at: 0)
    }

    mutating func trim(max: Int) {
        if storage.count > max { storage = Array(storage.prefix(max)) }
    }

    func joined(separator: String) -> String {
        storage.joined(separator: separator)
    }
}
