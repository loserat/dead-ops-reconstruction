import Foundation
import SceneKit
import SpriteKit

extension ArcadeGame {
    func layoutHUD(_ requested:CGSize){
        let size=CGSize(width:max(1,requested.width),height:max(1,requested.height))
        guard hud.size.width != size.width || hud.size.height != size.height else{return}
        hud.size=size
        let factor=min(size.width/1280,size.height/720)
        hudCanvas.setScale(factor);hudCanvas.position=CGPoint(x:(size.width-1280*factor)/2,y:(size.height-720*factor)/2)
        curtain.path=CGPath(rect:CGRect(x:-size.width/(2*factor),y:-size.height/(2*factor),width:size.width/factor,height:size.height/factor),transform:nil)
    }
    func syncRoleBadge(){
        let art=activeArt,badge=activeArt.badge
        badge.isHidden=core.playerCount==1 || !(core.phase == .playing || core.phase == .cleared || core.phase == .bonusRoom || core.phase == .transition)
        guard !badge.isHidden else{return}
        if art.roleText==nil {
            let text=SCNText(string:"",extrusionDepth:0);text.font = .boldSystemFont(ofSize:0.38);text.flatness=0.1
            let mat=material(selectedPlayerColor.tint,glow:true);mat.lightingModel = .constant
            mat.readsFromDepthBuffer=false;mat.writesToDepthBuffer=false;text.materials=[mat]
            let node=SCNNode(geometry:text);node.position.x = -0.24;node.castsShadow=false;node.renderingOrder=31
            badge.addChildNode(node);badge.constraints=[SCNBillboardConstraint()];art.roleText=text
        }
        let giving=core.incomingTransfer(to:core.activePlayerSlot) != nil
        let value=core.isPlayerActive ? "P\(core.activePlayerSlot+1)":giving ? "P\(core.activePlayerSlot+1) · GABE":"P\(core.activePlayerSlot+1) · \(Int(ceil(core.playerRoster.current.recoverySeconds)))s"
        if art.badgeText != value {art.badgeText=value;art.roleText?.string=value}
        art.roleText?.firstMaterial?.diffuse.contents=rgb(selectedPlayerColor.tint)
        art.roleText?.firstMaterial?.emission.contents=rgb(selectedPlayerColor.tint)
        badge.position=SCNVector3(core.hero.x,core.heroElevation+(core.isPlayerActive ? 1.85:1.1),core.hero.y)
    }
    func syncTeamPickupPresentation(){
        if core.playerCount==1 {syncPickupPresentation();return}
        var owner:Int?,best=Double.infinity
        for player in core.livingPlayers {core.withPlayer(player.slot){
            if let item=PickupPresentation.hint(in:core,keeping:pickupHintID) {
                let distance=(item.p-core.hero).length
                if distance<best {best=distance;owner=player.slot}
            }
        }}
        guard let owner else {
            pickupHintID=nil;pickupHintLabel.isHidden=true
            for node in Array(pickupNodes.values)+Array(directedRewardNodes.values) {node.childNode(withName:"pickup-class-marker",recursively:false)?.opacity=0.65}
            return
        }
        core.withPlayer(owner){syncPickupPresentation()}
        if !pickupHintLabel.isHidden {pickupHintLabel.text="P\(owner+1) · "+(pickupHintLabel.text ?? "")}
    }
    func syncTeamHUD(){syncRefinedHUD()}
    var runScore:Int {core.players.reduce(0){$0+$1.score}}
    var teamScoreLine:String {core.players.map{"P\($0.slot+1): \($0.score)"}.joined(separator:" · ")}
}
