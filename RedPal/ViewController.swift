import UIKit
import SpriteKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        if let skView = self.view as? SKView {
            // Carica la scena da MyScene.sks
            if let scene = MyScene(fileNamed: "MyScene") {
                scene.scaleMode = .aspectFill
                skView.presentScene(scene)
            }
        }
    }
}
