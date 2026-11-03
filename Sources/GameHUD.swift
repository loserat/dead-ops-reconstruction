import Foundation
import SceneKit
import SpriteKit

/// Retain the exact rounded path until its geometry changes. Render-thread only.
final class HUDRoundedShape:SKShapeNode {
    private var roundedRect:CGRect?
    private var roundedCorner:CGFloat?
    func setRoundedRect(_ rect:CGRect,corner:CGFloat) {
        guard roundedRect != rect || roundedCorner != corner || path == nil else{return}
        path=CGPath(roundedRect:rect,cornerWidth:corner,cornerHeight:corner,transform:nil)
        roundedRect=rect;roundedCorner=corner
    }
}

/// Assign unchanged label appearance once; SpriteKit otherwise may rebuild glyphs.
/// Read the actual node properties so state/owner changes still apply immediately.
enum HUDLabelStyle {
    static func color(_ label:SKLabelNode,_ value:GameColor) {if label.fontColor != value {label.fontColor=value}}
    static func size(_ label:SKLabelNode,_ value:CGFloat) {if label.fontSize != value {label.fontSize=value}}
    static func alignment(_ label:SKLabelNode,_ value:SKLabelHorizontalAlignmentMode) {if label.horizontalAlignmentMode != value {label.horizontalAlignmentMode=value}}
}

