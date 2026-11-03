import Foundation

/// Own visual locomotion, derived exclusively from actual world displacement.
/// Native animation clips, stride lengths and body proportions are unavailable.
struct CharacterLocomotion {
    static let radiansPerUnit=4.0
    var phase=0.0,amount=0.0,worldDirection=V2(x:0,y:-1)
    private var lastPosition:V2?,lastClock:Double?,lastRevision = -1
    mutating func update(position:V2,clock:Double,revision:Int,speed:Double,active:Bool,boosting:Bool) {
        guard position.x.isFinite,position.y.isFinite,clock.isFinite,speed.isFinite,speed>0 else{return}
        let dt=lastClock.map{clock-$0} ?? 0,delta=lastPosition.map{position-$0} ?? .zero
        let distance=delta.length
        let continuous=lastRevision==revision && dt>0 && dt<0.2 && distance<max(1.5,dt*speed*3)
        if continuous {
            if active && !boosting {
                phase=(phase+distance*Self.radiansPerUnit).truncatingRemainder(dividingBy:2*Double.pi)
                if distance>1e-8 {worldDirection=delta.unit}
            }
            let target=active && !boosting ? min(1,distance/max(0.00001,dt*speed)):0
            amount+=(target-amount)*(1-exp(-14*dt))
            if amount<1e-8 {amount=0}
        }else if dt != 0 || lastRevision != revision || distance>1e-8 {amount=0}
        lastPosition=position;lastClock=clock;lastRevision=revision
    }
    func localDirection(facing:V2)->V2 {
        let f=facing.unit.length>0 ? facing.unit:V2(x:0,y:-1),right=V2(x:-f.y,y:f.x)
        return V2(x:worldDirection.x*right.x+worldDirection.y*right.y,y:-(worldDirection.x*f.x+worldDirection.y*f.y)).unit
    }
}
struct CharacterLegPose {
    let pitch:Double,roll:Double,yaw:Double,knee:Double
    static func plan(phase:Double,amount:Double,direction:V2,left:Bool)->CharacterLegPose {
        let strength=amount.isFinite ? max(0,min(1,amount)):0
        let d=direction.x.isFinite && direction.y.isFinite && direction.length>0 ? direction.unit:V2(x:0,y:-1)
        let cycle=sin(phase.isFinite ? phase:0)*(left ? 1.0:-1.0),side=left ? -1.0:1.0
        let rawRoll=cycle*0.38*d.x*strength
        // Inward steps stay within the hip gap instead of crossing both legs through each other.
        let roll=rawRoll*side<0 ? side * (-min(0.075,abs(rawRoll))):rawRoll
        return CharacterLegPose(pitch:cycle*0.60*(-d.y)*strength,roll:roll,yaw:-0.24*d.x*strength,knee:max(0,-cycle)*0.68*strength)
    }
}
