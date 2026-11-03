import Foundation

enum PickupPersistence {
    // BO1 first-hand guide describes rare non-rotating drops. Frequency is an own approximation.
    static func eligible(_ kind:PickupKind)->Bool {kind != .treasure && kind != .gem}
    static func selected(roll:Double)->Bool {roll.isFinite && roll>=0 && roll<1.0/128}
    static func rotation(_ p:Pickup,clock:Double)->Double {
        p.persistent ? Double(p.id)*0.013:clock*(PickupPresentation.forKind(p.kind).category == .weapon ? 0.65:1.6)+Double(p.id)*0.013
    }
}

enum PickupCategory:Int {case treasure,resource,weapon,vehicle,protection,companion
    var title:String {switch self {case .treasure:return "SCHATZ";case .resource:return "VORRAT";case .weapon:return "WAFFE";case .vehicle:return "FAHRZEUG";case .protection:return "SCHUTZ";case .companion:return "HELFER"}}
    var markerCorners:Int {switch self {case .weapon:return 6;case .vehicle:return 4;case .resource:return 4;case .protection:return 24;case .companion:return 3;case .treasure:return 0}}
}
struct PickupPresentation {
    let category:PickupCategory,title:String,tint:Int
    static func forKind(_ kind:PickupKind)->PickupPresentation {
        switch kind {
        case .treasure:return Self(category:.treasure,title:"GOLD UND SILBER",tint:0xe2c16b)
        case .gem:return Self(category:.treasure,title:"EDELSTEIN",tint:0x80c9ff)
        case .life:return Self(category:.resource,title:"EXTRA-LEBEN",tint:0xffdf8a)
        case .dash:return Self(category:.resource,title:"BOOST",tint:0xffec72)
        case .bomb:return Self(category:.resource,title:"BOMBE",tint:0xff9c74)
        case .boots:return Self(category:.resource,title:"LAUFSTIEFEL",tint:0xffd05d)
        case .spread:return Self(category:.weapon,title:"SPAS-12",tint:0xf4cc83)
        case .ray:return Self(category:.weapon,title:"RAY GUN",tint:0x94f58c)
        case .rocket:return Self(category:.weapon,title:"RPG",tint:0xf3aa73)
        case .deathMachine:return Self(category:.weapon,title:"DEATH MACHINE",tint:0x85d8ed)
        case .grenade:return Self(category:.weapon,title:"CHINA LAKE",tint:0xccb4f5)
        case .flamethrower:return Self(category:.weapon,title:"M2-FLAMMENWERFER",tint:0xff8f6b)
        case .tank:return Self(category:.vehicle,title:"PANZER",tint:0x98c9ad)
        case .helicopter:return Self(category:.vehicle,title:"HIND",tint:0x9ed8e7)
        case .orb:return Self(category:.protection,title:"ELEKTRO-KUGELN",tint:0x8abfff)
        case .teddy:return Self(category:.protection,title:"TEDDY",tint:0xedd6ac)
        case .barrelShield:return Self(category:.protection,title:"FASS-SCHUTZ",tint:0xe0b586)
        case .chicken:return Self(category:.companion,title:"HUHN",tint:0xffedb3)
        case .monkey:return Self(category:.companion,title:"AFFENBOMBE",tint:0xe9aa91)
        case .turret:return Self(category:.companion,title:"SELBSTSCHUSSANLAGE",tint:0xa6d8c7)
        }
    }
    /// A restrained near-player readout: no label forest over every coin or through another floor.
    static func hint(in core:GameCore,keeping currentID:Int?)->Pickup? {
        guard core.phase == .playing || core.phase == .cleared || core.phase == .bonusRoom else{return nil}
        var candidates=core.pickups.filter{p in
            forKind(p.kind).category != .treasure && (p.p-core.hero).length<=3.2 &&
            (core.flying || abs(core.layout.height(p.p)-core.heroElevation)<0.65)
        }
        candidates+=core.visibleRewardBundles.compactMap{bundle in
            let reward=bundle.reward
            guard (reward.p-core.hero).length<=3.2,abs(reward.elevation-core.heroElevation)<0.65 else{return nil}
            return Pickup(id:reward.id,p:reward.p,kind:reward.kind,ttl:3600)
        }
        guard let nearest=candidates.min(by:{($0.p-core.hero).length<($1.p-core.hero).length}) else{return nil}
        if let current=candidates.first(where:{$0.id==currentID}),(current.p-core.hero).length<=(nearest.p-core.hero).length+0.45 {return current}
        return nearest
    }
}
