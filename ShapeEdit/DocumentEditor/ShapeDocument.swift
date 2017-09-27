/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    This is the main Document class which reads and writes our document objects using proper file coordination.
*/

import UIKit
import SceneKit

/// We save and restore the camera state as an object to be able to use `NSCoding`.
class CameraState: NSObject, NSCoding {
    // MARK: - Properties
    
    var position: SCNVector3!
    var rotation: SCNVector4
    
    // MARK: - Initialization
    
    override init() {
        position = SCNVector3(x: 0, y: 0, z: 4)
        rotation = SCNVector4()
        
        super.init()
    }
    
    // MARK: - NSCoding
    
    required init?(coder aDecoder: NSCoder) {
        position = SCNVector3(x: 0, y: 0, z: 4)
        rotation = SCNVector4()
        
        position.x = aDecoder.decodeFloat(forKey: "x")
        position.y = aDecoder.decodeFloat(forKey: "y")
        position.z = aDecoder.decodeFloat(forKey: "z")
        rotation.x = aDecoder.decodeFloat(forKey: "rx")
        rotation.y = aDecoder.decodeFloat(forKey: "ry")
        rotation.z = aDecoder.decodeFloat(forKey: "rz")
        rotation.w = aDecoder.decodeFloat(forKey: "rw")
        
        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(position.x, forKey: "x")
        aCoder.encode(position.y, forKey: "y")
        aCoder.encode(position.z, forKey: "z")
        aCoder.encode(rotation.x, forKey: "rx")
        aCoder.encode(rotation.y, forKey: "ry")
        aCoder.encode(rotation.z, forKey: "rz")
        aCoder.encode(rotation.w, forKey: "rw")
    }
}

/**
    The `ShapeDocument` is our main document class which manages loading and saving
    of shape files on disk.  We subclass from `UIDocument` in order to load and 
    save with proper file coordination handled automatically.
*/
class ShapeDocument: UIDocument {
    // MARK: - Types
    
    enum Shape: Int {
        case sphere
        case cube
        case cylinder
        case cone
        case torus
        case pyramid
    }
    
    // MARK: - Declarations

    static let shapeKey       = "shape"
    static let cameraStateKey = "cameraState"

    // MARK: - Properties
    
    var shape: Shape?
    var cameraState = CameraState()

    // MARK: - Document loading override
    
    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let data = contents as? Data else {
            fatalError("Cannot handle contents of type \(type(of: (contents) as AnyObject)).")
        }

        // Our document format is a simple plist.
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? [String: AnyObject] else {
            throw ShapeEditError.plistReadFailed
        }

        // The shape is saved as a number corresponding to our enum.
        guard let shapeRawValue = plist[ShapeDocument.shapeKey] as? Int else {
            throw ShapeEditError.noShape
        }
        
        shape = Shape(rawValue: shapeRawValue)
        
