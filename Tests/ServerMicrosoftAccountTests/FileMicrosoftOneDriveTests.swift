//
//  FileMicrosoftTests.swift
//  ServerTests
//
//  Created by Christopher G Prince on 9/13/19.
//


import XCTest
import Foundation
import LoggerAPI
import HeliumLogger
import ServerShared
@testable import ServerMicrosoftAccount
import ServerAccount

struct GooglePlist: Decodable, MicrosoftCredsConfiguration {
    let refreshToken: String
    var MicrosoftClientId:String?
    var MicrosoftClientSecret:String?
    let accessToken: String?
    
    static func load(from url: URL) -> Self {
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Could not get data from url")
        }

        let decoder = PropertyListDecoder()

        guard let plist = try? decoder.decode(Self.self, from: data) else {
            fatalError("Could not decode the plist")
        }

        return plist
    }
}

class FileMicrosoftOneDriveTests: XCTestCase {
    // In my OneDrive:
    let knownPresentFile = "DO-NOT-REMOVE.txt"

    let knownAbsentFile = "Markwa.Farkwa.Blarkwa"

    let plist = GooglePlist.load(from: URL(fileURLWithPath: "/Users/chris/Desktop/Apps/SyncServerII/Private/ServerMicrosoftAccount/token.plist"))
    let plistExpiredAccessToken = GooglePlist.load(from: URL(fileURLWithPath: "/Users/chris/Desktop/Apps/SyncServerII/Private/ServerMicrosoftAccount/tokenExpiredAccessToken.plist"))

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testCheckForFileFailsWithFileThatDoesNotExist() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        let exp = expectation(description: "\(#function)\(#line)")
        creds.refresh() { error in
            guard error == nil else {
                XCTFail()
                exp.fulfill()
                return
            }
            
            creds.checkForFile(fileName: self.knownAbsentFile) { result in
                switch result {
                case .success(.fileNotFound):
                    break
                case .success(.fileFound):
                    XCTFail()
                case .failure:
                    XCTFail()
                case .accessTokenRevokedOrExpired:
                    XCTFail()
                }

                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testCheckForFileFailsWithExpiredAccessToken() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.accessToken = plistExpiredAccessToken.accessToken

        let existingFile = self.knownPresentFile
        
        let exp = expectation(description: "\(#function)\(#line)")
        
        creds.checkForFile(fileName: existingFile) { result in
            switch result {
            case .success(.fileFound):
                XCTFail()
            case .success((.fileNotFound)):
                XCTFail()
            case .failure:
                XCTFail()
            case .accessTokenRevokedOrExpired:
                break
            }

            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    // Checks for an existing file in My Files > Apps > Neebla
    func testCheckForFileWorksWithExistingFile() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        //let existingFile = "539C70F7-8144-49F1-81C7-003DD5D8833B.14B026F1-6E5F-43E6-A54B-0524BB8F3E9C.0.txt"
        let existingFile = self.knownPresentFile
        
        let exp = expectation(description: "\(#function)\(#line)")
        creds.refresh() { error in
            guard error == nil else {
                XCTFail()
                exp.fulfill()
                return
            }
            
            creds.checkForFile(fileName: existingFile) { result in
                switch result {
                case .success(.fileFound):
                    break
                case .success((.fileNotFound)):
                    XCTFail()
                case .failure, .accessTokenRevokedOrExpired:
                    XCTFail()
                }

                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func uploadFile(file: TestFile) {
        let ext = file.mimeType.fileNameExtension
        let fileName = Foundation.UUID().uuidString + ".\(ext)"
        
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        let exp = expectation(description: "\(#function)\(#line)")
        
        creds.refresh() { error in
            guard error == nil else {
                XCTFail()
                exp.fulfill()
                return
            }
            
            let fileContentsData: Data!

            switch file.contents {
            case .string(let fileContents):
                fileContentsData = fileContents.data(using: .ascii)!
            case .url(let url):
                fileContentsData = try? Data(contentsOf: url)
            }
            
            guard fileContentsData != nil else {
                XCTFail()
                return
            }
            
            creds.uploadFile(withName: fileName, mimeType: file.mimeType, data: fileContentsData) { result in
                switch result {
                case .success(let hash):
                    XCTAssert(hash == file.sha1Hash)
                case .failure(let error):
                    Log.error("uploadFile: \(error)")
                    XCTFail()
                case .accessTokenRevokedOrExpired:
                    XCTFail()
                }
                
                exp.fulfill()
            }
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }
    
    func testSimpleUploadWithExpiredAccessToken() {
        let file = TestFile.test1
        let ext = file.mimeType.fileNameExtension
        let fileName = Foundation.UUID().uuidString + ".\(ext)"
        
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.accessToken = plistExpiredAccessToken.accessToken
        
        let exp = expectation(description: "\(#function)\(#line)")
            
        let fileContentsData: Data

        switch file.contents {
        case .string(let fileContents):
            fileContentsData = fileContents.data(using: .ascii)!
        case .url(let url):
            fileContentsData = try! Data(contentsOf: url)
        }
        
        creds.uploadFile(withName: fileName, mimeType: file.mimeType, data: fileContentsData) { result in
            switch result {
            case .success:
                XCTFail()
            case .failure:
                XCTFail()
            case .accessTokenRevokedOrExpired:
                break
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    func testUploadTextFileWorks() {
        uploadFile(file: .test1)
    }
    
    func testUploadImageFileWorks() {
        uploadFile(file: .catJpg)
    }
    
    func testUploadURLFileWorks() {
        uploadFile(file: .testUrlFile)
    }

    /* For Microsoft: What we need here is to--
        1) For a different account, say .microsoft2,
        2) generate an access token from a refresh token
        3) then revoke access from the account for the app
        4) use the access token below
        However, will the test fail because of the revocation or just because of expiry of the access token?
    */
    // func testUploadWithRevokedToken() {
    // }
    
    @discardableResult
    func uploadFile(accountType: AccountScheme.AccountName, creds: CloudStorage, deviceUUID:String, testFile: TestFile, uploadRequest:UploadFileRequest, fileVersion: FileVersionInt, options:CloudStorageFileNameOptions? = nil, nonStandardFileName: String? = nil, failureExpected: Bool = false, errorExpected: CloudStorageError? = nil, expectAccessTokenRevokedOrExpired: Bool = false) -> String? {
    
        var fileContentsData: Data!
        
        switch testFile.contents {
        case .string(let fileContents):
            fileContentsData = fileContents.data(using: .ascii)!
        case .url(let url):
            fileContentsData = try? Data(contentsOf: url)
        }
        
        guard fileContentsData != nil else {
            XCTFail()
            return nil
        }
        
        var cloudFileName:String!
        if let nonStandardFileName = nonStandardFileName {
            cloudFileName = nonStandardFileName
        }
        else {
            cloudFileName = Filename.inCloud(deviceUUID: deviceUUID, fileUUID: uploadRequest.fileUUID, mimeType: uploadRequest.mimeType, fileVersion: fileVersion)
        }
        
        let exp = expectation(description: "\(#function)\(#line)")

        creds.uploadFile(cloudFileName: cloudFileName, data: fileContentsData, options: options) { result in
            switch result {
            case .success(let checkSum):
                XCTAssert(testFile.checkSum(type: accountType) == checkSum)
                Log.debug("checkSum: \(checkSum)")
                if failureExpected {
                    XCTFail()
                }
            case .failure(let error):
                if expectAccessTokenRevokedOrExpired {
                    XCTFail()
                }
                
                cloudFileName = nil
                Log.debug("uploadFile: \(error)")
                if !failureExpected {
                    XCTFail()
                }
                
                if let errorExpected = errorExpected {
                    guard let error = error as? CloudStorageError else {
                        XCTFail()
                        exp.fulfill()
                        return
                    }
                    
                    XCTAssert(error == errorExpected)
                }
            case .accessTokenRevokedOrExpired:
                if !expectAccessTokenRevokedOrExpired {
                    XCTFail()
                }
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
        return cloudFileName
    }
    
     func testUploadWithExpiredToken() {
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
        
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.accessToken = plistExpiredAccessToken.accessToken
        
        let file = TestFile.test1
            
        let uploadRequest = UploadFileRequest()
        uploadRequest.fileUUID = fileUUID
        uploadRequest.mimeType = file.mimeType.rawValue
        uploadRequest.sharingGroupUUID = UUID().uuidString
        uploadRequest.checkSum = file.sha1Hash
        
        let options = CloudStorageFileNameOptions(cloudFolderName: nil, mimeType: file.mimeType.rawValue)

        self.uploadFile(accountType: AccountScheme.microsoft.accountName, creds: creds, deviceUUID:deviceUUID, testFile: file, uploadRequest:uploadRequest, fileVersion: 0, options: options, failureExpected: true, expectAccessTokenRevokedOrExpired: true)
     }

    func fullUpload(file: TestFile) {
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
        
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            let uploadRequest = UploadFileRequest()
            uploadRequest.fileUUID = fileUUID
            uploadRequest.mimeType = file.mimeType.rawValue
            uploadRequest.sharingGroupUUID = UUID().uuidString
            uploadRequest.checkSum = file.sha1Hash
            
            let options = CloudStorageFileNameOptions(cloudFolderName: nil, mimeType: file.mimeType.rawValue)
            
            self.uploadFile(accountType: AccountScheme.microsoft.accountName, creds: creds, deviceUUID:deviceUUID, testFile: file, uploadRequest:uploadRequest, fileVersion: 0, options: options)
            
            // The second time we try it, it should fail with CloudStorageError.alreadyUploaded -- same file.
            self.uploadFile(accountType: AccountScheme.microsoft.accountName, creds: creds, deviceUUID:deviceUUID, testFile: file, uploadRequest:uploadRequest, fileVersion: 0,options: options, failureExpected: true, errorExpected: CloudStorageError.alreadyUploaded)
        }
    }
    
    func refresh(creds: MicrosoftCreds, completion:@escaping (Bool)->()) {
        let exp = expectation(description: "full upload")
        
        creds.refresh() { error in
            guard error == nil else {
                XCTFail()
                exp.fulfill()
                completion(false)
                return
            }
            
            exp.fulfill()
        }

        waitForExpectations(timeout: 10, handler: nil)
        completion(true)
    }

    func testFullUploadWorks() {
        fullUpload(file: .test1)
    }
    
    func testFullImageUploadWorks() {
        fullUpload(file: .catJpg)
    }
    
    func testFullUploadURLWorks() {
        fullUpload(file: .testUrlFile)
    }

    func downloadFile(creds: MicrosoftCreds, cloudFileName: String, expectedStringFile:TestFile? = nil, expectedFailure: Bool = false, expectedFileNotFound: Bool = false, expectedRevokedToken: Bool = false) {
        let exp = expectation(description: "\(#function)\(#line)")

        creds.downloadFile(cloudFileName: cloudFileName, options: nil) { result in
            switch result {
            case .success(let data, let checkSum):
                if let expectedStringFile = expectedStringFile {
                    guard case .string(let expectedContents) = expectedStringFile.contents else {
                        XCTFail()
                        return
                    }
                    
                    guard let str = String(data: data, encoding: String.Encoding.ascii) else {
                        XCTFail()
                        Log.error("Failed on string decoding")
                        return
                    }
                    
                    XCTAssert(checkSum == expectedStringFile.sha1Hash)
                    XCTAssert(str == expectedContents)
                }
                
                if expectedFailure || expectedRevokedToken || expectedFileNotFound {
                    XCTFail()
                }
            case .failure(let error):
                if !expectedFailure || expectedRevokedToken || expectedFileNotFound {
                    XCTFail()
                    Log.error("Failed download: \(error)")
                }
            case .accessTokenRevokedOrExpired:
                if !expectedRevokedToken || expectedFileNotFound || expectedFailure {
                    XCTFail()
                }
            case .fileNotFound:
                if !expectedFileNotFound || expectedRevokedToken || expectedFailure{
                    XCTFail()
                }
            }
            
            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    func testDownloadOfNonExistingFileFails() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            self.downloadFile(creds: creds, cloudFileName: self.knownAbsentFile, expectedFileNotFound: true)
        }
    }
    
    // Download without checksum.
    func testSimpleDownloadWorks() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            let exp = self.expectation(description: "download")
            creds.downloadFile(cloudFileName: self.knownPresentFile) { result in
                switch result {
                case .success:
                    break
                case .failure:
                    XCTFail()
                case .accessTokenRevokedOrExpired:
                    XCTFail()
                }
                exp.fulfill()
            }
            
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }

    // Reason code 80049228
    func testSimpleDownloadWithExpiredAccessTokenFails() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.accessToken = plistExpiredAccessToken.accessToken

        let exp = self.expectation(description: "download")
        creds.downloadFile(cloudFileName: self.knownPresentFile) { result in
            switch result {
            case .success:
                XCTFail()
            case .failure:
                XCTFail()
            case .accessTokenRevokedOrExpired:
                break
            }
            exp.fulfill()
        }
        
        self.waitForExpectations(timeout: 10, handler: nil)
    }

    // From my testing it looks like if you (a) generate an access token from a refresh token, and (b) then revoke access for the account, then the access token still works-- until it expires. The test below fails with .failure, not with .accessTokenRevokedOrExpired.
#if false
    func testSimpleDownloadWithRevokedAccessTokenFails() {
        let creds = MicrosoftCreds()
        creds.accessToken = TestAccount.microsoft2RevokedAccessToken.secondToken()

        let exp = self.expectation(description: "download")
        creds.downloadFile(cloudFileName: self.knownPresentFile) { result in
            switch result {
            case .success:
                XCTFail()
            case .failure:
                XCTFail()
            case .accessTokenRevokedOrExpired:
                break
            }
            exp.fulfill()
        }
        self.waitExpectation(timeout: 10, handler: nil)
    }
#endif

    // See above for revoked token test conditions
    // func testDownloadWithRevokedToken() {
    // }
    
    func testUploadAndDownloadWorks() {
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
        
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken

        let file = TestFile.test1
        guard case .string = file.contents else {
            XCTFail()
            return
        }
        
        let uploadRequest = UploadFileRequest()
        uploadRequest.fileUUID = fileUUID
        uploadRequest.mimeType = file.mimeType.rawValue
        uploadRequest.sharingGroupUUID = UUID().uuidString
        uploadRequest.checkSum = file.sha1Hash
        
        let options = CloudStorageFileNameOptions(cloudFolderName: nil, mimeType: file.mimeType.rawValue)
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            guard let _ = self.uploadFile(accountType: AccountScheme.microsoft.accountName, creds: creds, deviceUUID:deviceUUID, testFile: file, uploadRequest:uploadRequest, fileVersion: 0, options: options) else {
                XCTFail()
                return
            }
            
            let cloudFileName = Filename.inCloud(deviceUUID: deviceUUID, fileUUID: uploadRequest.fileUUID, mimeType: uploadRequest.mimeType, fileVersion: 0)
            
            Log.debug("cloudFileName: \(String(describing: cloudFileName))")
            self.downloadFile(creds: creds, cloudFileName: cloudFileName, expectedStringFile: file)
        }
    }
    
    // Doesn't refresh the creds first.
    func deleteFile(creds: MicrosoftCreds, cloudFileName: String, expectedFailure: Bool = false) {
        let exp = expectation(description: "\(#function)\(#line)")

        creds.deleteFile(cloudFileName: cloudFileName) { result in
            switch result {
            case .success:
                if expectedFailure {
                    XCTFail()
                }
            case .accessTokenRevokedOrExpired:
                XCTFail()
            case .failure(let error):
                if !expectedFailure {
                    XCTFail()
                    Log.error("Failed download: \(error)")
                }
            }

            exp.fulfill()
        }
        
        waitForExpectations(timeout: 10, handler: nil)
    }

    // See above for comments on revoked token
    //func testDeletionWithRevokedAccessToken() {
    //}
    
    func testDeletionOfNonExistingFileFails() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            self.deleteFile(creds: creds, cloudFileName: self.knownAbsentFile, expectedFailure: true)
        }
    }

    func deletionOfExistingFile(file: TestFile) {
        let deviceUUID = Foundation.UUID().uuidString
        let fileUUID = Foundation.UUID().uuidString
        
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken

        let uploadRequest = UploadFileRequest()
        uploadRequest.fileUUID = fileUUID
        uploadRequest.mimeType = file.mimeType.rawValue
        uploadRequest.sharingGroupUUID = UUID().uuidString
        uploadRequest.checkSum = file.sha1Hash
        
        let options = CloudStorageFileNameOptions(cloudFolderName: nil, mimeType: file.mimeType.rawValue)
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            guard let fileName = self.uploadFile(accountType: AccountScheme.microsoft.accountName, creds: creds, deviceUUID:deviceUUID, testFile:file, uploadRequest:uploadRequest, fileVersion: 0, options: options) else {
                XCTFail()
                return
            }
            
            self.deleteFile(creds: creds, cloudFileName: fileName)
        }
    }
    
    func testSimpleDeletionWithExpiredAccessTokenFails() {
        // First need to get item id of the file in the normal way so it doesn't fail.
        
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            let exp = self.expectation(description: "delete")
            
            creds.checkForFile(fileName: self.knownPresentFile) { result in
                switch result {
                case .success(.fileFound(let checkResult)):
                    self.deleteExpectingExpiredAccessToken(itemId: checkResult.id, expectation: exp)
                case .success(.fileNotFound):
                    XCTFail()
                    exp.fulfill()
                case .accessTokenRevokedOrExpired, .failure:
                    XCTFail()
                    exp.fulfill()
                }
            }
            
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }

    func deleteExpectingExpiredAccessToken(itemId: String, expectation: XCTestExpectation) {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.accessToken = plistExpiredAccessToken.accessToken
        
        creds.deleteFile(itemId: itemId) { result in
            switch result {
            case .success:
                XCTFail()
            case .failure:
                XCTFail()
            case .accessTokenRevokedOrExpired:
                break
            }
            
            expectation.fulfill()
        }
    }

    func testDeletionOfExistingFileWorks() {
        deletionOfExistingFile(file: .test1)
    }
    
    func testDeletionOfExistingURLFileWorks() {
        deletionOfExistingFile(file: .testUrlFile)
    }
    
    func lookupFile(cloudFileName: String, expectError:Bool = false) {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }

            let exp = self.expectation(description: "\(#function)\(#line)")
            
            creds.lookupFile(cloudFileName:cloudFileName, options: nil) { result in
                switch result {
                case .success:
                    if expectError {
                        XCTFail()
                    }
                case .failure, .accessTokenRevokedOrExpired:
                    if !expectError {
                        XCTFail()
                    }
                }
                
                exp.fulfill()
            }
            
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }

    func testLookupFileThatExists() {
        lookupFile(cloudFileName: knownPresentFile)
    }
    
    func testLookupFileThatDoesNotExist() {
        lookupFile(cloudFileName: knownAbsentFile)
    }

    // See comments for revoked access token
    // func testLookupWithRevokedAccessToken() {
    // }
    
    // MARK: Large file upload
    
    func testCreateUploadSession() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        let fileName = UUID().uuidString
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            let exp = self.expectation(description: "uploadSession")
            
            creds.createUploadSession(cloudFileName: fileName) { result in
                switch result {
                case .success:
                    break
                case .failure, .accessTokenRevokedOrExpired:
                    XCTFail()
                }
                
                exp.fulfill()
            }
            
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }
    
    func testUploadStateComputedValues() {
        let inputData: [(numberBytes: UInt, blockSize: UInt,
            expectedNumberFullBlocks: UInt, expectedPartialLastBlock: Bool, expectedPartialLastBlockLength: Int)] = [
            
            (numberBytes: 99, blockSize: 100, expectedNumberFullBlocks: 0, expectedPartialLastBlock: true, expectedPartialLastBlockLength: 99),
            
            (numberBytes: 100, blockSize: 100, expectedNumberFullBlocks: 1, expectedPartialLastBlock: false, expectedPartialLastBlockLength: 0),
            
            (numberBytes: 100, blockSize: 50, expectedNumberFullBlocks: 2, expectedPartialLastBlock: false, expectedPartialLastBlockLength: 0),
            
            (numberBytes: 101, blockSize: 50, expectedNumberFullBlocks: 2, expectedPartialLastBlock: true, expectedPartialLastBlockLength: 1),
        ]
        
        for (numberBytes, blockSize,
            expectedNumberFullBlocks, expectedPartialLastBlock, expectedPartialLastBlockLength) in inputData {
            let data = Data(count: Int(numberBytes))
            
            guard let state = MicrosoftCreds.UploadState(blockSize: blockSize, data: data, checkBlockSize: false) else {
                XCTFail()
                return
            }
            
            XCTAssert(state.numberFullBlocks == expectedNumberFullBlocks)
            XCTAssert(state.partialLastBlock == expectedPartialLastBlock)
            XCTAssert(state.partialLastBlockLength == expectedPartialLastBlockLength)
        }
    }

    func testUploadStateOffsetsOnePartialBlock() {
        guard let state = MicrosoftCreds.UploadState(blockSize: 100, data: Data(count: Int(99)), checkBlockSize: false) else {
            XCTFail()
            return
        }
        
        XCTAssert(state.currentStartOffset == 0)
        XCTAssert(state.currentEndOffset == 99)
        
        XCTAssert(!state.advanceToNextBlock())
    }
    
    func testUploadStateOffsetsOneFullOnePartialBlock() {
        guard let state = MicrosoftCreds.UploadState(blockSize: 100, data: Data(count: Int(199)), checkBlockSize: false) else {
            XCTFail()
            return
        }
        
        XCTAssert(state.currentStartOffset == 0)
        XCTAssert(state.currentEndOffset == 100)
        
        XCTAssert(state.advanceToNextBlock())

        XCTAssert(state.currentStartOffset == 100)
        XCTAssert(state.currentEndOffset == 199)
        
        XCTAssert(!state.advanceToNextBlock())
    }
    
    func testUploadStateOffsetsOneFullOnePartialBlock2() {
        guard let state = MicrosoftCreds.UploadState(blockSize: 100, data: Data(count: Int(101)), checkBlockSize: false) else {
            XCTFail()
            return
        }
        
        XCTAssert(state.currentStartOffset == 0)
        XCTAssert(state.currentEndOffset == 100)
        
        XCTAssert(state.advanceToNextBlock())

        XCTAssert(state.currentStartOffset == 100)
        XCTAssert(state.currentEndOffset == 101)
        
        XCTAssert(!state.advanceToNextBlock())
    }
    
    func testUploadStateOffsetsExactlyTwoBlocks() {
        guard let state = MicrosoftCreds.UploadState(blockSize: 100, data: Data(count: Int(200)), checkBlockSize: false) else {
            XCTFail()
            return
        }
        
        XCTAssert(state.currentStartOffset == 0)
        XCTAssert(state.currentEndOffset == 100)
        
        XCTAssert(state.advanceToNextBlock())

        XCTAssert(state.currentStartOffset == 100)
        XCTAssert(state.currentEndOffset == 200)
        
        XCTAssert(!state.advanceToNextBlock())
    }
    
    func testUploadStateOffsetsTwoBlocksAndOnePartial() {
        guard let state = MicrosoftCreds.UploadState(blockSize: 100, data: Data(count: Int(250)), checkBlockSize: false) else {
            XCTFail()
            return
        }
        
        XCTAssert(state.currentStartOffset == 0)
        XCTAssert(state.currentEndOffset == 100)
        
        XCTAssert(state.contentRange == "bytes 0-99/250")
        
        XCTAssert(state.advanceToNextBlock())

        XCTAssert(state.currentStartOffset == 100)
        XCTAssert(state.currentEndOffset == 200)
        
        XCTAssert(state.advanceToNextBlock())
        
        XCTAssert(state.currentStartOffset == 200)
        XCTAssert(state.currentEndOffset == 250)
        
        XCTAssert(!state.advanceToNextBlock())
    }

    func testCreateUploadSessionWithExpiredToken() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.accessToken = plistExpiredAccessToken.accessToken
        
        let fileName = UUID().uuidString

        let exp = self.expectation(description: "uploadSession")
        
        creds.createUploadSession(cloudFileName: fileName) { result in
            switch result {
            case .success, .failure:
                XCTFail()
            case .accessTokenRevokedOrExpired:
                break
            }
            
            exp.fulfill()
        }
    
        self.waitForExpectations(timeout: 10, handler: nil)
    }

    func testUploadWithAPartialBlock() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
            
        creds.refreshToken = plist.refreshToken
        
        let fileName = UUID().uuidString
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            let exp = self.expectation(description: "uploadSession")
            
            creds.createUploadSession(cloudFileName: fileName) { result in
                switch result {
                case .success(let session):
                    let blockSize = MicrosoftCreds.UploadState.blockMultipleInBytes
                    guard let state = MicrosoftCreds.UploadState(blockSize: UInt(blockSize), data: Data(count: blockSize/2)) else {
                        XCTFail()
                        exp.fulfill()
                        return
                    }
                
                    creds.uploadBytes(toUploadSession: session, withUploadState: state) { result in
                        switch result {
                        case .success:
                            break
                        case .failure, .accessTokenRevokedOrExpired:
                            XCTFail()
                        }
                        
                        exp.fulfill()
                    }
                    
                case .failure, .accessTokenRevokedOrExpired:
                    XCTFail()
                    exp.fulfill()
                }
            }
            
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }

