/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    This is the Recents Manager and handles saving the recents list as it changes as well as notifies the delegate when recents are deleted / modified in a way that requires the UI to be refreshed.
*/

import Foundation

/**
    The delegate protocol implemented by the object that receives our results.
    We pass the updated list of results as well as a set of animations.
*/
protocol RecentModelObjectsManagerDelegate: class {
    func recentsManagerResultsDidChange(_ results: [RecentModelObject], animations: [DocumentBrowserAnimation])
}

/**
    The `RecentModelObjectsManager` manages our list of recents.  It receives
    notifications from the recents as a RecentModelObjectDelegate and computes
    animations from the notifications which is submits to it's delegate.
*/
class RecentModelObjectsManager: RecentModelObjectDelegate {
    // MARK: - Properties
    
    var recentModelObjects = [RecentModelObject]()
    
    static let maxRecentModelObjectCount = 3
    
    static let recentsKey = "recents"
    
    fileprivate let workerQueue: OperationQueue = {
        let coordinationQueue = OperationQueue()
        
        coordinationQueue.name = "com.example.apple-samplecode.ShapeEdit.recentobjectsmanager.workerQueue"
        
        coordinationQueue.maxConcurrentOperationCount = 1
        
        return coordinationQueue
    }()

    
    weak var delegate: RecentModelObjectsManagerDelegate? {
        didSet {
            /*
                If we already have results, we send them to the delegate as an
                initial update.
            */
            delegate?.recentsManagerResultsDidChange(recentModelObjects, animations: [.reload])
        }
    }
    
    // MARK: - Initialization
    
    init() {
        loadRecents()
    }
    
    deinit {
        // Be sure we are no longer listening for file presenter notifications.
        for recent in recentModelObjects {
            NSFileCoordinator.removeFilePresenter(recent)
        }
    }
    
    // MARK: - Recent Saving / Loading
    
    fileprivate func loadRecents() {
        workerQueue.addOperation {
            let defaults = UserDefaults.standard
            
            guard let loadedRecentData = defaults.object(forKey: RecentModelObjectsManager.recentsKey) as? [Data] else {
                return
            }
            
            let loadedRecents = loadedRecentData.flatMap { recentModelObjectData in
                return NSKeyedUnarchiver.unarchiveObject(with: recentModelObjectData) as? RecentModelObject
            }
            
            // Remove any existing recents we may have already stored in memory.
            for recent in self.recentModelObjects {
                NSFileCoordinator.removeFilePresenter(recent)
            }
            
            /* 
                Add all newly loaded recents to the recents set and register for
                `NSFilePresenter` notifications on all of them.
            */
            for recent in loadedRecents {
                recent.delegate = self
                NSFileCoordinator.addFilePresenter(recent)
            }
            
            self.recentModelObjects = loadedRecents
            
            // Check if the bookmark data is stale and resave the recents if it is.
            for recent in loadedRecents {
                if recent.bookmarkDataNeedsSave {
                    self.saveRecents()
                }
            }
            
            OperationQueue.main.addOperation {
                // Notify our delegate that the initial recents were loaded.
                self.delegate?.recentsManagerResultsDidChange(self.recentModelObjects, animations: [.reload])
            }
        }
    }
    
    fileprivate func saveRecents() {
        let recentModels = recentModelObjects.map { recentModelObject in
            return NSKeyedArchiver.archivedData(withRootObject: recentModelObject)
        }
        
        UserDefaults.standard.set(recentModels, forKey: RecentModelObjectsManager.recentsKey)
    }
    
    // MARK: - Recent List Management
    
    fileprivate func removeRecentModelObject(_ recent: RecentModelObject) {
        // Remove the file presenter so we stop getting notifications on the removed recent.
        NSFileCoordinator.removeFilePresenter(recent)
        
        /*
            Remove the recent from the array and save the recents array to disk
            so they will reflect the correct state when the app is relaunched.
        */
        guard let index = recentModelObjects.index(of: recent) else { return }

        recentModelObjects.remove(at: index)

        saveRecents()
    }
    
    func addURLToRecents(_ URL: Foundation.URL) {
        workerQueue.addOperation {
            // Add the recent to the recents manager.
            guard let recent = RecentModelObject(URL: URL) else { return }

            var animations = [DocumentBrowserAnimation]()
            
            if let index = self.recentModelObjects.index(of: recent) {
                self.recentModelObjects.remove(at: index)
                
                if index != 0 {
                    animations += [.move(fromIndex: index, toIndex: 0)]
                }
            }
            else {
                recent.delegate = self
                
                NSFileCoordinator.addFilePresenter(recent)
                
                animations += [.add(index: 0)]
            }
            
            self.recentModelObjects.insert(recent, at: 0)
            
            // Prune down the recent documents if there are too many.
            while self.recentModelObjects.count > RecentModelObjectsManager.maxRecentModelObjectCount {
                self.removeRecentModelObject(self.recentModelObjects.last!)
                
                animations += [.delete(index: self.recentModelObjects.count - 1)]
            }
            
            OperationQueue.main.addOperation {
                self.delegate?.recentsManagerResultsDidChange(self.recentModelObjects, animations: animations)
            }
        
            self.saveRecents()
        }
    }
    
    // MARK: - RecentModelObjectDelegate
    
    func recentWasDeleted(_ recent: RecentModelObject) {
        self.workerQueue.addOperation {
            guard let index = self.recentModelObjects.index(of: recent) else { return }
            
            self.removeRecentModelObject(recent)
            
            OperationQueue.main.addOperation {
                self.delegate?.recentsManagerResultsDidChange(self.recentModelObjects, animations: [
                    .delete(index: index)
                ])
            }
        }
    }
    
    func recentNeedsReload(_ recent: RecentModelObject) {
        self.workerQueue.addOperation {
            guard let index = self.recentModelObjects.index(of: recent) else { return }
            
            OperationQueue.main.addOperation {
                self.delegate?.recentsManagerResultsDidChange(self.recentModelObjects, animations: [
                    .update(index: index)
                ])
            }
        }
    }
}
