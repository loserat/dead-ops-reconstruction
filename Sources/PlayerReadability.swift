import Foundation

/// Own visibility/camera assistance; no collision or original-engine constants are changed.
struct PlayerOcclusionState {
    private(set) var strength=0.0,blockedSamples=0
    mutating func update(blocked:Int,dt:Double,phase:RunPhase){
        guard phase == .playing || phase == .cleared || phase == .bonusRoom else{strength=0;blockedSamples=0;return}
        blockedSamples=max(0,min(3,blocked));let target=Double(blockedSamples)/3
        let step=dt.isFinite ? max(0,dt):0,rate=target>strength ? 18.0:10.0
        strength+=(target-strength)*(1-exp(-rate*step))
    }
    static func velocity(previous:V2?,hero:V2,dt:Double,snap:Bool)->V2 {
        guard !snap,let previous,dt.isFinite,dt>0.0001 else{return .zero}
        let delta=hero-previous
        guard delta.x.isFinite,delta.y.isFinite,delta.length<=2 else{return .zero}
        let v=delta*(1/dt);return v.unit*min(6,v.length)
    }
}
