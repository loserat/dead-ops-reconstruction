import Foundation
import SceneKit

/// Separate display stage. It never moves a live actor or spends the player's banked score.
final class GameOverArt {
    let root=SCNNode(),stash=SCNNode()
    private(set) var soldier:SCNNode?,visitor:SCNNode?
    private(set) var builds=0
    private var lastClock = -1.0
    func update(game:ArcadeGame,aspect:Double) {
        guard game.core.phase == .gameOver,let ending=game.core.gameOverSequence else {
            root.isHidden=true
            if soldier != nil {root.childNodes.forEach{$0.removeFromParentNode()};soldier=nil;visitor=nil;lastClock = -1}
            return
        }
        if root.parent==nil {game.scene.rootNode.addChildNode(root)}
        if soldier==nil || ending.clock<lastClock {build(game)}
        lastClock=ending.clock;root.isHidden=false
        let t=ending.clock,flight=ending.heroFlight,leave=ending.departure
        soldier?.position=SCNVector3(-0.70-flight*8.5,1.22+sin(flight*Double.pi)*4-flight*2,0.45+flight*4.5)
        soldier?.eulerAngles=SCNVector3(flight*4,0.3,flight*7)
        soldier?.opacity=CGFloat(1-max(0,(flight-0.6)/0.4))
        for (name,side) in [("player-arm-left",1.0),("player-arm-right",-1.0)] {
            soldier?.childNode(withName:name,recursively:true)?.eulerAngles.z=NodeFloat(side*(t<2.4 ? 1.9+sin(t*8)*0.15:0.2))
        }
        visitor?.position=SCNVector3(1.45,1.22+ending.visitorHeight,-0.1)
        visitor?.isHidden=t<1.2 || ending.finished
        visitor?.eulerAngles.y=NodeFloat(t<3.65 ? Double.pi/2:Double.pi/8)
        visitor?.childNode(withName:"boss-arm-right",recursively:false)?.eulerAngles.x=NodeFloat(sin(ending.strike*Double.pi)*1.6)
        visitor?.childNode(withName:"boss-arm-left",recursively:false)?.eulerAngles.x=NodeFloat(t>=2.4 && t<3.2 ? -0.8+sin(t*16)*0.15:0)
        if let flame=visitor?.childNode(withName:"ending-jets",recursively:false) {
            flame.isHidden = !(t>=1.2 && t<2.4 || leave>0 && !ending.finished)
            flame.scale.y=NodeFloat(0.85+sin(t*35)*0.15)
        }
        stash.position=SCNVector3(ending.gathering*1.45,ending.gathering*0.8+leave*12,0)
        let shrink=1-ending.gathering*0.6;stash.scale=SCNVector3(shrink,shrink,shrink)
        stash.opacity=CGFloat(1-leave)
        // Frame the entire pedestal at 16:9 and 4:3, independent of the selected gameplay zoom.
        let scale=max(5.8,8.1/max(0.7,aspect)),distance=GameCameraProjection.distance(scale:scale,aspect:aspect),angle=atan2(10.7,17.0)
        game.camera.camera?.orthographicScale=scale
        game.camera.position=SCNVector3(0,101.3+distance*sin(angle),distance*cos(angle))
        game.camera.look(at:SCNVector3(0,101.3,0),up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
    }
    private func build(_ game:ArcadeGame) {
        root.childNodes.forEach{$0.removeFromParentNode()};stash.childNodes.forEach{$0.removeFromParentNode()}
        root.name="game-over-stage";root.position=SCNVector3(0,100,0);builds+=1
        let floor=box(45,0.25,38,0x17252a);floor.position.y = -0.2;root.addChildNode(floor)
        for (radius,height,y,color) in [(4.0,0.3,0.15,0x34494a),(3.55,0.35,0.475,0x59625a),(3.15,0.45,0.875,0x86774c)] {
            let step=cylinder(CGFloat(radius),CGFloat(height),color);step.position.y=NodeFloat(y);root.addChildNode(step)
        }
        let edge=SCNTorus(ringRadius:3.02,pipeRadius:0.055);edge.materials=[material(0xd7b767)]
        let ring=SCNNode(geometry:edge);ring.position.y=1.11;root.addChildNode(ring)
        for i in 0..<38 {
            let a=Double(i)*2.399,r=0.5+Double(i%7)*0.22
            let loot=game.treasureModel(i%6==0 ? .gem(GemColor.allCases[i%3],.medium):.treasure(index:i))
            loot.position=SCNVector3(cos(a)*r,1.14+Double(i%3)*0.06,sin(a)*r)
            loot.eulerAngles.y=NodeFloat(a);stash.addChildNode(loot)
        }
        root.addChildNode(stash)
        // Clone the already colored player; do not call a factory that resets shared uniform materials.
        let player=game.hero.childNodes.first?.clone() ?? SCNNode()
        for n in player.childNodes where n.name=="standard-gun" || n.name=="death-machine" || n.name?.hasPrefix("held-")==true || n.name=="muzzle" || n.name=="player-direction" || n.name=="player-marker" {n.isHidden=true}
        player.isHidden=false;player.opacity=1;root.addChildNode(player);soldier=player
        let ape=game.silverbackModel();ape.name="ending-silverback";root.addChildNode(ape);visitor=ape
        let jets=SCNNode();jets.name="ending-jets"
        for x in [-0.47,0.47] {
            let plume=SCNCone(topRadius:0.12,bottomRadius:0.32,height:1.3)
            plume.radialSegmentCount=10;plume.materials=[material(0xffaa56,glow:true)]
            let fire=SCNNode(geometry:plume);fire.position=SCNVector3(x,0.65,0.65);fire.opacity=0.65;jets.addChildNode(fire)
        }
        ape.addChildNode(jets)
    }
}
