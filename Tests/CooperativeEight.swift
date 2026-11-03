import Foundation
@main struct CooperativeEight {
 static func main(){
  setbuf(stdout,nil)
  for (count,warmup) in [(2,0),(4,31),(2,113)] {
   let g=GameCore();for _ in 0..<warmup {_=g.random()};g.reset(playerCount:count)
   let pilots=(0..<count).map{_ in NormalPilot()}
   var time=0.0,frames=0,invalid=0,round=0,rooms=0,lastPhase=g.phase
   while time<1800 && (g.round<=8 || g.phase == .transition) && g.phase != .gameOver {
    var inputs=[Controls]()
    for slot in g.players.indices {
     inputs.append(g.withPlayer(slot){g.isPlayerActive ? pilots[slot].sample(g):Controls()}!)
    }
    g.step(1.0/60,inputs:inputs);time+=1.0/60;frames+=1
    for p in g.players {if !p.hero.x.isFinite || !p.hero.y.isFinite || !g.layout.walkable(p.hero,clearance:0.24) {invalid+=1}}
    if round != g.round {round=g.round;print("RUN team\(count) seed\(warmup) round\(round) at\(Int(time))s lives\(g.players.map(\.lives)) deaths\(g.players.map(\.deaths))")}
    if g.phase == .bonusRoom && lastPhase != .bonusRoom {rooms+=1};lastPhase=g.phase
   }
   print("RESULT team\(count) seed\(warmup):round\(g.round),phase\(g.phase),time\(time),frames\(frames),lives\(g.players.map(\.lives)),deaths\(g.players.map(\.deaths)),score\(g.players.map(\.score)),invalid\(invalid)")
   precondition(g.round==9 && g.phase == .playing && !g.godMode && !g.usedGodMode && invalid==0 && g.players.allSatisfy{$0.trainingHits==0 && $0.score>0} && abs(g.elapsed-time)<0.00001,"normal cooperative first-eight run failed")
   print("PASS cooperative first eight:team\(count),seed\(warmup),\(Int(time))simulatedSeconds,\(frames)sharedFrames,\(rooms)sideRooms,0invalidPositions,noGodmodeOrInjectedEquipment;simulation only,no controller/render/hardware claim")
  }
 }
}
