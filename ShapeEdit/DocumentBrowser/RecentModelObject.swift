/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    This is the RecentsModelObject which listens for notifications about a single recent object. It then forwards the notifications on to the delegate.
*/

import Foundation

/**
    The delegate protocol implemented by the object that wants to be notified
    about changes to this recent.
*/
protocol RecentModelObjectDelegate: class {
    func recentWasDeleted(_ recent: RecentModelObject)
    func recentNeedsReload(_ recent: RecentModelObject)
}

/**
    The `RecentModelObject` manages a single recent on disk.  It is registered
    as a file presenter and as such is notified when the recent changes on
    disk.  It forwards these notifications on to its delegate.
*/
class RecentModelObject: NSObject, NSFilePresenter, ModelObject {
    // MARK: - Properties

    weak var delegate: RecentModelObjectDelegate?
    
    fileprivate(set) var url: URL
    
    fileprivate(set) var displayName = ""
    
    fileprivate(set) var subtitle = ""
    
    fileprivate(set) var bookmarkDataNeedsSave = false
    
    fileprivate var bookmarkData: Data?
    
    fileprivate var isSecurityScoped = false
    
    static let displayNameKey = "displayName"
    static let subtitleKey = "subtitle"
    static let bookmarkKey = "bookmark"

    var presentedItemURL: Foundation.URL? {
        return url
    }

    var presentedItemOperationQueue: OperationQueue {
        return OperationQueue.main
    }
    
    deinit {
        url.stopAccessingSecurityScopedResource()
    }

    // MARK: - NSCoding
    
    required init?(URL: Foundation.URL) {
        self.url = URL
        
        do {
            super.init()
            
            try refreshNameAndSubtitle()
            
            bookmarkDataNeedsSave = true
        }
        catch {
            return nil
        }
    }

    @objc required init?(coder aDecoder: NSCoder) {
        do {
            displayName = aDecoder.decodeObject(of: NSString.self, forKey: RecentModelObject.displayNameKey)! as String
            
            subtitle = aDecoder.decodeObject(of: NSString.self, forKey: RecentModelObject.subtitleKey)! as String
            
            // Decode the bookmark into a URL.
            var bookmarkDataIsStale: ObjCBool = false

            guard let bookmark = aDecoder.decodeObject(of: NSData.self, forKey: RecentModelObject.bookmarkKey) else {
                throw ShapeEditError.bookmarkResolveFailed
            }
            
            bookmarkData = bookmark as Data
            
            url = try (NSURL(resolvingBookmarkData: bookmark as Data, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &bookmarkDataIsStale) as URL)
            
            /*
                The URL is security-scoped for external documents, which live outside
                of the application's sandboxed container.
            */
            isSecurityScoped = url.startAccessingSecurityScopedResource()
            
            if bookmarkDataIsStale.boolValue {
                self.bookmarkDataNeedsSave = true
                
                print("\(url) is stale.")
            }
            
            super.init()
            
            do {
                try self.refreshNameAndSubtitle()
            }
            catch {
                // Ignore the error, use the stale display name.
            }
        }
        catch let error {
            print("bookmark for \(displayName) failed to resolve: \(error)")
            
            self.url = URL(string: "")!
            
            bookmarkDataNeedsSave = false
            
            self.bookmarkData = Data()
            
            super.init()
            
            return nil
        }
    }
    
    @objc func encodeWithCoder(_ aCoder: NSCoder) {
        do {
            aCoder.encode(displayName, forKey: RecentModelObject.displayNameKey)
            
            aCoder.encode(subtitle, forKey: RecentModelObject.subtitleKey)
            
            if bookmarkDataNeedsSave {
                /*
                    Encode our URL into a security scoped bookmark.  We need to be sure
                    to mark the bookmark as suitable for a bookmark file or it won't
                    resolve properly.
                */
                bookmarkData = try (url as NSURL).bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
                
                self.bookmarkDataNeedsSave = false
            }
            
            aCoder.encode(bookmarkData, forKey: RecentModelObject.bookmarkKey)
        }
        catch {
            print("bookmark for \(displayName) failed to encode: \(error).")
        }
    }

    // MARK: - NSFilePresenter Notifications
    
    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        /*
            Notify our delegate that the recent was deleted, then call the completion 
            handler to allow for the deletion to go through.
        */
        delegate?.recentWasDeleted(self)

        completionHandler(nil)
    }

    func presentedItemDidMove(to newURL: URL) {
        /*
            Update our presented item URL to the new location, then notify our
            delegate that the recent needs to be refreshed in the UI.
        */
        url = newURL
        
        do {
            try refreshNameAndSubtitle()
        }
        catch {
             // Ignore a failure here. We'll just keep the old display name.
        }
        
        delegate?.recentNeedsReload(self)
    }

    func presentedItemDidChange() {
        // Notify the delegate that the recent needs to be refreshed in the UI.
        delegate?.recentNeedsReload(self)
    }
    
    // MARK: - Initialization Support
   
    fileprivate func refreshNameAndSubtitle() throws {
        var refreshedName: AnyObject?

        try (url as NSURL).getPromisedItemResourceValue(&refreshedName, forKey: URLResourceKey.localizedNameKey)
        
        displayName = refreshedName as! String
        
        let fileManager = FileManager.default
        
        if let ubiquitousContainer = fileManager.url(forUbiquityContainerIdentifier: nil) {
            var relationship: FileManager.URLRelationship = .other
            
            try fileManager.getRelationship(&relationship, ofDirectoryAt: ubiquitousContainer, toItemAt: url)
            
            if relationship != .contains {
                var externalContainerName: AnyObject?
                
                try (url as NSURL).getPromisedItemResourceValue(&externalContainerName, forKey: URLResourceKey.ubiquitousItemContainerDisplayNameKey)
                
                subtitle = "in \(externalContainerName as! String)"
            }
            else {
                subtitle = ""
            }
        }
        else {
            throw ShapeEditError.signedOutOfiCloud
        }
    }
    
    /// Two RecentModelObjects are equal iff their urls are equal.
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? RecentModelObject else {
            return false
        }
        
        return (other.url == url)
    }
    
    /// Hash method implemented to match `isEqual(_:)`'s constraints.
    override var hash: Int {
        return (url as NSURL).hash
    }
}
