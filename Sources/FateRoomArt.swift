import Foundation
import SceneKit

extension ArcadeGame {
    func buildFateSymbols(){
        for statue in core.fateRoom?.lifeStatues ?? [] where statue.collectedBy==nil {
            let node=detailedPickup(.life);node.name="fate-life-\(statue.targetSlot)"
            decor.addChildNode(node);fateLifeNodes[statue.targetSlot]=node
        }
        for door in FateDoor.allCases {
            let arrow=SCNNode();arrow.name="fate-door-\(door.rawValue)";arrow.position=SCNVector3(door.p.x,0.12,door.p.y)
            arrow.eulerAngles.y=NodeFloat(-atan2(door.p.y,door.p.x))
            let mat=material(0xe7ca59,glow:true);mat.lightingModel = .constant
            for side in [-1.0,1] {arrow.addChildNode(beam(SCNVector3(-0.35,0.1,side*0.4),SCNVector3(0.28,0.1,0),radius:0.065,mat:mat))}
            arrow.isHidden=true;decor.addChildNode(arrow);fateDoorNodes[door.rawValue]=arrow
            guard let fate=core.fateRoom?.fate(at:door) else{continue}
            let kind:PickupKind=fate == .fortitude ? .gem:fate == .firepower ? .deathMachine:fate == .friendship ? .chicken:.dash
            let reward=detailedPickup(kind,loot:fate == .fortitude ? .gem(.red,.large):nil);reward.name="fate-reward-\(door.rawValue)";reward.isHidden=true
            reward.scale=SCNVector3(0.8,0.8,0.8);decor.addChildNode(reward);fateDropNodes[door.rawValue]=reward
            if fate == .feet {let boots=detailedPickup(.boots);boots.name="fate-boots";boots.isHidden=true;decor.addChildNode(boots);fateBootNodes[door.rawValue]=boots}
        }
    }
    func syncFateArt(){
        guard core.sideRoom?.kind == .fate,let room=core.fateRoom else{return}
        let clock=core.sideRoom!.clock
        for statue in room.lifeStatues {
            guard let node=fateLifeNodes[statue.targetSlot] else{continue}
            if statue.collectedBy != nil {node.removeFromParentNode();fateLifeNodes.removeValue(forKey:statue.targetSlot)}
            else {node.position=SCNVector3(statue.p.x,statue.elevation+0.15,statue.p.y);node.eulerAngles.y=NodeFloat(clock*1.4)}
        }
        for door in FateDoor.allCases {
            let claimed=room.claimedBy[door.rawValue] != nil
            let decided=room.decisionAt.map{clock >= $0+FateRoomTiming.settle} ?? false
            fateDoorNodes[door.rawValue]?.isHidden = !room.visible(door,at:clock) || claimed || decided
            guard let delivery=room.deliveries[door.rawValue] else {
                fateDropNodes[door.rawValue]?.isHidden=true;fateBootNodes[door.rawValue]?.isHidden=true;continue
            }
            let actor=core.players[delivery.slot]
            for (node,boots) in [(fateDropNodes[door.rawValue],false),(fateBootNodes[door.rawValue],true)] {
                guard let node else{continue}
                if let height=room.height(of:door,at:clock,boots:boots) {
                    node.position=SCNVector3(actor.hero.x,actor.heroElevation+height+0.15,actor.hero.y)
                    node.eulerAngles.y=NodeFloat(clock*1.4);node.isHidden=false
                }else {node.isHidden=true}
            }
        }
    }
}
