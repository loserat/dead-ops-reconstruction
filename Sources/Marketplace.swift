import Foundation

/// Measured-looking dimensions are provisional, based on the sampled reference views.
enum MarketplaceLayout {
    static let traps=[V2(x:-5.8,y:-3.1),V2(x:5.8,y:-3.1),V2(x:-5.8,y:3.1),V2(x:5.8,y:3.1)]
    static let crates=[V2(x:-10,y:-3.8),V2(x:10,y:-3.8),V2(x:-10,y:3.8),V2(x:10,y:3.8)]
    static let obstacles=crates.map{ArenaObstacle($0,half:V2(x:0.6,y:0.65),height:0.9)}
}
struct Bull {
    let id:Int
    var p:V2, direction:V2
    var speed=9.0,gait=0.0
    var golden=false
    var age=0.0
    var destination:V2?=nil
    var voice=HerdVoiceTimeline(),audioContacts=Set<Int>()
    /// A capsule tracks the body rather than using a large invisible circle.
    func contains(_ point:V2,margin:Double=0)->Bool {
        let rel=point-p,along=max(-0.58,min(0.58,rel.x*direction.x+rel.y*direction.y))
        return (rel-direction*along).length<0.40+margin
    }
}
extension V2 {
    func distance(toSegmentFrom start:V2,to end:V2)->Double {
        let line=end-start,rel=self-start,denom=line.x*line.x+line.y*line.y
        let t=denom>0 ? max(0,min(1,(rel.x*line.x+rel.y*line.y)/denom)):0
        return (self-(start+line*t)).length
    }
}
extension GameCore {
    func prepareStampede() {
        stampede=nil
        guard layout.kind == .marketplace else{return}
        if round==17 {stampede=StampedeDirector(mode:.challenge)}
        else if stageRound != 17 {stampede=StampedeDirector(mode:.normal)}
        // Later laps do not repeat the absolute round-17 challenge. Normal source traffic
        // begins on the following factory exit, rather than the first entry from the temple.
    }
    func stepStampede(_ dt:Double) {
        guard layout.kind == .marketplace,phase == .playing || phase == .cleared,dt.isFinite,dt>=0 else{return}
        var birthAges=[Int:Double]()
        if var flow=stampede {
            let events=flow.step(dt,openSides:Set(phase == .cleared ? availableExits.compactMap(\.side):[]),random:{self.random()})
            stampede=flow
            for e in events {
                let a=layout.enemyArrival(index:layout.entrance(on:e.side,roll:e.spawnRoll)).start.p
                let z=layout.enemyArrival(index:layout.entrance(on:e.side.opposite,roll:e.destinationRoll)).start.p
                let delta=z-a,id=id()
                bulls.append(Bull(id:id,p:a,direction:delta.unit,speed:delta.length/10,golden:e.golden,age:-e.activationDelay,destination:z))
                birthAges[id]=max(0,flow.clock-e.clock)
            }
        }
        moveStampedeBulls(dt,birthAges:birthAges)
    }
    func moveStampedeBulls(_ dt:Double,birthAges:[Int:Double]=[:],contacts:Bool=true) {
        for i in bulls.indices {
            let used=birthAges[bulls[i].id] ?? dt,oldAge=bulls[i].age
            bulls[i].age+=used
            let motion=max(0,min(10,bulls[i].age)-max(0,oldAge))
            let start=bulls[i].p,end=start+bulls[i].direction*(bulls[i].speed*motion)
            bulls[i].p=end;bulls[i].gait+=motion*bulls[i].speed*2.4
            if contacts {
                let roars=bulls[i].voice.roars(through:bulls[i].age,id:bulls[i].id)
                for _ in roars {emitAudio(.bullRoar,at:bulls[i].p)}
            }
            guard contacts,bulls[i].age>=0 else{continue}
            // Sweep the actual model body so even large synthetic frames cannot skip a contact.
            let tail=bulls[i].direction*0.58
            forEachLivingPlayer {if heroElevation<1.4 && hero.distance(toSegmentFrom:start-tail,to:end+tail)<0.67 {
                if bulls[i].audioContacts.insert(-activePlayerSlot-1).inserted {emitAudio(.bullImpact,at:hero)}
                loseLife()
            }}
            for j in foes.indices where foes[j].hp>0 && foes[j].elevation<1.4 {
                if foes[j].p.distance(toSegmentFrom:start-tail,to:end+tail)<0.69 {
                    if bulls[i].audioContacts.insert(foes[j].id).inserted {emitAudio(.bullImpact,at:foes[j].p)}
                    foes[j].hp=0;foes[j].environmentKill=true;foes[j].creditSlot=nil}
            }
        }
        bulls.removeAll { bull in
            if bull.destination != nil {return bull.age+1e-9>=10}
            return bull.age+1e-9>=10 || (bull.direction.x>0 && bull.p.x>14) || (bull.direction.x<0 && bull.p.x < -14) ||
            (bull.direction.y>0 && bull.p.y>10) || (bull.direction.y<0 && bull.p.y < -10)
        }
    }
    func stepStampedeTransition(_ dt:Double,transit:ArenaTransit) {
        if transit.committed {
            if stampede?.mode == .normal,sideRoom==nil {stepStampedeLeadIn(dt)}
        }else {
            let beforeBlack=max(0,transit.debounce+1-transit.clock)
            moveStampedeBulls(min(dt,beforeBlack),contacts:false)
            if dt+1e-9>=beforeBlack {bulls=[]}
        }
    }
    func stepStampedeLeadIn(_ dt:Double) {
        guard var flow=stampede else{return}
        _=flow.step(min(dt,flow.wait),random:{self.random()});stampede=flow
    }
    func explodeBulls(at p:V2,radius:Double) {
        let destroyed=bulls.filter{($0.p-p).length<radius+0.75}
        bulls.removeAll{($0.p-p).length<radius+0.75}
        for bull in destroyed {
            effects.append(Effect(id:id(),p:bull.p,ttl:0.5,size:1.7,color:2));emitAudio(.explosion)
            if bull.golden {
                emitAudio(.goldenBull)
                sourceLoot?.queueGoldenBull(at:bull.p,random:{self.random()})
                stepWorldLoot(0)
            }
        }
    }
    func bullHit(from start:V2,to end:V2,height:Double)->V2? {
        guard height>=0.15,height<=1.7 else{return nil}
        let segments=max(1,Int(ceil((end-start).length/0.12)))
        for i in 0...segments {
            let p=start+(end-start)*(Double(i)/Double(segments))
            if bulls.contains(where:{$0.contains(p,margin:0.035)}) {return p}
        }
        return nil
    }
}
