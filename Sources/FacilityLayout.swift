import Foundation

enum FacilityLayout {
    static let tanks=[V2(x:2,y:-1),V2(x:6,y:-1)]
    static let traps=[V2(x:-6.5,y:-3.8),V2(x:-6.5,y:3.8),V2(x:8.5,y:-5),V2(x:8.5,y:5)]
    static let piles=[V2(x:-7,y:-1),V2(x:-3,y:4),V2(x:2,y:4),V2(x:8.8,y:2.8)]
    static let obstacles=tanks.map{ArenaObstacle($0,half:V2(x:1.15,y:2.75),height:2.5)}
}
extension Foe {
    var hitRadius:Double {kind == .martyr ? 0.62:kind == .sasquatch ? 0.52:0.43}
    var hitHeight:Double {kind == .martyr || kind == .sasquatch ? 1.95:1.3}
    var contactRadius:Double {kind == .martyr ? 0.73:kind == .sasquatch ? 0.63:0.52}
}
extension GameCore {
    func detonateMartyr(_ foe:Foe,canDamageHero:Bool=true) {
        emitAudio(.explosion)
        effects.append(Effect(id:id(),p:foe.p,ttl:0.65,size:4.5,color:4,height:foe.elevation+0.6))
        if canDamageHero {forEachLivingPlayer{
            let distance=hypot((hero-foe.p).length,heroElevation-foe.elevation)
            if distance<BlastSource.martyr.profile.outer && layout.lineClear(foe.p,hero,clearance:0.02) {queueBlast(.martyr,distance:distance)}
        }}
        for boss in silverbacks where boss.hp>0 && (boss.p-foe.p).length<3 && layout.lineClear(foe.p,boss.p,clearance:0.02) {damageSilverback(60,id:boss.id)}
        for i in foes.indices where foes[i].hp>0 && hypot((foes[i].p-foe.p).length,foes[i].elevation-foe.elevation)<3 && layout.lineClear(foe.p,foes[i].p,clearance:0.02) {foes[i].hp=0;foes[i].creditSlot=foe.environmentKill ? nil:activePlayerSlot;foes[i].environmentKill=foe.environmentKill}
    }
    func resolveDefeatedFoes() {
        // Remove before exploding; chained martyrs cannot recursively score the same body twice.
        while let i=foes.firstIndex(where:{$0.hp<=0}) {let foe=foes.remove(at:i);kill(foe)}
    }
    func resolveMartyrDamage() {resolveDeferredBlasts()}
}
