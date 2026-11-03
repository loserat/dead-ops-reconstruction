import Foundation
@main struct OrbRetirementChecks {
 static func main() {
  setbuf(stdout,nil);var count=0
  func expect(_ yes:Bool,_ message:String) {guard yes else{fatalError(message)};count+=1;print("PASS \(message)")}
  func close(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-7}
  func shields(_ n:Int=4)->[OrbShield] {(0..<n).map{i in let a=TeslaRules.initialAngles[i],p=V2(x:cos(a),y:sin(a))*0.8;return OrbShield(id:100+i,angle:a,p:p,previousP:p)}}
  let state=TeslaOrbRetirement();var objects=[FlyingOrb]()
  state.begin(shields(),parent:.zero,elevation:0,objects:&objects)
  expect(objects.map(\.id)==[100,101,102,103] && objects.filter(\.launched).count==1,"unused source slot IDs survive; only first object detaches immediately")
  expect(objects.allSatisfy{close($0.deleteAt,4)} && zip(objects.map(\.launchAt),[0.0,0.5,1.0,1.5]).allSatisfy{close($0.0,$0.1)},"four half-second waits include last launch then two seconds before shared deletion")
  expect(close(objects[0].v.length,8) && close(objects[0].verticalSpeed,5),"own velocity interpretation preserves the complete archived origin difference times ten")
  func advance(_ dt:Double,_ parent:V2 = .zero) {state.advance(dt,objects:&objects,parent:parent,elevation:0,floor:{_ in nil},clear:{_,_,_ in true})}
  advance(0.499);expect(objects.filter(\.launched).count==1,"second orb remains linked until half second")
  advance(0.001,V2(x:2,y:0));expect(objects.filter(\.launched).count==2 && (objects[1].p-(V2(x:2,y:0)+objects[1].offset)).length<1e-7,"second orb detaches at its due time from current moving parent")
  advance(0.5);expect(objects.filter(\.launched).count==3,"third unused slot detaches at one second")
  advance(0.5);expect(objects.filter(\.launched).count==4 && objects.count==4,"fourth detaches at one and a half seconds without deleting earlier models")
  advance(2.499);expect(objects.count==4,"all four cosmetic bodies survive until common four-second deadline")
  advance(0.001);expect(objects.isEmpty,"all leftover models delete together at four seconds")
  for n in 1...4 {
   let s=TeslaOrbRetirement();var a=[FlyingOrb]();s.begin(shields(n),parent:.zero,elevation:0,objects:&a)
   let deadline=Double(n)*0.5+2
   expect(a.count==n && a.allSatisfy{close($0.deleteAt,deadline)},"\(n)unused slots alone determine cleanup waits; consumed slots add no delay")
   s.advance(deadline-0.001,objects:&a,parent:.zero,elevation:0,floor:{_ in 0},clear:{_,_,_ in true})
   expect(a.count==n && a.allSatisfy{$0.height>=0.12 && $0.height.isFinite && $0.p.length.isFinite},"own\(n)-body cosmetic flight stays finite and above ground before deletion")
   s.advance(0.001,objects:&a,parent:.zero,elevation:0,floor:{_ in 0},clear:{_,_,_ in true});expect(a.isEmpty,"\(n)-body deadline includes the final half-second wait")
  }
  let frozen=TeslaOrbRetirement();var f=[FlyingOrb]();frozen.begin(shields(),parent:.zero,elevation:0,objects:&f)
  frozen.advance(0,at:100,objects:&f,parent:.zero,elevation:0,floor:{_ in nil},clear:{_,_,_ in true})
  frozen.advance(0.25,at:100.25,objects:&f,parent:.zero,elevation:0,floor:{_ in nil},clear:{_,_,_ in true});let p=f[0].p
  for dt in [0.25,-1,Double.nan,Double.infinity] {frozen.advance(dt,at:100.25,objects:&f,parent:.zero,elevation:0,floor:{_ in nil},clear:{_,_,_ in true})}
  expect(close(frozen.clock,0.25) && f[0].p==p,"duplicate, invalid and paused clock deliveries cannot age cosmetic flight twice")
  frozen.advance(1,at:90,objects:&f,parent:.zero,elevation:0,floor:{_ in nil},clear:{_,_,_ in true});expect(close(frozen.clock,0.25),"backward world clocks do not change retirement state")
  for rate in [30,60,120] {
   let s=TeslaOrbRetirement();var a=[FlyingOrb]();s.begin(shields(),parent:.zero,elevation:3,objects:&a)
   for _ in 0..<rate {s.advance(1/Double(rate),objects:&a,parent:.zero,elevation:3,floor:{_ in nil},clear:{_,_,_ in true})}
   expect(a.filter(\.launched).count==3 && close(a[0].height,3.5+5-4.9) && close(a[0].p.y,8.8),"exact launch schedule and own free-flight solution agree at\(rate)Hz")
  }
  func game(_ players:Int=1)->GameCore {let g=GameCore();g.reset(playerCount:players);g.foes=[];g.pickups=[];g.sourceLoot=nil;g.combatSpawningHeld=true;g.invulnerable=999;return g}
  let expiry=game();expiry.grantOrbs(duration:0.02);let ids=expiry.orbShields.map(\.id);expiry.step(0.05,input:Controls())
  expect(expiry.orbShields.isEmpty && expiry.flyingOrbs.map(\.id)==ids && expiry.flyingOrbs.filter(\.launched).count==1,"actual timer expiry retires the same four models during the frame")
  expect(close(expiry.flyingOrbs[0].launchAt,0.02) && close(expiry.flyingOrbs[0].ttl,3.97),"fractional expiry advances only remaining thirty milliseconds, without a full extra frame")
  let refilled=game();refilled.grantOrbs();refilled.orbShields.remove(at:1);let old=refilled.orbShields.map(\.id);refilled.grantOrbs()
  expect(refilled.orbShields.count==4 && refilled.flyingOrbs.map(\.id)==old && refilled.flyingOrbs.allSatisfy{close($0.deleteAt,3.5)},"real replacement keeps three unused old models and grants four fresh charges")
  refilled.stepTesla(0.25);refilled.grantOrbs();expect(refilled.flyingOrbs.count==7 && refilled.orbShields.count==4,"another pickup cannot erase an older cleanup wave")
  refilled.stepTesla(3.25);expect(refilled.flyingOrbs.count==4 && refilled.orbShields.count==4,"old common deadline removes only its own generation")
  let harmless=game();harmless.grantOrbs();harmless.retireOrbs();harmless.foes=[Foe(id:500001,p:harmless.flyingOrbs[1].p,hp:99,speed:0,gait:0)]
  harmless.resolveOrbHits();harmless.stepTesla(1)
  expect(harmless.foes[0].hp==99 && harmless.score==0 && harmless.playerRoster.current.tesla.ready,"retiring still-linked models have no damage triggers, points or discharge gate")
  let death=game(2);death.withPlayer(1){death.grantOrbs();death.invulnerable=0;death.playerRoster.current.bodyShield=nil;death.loseLife()}
  expect(death.players[1].isDown && death.players[1].orbShields.isEmpty && death.players[1].flyingOrbs.count==4,"actual physical player-two death launches cleanup while removing every damaging charge")
  death.stepTesla(1.5);expect(death.players[1].flyingOrbs.filter(\.launched).count==4,"all-player clock continues cleanup even while owner waits down")
  death.stepTeamRecovery(2);expect(!death.players[1].isDown && death.players[1].flyingOrbs.count==4,"same-map respawn does not erase already free physical models")
  death.stepTesla(2.5);expect(death.players[1].flyingOrbs.isEmpty,"death cleanup ends at shared deadline after respawn")
  let god=game();god.grantOrbs();god.godMode=true;god.invulnerable=0;god.loseLife()
  expect(god.trainingHits==1 && god.orbShields.count==4 && god.flyingOrbs.isEmpty,"virtual Godmode hit neither retires nor consumes existing equipment")
  let team=game(4);team.forEachPlayer{team.grantOrbs();team.grantOrbs()};team.stepTesla(0.5)
  expect(team.players.allSatisfy{$0.orbShields.count==4 && $0.flyingOrbs.count==4 && $0.flyingOrbs.filter(\.launched).count==2},"four real owners keep independent new charges and staggered cleanup models")
  expect(Set(team.players.flatMap{($0.orbShields.map(\.id)+$0.flyingOrbs.map(\.id))}).count==32 && team.activePlayerSlot==0,"no duplicate object IDs or leaked active role in four-owner cleanup")
  team.withPlayer(1){team.orb=0};expect(team.players[1].orbShields.isEmpty && team.players[1].flyingOrbs.count==8 && team.players[0].orbShields.count==4,"explicit support removal retires only that owner's current generation")
  team.clearArenaSupport();expect(team.players.allSatisfy{$0.flyingOrbs.isEmpty && $0.orbShields.count==($0.slot==1 ? 0:4)},"map-support cleanup removes old physics models without stealing carried charges")
  team.reset();expect(team.players.allSatisfy{$0.flyingOrbs.isEmpty && $0.orbRetirement.clock==0},"new attempt clears all per-owner retirement clocks and models")
  let room=game();room.phase = .cleared;room.enterSideRoom(SideRoomOffer(kind:.treasure,p:room.layout.sideRoute(onLeft:true)));room.sourceLoot=nil;room.pickups=[];room.grantOrbs();room.grantOrbs();room.step(0.6,input:Controls())
  expect(room.phase == .bonusRoom && room.orbRemaining==40 && room.flyingOrbs.filter(\.launched).count==2,"safe-room carried timer stays frozen while old cleanup clocks advance")
  let teleported=game();teleported.grantOrbs();teleported.retireOrbs();teleported.stepTesla(0.2);let free=teleported.flyingOrbs[0].p
  teleported.hero=V2(x:5,y:3);teleported.repositionCompanions()
  expect(teleported.flyingOrbs[0].p==free && (teleported.flyingOrbs[1].p-(teleported.hero+teleported.flyingOrbs[1].offset)).length<1e-8,"same-map teleport moves linked leftovers while already free bodies retain world position")
  let pause=game();pause.grantOrbs();pause.grantOrbs();pause.step(0.1,input:Controls());let pauseP=pause.flyingOrbs[0].p,pauseClock=pause.playerRoster.current.orbRetirement.clock
  pause.step(0,input:Controls(pause:true));pause.step(20,input:Controls())
  expect(pause.phase == .paused && pause.flyingOrbs[0].p==pauseP && pause.playerRoster.current.orbRetirement.clock==pauseClock,"actual game pause freezes launched models and pending half-second departures")
  pause.step(0,input:Controls(accept:true));pause.step(0.4,input:Controls())
  expect(pause.flyingOrbs.filter(\.launched).count==2,"actual resume waits only the unelapsed part of the original stagger")
  let terminal=game();terminal.grantOrbs();terminal.lives=0;terminal.invulnerable=0;terminal.playerRoster.current.bodyShield=nil;terminal.loseLife()
  expect(terminal.phase == .gameOver && terminal.flyingOrbs.count==4,"terminal physical death starts the same unused-orb cleanup")
  terminal.step(1.5,input:Controls());expect(terminal.flyingOrbs.filter(\.launched).count==4,"game-over presentation allows remaining physics departures without resuming combat")
  terminal.step(2.5,input:Controls());expect(terminal.flyingOrbs.isEmpty && terminal.score==0 && terminal.deaths==1,"game-over cleanup finishes at four seconds without hits or extra deaths")
  let collision=TeslaOrbRetirement();var solid=[FlyingOrb]();collision.begin(shields(1),parent:.zero,elevation:0,objects:&solid)
  collision.advance(0.3,objects:&solid,parent:.zero,elevation:0,floor:{_ in 0},clear:{_,_,_ in false})
  expect(solid[0].v == .zero && (solid[0].p-solid[0].offset).length<1e-8 && solid[0].height.isFinite,"own solid collision stops cosmetic horizontal motion without a projectile or hit")
  print("\(count) orb retirement checks passed")
 }
}