    func testUploadWithSingleBlock() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        creds.refreshToken = plist.refreshToken
        
        let fileName = UUID().uuidString
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            let exp = self.expectation(description: "uploadSession")
            
            creds.createUploadSession(cloudFileName: fileName) { result in
                switch result {
                case .success(let session):
                    let blockSize = MicrosoftCreds.UploadState.blockMultipleInBytes
                    guard let state = MicrosoftCreds.UploadState(blockSize: UInt(blockSize), data: Data(count: blockSize)) else {
                        XCTFail()
                        exp.fulfill()
                        return
                    }
                
                    creds.uploadBytes(toUploadSession: session, withUploadState: state) { result in
                        switch result {
                        case .success:
                            break
                        case .failure, .accessTokenRevokedOrExpired:
                            XCTFail()
                        }
                        
                        exp.fulfill()
                    }
                    
                case .failure, .accessTokenRevokedOrExpired:
                    XCTFail()
                    exp.fulfill()
                }
            }
            
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }

    func testUploadWithTwoBlocks() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        let fileName = UUID().uuidString
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            let exp = self.expectation(description: "uploadSession")
            
            creds.createUploadSession(cloudFileName: fileName) { result in
                switch result {
                case .success(let session):
                    let blockSize = MicrosoftCreds.UploadState.blockMultipleInBytes
                    guard let state = MicrosoftCreds.UploadState(blockSize: UInt(blockSize), data: Data(count: blockSize*2)) else {
                        XCTFail()
                        exp.fulfill()
                        return
                    }
                
                    creds.uploadBytes(toUploadSession: session, withUploadState: state) { result in
                        switch result {
                        case .success:
                            break
                        case .failure, .accessTokenRevokedOrExpired:
                            XCTFail()
                        }
                        
                        exp.fulfill()
                    }
                    
                case .failure, .accessTokenRevokedOrExpired:
                    XCTFail()
                    exp.fulfill()
                }
            }
            
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }

    func testUploadWithTwoBlocksAndAPartial() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        let fileName = UUID().uuidString
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            let exp = self.expectation(description: "uploadSession")
            
            creds.createUploadSession(cloudFileName: fileName) { result in
                switch result {
                case .success(let session):
                    let blockSize = MicrosoftCreds.UploadState.blockMultipleInBytes
                    guard let state = MicrosoftCreds.UploadState(blockSize: UInt(blockSize), data: Data(count: blockSize*2 + 100)) else {
                        XCTFail()
                        exp.fulfill()
                        return
                    }
                
                    creds.uploadBytes(toUploadSession: session, withUploadState: state) { result in
                        switch result {
                        case .success:
                            break
                        case .failure, .accessTokenRevokedOrExpired:
                            XCTFail()
                        }
                        
                        exp.fulfill()
                    }
                    
                case .failure, .accessTokenRevokedOrExpired:
                    exp.fulfill()
                }
            }
            
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }

    func testUploadImageUsingSessionMethod() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        let file = TestFile.catJpg
        let ext = file.mimeType.fileNameExtension
        let fileName = Foundation.UUID().uuidString + ".\(ext)"
    
        guard case .url(let url) = file.contents,
            let fileContentsData = try? Data(contentsOf: url) else {
            XCTFail()
            return
        }
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            let exp = self.expectation(description: "uploadSession")
            
            creds.uploadFileUsingSession(withName: fileName, mimeType: file.mimeType, data: fileContentsData) { result in
            
                switch result {
                case .success(let checkSum):
                    XCTAssert(file.sha1Hash == checkSum)
                case .failure:
                    XCTFail()
                case .accessTokenRevokedOrExpired:
                    XCTFail()
                }
                
                exp.fulfill()
            }
            
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }

    func testCreateAppFolder() {
        guard let creds = MicrosoftCreds(configuration: plist, delegate: nil) else {
            XCTFail()
            return
        }
        
        creds.refreshToken = plist.refreshToken
        
        refresh(creds: creds) { success in
            guard success else {
                XCTFail()
                return
            }
            
            let exp = self.expectation(description: "uploadSession")
            
            creds.createAppFolder() { result in
                switch result {
                case .success:
                    break
                case .failure, .accessTokenRevokedOrExpired:
                    XCTFail()
                }
                
                exp.fulfill()
            }
            
            self.waitForExpectations(timeout: 10, handler: nil)
        }
    }
}
