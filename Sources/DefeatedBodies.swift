import Foundation

/// Presentation only. Existing foe identity is reused; no gameplay IDs or random values are consumed.
struct DefeatPresentation {
    let id:Int,position:V2,elevation:Double,launched:Bool
}

/// Own bounded animation, not an emulation of the archived engine's articulated ragdoll.
struct DefeatedBodyMotion {
    static let retainedLimit=55,eventLimit=256
    let launched:Bool
    // 220 archived units provisionally map to 2.2 own units. Gravity/spin are our visual approximation.
    static let launchSpeed=2.2,gravity=4.8
    var duration:Double {launched ? 2*Self.launchSpeed/Self.gravity:0.42}
    func pose(age:Double)->(angle:Double,lift:Double,opacity:Double,settled:Bool) {
        let t=age.isFinite ? max(0,age):0,u=min(1,t/duration)
        let turn=launched ? u:u*u*(3-2*u)
        return (Double.pi*(launched ? 1.5:0.5)*turn,
                launched ? max(0,Self.launchSpeed*min(t,duration)-0.5*Self.gravity*pow(min(t,duration),2)):0,
                1-0.35*u,u>=1)
    }
}
