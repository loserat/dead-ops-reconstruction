import Foundation

enum TreasureMetal:Int,CaseIterable {case gold,silver}
enum TreasureForm:Int,CaseIterable {case coin,bar,stack,medallion,insignia}
enum GemColor:Int,CaseIterable {case blue,red,white
    var tint:Int {self == .blue ? 0x76bfff:self == .red ? 0xff807a:0xe9f6ff}
}
enum GemSize:Int,CaseIterable {case small,medium,large
    var width:Double {self == .small ? 0.28:self == .medium ? 0.40:0.58}
}
enum LootAppearance:Equatable {
    case metal(TreasureMetal,TreasureForm)
    case gem(GemColor,GemSize)
    static func treasure(index:Int)->LootAppearance {
        let i=abs(index%9)
        return i==8 ? .metal(.gold,.insignia):.metal(i<4 ? .gold:.silver,[.coin,.bar,.stack,.medallion][i%4])
    }
    var size:GemSize? {if case .gem(_,let s)=self {return s};return nil}
    var gemColor:GemColor? {if case .gem(let c,_)=self {return c};return nil}
}

/// Source popup vector and 3s trigger lock; flight/ground collision use our own map scale.
/// The model exists for one local network wait before PhysicsLaunch begins.
struct PickupPopup:Equatable {
    static let initialization=0.1,triggerLock=3.0,contactDelay=initialization+triggerLock
    static let sourceUnitsPerWorldUnit=60.0,gravity=14.0
    var origin:V2
    let offset:V2,velocity:V2,initialHeight:Double,verticalVelocity:Double
    init(origin:V2,random:()->Double) {
        self.origin=origin
        let vector=V2(x:-4+8*SourceLootRandom.unit(random()),y:-4+8*SourceLootRandom.unit(random()))
        let speed=25+15*SourceLootRandom.unit(random()),scale=Self.sourceUnitsPerWorldUnit
        offset=vector*(4/scale);velocity=vector*(speed/scale)
        initialHeight=80/scale;verticalVelocity=20*speed/scale
    }
    var flightDuration:Double {(verticalVelocity+sqrt(verticalVelocity*verticalVelocity+2*Self.gravity*initialHeight))/Self.gravity}
    func position(age:Double)->V2 {
        guard age>=Self.initialization else{return origin}
        return origin+offset+velocity*max(0,min(flightDuration,age-Self.initialization))
    }
    func height(age:Double)->Double {
        guard age>=Self.initialization else{return 0}
        let t=max(0,age-Self.initialization)
        return max(0,initialHeight+verticalVelocity*t-Self.gravity*t*t/2)
    }
}

