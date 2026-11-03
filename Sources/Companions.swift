import Foundation

struct ChickenCompanion {
    let id:Int
    var p:V2, facing:V2, ttl:Double, shotClock=0.0, flash=0.0,elevation=0.0,permanent=false
}
struct OrbShield {let id:Int;var angle:Double,p:V2,previousP:V2}
struct ElectricArc {let id:Int,a:V2,b:V2;var ttl:Double=0.18;var aHeight=0.7,bHeight=0.7,travelDuration=0.0
    var progress:Double {travelDuration>0 ? max(0,min(1,1-ttl/travelDuration)):1}
}

extension GameCore {
    func addChicken(duration:Double=40,permanent:Bool=false) {
        let p=layout.boundary(hero+V2(x:0.65,y:0.65),clearance:0.25)
        chickens.append(ChickenCompanion(id:id(),p:p,facing:facing,ttl:duration,elevation:heroElevation,permanent:permanent))
    }
    func grantOrbs(duration:Double=40) {
        retireOrbs()
        orbRemaining=duration;orbShields=[]
        for a in TeslaRules.initialAngles {
            let p=hero+V2(x:cos(a),y:sin(a))*TeslaRules.orbitRadius
            orbShields.append(OrbShield(id:id(),angle:a,p:p,previousP:p))
        }
    }
    func repositionCompanions() {
        repositionVehicleAfterTeleport();repositionShieldBarrels()
        for i in chickens.indices {chickens[i].p=layout.boundary(hero+chickenOffset(i),clearance:0.25);chickens[i].elevation=heroElevation}
        for i in orbShields.indices {
            let a=orbShields[i].angle,p=hero+V2(x:cos(a),y:sin(a))*TeslaRules.orbitRadius
            orbShields[i].p=p;orbShields[i].previousP=p
        }
        electricArcs=[]
        playerRoster.current.orbRetirement.relocateAttached(&flyingOrbs,parent:hero,elevation:heroElevation)
    }
    func chickenOffset(_ index:Int)->V2 {
        let side=index%2==0 ? 1.0:-1.0,row=Double(index/2)
        let back=facing * (-0.75-row*0.34),right=V2(x:-facing.y,y:facing.x)*(side*(0.72+row*0.12))
        return back+right
    }
    func updateCompanions(_ dt:Double,advanceTimers:Bool=true) {
        electricArcs=electricArcs.compactMap{var a=$0;a.ttl-=dt;return a.ttl>0 ? a:nil}
        for i in chickens.indices {
            if advanceTimers && !chickens[i].permanent {chickens[i].ttl=max(0,chickens[i].ttl-dt)}
            chickens[i].shotClock-=dt;chickens[i].flash=max(0,chickens[i].flash-dt)
            let target=layout.boundary(hero+chickenOffset(i),clearance:0.25)
            if (chickens[i].p-hero).length>4 {chickens[i].p=target}
            else {chickens[i].p=chickens[i].p+(target-chickens[i].p)*(1-exp(-9*dt))}
            chickens[i].elevation+=(heroElevation-chickens[i].elevation)*(1-exp(-12*dt))
            if chickens[i].ttl>2 {chickens[i].facing=facing}
        }
        chickens.removeAll{$0.ttl<=0}
        let remaining=orbRemaining,orbitStep=advanceTimers ? min(dt,max(0,remaining)):dt
        for i in orbShields.indices {
            orbShields[i].previousP=orbShields[i].p;orbShields[i].angle+=orbitStep*TeslaRules.angularSpeed
            let a=orbShields[i].angle
            orbShields[i].p=hero+V2(x:cos(a),y:sin(a))*TeslaRules.orbitRadius
        }
        if advanceTimers {orbRemaining=max(0,remaining-dt)}
        if orbRemaining<=0 && !orbShields.isEmpty {retireOrbs(after:max(0,min(dt,remaining)))}
    }
    func retireOrbs(after delay:Double=0) {
        let owner=playerRoster.current
        owner.orbRetirement.begin(orbShields,after:delay,parent:hero,elevation:heroElevation,objects:&owner.flyingOrbs)
        orbShields=[];orbRemaining=0
    }

    func fireChickens(playerFiring:Bool) {
        guard weaponsEnabled else{return}
        for i in chickens.indices {
            let departing=chickens[i].ttl<=2 && !chickens[i].permanent
            guard playerFiring || departing else{chickens[i].shotClock=max(0,chickens[i].shotClock);continue}
            var count=0
            while chickens[i].shotClock<=0 && count<64 {
                if departing {
                    let a=elapsed*20+Double(chickens[i].id)*0.7+Double(count)*0.2
                    chickens[i].facing=V2(x:cos(a),y:sin(a))
                }else{chickens[i].facing=facing}
                fireUsing(chickenWeapon,from:chickens[i].p,direction:chickens[i].facing,height:chickens[i].elevation+1.05,descendingTo:flying ? layout.height(chickens[i].p+chickens[i].facing*2.5)+0.53:nil)
                chickens[i].shotClock += departing ? 0.055:WeaponProfile.forPickup(chickenWeapon).interval
                chickens[i].flash=0.045;count+=1
            }
        }
    }

    func distance(_ p:V2,toSegment a:V2,_ b:V2)->Double {
        let line=b-a,rel=p-a,denom=max(0.000001,line.x*line.x+line.y*line.y)
        let t=max(0,min(1,(rel.x*line.x+rel.y*line.y)/denom))
        return (p-(a+line*t)).length
    }
    func resolveOrbHits() {resolveTeslaOrbContacts()}
}
