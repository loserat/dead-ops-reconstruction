import Foundation

enum FateKind:Int,CaseIterable {
    case fortitude, firepower, friendship, feet
    var title:String {switch self {case .fortitude:return "AUSDAUER";case .firepower:return "FEUERKRAFT";case .friendship:return "FREUNDSCHAFT";case .feet:return "FLINKE FÜSSE"}}
    var detail:String {switch self {
    case .fortitude:return "Doppelte Fund-Laufzeit · Multiplikator nach Tod mindestens ×2"
    case .firepower:return "Death Machine als dauerhafte Standardwaffe"
    case .friendship:return "Ein dauerhaftes Huhn · zusätzliche Hühner halten doppelt so lang"
    case .feet:return "Dauerhaft schneller · mindestens drei Boosts zu Rundenbeginn"
    }}
    var color:Int {switch self {case .fortitude:return 0xd7c77d;case .firepower:return 0xd58d64;case .friendship:return 0x9bbfe0;case .feet:return 0xb2ce81}}
}

extension GameCore {
    var effectiveFate:FateKind? {playerRoster.current.fatePending ? nil:fate}
    var activeWeapon:PickupKind? {weapon ?? (effectiveFate == .firepower ? .deathMachine:nil)}
    var fireInterval:Double {WeaponProfile.forPickup(activeWeapon).interval}
    var moveSpeed:Double {(boots>0 || effectiveFate == .feet) ? 9.8:6.4}
    var pickupDurationFactor:Double {effectiveFate == .fortitude ? 2:1}
    func restoreFateBenefits() {
        if effectiveFate == .friendship && !chickens.contains(where:{$0.permanent}) {addChicken(permanent:true)}
    }
    func enterFateRoom() {
        guard players.contains(where:{$0.fate==nil}),!fateRoomVisited else{return}
        retireCombatSpawning()
        clearElectricHazards();clearArenaSupport();flameJets=[];fateRoomVisited=true;sideRoom=SideRoomState(kind:.fate,sourceRound:round)
        fateRoom=FateRoomState(rolls:[random(),random(),random()])
        arenaExits=[]
        phase = .bonusRoom;sideRoomOffer=nil;martyrDamagePending=false;barrels=[];barrelDamagePending=false;bulls=[];foes=[];shots=[];clearWorldLoot();effects=[]
        forEachPlayer{hero=teamPosition(V2(x:0,y:2.2),slot:activePlayerSlot);heroElevation=flying ? 3.1:0;heroFallSpeed=0;cancelBoost();clearDeferredPlayerDamage();repositionCompanions()}
        fateRoom?.lifeStatues=players.filter(\.isDown).map{FateLifeStatue(targetSlot:$0.slot,p:$0.hero,elevation:$0.heroElevation+8)}
        environmentRevision+=1
        announce("RAUM DES SCHICKSALS")
    }
    func chooseFate(_ choice:FateKind) {
        guard let door=fateRoom?.door(for:choice) else{return}
        collectFate(at:door)
    }
}

enum CaveLayout {
    static let width=9.0,depth=6.0
    static let traps=[V2(x:-6,y:-1.5),V2(x:6,y:-1.5),V2(x:-6,y:1.5),V2(x:6,y:1.5)]
    static let obstacles=[ArenaObstacle(.zero,radius:0.88,height:2.8)]
    static let piles=[V2(x:-3.2,y:-2.8),V2(x:3.2,y:-2.8),V2(x:-3.2,y:2.8),V2(x:3.2,y:2.8)]
}