/// Behavioral reference: publicly archived PS3 1.13 scripts, not an officially authenticated release.
/// See Reference/treasure-reference-v35.txt for provenance, guide conflicts and our own placements.
enum TreasureRules {
    static let ordinaryValue=125,gemDirectValue=625,barUnits=512
    static let ordinarySteps=[20,13,9,6,4,3,2,1,1]
    static let maximumGemUnits=563,quarterGemUnits=128
    static func ordinaryUnits(at multiplier:Int)->Int {ordinarySteps[max(0,min(8,multiplier-1))]}
    static func randomGemUnits(_ roll:Double)->Int {
        let t=roll.isFinite ? max(0,min(1,roll)):0
        return Int(Double(barUnits)*(0.3+0.8*t))
    }
    // A fractional final spawn_uber_prizes chunk can legitimately truncate to zero.
    static func boundedGemUnits(_ units:Int)->Int {max(0,min(maximumGemUnits,units))}
    static func gemSize(_ units:Int)->GemSize {units<256 ? .small:units<384 ? .medium:.large}
    static func gemScale(_ units:Int)->Double {max(1,min(5,Double(boundedGemUnits(units))/256))}
}
extension GameCore {
    func stepPickupLifetimes(_ dt:Double) {
        guard dt.isFinite,dt>=0 else{return}
        pickups=pickups.compactMap { pickup in
            var result=pickup;result.age+=dt
            if let popup=result.popup {result.p=layout.clamped(popup.position(age:result.age),clearance:0.4)}
            if result.hasNoTimeout {return result}
            result.ttl-=dt;return result.ttl>1e-9 ? result:nil
        }
    }
    var multiplierFill:Double {max(0,min(1,multiplierCharge))}
    var pointsUntilLife:Int {max(0,nextLifeAt-score)}
    var canGainDisplayedLife:Bool {godMode ? displayedLives<9:lives<9}
    func grantExtraLife() {
        if godMode && lives>=9 && displayedLives<9 {trainingBonusLives+=1}
        lives=min(9,lives+1);collectedLives+=1
        if playerRoster.current.isDown,phase == .playing || phase == .cleared || phase == .bonusRoom || phase == .transition {
            queueReserveRespawn()
        }
    }
    func addMultiplierUnits(_ amount:Int) {
        guard amount>0 else{return}
        // Production progress is an exact binary fraction of 512. Keep one promotion per pickup,
        // including a full bar at exactly 512; the following positive unit crosses it.
        let old=multiplierCharge.isFinite ? max(0,min(9,multiplierCharge)):0
        var units=Int((old*Double(TreasureRules.barUnits)).rounded())+min(TreasureRules.maximumGemUnits,amount)
        if units>TreasureRules.barUnits {
            units-=TreasureRules.barUnits
            if multiplier<9 {multiplier+=1;announce("MULTIPLIKATOR ×\(multiplier)")}
            else {units=TreasureRules.barUnits}
        }
        multiplierCharge=Double(units)/Double(TreasureRules.barUnits)
    }
    func collectLoot(_ kind:PickupKind,appearance:LootAppearance?,gemUnits:Int?=nil) {
        let before=nextLifeAt
        if kind == .treasure {
            // Score uses the multiplier before this item's meter increase.
            award(TreasureRules.ordinaryValue*multiplier)
            addMultiplierUnits(TreasureRules.ordinaryUnits(at:multiplier))
        }else if kind == .gem {
            award(TreasureRules.gemDirectValue*multiplier)
            // A direct developer/test award has no world item; normal pickups always carry the value.
            let units=gemUnits.map(TreasureRules.boundedGemUnits) ?? TreasureRules.randomGemUnits(random())
            addMultiplierUnits(units)
        }
        if nextLifeAt>before {announce("LEBENSSTATUE IM ANFLUG")}
    }
    func lootAppearance(for kind:PickupKind,index:Int,gemUnits:Int?=nil)->LootAppearance? {
        if kind == .treasure {return .treasure(index:index)}
        if kind == .gem {
            let size=gemUnits.map(TreasureRules.gemSize) ?? GemSize.allCases[abs(index%3)]
            return .gem(GemColor.allCases[abs(index%3)],size)
        }
        return nil
    }
    func worldPickup(id:Int,p:V2,kind:PickupKind,ttl:Double?=nil,appearance:LootAppearance?=nil,persistent:Bool=false,gemUnits:Int?=nil,lifetime:PickupLifetime?=nil)->Pickup {
        let units=kind == .gem ? gemUnits.map(TreasureRules.boundedGemUnits) ?? TreasureRules.randomGemUnits(random()):nil
        var look=appearance ?? lootAppearance(for:kind,index:id,gemUnits:units)
        if let units,case .gem(let color,_)=look {look = .gem(color,TreasureRules.gemSize(units))}
        let policy=lifetime ?? (ttl==nil ? .source(for:kind):.custom)
        return Pickup(id:id,p:p,kind:kind,ttl:ttl ?? policy.duration ?? 0,loot:look,persistent:persistent,gemUnits:units,lifetime:policy)
    }
    func addLoot(at p:V2,kind:PickupKind,appearance:LootAppearance?=nil,ttl:Double?=nil,gemUnits:Int?=nil,lifetime:PickupLifetime?=nil) {
        let n=id(),q=layout.clamped(p,clearance:0.4)
        pickups.append(worldPickup(id:n,p:q,kind:kind,ttl:ttl,appearance:appearance,gemUnits:gemUnits,lifetime:lifetime))
    }
    func spillLostMultiplier(at origin:V2) {
        let lost=multiplier-(fate == .fortitude ? 1:0)
        guard lost>1 else{return}
        let roll=random(),fraction=0.3+0.2*roll
        var units=Int(fraction*Double(lost*TreasureRules.barUnits)),index=0
        while units>0 {
            let chunk=min(TreasureRules.quarterGemUnits,units),angle=Double(index)*2.399
            let radius=0.8+Double(index%4)*0.32
            addLoot(at:origin+V2(x:cos(angle),y:sin(angle))*radius,kind:.gem,gemUnits:chunk)
            units-=chunk;index+=1
        }
    }
    func seedClearedTreasure() {
        sourceLoot?.queueRoundTreasure(boss:false);stepWorldLoot(0)
    }
    func seedBossTreasure(at p:V2) {
        // Source reward is twenty-five map-location globs, once after the complete boss round.
        sourceLoot?.queueRoundTreasure(boss:true);stepWorldLoot(0)
    }
}
