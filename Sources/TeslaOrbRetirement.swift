import Foundation

enum TeslaOrbRetirementRules {
    static let stagger=0.5,deletionWait=2.0,launchMultiplier=10.0
    // Own cosmetic physics. Native PhysicsLaunch mass, impulse and collision data are unavailable.
    static let gravity=9.8,restitution=0.32,radius=0.12,physicsStep=1.0/120
}

struct FlyingOrb {
    let id:Int,offset:V2,launchAt:Double,deleteAt:Double
    var p:V2,height:Double,v:V2 = .zero,verticalSpeed=0.0
    var launched=false,ttl:Double
}

/// Per-owner cleanup clock. Retired models have no damage triggers or random-number draws.
/// Every surviving slot gets a half-second wait, including the last one, then all delete together.
final class TeslaOrbRetirement {
    private(set) var clock=0.0,lastWorldClock=0.0
    private var previousParent:V2?,previousElevation=0.0

    func begin(_ orbs:[OrbShield],after delay:Double=0,parent:V2,elevation:Double,objects:inout [FlyingOrb]) {
        guard !orbs.isEmpty,delay.isFinite,delay>=0 else{return}
        if previousParent==nil {previousParent=parent;previousElevation=elevation}
        let start=clock+delay,deleteAt=start+Double(orbs.count)*TeslaOrbRetirementRules.stagger+TeslaOrbRetirementRules.deletionWait
        for (index,orb) in orbs.enumerated() {
            let launch=start+Double(index)*TeslaOrbRetirementRules.stagger
            var object=FlyingOrb(id:orb.id,offset:orb.p-parent,launchAt:launch,deleteAt:deleteAt,
                                 p:orb.p,height:elevation+TeslaRules.orbitHeight,ttl:deleteAt-clock)
            if launch<=clock+1e-10 {launchObject(&object,parent:parent,elevation:elevation)}
            objects.append(object)
        }
    }

    private func launchObject(_ orb:inout FlyingOrb,parent:V2,elevation:Double) {
        orb.p=parent+orb.offset;orb.height=elevation+TeslaRules.orbitHeight
        orb.v=orb.offset*TeslaOrbRetirementRules.launchMultiplier
        orb.verticalSpeed=TeslaRules.orbitHeight*TeslaOrbRetirementRules.launchMultiplier
        orb.launched=true
    }

    func relocateAttached(_ objects:inout [FlyingOrb],parent:V2,elevation:Double) {
        for i in objects.indices where !objects[i].launched {
            objects[i].p=parent+objects[i].offset;objects[i].height=elevation+TeslaRules.orbitHeight
        }
        previousParent=parent;previousElevation=elevation
    }

    func advance(_ dt:Double,at worldClock:Double?=nil,objects:inout [FlyingOrb],parent:V2,elevation:Double,
                 floor:(V2)->Double?,clear:(V2,V2,Double)->Bool) {
        guard dt.isFinite,dt>=0,worldClock?.isFinite != false else{return}
        if let worldClock,worldClock<lastWorldClock {return}
        let used=worldClock.map{min(dt,max(0,$0-lastWorldClock))} ?? dt
        if let worldClock {lastWorldClock=worldClock}
        guard used>0 else{return}
        let end=clock+used,oldParent=previousParent ?? parent,oldElevation=previousParent==nil ? elevation:previousElevation
        for i in objects.indices {
            var orb=objects[i]
            if !orb.launched {
                if orb.launchAt<=end+1e-10 {
                    let fraction=max(0,min(1,(orb.launchAt-clock)/used))
                    launchObject(&orb,parent:oldParent+(parent-oldParent)*fraction,
                                 elevation:oldElevation+(elevation-oldElevation)*fraction)
                }else {orb.p=parent+orb.offset;orb.height=elevation+TeslaRules.orbitHeight}
            }
            var remaining=orb.launched ? max(0,min(end,orb.deleteAt)-max(clock,orb.launchAt)):0
            while remaining>1e-10 {
                let step=min(remaining,TeslaOrbRetirementRules.physicsStep)
                let next=orb.p+orb.v*step
                let nextHeight=orb.height+orb.verticalSpeed*step-0.5*TeslaOrbRetirementRules.gravity*step*step
                if clear(orb.p,next,min(orb.height,nextHeight)) {orb.p=next}
                else {orb.v = .zero} // Own cosmetic collision stop; never applies a hit or awards points.
                orb.height=nextHeight;orb.verticalSpeed-=TeslaOrbRetirementRules.gravity*step
                if let ground=floor(orb.p),orb.height<ground+TeslaOrbRetirementRules.radius {
                    orb.height=ground+TeslaOrbRetirementRules.radius
                    orb.verticalSpeed=abs(orb.verticalSpeed)>0.45 ? abs(orb.verticalSpeed)*TeslaOrbRetirementRules.restitution:0
                    orb.v=orb.v*0.78
                }
                remaining-=step
            }
            orb.ttl=max(0,orb.deleteAt-end);objects[i]=orb
        }
        objects.removeAll{$0.deleteAt<=end+1e-9}
        clock=end;previousParent=parent;previousElevation=elevation
    }
}
