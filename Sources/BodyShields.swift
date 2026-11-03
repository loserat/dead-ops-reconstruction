import Foundation

/// Archived script waits. 100 source units per own world unit remains provisional.
struct BodyShield {
    static let contactDelay=0.05,radius=0.65,heightTolerance=0.5
    var age=0.0
    let duration:Double
    var remaining:Double {max(0,duration-age)}
    var contactActive:Bool {age>=Self.contactDelay && remaining>0}
    var fading:Bool {remaining<=3}
}
extension GameCore {
    var damageProtected:Bool {invulnerable>0 || boostProtected || (playerRoster.current.bodyShield?.remaining ?? 0)>0}
    func beginBodyShield(short:Bool=false,startsAfter:Double=0) {
        let player=playerRoster.current,duration=short ? RecoveryRules.shortShield:RecoveryRules.fullShield
        let delay=startsAfter.isFinite ? max(0,startsAfter):0
        // Own overlap policy: a short donation shield never cuts an existing full shield short.
        if let current=player.bodyShield,current.remaining-delay>=duration {return}
        let mature=player.bodyShield.flatMap{$0.remaining>delay ? $0.age+delay:nil} ?? 0
        let activationAge=max(0,min(BodyShield.contactDelay,mature))
        player.bodyShield=BodyShield(age:activationAge-delay,duration:duration+activationAge)
    }
    func advanceBodyShield(_ player:RunPlayer,_ dt:Double) {
        guard var shield=player.bodyShield else{return}
        let oldAge=shield.age;shield.age+=max(0,dt)
        if !player.isDown,player.vehicle==nil {
            if shield.duration-oldAge>3 && shield.remaining<=3 {emitAudio(.shieldWarning)}
            if shield.remaining<=1e-9 {emitAudio(.shieldEnd)}
        }
        if oldAge<shield.duration && shield.age>=BodyShield.contactDelay {player.shieldContactThisStep=true}
        player.bodyShield=shield.remaining>1e-9 ? shield:nil
    }
    func resolveBodyShieldContacts(from old:V2?=nil,oldHeight:Double?=nil) {
        guard isPlayerActive,playerRoster.current.shieldContactThisStep || playerRoster.current.bodyShield?.contactActive==true else{return}
        let start=old ?? hero,height=oldHeight ?? heroElevation
        for i in foes.indices where foes[i].hp>0 {
            if foes[i].p.distance(toSegmentFrom:start,to:hero)<BodyShield.radius &&
                abs(foes[i].elevation-(height+heroElevation)*0.5)<=BodyShield.heightTolerance {
                foes[i].hp=0;foes[i].creditSlot=activePlayerSlot;foes[i].launchedByContact=true
            }
        }
    }
    func moveShieldedFoot(_ dt:Double,move:V2) {
        let delta=move.unit*(dt*moveSpeed*min(1,move.length)),count=max(1,Int(ceil(delta.length/0.14)))
        for _ in 0..<count {
            let old=hero,height=heroElevation
            hero=layout.moved(hero,by:delta*(1/Double(count)));updateHeroElevation(dt/Double(count))
            resolveBodyShieldContacts(from:old,oldHeight:height)
        }
    }
    func resolveBoostContacts(from old:V2,to end:V2,oldHeight:Double,endHeight:Double) {
        guard boostProtected,isPlayerActive else{return}
        for i in foes.indices where foes[i].hp>0 && abs(foes[i].elevation-(oldHeight+endHeight)*0.5)<=0.5 {
            // Local forward trigger offsets follow current aim; launch velocity was captured separately.
            if [0.5,2.0].contains(where:{offset in foes[i].p.distance(toSegmentFrom:old+facing*offset,to:end+facing*offset)<0.85}) {
                foes[i].hp=0;foes[i].creditSlot=activePlayerSlot;foes[i].launchedByContact=true
            }
        }
    }
}
