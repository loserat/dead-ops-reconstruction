import Foundation

/// The reference checks the next round number, only before another round in the same arena.
enum FateEntryRules {
    static func due(after completedRound:Int,visited:Bool,roll:()->Int)->Bool {
        guard completedRound>0,completedRound%4 != 0,!visited,completedRound>=12 else{return false}
        if completedRound>=15 {return true}
        // RandomInt(100) > 30 rejects; 0 through 30 therefore mean 31 outcomes, not 30.
        return roll()<=30
    }
}

enum FateDoor:Int,CaseIterable {
    case west,north,east,south
    var p:V2 {switch self {case .west:return V2(x:-7,y:0);case .north:return V2(x:0,y:-4.5);case .east:return V2(x:7,y:0);case .south:return V2(x:0,y:4.5)}}
    func contains(_ p:V2)->Bool {
        switch self {
        case .west:return p.x < -6.4 && abs(p.y)<1.1
        case .north:return p.y < -3.9 && abs(p.x)<1.1
        case .east:return p.x > 6.4 && abs(p.y)<1.1
        case .south:return p.y > 3.9 && abs(p.x)<1.1
        }
    }
}
enum FateRoomTiming {
    // Public PS3-script behavior; world-space height/radii remain our own scale.
    static let firstArrow=5.0,arrowInterval=0.2,choiceWindow=30.0,fall=1.3,bootsDelay=1.0,settle=5.0,farewell=5.0
    static let choiceEnd=firstArrow+choiceWindow
}
struct FateDelivery {
    let slot:Int,chosenAt:Double
    var landed=false,bootsLanded=false
}
/// One ordinary team-life pickup is dropped toward each player down at room entry.
struct FateLifeStatue {
    let targetSlot:Int
    var p:V2,elevation:Double
    var landed=false
    var collectedBy:Int?
}
struct FateRoomState {
    let order:[FateDoor]
    var deliveries:[Int:FateDelivery]=[:]
    var decisionAt:Double?
    var lifeStatues:[FateLifeStatue]=[]
    var claimedBy:[Int:Int] {deliveries.mapValues(\.slot)}
    init(rolls:[Double]){
        var doors=FateDoor.allCases
        for i in stride(from:3,through:1,by:-1) {
            let roll=rolls.indices.contains(3-i) && rolls[3-i].isFinite ? max(0,min(1,rolls[3-i])):0
            doors.swapAt(i,min(i,Int(roll*Double(i+1))))
        }
        order=doors
    }
    func fate(at door:FateDoor)->FateKind {FateKind(rawValue:order.firstIndex(of:door)!)!}
    func door(for fate:FateKind)->FateDoor {order[fate.rawValue]}
    func visible(_ door:FateDoor,at clock:Double)->Bool {clock>=FateRoomTiming.firstArrow+Double(order.firstIndex(of:door)!)*FateRoomTiming.arrowInterval}
    func accepting(at clock:Double)->Bool {clock>=FateRoomTiming.firstArrow && clock<FateRoomTiming.choiceEnd && (decisionAt==nil || clock<decisionAt!+FateRoomTiming.settle)}
    func height(of door:FateDoor,at clock:Double,boots:Bool=false)->Double? {
        guard let delivery=deliveries[door.rawValue],!(boots ? delivery.bootsLanded:delivery.landed) else{return nil}
        let elapsed=clock-delivery.chosenAt-(boots ? FateRoomTiming.bootsDelay:0)
        guard elapsed>=0 else{return nil}
        return 8*max(0,1-elapsed/FateRoomTiming.fall)
    }
    var returnAt:Double? {decisionAt.map{$0+FateRoomTiming.settle+FateRoomTiming.farewell}}
}
extension GameCore {
    func stepFateLifeStatues(){
        guard sideRoom?.kind == .fate,let clock=sideRoom?.clock,let state=fateRoom else{return}
        for i in state.lifeStatues.indices {
            var statue=fateRoom!.lifeStatues[i]
            guard statue.collectedBy==nil,!statue.landed,players.indices.contains(statue.targetSlot) else{continue}
            let actor=players[statue.targetSlot]
            statue.p=actor.hero;statue.elevation=actor.heroElevation+8*max(0,1-clock/FateRoomTiming.fall)
            statue.landed=clock>=FateRoomTiming.fall;fateRoom!.lifeStatues[i]=statue
        }
        guard clock>=0.4 else{return}
        for player in players where !player.isDown {
            for i in state.lifeStatues.indices {
                let statue=fateRoom!.lifeStatues[i]
                guard statue.collectedBy==nil,(statue.p-player.hero).length<0.8,abs(statue.elevation-player.heroElevation)<0.65 else{continue}
                // Consume before the shared callback, which can restore and reposition several actors.
                fateRoom!.lifeStatues[i].collectedBy=player.slot
                grantTeamLife();emitAudio(.life);announce("LEBENSSTATUE · TEAM VERSTÄRKT")
            }
        }
    }
    /// Evaluate once at the selected combat exit, before a bonus room can be entered.
    @discardableResult
    func takeFateRouteIfDue()->Bool {
        guard phase == .cleared,sideRoom==nil,fateEntryEvaluatedRound != round else{return false}
        fateEntryEvaluatedRound=round
        guard players.contains(where:{$0.fate==nil}),FateEntryRules.due(after:round,visited:fateRoomVisited,roll:{min(99,Int(random()*100))}) else{return false}
        enterFateRoom();return true
    }
    var fateCameraSubjects:[CameraSubject] {
        guard sideRoom?.kind == .fate,let room=fateRoom else{return []}
        let actors=recoveryCameraPlayers
        var subjects=actors.map{CameraSubject(p:$0.hero,elevation:$0.heroElevation,radius:$0.vehicle == nil ? 1.2:2.5,height:2.4)}
        subjects+=FateDoor.allCases.map{CameraSubject(p:$0.p,elevation:0,radius:0.7,height:0.5)}
        subjects+=room.lifeStatues.filter{$0.collectedBy==nil}.map{CameraSubject(p:$0.p,elevation:$0.elevation,radius:0.7,height:1.1)}
        for door in FateDoor.allCases {
            guard let delivery=room.deliveries[door.rawValue],players.indices.contains(delivery.slot) else{continue}
            let actor=players[delivery.slot]
            for second in [false,true] where !second || room.fate(at:door) == .feet {
                if let height=room.height(of:door,at:sideRoom!.clock,boots:second) {subjects.append(CameraSubject(p:actor.hero,elevation:actor.heroElevation+height,radius:0.7,height:0.7))}
            }
        }
        return subjects
    }
    func revealedFatePosition(_ choice:FateKind)->V2? {
        guard sideRoom?.kind == .fate,let room=fateRoom else{return nil}
        let door=room.door(for:choice)
        return room.visible(door,at:sideRoom!.clock) ? door.p:nil
    }
    func collectFate(at door:FateDoor){
        guard phase == .bonusRoom,sideRoom?.kind == .fate,isPlayerActive,fate==nil,
              let room=fateRoom,room.accepting(at:sideRoom!.clock),room.deliveries[door.rawValue]==nil,door.contains(hero) else{return}
        let choice=room.fate(at:door)
        fate=choice;playerRoster.current.fatePending=true;playerRoster.current.missedFate=false
        fateRoom?.deliveries[door.rawValue]=FateDelivery(slot:activePlayerSlot,chosenAt:sideRoom!.clock)
        emitAudio(.pickup);announce("SCHICKSAL GEWÄHLT: \(choice.title)")
    }
    func deliverFate(_ choice:FateKind){
        playerRoster.current.fatePending=false
        switch choice {
        case .fortitude:
            addMultiplierUnits(TreasureRules.barUnits+1)
            for _ in 0..<3 {
                let center=layout.treasurePileCenters[min(layout.treasurePileCenters.count-1,Int(random()*Double(layout.treasurePileCenters.count)))]
                for i in 0..<(3+min(4,Int(random()*5))) {
                    let angle=Double(i)*2.399,point=center+V2(x:cos(angle),y:sin(angle))*0.7
                    addLoot(at:point,kind:random()<0.01 ? .gem:.treasure)
                }
            }
        case .firepower:weapon=nil;weaponReserve=0;shotClock=0
        case .friendship:restoreFateBenefits()
        case .feet:break
        }
        emitAudio(.pickup);announce("SCHICKSAL: \(choice.title)")
    }
    func stepFateRoom(){
        guard phase == .bonusRoom,sideRoom?.kind == .fate else{return}
        let clock=sideRoom!.clock
        // Stable actor order resolves simultaneous native trigger contacts; historical engine order is unknown.
        for player in players where !player.isDown && player.fate==nil {
            if let door=FateDoor.allCases.first(where:{$0.contains(player.hero)}) {withPlayer(player.slot){collectFate(at:door)}}
        }
        for door in FateDoor.allCases {
            guard var delivery=fateRoom?.deliveries[door.rawValue] else{continue}
            let choice=fateRoom!.fate(at:door),elapsed=clock-delivery.chosenAt
            if !delivery.landed && elapsed>=FateRoomTiming.fall {
                delivery.landed=true;fateRoom?.deliveries[door.rawValue]=delivery
                withPlayer(delivery.slot){deliverFate(choice)}
            }
            if choice == .feet && !delivery.bootsLanded && elapsed>=FateRoomTiming.bootsDelay+FateRoomTiming.fall {
                delivery.bootsLanded=true;fateRoom?.deliveries[door.rawValue]=delivery
                withPlayer(delivery.slot){dashes=max(3,dashes);emitAudio(.pickup)}
            }
        }
        if fateRoom?.decisionAt==nil {
            if players.allSatisfy({$0.fate != nil}) {fateRoom?.decisionAt=clock}
            else if clock>=FateRoomTiming.choiceEnd {fateRoom?.decisionAt=FateRoomTiming.choiceEnd}
        }
        if let returnAt=fateRoom?.returnAt,clock>=returnAt {
            for p in players where p.fate==nil {p.missedFate=true}
            requestFateReturn()
        }
    }
    var fateRoomInstruction:String {
        guard let room=sideRoom,room.kind == .fate,let state=fateRoom else{return ""}
        if let decided=state.decisionAt,room.clock>=decided+FateRoomTiming.settle {return "SCHICKSAL ENTSCHIEDEN · WEITER IN \(max(0,Int(ceil(decided+FateRoomTiming.settle+FateRoomTiming.farewell-room.clock))))s"}
        if room.clock>=FateRoomTiming.choiceEnd {return "AUSWAHL VORBEI · WARTE AUF DEN ÜBERGANG"}
        if let fate {return playerRoster.current.fatePending ? "\(fate.title) · BELOHNUNG KOMMT ZU DIR":"SCHICKSAL: \(fate.title) · WARTE AUF DAS TEAM"}
        if room.clock<FateRoomTiming.firstArrow {
            return state.lifeStatues.contains(where:{$0.collectedBy==nil}) ? "LEBENSSTATUE FÜR DAS TEAM EINSAMMELN":"RAUM DES SCHICKSALS · WÄHLE DEINEN WEG"
        }
        if room.clock<FateRoomTiming.firstArrow+3*FateRoomTiming.arrowInterval+0.6 {return "MERKE DIR DIE REIHENFOLGE DER PFEILE"}
        return "WÄHLE EINEN FREIEN AUSGANG · \(max(0,Int(ceil(FateRoomTiming.choiceEnd-room.clock))))s"
    }
}