        // The camera state is saved using NSCoding.
        if let cameraStateData = plist[ShapeDocument.cameraStateKey] as? Data,
              let cameraState = NSKeyedUnarchiver.unarchiveObject(with: cameraStateData) as? CameraState {
            self.cameraState = cameraState
        }
        else {
            // This is a new document so save it to disk to generate the thumbnail.
            updateChangeCount(.done)
        }
    }

    // MARK: - Document Saving Override

    override func contents(forType typeName: String) throws -> Any {
        /*
            Saving the document consists of creating the property list, then 
            creating an `NSData` object using plist serialization.
        */
        
        let cameraStateData = NSKeyedArchiver.archivedData(withRootObject: cameraState)
        
        guard let shapeRawValue = shape?.rawValue else {
            throw ShapeEditError.noShape
        }
        
        let plist: [AnyHashable: Any] = [
            ShapeDocument.shapeKey: shapeRawValue,
            ShapeDocument.cameraStateKey: cameraStateData
        ]

        return try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
    }

    override func fileAttributesToWrite(to url: URL, for saveOperation: UIDocumentSaveOperation) throws -> [AnyHashable: Any] {
        let aspectRatio = 220.0 / 270.0

        let thumbnailSize = CGSize(width: CGFloat(1024.0 * aspectRatio), height: 1024.0)

        let image = renderThumbnailOfSize(thumbnailSize)

        return [
            URLResourceKey.hasHiddenExtensionKey: true,
            URLResourceKey.thumbnailDictionaryKey: [
                URLThumbnailDictionaryItem.NSThumbnail1024x1024SizeKey: image
            ]
        ]
    }
    
    // MARK: - View Interaction
    
    func updateCameraState(_ node: SCNNode) {
        // Called by the view after the user has changed the camera state.
        cameraState.position = node.position
        
        cameraState.rotation = node.rotation
        
        updateChangeCount(.done)
    }
    
    // MARK: - Thumbnail Generation
    
    var color: UIColor {
        switch shape {
            case nil:
                return UIColor.gray
                
            case .sphere?:
                return UIColor(red: 253/255, green: 61/255, blue: 57/255, alpha: 1)
                
            case .cube?:
                return UIColor(red: 60/255, green: 171/255, blue: 219/255, alpha: 1)
                
            case .cylinder?:
                return UIColor(red: 83/255, green: 216/255, blue: 106/255, alpha: 1)
                
            case .cone?:
                return UIColor(red: 89/255, green: 91/255, blue: 212/255, alpha: 1)
                
            case .torus?:
                return UIColor(red: 255/255, green: 204/255, blue: 0/255, alpha: 1)
                
            case .pyramid?:
                return UIColor(red: 254/255, green: 149/255, blue: 38/255, alpha: 1)
        }
    }
    
    var backgroundColor: UIColor {
        return color.withAlphaComponent(0.3)
    }
    
    func setSceneOnRenderer(_ renderer: SCNSceneRenderer) {
        let node: SCNNode
        let geometry: SCNGeometry
        
        switch shape {
            case nil:
                geometry = SCNGeometry()
            
            case .sphere?:
                geometry = SCNSphere(radius: 1)
            
            case .cube?:
                geometry = SCNBox(width: 2, height: 2, length: 2, chamferRadius: 0.1)
            
            case .cylinder?:
                geometry = SCNCylinder(radius: 0.75, height: 2)
            
            case .cone?:
                geometry = SCNCone(topRadius: 0.5, bottomRadius: 1.5, height: 1.5)
            
            case .torus?:
                geometry = SCNTorus(ringRadius: 1.0, pipeRadius: 0.2)
            
            case .pyramid?:
                geometry = SCNPyramid(width: 1.5, height: 1.5, length: 1.5)
        }
        
        let colorMaterial = SCNMaterial()
        colorMaterial.diffuse.contents = color
        geometry.firstMaterial = colorMaterial
        node = SCNNode(geometry: geometry)
        
        let scene = SCNScene()
        scene.rootNode.addChildNode(node)
        
        let camera = SCNCamera()
        let pov = SCNNode()
        pov.camera = camera
        pov.position = cameraState.position
        pov.rotation = cameraState.rotation
        scene.rootNode.addChildNode(pov)
        
        let ambientLight = SCNLight()
        let ambientLightNode = SCNNode()
        ambientLight.type = SCNLight.LightType.ambient
        ambientLight.color = UIColor(white: 0.3, alpha: 1)
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode);
        renderer.scene = scene

        renderer.scene = scene
        
        renderer.pointOfView = pov
    }
    
    func renderThumbnailOfSize(_ size: CGSize) -> UIImage {
        /*
            We want to create a thumbnail while running on the background thread.
            The obvious choice would be to use `SCNView`'s snapshot method, but we
            have a problem: we don't have an `SCNView`, and we can't create a view
            while on the background thread. Instead of eagerly creating a view
            that is only used for snapshotting, we create our own renderer, frame,
            color and depth buffers, and then render and read the pixels into a
            `CGImage`.
        */
        
        let width = Int(size.width)
        let height = Int(size.height)
        
        // Create and setup a context and renderer.
        let glContext = EAGLContext(api: .openGLES2)!
        let renderer = SCNRenderer(context: glContext, options: [:])
        renderer.autoenablesDefaultLighting = true
        setSceneOnRenderer(renderer)
        
        // Make the context current.
        let previousContext = EAGLContext.current()
        defer {
            EAGLContext.setCurrent(previousContext)
        }
        EAGLContext.setCurrent(glContext)
        
        // Create our frame buffer.
        var frameBuffer: GLuint = 0
        glGenFramebuffers(1, &frameBuffer)
        defer {
            glDeleteFramebuffers(1, &frameBuffer)
        }
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), frameBuffer)
        
        // Create a color buffer (RGBA) and attach it to our frame buffer.
        var colorBuffer: GLuint = 0
        glGenRenderbuffers(1, &colorBuffer)
        defer {
            glDeleteRenderbuffers(1, &colorBuffer)
        }
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), colorBuffer)
        
        // RGBA.
        glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_RGBA8), GLsizei(width), GLsizei(height))
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_COLOR_ATTACHMENT0), GLenum(GL_RENDERBUFFER), colorBuffer)
        
        // Create a depth buffer and attach it to out frame buffer.
        var depthBuffer: GLuint = 0
        glGenRenderbuffers(1, &depthBuffer)
        defer {
            glDeleteRenderbuffers(1, &depthBuffer)
        }
        glBindRenderbuffer(GLenum(GL_RENDERBUFFER), depthBuffer)
        glRenderbufferStorage(GLenum(GL_RENDERBUFFER), GLenum(GL_DEPTH_COMPONENT24), GLsizei(width), GLsizei(height))
        glFramebufferRenderbuffer(GLenum(GL_FRAMEBUFFER), GLenum(GL_DEPTH_ATTACHMENT), GLenum(GL_RENDERBUFFER), depthBuffer)

        // Set the background color.
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        backgroundColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        glClearColor(Float(red), Float(green), Float(blue), Float(alpha))
        
        // Set our viewport, clear out the buffers and render.
        glViewport(0, 0, GLsizei(width), GLsizei(height))
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        renderer.render(atTime: 0.0)
        
        // Read the contents of our framebuffer into an `NSMutableData`.
        
        // RGBA.
        let componentsPerPixel = 4
        
        // 8-bit.
        let bitsPerComponent = 8
        
        let imageBits = NSMutableData(length: width * height * componentsPerPixel)!
        glReadPixels(0, 0, GLsizei(width), GLsizei(height), GLenum(GL_RGBA), GLenum(GL_UNSIGNED_BYTE), imageBits.mutableBytes)
        
        // Create a `CGImage` off that data.
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let dataProvider = CGDataProvider(data: imageBits)
        
        let cgBitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
        let cgImage = CGImage(width: width, height: height, bitsPerComponent: bitsPerComponent, bitsPerPixel: componentsPerPixel * bitsPerComponent, bytesPerRow: width * componentsPerPixel, space: colorSpace, bitmapInfo: cgBitmapInfo, provider: dataProvider!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        
        // Flip the image to match our Editor view's coordinate system.
        let image = UIImage(cgImage: cgImage)
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, 1.0)
        
        let context = UIGraphicsGetCurrentContext()
        
        let flipVertical = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: image.size.height)
        
        context!.concatenate(flipVertical)
        
        let imageRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        image.draw(in: imageRect)
        
        let flippedImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return flippedImage!
    }
}
