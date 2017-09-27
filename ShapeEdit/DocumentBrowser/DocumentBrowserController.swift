/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    This is the `DocumentBrowserController` which handles display of all elements of the Document Browser.  It listens for notifications from the `DocumentBrowserQuery`, `RecentModelObjectsManager`, and `ThumbnailCache` and updates the `UICollectionView` for the Document Browser when events
                occur.
*/

import UIKit

/**
    The `DocumentBrowserController` registers for notifications from the `ThumbnailCache`,
    the `RecentModelObjectsManager`, and the `DocumentBrowserQuery` and updates the UI for
    changes.  It also handles pushing the `DocumentViewController` when a document is
    selected.
*/
class DocumentBrowserController: UICollectionViewController, DocumentBrowserQueryDelegate, RecentModelObjectsManagerDelegate, ThumbnailCacheDelegate {
    
    // MARK: - Constants
    
    static let recentsSection = 0
    static let documentsSection = 1

    static let documentExtension = "shapeFile"
    
    // MARK: - Properties
    
    var documents = [DocumentBrowserModelObject]()
    
    var recents = [RecentModelObject]()
    
    var browserQuery = DocumentBrowserQuery()
    
    let recentsManager = RecentModelObjectsManager()
    
    let thumbnailCache = ThumbnailCache(thumbnailSize: CGSize(width: 220, height: 270))
    
    fileprivate let coordinationQueue: OperationQueue = {
        let coordinationQueue = OperationQueue()
        
        coordinationQueue.name = "com.example.apple-samplecode.ShapeEdit.documentbrowser.coordinationQueue"
        
        return coordinationQueue
    }()
    
    // MARK: - View Controller Override
    
    override func awakeFromNib() {
        // Initialize ourself as the delegate of our created queries.
        browserQuery.delegate = self

        thumbnailCache.delegate = self
        
        recentsManager.delegate = self
        
        title = "My Favorite Shapes & Colors"
    }

    override func viewDidAppear(_ animated: Bool) {
        /*
            Our app only supports iCloud Drive so display an error message when 
            it is disabled.
        */
        if FileManager().ubiquityIdentityToken == nil {
            let alertController = UIAlertController(title: "iCloud is disabled", message: "Please enable iCloud Drive in Settings to use this app", preferredStyle: .alert)
            
            let alertAction = UIAlertAction(title: "Dismiss", style: .default, handler: nil)
            
            alertController.addAction(alertAction)
            
            present(alertController, animated: true, completion: nil)
        }
    }

    @IBAction func insertNewObject(_ sender: UIBarButtonItem) {
        // Create a document with the default template.
        let templateURL = Bundle.main.url(forResource: "Template", withExtension: DocumentBrowserController.documentExtension)!

        createNewDocumentWithTemplate(templateURL)
    }
    
    // MARK: - DocumentBrowserQueryDelegate

    func documentBrowserQueryResultsDidChangeWithResults(_ results: [DocumentBrowserModelObject], animations: [DocumentBrowserAnimation]) {
        if animations == [.reload] {
            /*
                Reload means we're reloading all items, so mark all thumbnails
                dirty and reload the collection view.
            */
            documents = results
            thumbnailCache.markThumbnailCacheDirty()
            collectionView?.reloadData()
        }
        else {
            var indexPathsNeedingReload = [IndexPath]()
            
            let collectionView = self.collectionView!

            collectionView.performBatchUpdates({
                /*
                    Perform all animations, and invalidate the thumbnail cache 
                    where necessary.
                */
                indexPathsNeedingReload = self.processAnimations(animations, oldResults: self.documents, newResults: results, section: DocumentBrowserController.documentsSection)

                // Save the new results.
                self.documents = results
            }, completion: { success in
                if success {
                    collectionView.reloadItems(at: indexPathsNeedingReload)
                }
            })
        }
    }

    // MARK: - RecentModelObjectsManagerDelegate
    
