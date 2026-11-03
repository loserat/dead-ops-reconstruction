import Foundation
@main struct FateRoomChecks {
    static func main(){
        setbuf(stdout,nil);var count=0
        func expect(_ value:Bool,_ message:String){guard value else{print("FAIL \(message)");exit(1)};count+=1;print("PASS \(message)")}
        func close(_ a:Double,_ b:Double)->Bool {abs(a-b)<0.000001}
        func game(_ players:Int=1)->GameCore {let g=GameCore();g.reset(playerCount:players);g.round=14;g.beginRound();g.phase = .cleared;g.enterFateRoom();return g}
        func wait(_ g:GameCore,_ seconds:Double){var remaining=seconds;while remaining>0.0000001 {let dt=min(1.0/60,remaining);g.step(dt,inputs:[]);remaining-=dt}}
        func visit(_ g:GameCore,_ slot:Int,_ fate:FateKind){g.players[slot].hero=g.fateRoom!.door(for:fate).p}
        func open(_ g:GameCore){g.sideRoom!.clock=FateRoomTiming.firstArrow;g.step(0,inputs:[])}
        var permutations=Set<[Int]>()
        for a in 0..<4 {for b in 0..<3 {for c in 0..<2 {permutations.insert(FateRoomState(rolls:[(Double(a)+0.1)/4,(Double(b)+0.1)/3,(Double(c)+0.1)/2]).order.map(\.rawValue))}}}
        expect(permutations.count==24,"door mapping supports all24 compass permutations")
        for rolls in [[Double.nan,Double.infinity,-Double.infinity],[-1,-2,-3],[1,1,1],[2,4,100],[]] {
            let s=FateRoomState(rolls:rolls)
            expect(Set(s.order).count==4 && FateKind.allCases.allSatisfy{s.fate(at:s.door(for:$0))==$0},"bounded random inputs retain four reversible unique door assignments")
        }
        let reveal=game(),state=reveal.fateRoom!
        expect(reveal.fateCameraSubjects.count==5 && reveal.fateCameraSubjects.suffix(4).map(\.p)==FateDoor.allCases.map(\.p),"solo framing includes four exits before they become visible")
        expect(FateDoor.allCases.allSatisfy{!state.visible($0,at:0)} && reveal.revealedFatePosition(.firepower)==nil,"intro conceals arrow order and route hints")
        for (rank,door) in state.order.enumerated() {let t=5+Double(rank)*0.2;expect(!state.visible(door,at:t-0.001) && state.visible(door,at:t),"arrows reveal at their ordered0.2second boundaries after the introduction")}
        reveal.sideRoom!.clock=5.7;expect(reveal.revealedFatePosition(.firepower)==state.door(for:.firepower).p,"revealed routes use the randomized power assignment")
        let fire=game();visit(fire,0,.firepower);fire.chooseFate(.firepower);wait(fire,4.9)
        expect(fire.fate==nil && fire.fateRoom!.deliveries.isEmpty && fire.phase == .bonusRoom,"intro door contact and a direct choice cannot start delivery early")
        fire.apply(.ray);open(fire)
        expect(fire.fate == .firepower && fire.players[0].fatePending && fire.weapon == .ray && fire.activeWeapon == .ray,"open exit contact reserves firepower without applying its weapon callback early")
        expect(fire.fateRoom!.claimedBy.count==1 && fire.fateRoom!.decisionAt==5 && fire.round==14,"reservation owns one door and starts settlement without immediately advancing combat")
        let door=fire.fateRoom!.door(for:.firepower),startHeight=fire.fateRoom!.height(of:fire.fateRoom!.door(for:.firepower),at:5)!
        expect(startHeight==8 && fire.fateCameraSubjects.count==6,"only the reserved exit creates one personal high delivery subject")
        fire.hero=V2(x:2,y:2);wait(fire,0.6)
        expect(fire.fateRoom!.height(of:door,at:fire.sideRoom!.clock)!<startHeight && fire.players[0].fatePending,"moving away from a reserved exit does not lose its in-flight reward")
        let reserve=fire.weaponReserve;wait(fire,0.8)
        expect(!fire.players[0].fatePending && fire.weapon==nil && fire.activeWeapon == .deathMachine && reserve==50,"delivery replaces a carried temporary weapon only on impact")
        expect(fire.phase == .bonusRoom && fire.round==14 && fire.fateRoom!.deliveries[door.rawValue]!.landed,"completed delivery retains the shared settlement and farewell period")
        fire.chooseFate(.feet);expect(fire.fate == .firepower && fire.fateRoom!.claimedBy.count==1,"an already reserved actor cannot change fate at a second door")
        wait(fire,3.7);expect(fire.fateRoomInstruction.contains("ENTSCHIEDEN") && fire.round==14,"after five settlement seconds the farewell is shown before combat")
        wait(fire,4.91);expect(fire.phase == .transition && fire.round==14,"shared farewell enters a hidden return before map change");wait(fire,2.7);expect(fire.phase == .playing && fire.round==15 && fire.fateRoom==nil && fire.sideRoom==nil,"the second five-second stage returns to combat exactly once")
        expect(fire.fateCameraSubjects.isEmpty && !fire.players[0].fatePending,"normal combat retains no room framing or unfinished personal delivery")
        for fate in FateKind.allCases {
            let g=game();let door=g.fateRoom!.door(for:fate)
            g.hero=g.layout.boundary(door.p*10,clearance:0.29);open(g)
            expect(g.fate==fate && g.fateRoom!.claimedBy[door.rawValue]==0,"holding beyond an arrow against the outer wall still touches its exit trigger")
            wait(g,2.4);expect(!g.players[0].fatePending && g.fate==fate,"every reserved power completes its personal delivery without re-entering the exit")
        }
        let feet=game();feet.dashes=0;visit(feet,0,.feet);open(feet);let feetDoor=feet.fateRoom!.door(for:.feet)
        expect(feet.moveSpeed==6.4 && feet.dashes==0 && feet.fateRoom!.height(of:feetDoor,at:5,boots:true)==nil,"feet reservation does not grant speed boosts before the separate deliveries")
        wait(feet,1.1)
        expect(feet.fateRoom!.height(of:feetDoor,at:feet.sideRoom!.clock) != nil && feet.fateRoom!.height(of:feetDoor,at:feet.sideRoom!.clock,boots:true) != nil,"feet starts a second boots delivery one second after the bolt")
        wait(feet,0.3);expect(feet.moveSpeed==9.8 && feet.dashes==0 && !feet.players[0].fatePending,"the first feet impact activates speed while the later boots still have to land")
        wait(feet,1);expect(feet.dashes==3 && feet.fateRoom!.deliveries[feetDoor.rawValue]!.bootsLanded,"boots impact establishes the minimum three boosts in the safe room")
        feet.dashes=7;wait(feet,0.2);expect(feet.dashes==7,"a completed delivery cannot repeatedly reset or reduce a boost stock")
        let fortune=game();fortune.multiplier=3;fortune.multiplierCharge=0.25;visit(fortune,0,.fortitude);open(fortune);wait(fortune,1.4)
        expect(fortune.multiplier==4 && fortune.multiplierCharge==129.0/512 && fortune.pickupDurationFactor==2,"fortune arrival advances the existing meter by513 units and then enables duration benefits")
        expect((9...21).contains(fortune.pickups.count) && fortune.pickups.allSatisfy{fortune.layout.walkable($0.p,clearance:0.28)},"fortune materializes three reachable own treasure piles rather than silently omitting its bonus loot")
        let pileCount=fortune.pickups.count;wait(fortune,0.1);expect(fortune.pickups.count==pileCount,"a completed fortune callback cannot duplicate its piles each frame")
        let friend=game();visit(friend,0,.friendship);open(friend);expect(friend.chickens.isEmpty,"friendship does not create a helper before delivery")
        wait(friend,1.4);expect(friend.chickens.filter(\.permanent).count==1,"friendship creates exactly one personal permanent helper on delivery")
        let competition=game(2);visit(competition,0,.firepower);visit(competition,1,.firepower);open(competition)
        expect(competition.players.map(\.fate)==[.firepower,nil] && competition.fateRoom!.deliveries.count==1,"one physical exit reserves only once with stable ordering for simultaneous contacts")
        competition.withPlayer(1){competition.chooseFate(.firepower)};expect(competition.players[1].fate==nil,"a teammate cannot steal an already reserved door while its payload is falling")
        visit(competition,1,.friendship);competition.step(0,inputs:[]);wait(competition,1.4)
        expect(competition.players.map(\.fate)==[.firepower,.friendship] && competition.players[1].chickens.filter(\.permanent).count==1 && competition.players[0].chickens.isEmpty,"a second visitor can reserve another exit and receive only its own callback")
        let four=game(4);for f in FateKind.allCases {visit(four,f.rawValue,f)};wait(four,17.9)
        expect(four.round==15 && four.players.map(\.fate)==FateKind.allCases.map{Optional($0)} && four.players.allSatisfy{!$0.fatePending && !$0.missedFate},"four real visitors complete introduction reservation personal delivery and shared farewell")
        let missed=game();wait(missed,35.01)
        expect(missed.phase == .bonusRoom && missed.fate==nil && close(missed.fateRoom!.decisionAt!,35),"thirty selectable seconds expire without manufacturing a missing fate")
        visit(missed,0,.feet);missed.step(0,inputs:[]);expect(missed.fate==nil,"an unreserved actor cannot start a delivery after the deadline")
        wait(missed,12.7);expect(missed.round==15 && missed.players[0].missedFate && missed.fate==nil,"timeout still includes settlement and farewell before returning without a fate")
        let late=game();late.sideRoom!.clock=34.9;visit(late,0,.feet);late.step(0,inputs:[]);wait(late,2.4)
        expect(late.fate == .feet && !late.players[0].fatePending && late.dashes>=3,"a valid last-second reservation completes after the selection window closes")
        let paused=game();visit(paused,0,.friendship);open(paused);let clock=paused.sideRoom!.clock
        paused.step(0,inputs:[Controls(systemPause:true)]);paused.step(100,inputs:[])
        expect(paused.phase == .paused && paused.sideRoom!.clock==clock && paused.players[0].fatePending && paused.chickens.isEmpty,"system pause freezes in-flight rewards callbacks and the settlement deadline")
        paused.step(0,inputs:[Controls(accept:true)]);wait(paused,1.4);expect(paused.chickens.count==1 && !paused.players[0].fatePending,"resume continues the original reserved delivery exactly once")
        for dt in [Double.nan,Double.infinity,-1] {let before=paused.sideRoom!.clock;paused.step(dt,inputs:[]);expect(paused.sideRoom!.clock==before,"invalid frame durations cannot change reservation or delivery timing")}
        let down=game(2);down.players[1].isDown=true;down.players[1].lives=0;down.players[1].reviveRemaining=60;down.players[1].donationCooldown=999;visit(down,0,.firepower);wait(down,35.1)
        expect(down.players[0].fate == .firepower && down.players[1].isDown && close(down.players[1].reviveRemaining,24.9) && down.phase == .bonusRoom,"a missing downed player keeps one shared recovery clock through the full selection period")
        wait(down,12.7);expect(down.round==15 && !down.players[1].isDown && down.players[1].missedFate && down.players[1].fate==nil,"normal round start restores a still-downed teammate while retaining the missed choice")
        let revive=game(2);revive.players[1].isDown=true;revive.players[1].lives=0;revive.players[1].reviveRemaining=3;revive.players[1].donationCooldown=999;wait(revive,3.1);visit(revive,0,.firepower);visit(revive,1,.friendship);wait(revive,14.8)
        expect(revive.round==15 && revive.players.map(\.fate)==[.firepower,.friendship],"a naturally recovered teammate may still reach and reserve a free exit")
        let air=game(2);visit(air,0,.firepower);visit(air,1,.feet);air.withPlayer(1){air.apply(.helicopter)};open(air);wait(air,1.1)
        expect(air.players.allSatisfy(\.fatePending) && air.players[1].vehicle!.remaining==20,"ground and flying owners wait for the same directed delivery while safe-room fuel remains frozen")
        wait(air,1.3);expect(air.players.allSatisfy{!$0.fatePending} && air.players[1].dashes>=3 && air.players[1].vehicle!.remaining==20,"airborne feet receives both packages without spending its vehicle reserve")
        let skipped=game();visit(skipped,0,.firepower);skipped.step(60,inputs:[]);skipped.step(2.7,inputs:[])
        expect(skipped.round==15 && skipped.fate==nil && skipped.players[0].missedFate,"a long elapsed frame cannot backdate a door reservation after the entire opportunity")
        let reset=game();visit(reset,0,.friendship);open(reset);reset.reset()
        expect(reset.fateRoom==nil && !reset.fateRoomVisited && reset.players.allSatisfy{$0.fate==nil && !$0.fatePending && !$0.missedFate},"new run clears pending powers reservations and missed-choice state")
        print("\(count) fate room checks passed;PS3-script directed-delivery model,own world scale and simultaneous-contact order;not authenticated original binary or hardware acceptance")
    }
}
