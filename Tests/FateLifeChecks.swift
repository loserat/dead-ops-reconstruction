import Foundation
@main struct FateLifeChecks {
 static func main(){
  var count=0
  func expect(_ yes:Bool,_ message:String){guard yes else{fatalError(message)};count+=1;print("PASS \(message)")}
  func close(_ a:Double,_ b:Double)->Bool{abs(a-b)<1e-6}
  func game(_ count:Int=2,_ down:[Int]=[1])->GameCore {
   let g=GameCore();g.reset(playerCount:count);g.round=15;g.beginRound();g.phase = .cleared
   for p in g.players {p.lives=0;p.donationCooldown=999;if down.contains(p.slot){p.isDown=true;p.reviveRemaining=50}}
   g.enterFateRoom();g.players[0].hero=V2(x:-3,y:-2);return g
  }
  let solo=game(1,[]),alive=game(4,[])
  expect(solo.fateRoom!.lifeStatues.isEmpty && alive.fateRoom!.lifeStatues.isEmpty,"entry with no downed players creates no free life statues")
  let entry=game(4,[1,2,3])
  expect(entry.fateRoom!.lifeStatues.map(\.targetSlot)==[1,2,3],"one ordinary life statue is directed toward each downed entry role")
  expect(entry.players.dropFirst().allSatisfy{$0.isDown && $0.reviveRemaining==50 && $0.lives==0},"entry itself does not grant reserves or bypass existing recovery timers")
  expect(entry.fateRoom!.lifeStatues.allSatisfy{$0.elevation==8 && !$0.landed && $0.collectedBy==nil},"statues start above their intended targets without being collected")
  expect(entry.fateCameraSubjects.count==8 && entry.fateCameraSubjects.filter{$0.elevation==8}.count==3,"camera subjects include all three high statues and the four exits")
  expect(entry.fateRoomInstruction.contains("LEBENSSTATUE"),"room introduction explains the physical team-life opportunity")
  entry.step(0.5,inputs:[])
  expect(entry.fateRoom!.lifeStatues.allSatisfy{$0.elevation>4 && $0.elevation<8} && entry.players.dropFirst().allSatisfy{close($0.reviveRemaining,49.5)},"a shared half-second advances each drop and each waiting clock only once")
  entry.players[1].hero=V2(x:3,y:2);entry.step(0.1,inputs:[])
  expect(entry.fateRoom!.lifeStatues[0].p==entry.players[1].hero,"in-flight statue follows the actual target position")
  let clock=entry.sideRoom!.clock,height=entry.fateRoom!.lifeStatues[0].elevation,wait=entry.players[1].reviveRemaining
  entry.step(0,input:Controls(pause:true));entry.step(5,input:Controls())
  expect(entry.phase == .paused && entry.sideRoom!.clock==clock && entry.fateRoom!.lifeStatues[0].elevation==height && entry.players[1].reviveRemaining==wait,"pause freezes physical falls and ordinary teammate recovery together")
  entry.step(0,input:Controls(accept:true));entry.step(0.71,inputs:[])
  expect(entry.fateRoom!.lifeStatues.allSatisfy(\.landed) && entry.fateRoom!.lifeStatues.allSatisfy{$0.elevation==0},"uncollected statues land at their target floor")
  let landed=entry.fateRoom!.lifeStatues[0].p;entry.players[1].hero=V2(x:5,y:2);entry.step(0.1,inputs:[])
  expect(entry.fateRoom!.lifeStatues[0].p==landed && entry.players[1].isDown,"a landed statue stops following its target and is not an automatic resurrection")
  entry.players[0].hero=landed;entry.players[0].heroElevation=2;entry.step(0,inputs:[])
  expect(entry.fateRoom!.lifeStatues[0].collectedBy==nil,"horizontal overlap alone cannot collect a statue on another vertical level")
  entry.players[0].heroElevation=0;entry.players[0].hero=landed+V2(x:0.801,y:0);entry.step(0,inputs:[])
  expect(entry.fateRoom!.lifeStatues[0].collectedBy==nil,"living teammate beyond the physical pickup radius receives no award")
  entry.players[0].hero=landed;entry.step(0,inputs:[])
  expect(entry.fateRoom!.lifeStatues[0].collectedBy==0 && entry.players[1].respawnRemaining==2 && entry.players[2].collectedLives==0,"a living collector consumes one statue and starts the shared staged return at its first waiting role")
  entry.stepTeamRecovery(6)
  expect(entry.players.map(\.lives)==[1,0,0,0] && entry.players.allSatisfy{$0.collectedLives==1},"ordinary team-life callback grants one survivor reserve while each restored body spends its new life")
  expect(entry.players.allSatisfy{$0.donationsGiven==0 && $0.donationsReceived==0},"physical statue restoration neither steals donor reserves nor manufactures donation rewards")
  entry.players[2].hero=V2(x:-5,y:-2);entry.players[3].hero=V2(x:-3,y:-2)
  let kept=entry.players.map(\.collectedLives);for _ in 0..<10 {entry.step(0,inputs:[])}
  expect(entry.players.map(\.collectedLives)==kept,"one consumed statue cannot grant more lives on repeated frames")
  for index in [1,2] {entry.players[0].hero=entry.fateRoom!.lifeStatues[index].p;entry.step(0,inputs:[])}
  expect(entry.fateRoom!.lifeStatues.allSatisfy{$0.collectedBy==0} && entry.players.map(\.lives)==[3,2,2,2],"three separate physical statues each retain their one shared team award")
  expect(entry.fateCameraSubjects.count==8,"collected statues no longer add stale high camera subjects")
  let early=game();early.players[0].hero=early.players[1].hero;early.step(0.9,inputs:[])
  expect(early.players[1].isDown && early.players[0].collectedLives==0,"a statue above the living body's collection reach cannot be claimed during early descent")
  let recovered=game();recovered.players[1].reviveRemaining=0.1;recovered.step(0.2,inputs:[])
  expect(!recovered.players[1].isDown && recovered.fateRoom!.lifeStatues[0].collectedBy==nil,"ordinary recovery can finish before landing without deleting its still-falling statue")
  recovered.step(1.1,inputs:[])
  expect(recovered.fateRoom!.lifeStatues[0].collectedBy==1 && recovered.players.map(\.lives)==[1,1],"a target revived normally can physically collect its falling statue for team reserves")
  let capped=game();capped.players[0].lives=9;capped.step(1.3,inputs:[]);capped.players[0].hero=capped.fateRoom!.lifeStatues[0].p;capped.step(0,inputs:[]);capped.stepTeamRecovery(2)
  expect(capped.players[0].lives==9 && !capped.players[1].isDown && capped.players[1].lives==0,"cap at nine does not prevent the same physical item restoring a waiting teammate")
  let missed=game();missed.sideRoom!.clock=FateRoomTiming.choiceEnd;missed.step(0,inputs:[])
  expect(missed.players[1].isDown && missed.fateRoom!.lifeStatues[0].collectedBy==nil,"an uncollected ground statue does not reset the recovery clock at choice timeout")
  missed.sideRoom!.clock=FateRoomTiming.choiceEnd+FateRoomTiming.settle+FateRoomTiming.farewell;missed.step(0,inputs:[]);missed.step(2.7,inputs:[])
  expect(missed.round==16 && missed.fateRoom==nil && missed.players.allSatisfy{$0.collectedLives==0},"own room cleanup carries no unearned life into the next combat arena")
  let reset=game();reset.reset();expect(reset.fateRoom==nil && reset.players.allSatisfy{$0.collectedLives==0},"new run removes all physical statue state")
  print("\(count) fate life statue checks passed;own drop scale/trigger/cleanup and shared staged life callback,not exact original respawn timing")
 }
}
