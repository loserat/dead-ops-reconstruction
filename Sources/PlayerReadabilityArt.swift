import Foundation
import SceneKit

/// A single cached, color-tinted copy is visible only while the player's actual body is obscured.
/// It never hides map geometry, changes collision, or exposes enemy silhouettes.
final class PlayerVisibilityArt {
    let root=SCNNode(),tint=SCNMaterial()
    private var pairs:[(SCNNode,SCNNode)]=[]
    private var identity:ObjectIdentifier?,color:PlayerColor?
    private var nextProbe=0.0,lastPosition:SCNVector3?
    private(set) var state=PlayerOcclusionState(),probes=0,cloneBuilds=0
    init(){
        root.name="player-occlusion-cue";root.isHidden=true
        tint.lightingModel = .constant;tint.readsFromDepthBuffer=false;tint.writesToDepthBuffer=false
        tint.isDoubleSided=false;tint.blendMode = .alpha;tint.transparencyMode = .aOne
    }
    func reset(){root.isHidden=true;state=PlayerOcclusionState();nextProbe=0;lastPosition=nil}
    private func build(_ source:SCNNode){
        root.childNodes.forEach{$0.removeFromParentNode()};pairs=[]
        let copy=source.clone();root.addChildNode(copy)
        func pair(_ a:SCNNode,_ b:SCNNode){
            pairs.append((a,b));b.castsShadow=false;b.renderingOrder=30
            if let g=a.geometry {b.geometry=g.copy() as? SCNGeometry;b.geometry?.materials=[tint]}
            for (x,y) in zip(a.childNodes,b.childNodes){pair(x,y)}
        }
        pair(source,copy);cloneBuilds+=1
    }
    func update(game:ArcadeGame,dt:Double,now:Double){
        let active=game.core.phase == .playing || game.core.phase == .cleared || game.core.phase == .bonusRoom || game.core.phase == .transition
        guard active,game.core.isPlayerActive else{reset();return}
        let source=game.vehicleNode ?? game.hero,id=ObjectIdentifier(source)
        if identity != id {identity=id;root.childNodes.forEach{$0.removeFromParentNode()};pairs=[];reset()}
        if root.parent==nil {game.scene.rootNode.addChildNode(root)}
        if color != game.selectedPlayerColor {color=game.selectedPlayerColor;tint.diffuse.contents=rgb(game.selectedPlayerColor.tint);tint.emission.contents=rgb(0)}
        let p=source.position
        let moved=lastPosition.map{hypot(Double(p.x-$0.x),Double(p.z-$0.z))>0.18 || abs(Double(p.y-$0.y))>0.12} ?? true
        var blocked=state.blockedSamples
        if now>=nextProbe || moved {
            blocked=blockedSamples(game:game,source:source);probes+=1;nextProbe=now+1.0/30;lastPosition=p
        }
        state.update(blocked:blocked,dt:dt,phase:game.core.phase)
        root.isHidden=state.strength<0.015
        guard !root.isHidden else{return}
        if pairs.isEmpty {build(source)}
        for (a,b) in pairs {b.transform=a.transform;b.isHidden=a.isHidden;b.opacity=a.opacity}
        // Root source blinking does not erase the owner's location during respawn protection.
        pairs.first?.1.opacity=1
        root.opacity=CGFloat(state.strength*0.55)
    }
    func blockedSamples(game:ArcadeGame,source:SCNNode)->Int {
        var enemies=Set(game.foeNodes.values.map{ObjectIdentifier($0)})
        for n in game.silverbackNodes.values {enemies.insert(ObjectIdentifier(n))}
        for n in game.bullNodes.values {enemies.insert(ObjectIdentifier(n))}
        for n in game.barrelNodes.values {enemies.insert(ObjectIdentifier(n))}
        if let n=game.raiderNode {enemies.insert(ObjectIdentifier(n))}
        func obstructs(_ hit:SCNHitTestResult,staticMap:Bool=false)->Bool {
            guard let mat=game.hitMaterial(hit),mat !== game.artMaterials["water"],mat.transparency>0.8 else{return false}
            if let mask=game.foliageMask(for:mat),!mask.isOpaque(at:hit.textureCoordinates(withMappingChannel:mat.diffuse.mappingChannel)) {return false}
            var node:SCNNode?=hit.node,opacity=CGFloat(1),candidate=staticMap
            while let n=node {
                if n === source || n === game.hero || n === game.vehicleNode || n === root {return false}
                if n.isHidden {return false};opacity*=n.opacity
                if n === game.decor || enemies.contains(ObjectIdentifier(n)) {candidate=true}
                node=n.parent
            }
            return candidate && opacity>0.8
        }
        let p=source.position,front=game.camera.worldFront
        return [0.25,0.75,1.20].reduce(0){count,h in
            let target=SCNVector3(p.x,p.y+NodeFloat(h),p.z)
            // Perspective sightlines start at the actual camera; inspection sheets can remain orthographic.
            let from=game.camera.camera?.usesOrthographicProjection == true ? SCNVector3(target.x-front.x*40,target.y-front.y*40,target.z-front.z*40):game.camera.worldPosition
            let options:[String:Any]=[SCNHitTestOption.backFaceCulling.rawValue:false,SCNHitTestOption.searchMode.rawValue:SCNHitTestSearchMode.all.rawValue,SCNHitTestOption.ignoreHiddenNodes.rawValue:true]
            // Flattened clones can report their detached source node. Querying decor explicitly
            // establishes map ownership without guessing from that source node's parent chain.
            let mapHits=game.decor.hitTestWithSegment(from:game.decor.convertPosition(from,from:nil),to:game.decor.convertPosition(target,from:nil),options:options)
            if mapHits.contains(where:{obstructs($0,staticMap:true)}) {return count+1}
            let hits=game.scene.rootNode.hitTestWithSegment(from:from,to:target,options:options)
            return count+(hits.contains(where:{obstructs($0)}) ? 1:0)
        }
    }
}