    func recentsManagerResultsDidChange(_ results: [RecentModelObject], animations: [DocumentBrowserAnimation]) {
        if animations == [.reload] {
            recents = results
            
            let indexSet = IndexSet(integer: DocumentBrowserController.recentsSection)

            collectionView?.reloadSections(indexSet)
        }
        else {
            var indexPathsNeedingReload = [IndexPath]()

            let collectionView = self.collectionView!
            collectionView.performBatchUpdates({
                /*
                    Perform all animations, and invalidate the thumbnail cache 
                    where necessary.
                */
                indexPathsNeedingReload = self.processAnimations(animations, oldResults: self.recents, newResults: results, section: DocumentBrowserController.recentsSection)

                // Save the results
                self.recents = results
            }, completion: { success in
                if success {
                    collectionView.reloadItems(at: indexPathsNeedingReload)
                }
            })
        }
    }
    
    // MARK: - Animation Support

    fileprivate func processAnimations<ModelType: ModelObject>(_ animations: [DocumentBrowserAnimation], oldResults: [ModelType], newResults: [ModelType], section: Int) -> [IndexPath] {
        let collectionView = self.collectionView!
        
        var indexPathsNeedingReload = [IndexPath]()
        
        for animation in animations {
            switch animation {
                case .add(let row):
                    collectionView.insertItems(at: [
                        IndexPath(row: row, section: section)
                    ])
                
                case .delete(let row):
                    collectionView.deleteItems(at: [
                        IndexPath(row: row, section: section)
                    ])
                    
                    let url = oldResults[row].url
                    self.thumbnailCache.removeThumbnailForURL(url)
                    
                case .move(let from, let to):
                    let fromIndexPath = IndexPath(row: from, section: section)
                    
                    let toIndexPath = IndexPath(row: to, section: section)
                    
                    collectionView.moveItem(at: fromIndexPath, to: toIndexPath)
                
                case .update(let row):
                    indexPathsNeedingReload += [
                        IndexPath(row: row, section: section)
                    ]
                    
                    let url = newResults[row].url
                    self.thumbnailCache.markThumbnailDirtyForURL(url)
                    
                case .reload:
                    fatalError("Unreachable")
            }
        }
        
        return indexPathsNeedingReload
    }

    // MARK: - ThumbnailCacheDelegateType
    
    func thumbnailCache(_ thumbnailCache: ThumbnailCache, didLoadThumbnailsForURLs URLs: Set<URL>) {
        let documentPaths: [IndexPath] = URLs.flatMap { url in
            guard let matchingDocumentIndex = documents.index(where: { $0.url as URL == url }) else { return nil }
            
            return IndexPath(item: matchingDocumentIndex, section: DocumentBrowserController.documentsSection)
        }
        
        let recentPaths: [IndexPath] = URLs.flatMap { url in
            guard let matchingRecentIndex = recents.index(where: { $0.url as URL == url }) else { return nil }
            
            return IndexPath(item: matchingRecentIndex, section: DocumentBrowserController.recentsSection)
        }
        
        self.collectionView!.reloadItems(at: documentPaths + recentPaths)
    }

    // MARK: - Collection View

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == DocumentBrowserController.recentsSection {
            return recents.count
        }

        return documents.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! DocumentCell

        guard let document = documentForIndexPath(indexPath) else {
            cell.title = ""
            cell.subtitle = ""
            cell.thumbnail = nil
            return cell
        }
        
        cell.title = document.displayName
        cell.subtitle = document.subtitle
        
        cell.thumbnail = thumbnailCache.loadThumbnailForURL(document.url)
        
        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionElementKindSectionHeader {
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionElementKindSectionHeader, withReuseIdentifier: "Header", for: indexPath) as! HeaderView

            header.title = indexPath.section == DocumentBrowserController.recentsSection ? "Recently Viewed" : "All Shapes"
            
