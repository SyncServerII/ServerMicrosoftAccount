//
//  TestFiles.swift
//  ServerTests
//
//  Created by Christopher G Prince on 10/23/18.
//

import Foundation
import XCTest
import ServerShared

struct TestFile {
    enum FileContents {
        case string(String)
        case url(URL)
    }

    let sha1Hash: String // Microsoft
    
    let contents: FileContents
    let mimeType: MimeType
    
    func checkSum(type: AccountScheme.AccountName) -> String! {
        switch type {
        case AccountScheme.microsoft.accountName:
            return sha1Hash
            
        default:
            XCTFail()
            return nil
        }
    }
    
    static let test1 = TestFile(
        sha1Hash: "0A4D55A8D778E5022FAB701977C5D840BBC486D0",
        contents: .string("Hello World"),
        mimeType: .text)
    
    static let test2 = TestFile(
        sha1Hash: "3480185FC5811EC5F242E13B23E2D9274B080EF1",
        contents: .string("This is some longer text that I'm typing here and hopefullly I don't get too bored"),
        mimeType: .text)

#if os(macOS)
        private static let catFileURL = URL(fileURLWithPath: "/tmp/Cat.jpg")
#else
        private static let catFileURL = URL(fileURLWithPath: "./Resources/Cat.jpg")
#endif

    static let catJpg = TestFile(
        sha1Hash: "41CA4AF2CE9C85D4F9969EA5D5C551D1FABD4857",
        contents: .url(catFileURL),
        mimeType: .jpeg)

#if os(macOS)
        private static let urlFile = URL(fileURLWithPath: "/tmp/example.url")
#else
        private static let urlFile = URL(fileURLWithPath: "./Resources/example.url")
#endif

    // The specific hash values are obtained from bootstraps in the iOS client test cases.
    static let testUrlFile = TestFile(
        sha1Hash: "92D74581DBCBC143ED68079A476CD770BE7E4BD9",
        contents: .url(urlFile),
        mimeType: .url)
}
