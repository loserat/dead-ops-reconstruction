import Foundation

extension GameCore {
    func teslaTarget(_ f:Foe)->TeslaTarget {
        let low=f.kind == .hound || f.kind == .crawler
        return TeslaTarget(id:f.id,p:f.p,headHeight:f.elevation+(low ? 0.48:f.hitHeight*0.9),spineHeight:f.elevation+(low ? 0.34:f.hitHeight*0.55),alive:f.hp>0,boss:false,marked:f.teslaMarked)
    }
    func teslaTarget(_ boss:Silverback)->TeslaTarget {
        TeslaTarget(id:boss.id,p:boss.p,headHeight:boss.entryElevation+2.8,spineHeight:boss.entryElevation+1.6,alive:boss.hp>0,boss:true,marked:boss.teslaMarked)
    }
    func teslaTarget(_ raider:TreasureRaider)->TeslaTarget {
        TeslaTarget(id:raider.id,p:raider.p,headHeight:raider.elevation+2.8,spineHeight:raider.elevation+1.6,boss:true,marked:raider.teslaMarked)
    }
    func teslaTargets()->[TeslaTarget] {
        foes.filter{$0.hp>0}.map{teslaTarget($0)}+silverbacks.filter{$0.hp>0}.map{teslaTarget($0)}+(treasureRaider.map{[teslaTarget($0)]} ?? [])
    }
    func teslaLookup(_ id:Int)->TeslaTarget? {
        if let f=foes.first(where:{$0.id==id}) {return teslaTarget(f)}
        if let b=silverbacks.first(where:{$0.id==id}) {return teslaTarget(b)}
        if let r=treasureRaider,r.id==id {return teslaTarget(r)}
        return nil
    }
    func markTeslaTarget(_ id:Int,_ value:Bool) {
        if let i=foes.firstIndex(where:{$0.id==id}) {foes[i].teslaMarked=value}
        else if let i=silverbacks.firstIndex(where:{$0.id==id}) {silverbacks[i].teslaMarked=value}
        else if treasureRaider?.id==id {treasureRaider?.teslaMarked=value}
    }
    func stepRetiringOrbs(_ dt:Double,at worldClock:Double?=nil) {
        forEachPlayer {
            let retiringOwner=playerRoster.current
            retiringOwner.orbRetirement.advance(dt,at:worldClock,objects:&retiringOwner.flyingOrbs,parent:hero,elevation:heroElevation,
                floor:{self.layout.contains($0,margin:0) ? self.layout.height($0):nil},
                clear:{self.projectileClear(from:$0,to:$1,height:$2)})
        }
    }
    func stepTesla(_ dt:Double,at worldClock:Double?=nil) {
        guard dt.isFinite,dt>=0,worldClock?.isFinite != false else{return}
        stepRetiringOrbs(dt,at:worldClock)
        forEachPlayer {
            if playerRoster.current.isDown {electricArcs=electricArcs.compactMap{var a=$0;a.ttl-=dt;return a.ttl>0 ? a:nil}}
            let owner=activePlayerSlot,state=playerRoster.current.tesla
            let used=worldClock.map{min(max(0,dt),max(0,$0-state.lastWorldClock))} ?? max(0,dt)
            let end=state.clock+used
            state.advance(dt,at:worldClock,targets:{self.teslaTargets()},lookup:{self.teslaLookup($0)},mark:{self.markTeslaTarget($0,$1)},visible:{a,b in self.exitPulseClear(from:a.p,height:a.headHeight,to:b.p,targetHeight:b.headHeight)},random:{self.random()}) {event in
                switch event {
                case .arc(let from,let to,let time):
                    let remaining=TeslaRules.travel-max(0,end-time)
                    if remaining>0 {
                        self.electricArcs.append(ElectricArc(id:self.id(),a:from.p,b:to.p,ttl:remaining,aHeight:from.spineHeight,bHeight:to.spineHeight,travelDuration:TeslaRules.travel))
                    }
                    self.emitAudio(.hazardZap,at:from.p)
                case .kill(let id,_,let time):
                    guard let i=self.foes.firstIndex(where:{$0.id==id && $0.hp>0}) else{return}
                    self.foes[i].hp=0;self.foes[i].creditSlot=owner;self.foes[i].environmentKill=false
                    let remaining=0.24-max(0,end-time)
                    if remaining>0 {self.effects.append(Effect(id:self.id(),p:self.foes[i].p,ttl:remaining,size:0.58,color:3,height:self.foes[i].elevation+self.foes[i].hitHeight*0.55))}
                    self.emitAudio(.hazardZap,at:self.foes[i].p)
                }
            }
        }
    }
    func clearTeslaTargets(){forEachPlayer{playerRoster.current.tesla.clearTargets();electricArcs=[]}}
    /// A retained damagedby="tesla" also routes later ape damage through its script handler.
    /// Boss initialization only consumes the attacker's gate; it never starts an ordinary chain.
    func notifyTeslaBossDamage(_ id:Int) {
        guard let boss=silverbacks.first(where:{$0.id==id && $0.teslaContacted}),let target=teslaLookup(boss.id) else{return}
        playerRoster.current.tesla.begin(target,mark:{self.markTeslaTarget($0,$1)})
    }
    func resolveTeslaOrbContacts(bossesOnly:Bool=false) {
        guard weaponsEnabled,playerRoster.current.tesla.ready else{return}
        var consumed=Set<Int>()
        for orb in orbShields {
            guard playerRoster.current.tesla.ready else{break}
            let bottom=heroElevation+TeslaRules.orbitHeight,top=bottom+TeslaRules.triggerHeight
            var contacts:[(target:TeslaTarget,distance:Double)]=[]
            if !bossesOnly {
                for f in foes where f.hp>0 && !f.teslaContacted && bottom<=f.elevation+f.hitHeight && top>=f.elevation {
                    let d=f.p.distance(toSegmentFrom:orb.previousP,to:orb.p)
                    if d<TeslaRules.triggerRadius+f.hitRadius {contacts.append((teslaTarget(f),(f.p-orb.p).length))}
                }
            }
            for b in silverbacks where b.hp>0 && !b.teslaContacted && bottom<=b.entryElevation+3.1 && top>=b.entryElevation {
                let d=b.p.distance(toSegmentFrom:orb.previousP,to:orb.p)
                if d<TeslaRules.triggerRadius+1.15 {contacts.append((teslaTarget(b),(b.p-orb.p).length))}
            }
            if let r=treasureRaider,!r.teslaContacted,bottom<=r.elevation+3.1,top>=r.elevation,r.p.distance(toSegmentFrom:orb.previousP,to:orb.p)<TeslaRules.triggerRadius+1.15 {
                contacts.append((teslaTarget(r),(r.p-orb.p).length))
            }
            // The native trigger callback order is unavailable; own simultaneous contacts use distance, then ID.
            guard let hit=contacts.min(by:{abs($0.distance-$1.distance)<1e-9 ? $0.target.id<$1.target.id:$0.distance<$1.distance})?.target else{continue}
            consumed.insert(orb.id)
            if let i=foes.firstIndex(where:{$0.id==hit.id}) {
                let f=foes[i]
                if f.referenceVitality==nil {foes[i].referenceVitality=ReferenceVitality.foe(f.kind,round:round,mini:false,localMaximum:max(f.hp,RoundRules.health(f.kind,round:round)))}
                foes[i].teslaContacted=true
                foes[i].hp-=foes[i].referenceVitality!.damageScale
                foes[i].creditSlot=activePlayerSlot;foes[i].environmentKill=false
            }else if let i=silverbacks.firstIndex(where:{$0.id==hit.id}) {
                silverbacks[i].teslaContacted=true
                damageSilverback(Silverback.maxHP/(500000*Double(max(1,playerCount))),id:hit.id)
            }else if treasureRaider?.id==hit.id {
                treasureRaider?.teslaContacted=true;registerRaiderHit(1,id:hit.id)
            }
            // A sibling already reserved by another chain still consumes one orb/raw1 contact,
            // but tesla_damage_init returns before closing this player's gate.
            playerRoster.current.tesla.begin(hit,mark:{self.markTeslaTarget($0,$1)})
            effects.append(Effect(id:id(),p:hit.p,ttl:0.20,size:0.4,color:3,height:hit.headHeight))
            emitAudio(.hazardZap,at:hit.p)
        }
        orbShields.removeAll{consumed.contains($0.id)}
        if orbShields.isEmpty {orbRemaining=0}
    }
}