            return header
        }

        return super.collectionView(collectionView, viewForSupplementaryElementOfKind: kind, at: indexPath)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Locate the selected document and open it.
        let document = documentForIndexPath(indexPath)
        guard let documentUrl = document?.url else { return }
        openDocumentAtURL(documentUrl)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let document = documentForIndexPath(indexPath) else { return }
        
        let visibleURLs: [URL?] = collectionView.indexPathsForVisibleItems.map { indexPath in
            if let document = documentForIndexPath(indexPath) {
                return document.url
            }
            
            return nil
        }
        
        let presentURLs = visibleURLs.flatMap{$0}
        
        if !presentURLs.contains(document.url) {
            thumbnailCache.cancelThumbnailLoadForURL(document.url)
        }
    }

    
    // MARK: - Document handling support
        
    fileprivate func documentBrowserModelObjectForURL(_ url: URL) -> DocumentBrowserModelObject? {
        guard let matchingDocumentIndex = documents.index(where: { $0.url as URL == url }) else { return nil }
        
        return documents[matchingDocumentIndex]
    }

    fileprivate func documentForIndexPath(_ indexPath: IndexPath) -> ModelObject? {
        if indexPath.section == DocumentBrowserController.recentsSection {
            if recents.count > indexPath.row {
                return recents[indexPath.row]
            }
        } else if indexPath.section == DocumentBrowserController.documentsSection {
            if documents.count > indexPath.row {
                return documents[indexPath.row]
            }
        }

        return nil
    }
    
    fileprivate func presentCloudDisabledAlert() {
        OperationQueue.main.addOperation {
            let alertController = UIAlertController(title: "iCloud is disabled", message: "Please enable iCloud Drive in Settings to use this app", preferredStyle: .alert)
            
            let alertAction = UIAlertAction(title: "Dismiss", style: .default, handler: nil)
            
            alertController.addAction(alertAction)
            
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    fileprivate func createNewDocumentWithTemplate(_ templateURL: URL) {
        /*
            We don't create a new document on the main queue because the call to
            fileManager.URLForUbiquityContainerIdentifier could potentially block
        */
        coordinationQueue.addOperation {
            let fileManager = FileManager()
            guard let baseURL = fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents").appendingPathComponent("Untitled") else {
                
                self.presentCloudDisabledAlert()
                
                return
            }

            var target = baseURL.appendingPathExtension(DocumentBrowserController.documentExtension)
            
            /*
                We will append this value to our name until we find a path that
                doesn't exist.
            */
            var nameSuffix = 2
            
            /*
                Find a suitable filename that doesn't already exist on disk.
                Do not use `fileManager.fileExistsAtPath(target.path!)` because
                the document might not have downloaded yet.
            */
            while (target as NSURL).checkPromisedItemIsReachableAndReturnError(nil) {
                target = URL(fileURLWithPath: baseURL.path + "-\(nameSuffix).\(DocumentBrowserController.documentExtension)")

                nameSuffix += 1
            }
            
            // Coordinate reading on the source path and writing on the destination path to copy.
            let readIntent = NSFileAccessIntent.readingIntent(with: templateURL, options: [])

            let writeIntent = NSFileAccessIntent.writingIntent(with: target, options: .forReplacing)
            
            NSFileCoordinator().coordinate(with: [readIntent, writeIntent], queue: self.coordinationQueue) { error in
                if error != nil {
                    return
                }
                
                do {
                    try fileManager.copyItem(at: readIntent.url, to: writeIntent.url)
                    
                    try (writeIntent.url as NSURL).setResourceValue(true, forKey: URLResourceKey.hasHiddenExtensionKey)
                    
                    OperationQueue.main.addOperation {
                        self.openDocumentAtURL(writeIntent.url)
                    }
                }
                catch {
                    fatalError("Unexpected error during trivial file operations: \(error)")
                }
            }
        }
    }
    
    // MARK: - Document Opening
    
    func documentWasOpenedSuccessfullyAtURL(_ URL: Foundation.URL) {
        recentsManager.addURLToRecents(URL)
    }
    
    func openDocumentAtURL(_ url: URL) {
        // Push a view controller which will manage editing the document.
        let controller = storyboard!.instantiateViewController(withIdentifier: "Document") as! DocumentViewController

        controller.documentURL = url
        
        show(controller, sender: self)
    }

    func openDocumentAtURL(_ url: URL, copyBeforeOpening: Bool) {
        if copyBeforeOpening  {
            // Duplicate the document and open it.
            createNewDocumentWithTemplate(url)
        }
        else {
            openDocumentAtURL(url)
        }
    }
}
