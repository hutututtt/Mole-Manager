import GameplayKit
import QuartzCore
import SceneKit
import SwiftUI

// A native 3D SceneKit View
struct MoleSceneView: NSViewRepresentable {
  @Binding var state: AppState
  @Binding var rotationVelocity: CGSize  // Interaction Input
  var activeColor: (Double, Double, Double)  // (Red, Green, Blue)
  var appMode: AppMode  // Pass the mode
  var isRunning: Bool  // Fast spin trigger

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> SCNView {
    let scnView = SCNView()

    // Scene Setup
    let scene = SCNScene()
    scnView.scene = scene
    scnView.backgroundColor = NSColor.clear
    scnView.delegate = context.coordinator
    scnView.isPlaying = true

    // 1. The Planet (Sphere)
    let sphereGeo = SCNSphere(radius: 1.4)
    sphereGeo.segmentCount = 192

    // Atmosphere Shader removed strictly based on user feedback (No "layer" wanted)
    // sphereGeo.shaderModifiers = nil

    let sphereNode = SCNNode(geometry: sphereGeo)
    sphereNode.name = "molePlanet"

    // Material
    let material = SCNMaterial()
    material.lightingModel = .physicallyBased
    material.diffuse.contents = NSColor.gray  // Placeholder

    sphereNode.geometry?.materials = [material]
    scene.rootNode.addChildNode(sphereNode)

    // 2. Lighting
    // A. Main Sun
    let sunLight = SCNNode()
    sunLight.light = SCNLight()
    sunLight.light?.type = .omni
    sunLight.light?.color = NSColor(calibratedWhite: 1.0, alpha: 1.0)
    sunLight.light?.intensity = 1350  // Reduced from 1500 for less glare
    sunLight.position = SCNVector3(x: 8, y: 5, z: 12)
    sunLight.light?.castsShadow = true
    scene.rootNode.addChildNode(sunLight)

    // B. Rim Light
    let rimLight = SCNNode()
    rimLight.name = "rimLight"
    rimLight.light = SCNLight()
    rimLight.light?.type = .spot
    rimLight.light?.color = NSColor(calibratedRed: 0.8, green: 0.8, blue: 1.0, alpha: 1.0)
    rimLight.light?.intensity = 600
    rimLight.position = SCNVector3(x: -6, y: 3, z: -6)
    rimLight.look(at: SCNVector3Zero)
    scene.rootNode.addChildNode(rimLight)

    // C. Ambient
    let ambientLight = SCNNode()
    ambientLight.light = SCNLight()
    ambientLight.light?.type = .ambient
    ambientLight.light?.intensity = 300  // Lifted from 150 to soften shadows
    ambientLight.light?.color = NSColor(white: 0.2, alpha: 1.0)
    scene.rootNode.addChildNode(ambientLight)

    // Camera
    let cameraNode = SCNNode()
    cameraNode.camera = SCNCamera()
    cameraNode.position = SCNVector3(x: 0, y: 0, z: 4)
    scene.rootNode.addChildNode(cameraNode)

    scnView.antialiasingMode = .multisampling4X
    scnView.allowsCameraControl = false

    return scnView
  }

  func updateNSView(_ scnView: SCNView, context: Context) {
    context.coordinator.parent = self

    guard let scene = scnView.scene,
      scene.rootNode.childNode(withName: "molePlanet", recursively: false) != nil
    else { return }
    // Only update if mode changed to prevent expensive texture reloads
    if context.coordinator.currentMode != appMode {
      context.coordinator.currentMode = appMode

      if let scene = scnView.scene,
        let planet = scene.rootNode.childNode(withName: "molePlanet", recursively: true),
        let material = planet.geometry?.firstMaterial
      {
        var textureName = "mars"
        var constRoughness: Double? = 0.9
        var rimColor = NSColor(calibratedRed: 1.0, green: 0.5, blue: 0.3, alpha: 1.0)

        switch appMode {
        case .cleaner:
          textureName = "mercury"
          constRoughness = 0.6
          rimColor = NSColor(calibratedRed: 0.8, green: 0.8, blue: 0.9, alpha: 1.0)
        case .uninstaller:
          textureName = "mars"
          constRoughness = 0.9
          rimColor = NSColor(calibratedRed: 1.0, green: 0.3, blue: 0.1, alpha: 1.0)
        case .optimizer:
          textureName = "earth"
          constRoughness = 0.4
          rimColor = NSColor(calibratedRed: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
        }

        // Load Texture (Support PNG and JPG)
        var finalImage: NSImage?
        if let url = Bundle.module.url(forResource: textureName, withExtension: "png") {
          finalImage = NSImage(contentsOf: url)
        } else if let url = Bundle.module.url(forResource: textureName, withExtension: "jpg") {
          finalImage = NSImage(contentsOf: url)
        }

        if let image = finalImage {
          material.diffuse.contents = image
          material.normal.contents = image
          material.normal.intensity = 1.0

          if let r = constRoughness {
            material.roughness.contents = r
          } else {
            material.roughness.contents = image
          }
          material.emission.contents = NSColor.black
        } else {
          material.diffuse.contents = NSColor.gray
        }

        if let rimLight = scene.rootNode.childNode(withName: "rimLight", recursively: false) {
          SCNTransaction.begin()
          SCNTransaction.animationDuration = 0.5
          rimLight.light?.color = rimColor
          SCNTransaction.commit()
        }
      }
    }
  }

  class Coordinator: NSObject, SCNSceneRendererDelegate {
    var parent: MoleSceneView
    var currentMode: AppMode?  // Track current mode to avoid reloading textures

    init(_ parent: MoleSceneView) {
      self.parent = parent
    }

    // ... rest of coordinator

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
      guard
        let planet = renderer.scene?.rootNode.childNode(withName: "molePlanet", recursively: false)
      else { return }

      // Auto Rotation Speed
      // Slower, majestic rotation
      // Auto Rotation Speed
      // Slower, majestic rotation normally. Fast when working.
      let baseRotation = parent.isRunning ? 0.05 : 0.002

      // Drag Influence
      let dragInfluence = Double(parent.rotationVelocity.width) * 0.0005

      // Vertical Tilt (X-Axis) + Slow Restore to 0
      let tiltInfluence = Double(parent.rotationVelocity.height) * 0.0005

      // Apply Rotation
      planet.eulerAngles.y += CGFloat(baseRotation + dragInfluence)
      planet.eulerAngles.x += CGFloat(tiltInfluence)
    }
  }
}