enum HUDNumbers {
    static func points(_ value:Int)->String {
        let raw=String(value),negative=raw.hasPrefix("-"),digits=negative ? String(raw.dropFirst()):raw
        var out=""
        for (i,c) in digits.reversed().enumerated() {if i>0 && i%3==0 {out.append(".")};out.append(c)}
        return (negative ? "−":"")+String(out.reversed())
    }
}
extension ArcadeGame {
    private func hudGlyph(_ kind:Int)->SKNode {
        let node=SKNode();node.name=["hud-life-icon","hud-bomb-icon","hud-boost-icon"][kind]
        func shape(_ path:CGPath)->SKShapeNode {let n=SKShapeNode(path:path);n.fillColor=rgb(0xcad7e5);n.lineWidth=0;node.addChild(n);return n}
        if kind==0 {
            _=shape(CGPath(ellipseIn:CGRect(x:-3.7,y:1,width:7.4,height:7.4),transform:nil))
            _=shape(CGPath(roundedRect:CGRect(x:-5.5,y:-8,width:11,height:8),cornerWidth:3,cornerHeight:3,transform:nil))
        }else if kind==1 {
            _=shape(CGPath(ellipseIn:CGRect(x:-5.3,y:-6,width:10.6,height:10.6),transform:nil))
            let fuse=CGMutablePath();fuse.move(to:CGPoint(x:2,y:4));fuse.addLine(to:CGPoint(x:5,y:8));fuse.addLine(to:CGPoint(x:8,y:8))
            let line=SKShapeNode(path:fuse);line.strokeColor=rgb(0xffcf86);line.lineWidth=1.7;node.addChild(line)
        }else {
            let bolt=CGMutablePath();bolt.move(to:CGPoint(x:1,y:9));bolt.addLine(to:CGPoint(x:-6,y:-1));bolt.addLine(to:CGPoint(x:-1,y:-1));bolt.addLine(to:CGPoint(x:-3,y:-9));bolt.addLine(to:CGPoint(x:7,y:2));bolt.addLine(to:CGPoint(x:2,y:2));bolt.closeSubpath();_=shape(bolt)
        }
        return node
    }
    func buildRefinedHUD() {
        for node in [roundBackdrop,noticeBackdrop] {node.zPosition=1.5;node.fillColor=rgb(0x101c2a,0.91);node.strokeColor=rgb(0xffffff,0.10);node.lineWidth=1;hudCanvas.addChild(node)}
        let round=PlayHUDLayout.roundRect
        roundBackdrop.path=CGPath(roundedRect:CGRect(x:-round.width/2,y:-round.height/2,width:round.width,height:round.height),cornerWidth:13,cornerHeight:13,transform:nil)
        roundBackdrop.position=CGPoint(x:round.midX,y:round.midY)
        notice.fontName="AvenirNext-DemiBold";notice.fontSize=18;notice.numberOfLines=2;notice.preferredMaxLayoutWidth=1060;notice.zPosition=2
        roundLabel.fontName="AvenirNext-DemiBold";roundLabel.zPosition=2
        pickupHintLabel.fontName="AvenirNext-DemiBold"
    }
    @discardableResult private func hudText(_ label:SKLabelNode,_ value:String?)->Bool {guard label.text != value else{return false};label.text=value;return true}
    private func buildPlayerCard(_ art:PlayerArtState) {
        let background=SKShapeNode(rect:CGRect(x:0,y:0,width:PlayHUDLayout.cardWidth,height:PlayHUDLayout.cardHeight),cornerRadius:13)
        background.lineWidth=1;background.fillColor=rgb(0x101c2a,0.93);background.strokeColor=rgb(0xffffff,0.13);art.tile.addChild(background);art.tileBackground=background
        let accent=SKShapeNode(rect:CGRect(x:0,y:16,width:3,height:88),cornerRadius:1.5);accent.name="owner-accent";accent.lineWidth=0;art.tile.addChild(accent)
        let track=SKShapeNode(rect:CGRect(x:12,y:43,width:260,height:3),cornerRadius:1.5);track.fillColor=rgb(0x344657);track.lineWidth=0;art.tile.addChild(track)
        let meter=HUDRoundedShape();meter.lineWidth=0;meter.position=CGPoint(x:12,y:43);art.tile.addChild(meter);art.tileMeter=meter
        for (index,y) in [98.0,96,5,28,16].enumerated() {
            let label=SKLabelNode(fontNamed:index==1 ? "Menlo-Bold":"AvenirNext-DemiBold")
            label.fontSize=index==0 ? 13:index==1 ? 17:index==2 ? 10:11
            label.horizontalAlignmentMode=index==1 ? .right:.left;label.position=CGPoint(x:index==1 ? 268:12,y:y);art.tile.addChild(label);art.tileLabels.append(label)
        }
        for i in 0..<3 {
            let x=20+Double(i)*88,glyph=hudGlyph(i);glyph.position=CGPoint(x:x,y:76);art.tile.addChild(glyph)
            let value=SKLabelNode(fontNamed:"AvenirNext-Bold");value.horizontalAlignmentMode = .left;value.fontSize=25;value.position=CGPoint(x:x+14,y:66);art.tile.addChild(value);art.hudCounters.append(value)
            let caption=SKLabelNode(fontNamed:"AvenirNext-Medium");caption.horizontalAlignmentMode = .left;caption.fontSize=9;caption.fontColor=rgb(0x91a6ba);caption.position=CGPoint(x:x-6,y:53);art.tile.addChild(caption);art.hudCounterTitles.append(caption)
        }
    }
    func syncRefinedHUD() {
        let multiple=core.playerCount>1,ending=core.phase == .gameOver && core.gameOverSequence != nil,hidden=menu.visible(core.phase) || ending || core.loopReturn != nil
        if teamHUD.parent==nil {teamHUD.zPosition=2;hudCanvas.addChild(teamHUD)}
        teamHUD.isHidden=hidden
        readabilityHUD.isHidden=true
        for node in [stat,score,weaponLabel,fateLabel,nextLifeLabel,supportLabel,vehicleLabel,multiplierFill] {node.isHidden=true}
        roundBackdrop.isHidden=hidden || multiple;roundLabel.isHidden=hidden
        HUDLabelStyle.size(roundLabel,multiple ? 13:14);roundLabel.position=CGPoint(x:multiple ? 64:1240,y:multiple ? 64:669);HUDLabelStyle.alignment(roundLabel,multiple ? .left:.right)
        pickupHintLabel.position=CGPoint(x:multiple ? 64:24,y:multiple ? 32:28)
        if notice.text == "LEBENSSTATUE IM ANFLUG" {
            let rewards=core.visibleRewardBundles.filter{$0.reward.personalLife}
            notice.text=rewards.isEmpty ? "LEBENSSTATUE VERDIENT":rewards.contains{!$0.reward.landed} ? "LEBENSSTATUE IM ANFLUG":"LEBENSSTATUE BEREIT"
        }
        notice.position=CGPoint(x:640,y:multiple ? 96:64)
        let bossIntroVisible=core.bossArrivalClock.map{$0.clock>=0.1 && $0.clock<5.1} ?? false
        notice.isHidden=hidden || bossIntroVisible || core.bossVictory != nil
        noticeBackdrop.isHidden=hidden || bossIntroVisible || core.bossVictory != nil || (notice.text ?? "").isEmpty
        noticeBackdrop.position=CGPoint(x:640,y:notice.position.y+7)
        noticeBackdrop.setRoundedRect(CGRect(x:-min(1120,max(160,notice.frame.width+32))/2,y:-15,width:min(1120,max(160,notice.frame.width+32)),height:max(36,notice.frame.height+16)),corner:12)
        bossHUD.position.y=multiple ? -130:-72
        for player in core.players {core.withPlayer(player.slot){
            let art=activeArt
            if art.tile.parent==nil {teamHUD.addChild(art.tile)}
            if art.tileBackground==nil {buildPlayerCard(art)}
            art.tile.position=CGPoint(x:PlayHUDLayout.cardX(slot:player.slot,players:core.playerCount),y:PlayHUDLayout.cardY)
            if let accent=art.tile.childNode(withName:"owner-accent") as? SKShapeNode {accent.fillColor=rgb(selectedPlayerColor.tint)}
            (art.tileMeter as? HUDRoundedShape)?.setRoundedRect(CGRect(x:0,y:0,width:260*core.multiplierFill,height:3),corner:1.5)
            art.tileMeter?.fillColor=rgb(core.multiplier>=9 ? 0xffd77e:selectedPlayerColor.tint)
            let incoming=core.incomingTransfer(to:player.slot),waiting=player.isDown ? (incoming != nil ? " · GABE":" · \(Int(ceil(player.recoverySeconds)))s"):""
            let headerChanged=hudText(art.tileLabels[0],"P\(player.slot+1)"+(multiple ? " · "+selectedPlayerColor.title.uppercased():" · SPIELER")+waiting)
            let scoreChanged=hudText(art.tileLabels[1],HUDNumbers.points(core.score)+"  ×\(core.multiplier)")
            if scoreChanged {
                art.tileLabels[1].fontSize=17
                while art.tileLabels[1].frame.width>164 && art.tileLabels[1].fontSize>8.5 {art.tileLabels[1].fontSize-=0.5}
            }
            if headerChanged || scoreChanged {
                art.tileLabels[0].fontSize=13
                let width=min(110,max(40,art.tileLabels[1].frame.minX-20))
                while art.tileLabels[0].frame.width>width && art.tileLabels[0].fontSize>9 {art.tileLabels[0].fontSize-=0.5}
            }
            HUDLabelStyle.color(art.tileLabels[0],rgb(selectedPlayerColor.tint));HUDLabelStyle.color(art.tileLabels[1],rgb(0xf1f5f9))
            if hudText(art.hudCounters[0],player.isDown ? String(Int(ceil(player.recoverySeconds)))+"s":String(core.displayedLives)) {
                art.hudCounters[0].fontSize=25
                while art.hudCounters[0].frame.width>64 && art.hudCounters[0].fontSize>12 {art.hudCounters[0].fontSize-=0.5}
            }
            HUDLabelStyle.color(art.hudCounters[0],rgb(player.isDown ? 0xffce91:selectedPlayerColor.tint))
            hudText(art.hudCounters[1],String(core.bombs));hudText(art.hudCounters[2],String(core.dashes))
            for label in art.hudCounters.dropFirst() {HUDLabelStyle.color(label,rgb(0xf1f5f9))}
            hudText(art.hudCounterTitles[0],player.isDown ? "RÜCKKEHR":core.godMode ? "LEBEN · ÜBUNG":"LEBEN")
            hudText(art.hudCounterTitles[1],"BOMBEN");hudText(art.hudCounterTitles[2],"BOOSTS")
            let recovery=incoming.map{"LEBENSGABE VON P\($0.donor+1) · UNTERWEGS"} ?? (player.respawnRemaining != nil ? "RÜCKKEHR LÄUFT · RESERVE \(player.lives)":"WIEDERKEHR · TEAM MUSS ÜBERLEBEN")
            let nextLife=core.pointsUntilLife==0 ? "WEITERE PUNKTE: EXTRA-LEBEN":"EXTRA-LEBEN IN "+HUDNumbers.points(core.pointsUntilLife)+" P"
            let lifeStatus=core.scoreLifeStatus(for:player.slot) ?? (core.canGainDisplayedLife ? nextLife:"LEBEN VOLL · 9")
            hudText(art.tileLabels[2],player.isDown ? recovery:lifeStatus)
            HUDLabelStyle.color(art.tileLabels[2],rgb(player.isDown ? 0xffce91:0x91a6ba))
            let gun=WeaponProfile.forPickup(core.activeWeapon).title
            hudText(art.tileLabels[3],core.vehicle != nil ? vehicleLabel.text:gun+(core.weapon == nil ? " · ∞":" · \(Int(ceil(core.weaponReserve/5)))s"))
            let power=(supportLabel.text ?? "").replacingOccurrences(of:"\n",with:" · ").replacingOccurrences(of:"     ",with:" · ")
            let detail=core.fate.map{$0.title+(player.fatePending ? " KOMMT":"")+" · "+power} ?? (player.missedFate ? "SCHICKSAL VERPASST · "+power:power)
            let injury=core.playerWoundText+(core.woundRecoveryActive ? " · ERHOLUNG":"")
            hudText(art.tileLabels[4],String((injury.isEmpty ? detail:injury+(detail.isEmpty ? "":" · "+detail)).prefix(35)))
            HUDLabelStyle.color(art.tileLabels[3],rgb(0xdce6ef));HUDLabelStyle.color(art.tileLabels[4],rgb(core.hasPlayerWounds ? 0xffb3a0:0xa9b9c9))
        }}
    }
}
