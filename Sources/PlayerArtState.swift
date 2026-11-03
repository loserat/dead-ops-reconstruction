import Foundation
import SceneKit
import SpriteKit

/// Render-thread-only personal nodes. World geometry and enemies are retained once by ArcadeGame.
final class PlayerArtState {
    let slot:Int,hero=SCNNode(),badge=SCNNode(),tile=SKNode()
    let playerVisibility=PlayerVisibilityArt()
    let supportLabel=SKLabelNode(fontNamed:"Menlo-Bold"),vehicleLabel=SKLabelNode(fontNamed:"Menlo-Bold")
    var roleText:SCNText?,badgeText=""
    var hudCounters:[SKLabelNode]=[],hudCounterTitles:[SKLabelNode]=[]
    var tileLabels:[SKLabelNode]=[],tileBackground:SKShapeNode?,tileMeter:SKShapeNode?
    var chickenNodes:[Int:SCNNode]=[:]
    var orbNodes:[Int:SCNNode]=[:]
    var flyingOrbNodes:[Int:SCNNode]=[:]
    var arcNodes:[Int:SCNNode]=[:]
    var shieldBarrelNodes:[Int:SCNNode]=[:]
    var departingShieldNodes:[Int:SCNNode]=[:]
    var monkeyNodes:[Int:SCNNode]=[:]
    var sentryNodes:[Int:SCNNode]=[:]
    var teddyNode:SCNNode?=nil
    var vehicleNode:SCNNode?=nil
    var vehicleShadow:SCNNode?=nil
    var locomotion=CharacterLocomotion()
    var walking:Double {get{locomotion.phase}set{locomotion.phase=newValue}}
    var locomotionAmount:Double {locomotion.amount}
    var appliedPlayerColor:PlayerColor?=nil
    var bodyShieldNode:SCNNode?,boostTrailNode:SCNNode?
    var bodyShieldFading:Bool?
    init(slot:Int){self.slot=slot;hero.name="player-\(slot+1)";badge.name="player-\(slot+1)-badge"}
    func detach(){
        hero.removeFromParentNode();badge.removeFromParentNode();tile.removeFromParent();playerVisibility.root.removeFromParentNode()
        for group in [chickenNodes,orbNodes,flyingOrbNodes,arcNodes,shieldBarrelNodes,departingShieldNodes,monkeyNodes,sentryNodes] {
            for node in group.values {node.removeFromParentNode()}
        }
        for node in [teddyNode,vehicleNode,vehicleShadow,bodyShieldNode,boostTrailNode] {node?.removeFromParentNode()}
    }
}
extension ArcadeGame {
    var activeArt:PlayerArtState {playerArtStates[core.activePlayerSlot]}
    var hero:SCNNode {activeArt.hero}
    var playerVisibility:PlayerVisibilityArt {activeArt.playerVisibility}
    var supportLabel:SKLabelNode {activeArt.supportLabel}
    var vehicleLabel:SKLabelNode {activeArt.vehicleLabel}
    var selectedPlayerColor:PlayerColor {core.activePlayerSlot==0 ? settings.playerColor:settings.color(for:core.activePlayerSlot)}
    func ownerMaterialKey(_ name:String)->String {core.activePlayerSlot==0 ? name:name+"-p\(core.activePlayerSlot)"}
    var chickenNodes:[Int:SCNNode] {
        _read {let art=activeArt;yield art.chickenNodes}
        _modify {let art=activeArt;yield &art.chickenNodes}
    }
    var orbNodes:[Int:SCNNode] {
        _read {let art=activeArt;yield art.orbNodes}
        _modify {let art=activeArt;yield &art.orbNodes}
    }
    var flyingOrbNodes:[Int:SCNNode] {
        _read {let art=activeArt;yield art.flyingOrbNodes}
        _modify {let art=activeArt;yield &art.flyingOrbNodes}
    }
    var arcNodes:[Int:SCNNode] {
        _read {let art=activeArt;yield art.arcNodes}
        _modify {let art=activeArt;yield &art.arcNodes}
    }
    var shieldBarrelNodes:[Int:SCNNode] {
        _read {let art=activeArt;yield art.shieldBarrelNodes}
        _modify {let art=activeArt;yield &art.shieldBarrelNodes}
    }
    var departingShieldNodes:[Int:SCNNode] {
        _read {let art=activeArt;yield art.departingShieldNodes}
        _modify {let art=activeArt;yield &art.departingShieldNodes}
    }
    var monkeyNodes:[Int:SCNNode] {
        _read {let art=activeArt;yield art.monkeyNodes}
        _modify {let art=activeArt;yield &art.monkeyNodes}
    }
    var sentryNodes:[Int:SCNNode] {
        _read {let art=activeArt;yield art.sentryNodes}
        _modify {let art=activeArt;yield &art.sentryNodes}
    }
    var teddyNode:SCNNode? {
        _read {let art=activeArt;yield art.teddyNode}
        _modify {let art=activeArt;yield &art.teddyNode}
    }
    var vehicleNode:SCNNode? {
        _read {let art=activeArt;yield art.vehicleNode}
        _modify {let art=activeArt;yield &art.vehicleNode}
    }
    var vehicleShadow:SCNNode? {
        _read {let art=activeArt;yield art.vehicleShadow}
        _modify {let art=activeArt;yield &art.vehicleShadow}
    }
    var walking:Double {
        _read {let art=activeArt;yield art.walking}
        _modify {let art=activeArt;yield &art.walking}
    }
    var appliedPlayerColor:PlayerColor? {
        _read {let art=activeArt;yield art.appliedPlayerColor}
        _modify {let art=activeArt;yield &art.appliedPlayerColor}
    }
    func ensurePlayerArtRoster(){
        while playerArtStates.count>core.playerCount {playerArtStates.removeLast().detach()}
        while playerArtStates.count<core.playerCount {playerArtStates.append(PlayerArtState(slot:playerArtStates.count))}
        for player in core.players {core.withPlayer(player.slot){
            if hero.childNodes.isEmpty {hero.addChildNode(detailedCharacter(player:true))}
            if hero.parent==nil {actors.addChildNode(hero)}
            if activeArt.badge.parent==nil {actors.addChildNode(activeArt.badge)}
        }}
    }
}
