import SceneKit

struct FallenBodyArt {
    let node:SCNNode,started:Double,base:Double,axis:V2,corners:[SCNVector3],motion:DefeatedBodyMotion
}

extension ArcadeGame {
    func clearFallenBodies() {
        for n in corpseNodes {n.removeFromParentNode()}
        corpseNodes=[];fallingBodies=[]
    }
    func addFallenBody(_ event:DefeatPresentation,from old:SCNNode) {
        let model=old.clone();rebindEnemySkin(on:model)
        model.childNode(withName:"martyr-glow",recursively:true)?.removeFromParentNode()
        model.childNode(withName:"burning",recursively:false)?.removeFromParentNode()
        model.position=SCNVector3Zero
        let root=SCNNode();root.name="fallen-foe-\(event.id)";root.addChildNode(model)
        let initial=root.boundingBox,center=NodeFloat((initial.min.y+initial.max.y)/2)
        model.position.y = -center
        let b=root.boundingBox
        let corners=[b.min.x,b.max.x].flatMap{x in [b.min.y,b.max.y].flatMap{y in [b.min.z,b.max.z].map{z in SCNVector3(x,y,z)}}}
        // Stable local variation never changes the simulation's random stream or cause of death.
        let direction=Double(event.id%17)*2.399963229728653
        let axis=V2(x:cos(direction),y:sin(direction))
        root.position=SCNVector3(event.position.x,event.elevation+0.08,event.position.y)
        root.castsShadow=false;remains.addChildNode(root);corpseNodes.append(root)
        fallingBodies.append(FallenBodyArt(node:root,started:core.elapsed,base:event.elevation+0.08,axis:axis,corners:corners,motion:DefeatedBodyMotion(launched:event.launched)))
        if corpseNodes.count>DefeatedBodyMotion.retainedLimit {
            let retired=corpseNodes.removeFirst();retired.removeFromParentNode()
            fallingBodies.removeAll{$0.node === retired}
        }
    }
    func animateFallenBodies() {
        fallingBodies.removeAll {body in
            guard body.node.parent === remains else{return true}
            let pose=body.motion.pose(age:core.elapsed-body.started),c=cos(pose.angle),s=sin(pose.angle)
            // Support the rotated bounding corners above the death surface rather than burying the torso.
            var bottom=Double.infinity
            for point in body.corners {
                let crossY=body.axis.y*Double(point.x)-body.axis.x*Double(point.z)
                let rotatedY=Double(point.y)*c+crossY*s
                bottom=min(bottom,rotatedY)
            }
            body.node.rotation=SCNVector4(body.axis.x,0,body.axis.y,pose.angle)
            body.node.position.y=NodeFloat(body.base-bottom+pose.lift)
            body.node.opacity=CGFloat(pose.opacity)
            return pose.settled
        }
    }
}
