/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    These are the base protocol classes for dealing with elements in our document browser.
*/
import Foundation

/// The base protocol for all collection view objects to display in our UI.
protocol ModelObject: class {
    var displayName: String { get }
    
    var subtitle: String { get }
    
    var url: Foundation.URL { get }
}

/**
    Represents an animation as computed on the query's results set. Each animation 
    can add, remove, update or move a row.
*/
enum DocumentBrowserAnimation {
    case reload
    case delete(index: Int)
    case add(index: Int)
    case update(index: Int)
    case move(fromIndex: Int, toIndex: Int)
}

/**
    We need to implement the `Equatable` protocol on our animation objects so we
    can match them later.
*/
extension DocumentBrowserAnimation: Equatable { }

func ==(lhs: DocumentBrowserAnimation, rhs: DocumentBrowserAnimation) -> Bool {
    switch (lhs, rhs) {
        case (.reload, .reload):
            return true
            
        case let (.delete(left), .delete(right)) where left == right:
            return true
            
        case let (.add(left), .add(right)) where left == right:
            return true
            
        case let (.update(left), .update(right)) where left == right:
            return true
            
        case let (.move(leftFrom, leftTo), .move(rightFrom, rightTo)) where leftFrom == rightFrom && leftTo == rightTo:
            return true
            
        default:
            return false
    }
}

/*
    We implement the `CustomDebugStringConvertible` protocol for pretty printing 
    purposes while debugging.
*/
extension DocumentBrowserAnimation: CustomDebugStringConvertible {
    var debugDescription: String {
        switch self {
            case .reload:
                return "Reload"
                
            case .delete(let i):
                return "Delete(\(i))"
                
            case .add(let i):
                return "Add(\(i))"
                
            case .update(let i):
                return "Update(\(i))"
                
            case .move(let f, let t):
                return "Move(\(f)->\(t))"
        }
    }
}
