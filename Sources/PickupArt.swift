import Foundation
import SceneKit
import SpriteKit

extension ArcadeGame {
    func pickupClassMarker(_ kind:PickupKind)->SCNNode {
        let style=PickupPresentation.forKind(kind),count=style.category.markerCorners
        let root=SCNNode();root.name="pickup-class-marker"
        guard count>0 else{return root}
        let angle=style.category == .vehicle ? Double.pi/4:0.0
        var vertices=[SCNVector3](),indices=[Int32]()
        for i in 0..<count {
            let a=Double(i)*2*Double.pi/Double(count)+angle,b=Double(i+1)*2*Double.pi/Double(count)+angle,start=Int32(vertices.count)
            for (t,r) in [(a,0.59),(b,0.59),(a,0.545),(b,0.545)] {vertices.append(SCNVector3(cos(t)*r,0.08,sin(t)*r))}
            indices += [start,start+1,start+2,start+1,start+3,start+2]
        }
        let key="pickup-class-\(style.tint)",mat:SCNMaterial
        if let old=artMaterials[key] {mat=old}else{mat=material(style.tint);mat.lightingModel = .constant;mat.isDoubleSided=true;mat.writesToDepthBuffer=false;artMaterials[key]=mat}
        // The island uses an alpha shore mesh. Draw these transparent overlays after it,
        // while retaining depth reads so solid props and upper floors still occlude them.
        let outline=mesh(vertices,indices,mat:mat);outline.renderingOrder=20
        root.addChildNode(outline);root.castsShadow=false;root.opacity=0.65
        return root
    }
    func syncPickupPresentation() {
        let selected=PickupPresentation.hint(in:core,keeping:pickupHintID);pickupHintID=selected?.id
        for (id,node) in pickupNodes.merging(directedRewardNodes,uniquingKeysWith:{$1}) {
            guard let marker=node.childNode(withName:"pickup-class-marker",recursively:false) else{continue}
            let emphasized=id==pickupHintID
            marker.opacity=emphasized ? 1:0.65
            let s=emphasized ? 1.07+0.025*sin(core.elapsed*4):1
            marker.scale=SCNVector3(s,1,s)
        }
        guard let selected else{pickupHintLabel.isHidden=true;return}
        let bundle=core.visibleRewardBundles.first(where:{$0.reward.id==selected.id}),amount=bundle?.count ?? 1
        let warning=selected.expiryWarning ? " · LÄUFT AB":""
        let scope=selected.kind == .life ? (bundle?.reward.personalLife == true ? " · PERSÖNLICH":" · FÜR DAS TEAM"):""
        let style=PickupPresentation.forKind(selected.kind),text=(amount>1 ? "\(amount) × ":"")+"\(style.title) · \(style.category.title)"+scope+(selected.persistent ? " · BLEIBT LIEGEN":warning)
        if pickupHintLabel.text != text {pickupHintLabel.text=text;pickupHintLabel.fontColor=rgb(style.tint)}
        pickupHintLabel.isHidden=false
    }
}
