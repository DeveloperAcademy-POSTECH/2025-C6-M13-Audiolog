//
//  getDocumentURL.swift
//  Audiolog
//
//  Created by Sean Cho on 11/11/25.
//

import Foundation

func getDocumentURL() -> URL {
    let fileManager = FileManager.default
    guard
        let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first
    else {
        fatalError(
            "The app failed to recieve a url to the document directory"
        )
    }
    return documentsURL
}
