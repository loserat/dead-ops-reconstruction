import Foundation

@main struct CharacterMotionChecks {
    static func main(){
        var count=0
        func expect(_ value:Bool,_ message:String){count+=1;if !value{fatalError("FAIL character motion: "+message)};print("PASS "+message)}
        func close(_ a:Double,_ b:Double)->Bool {abs(a-b)<1e-7}
        func update(_ gait:inout CharacterLocomotion,_ p:V2,_ t:Double,_ revision:Int=1,_ active:Bool=true,_ boost:Bool=false){gait.update(position:p,clock:t,revision:revision,speed:6.4,active:active,boosting:boost)}
        let expectedPhase=(6.4*CharacterLocomotion.radiansPerUnit).truncatingRemainder(dividingBy:2*Double.pi)
        for rate in [30,60,120] {
            var gait=CharacterLocomotion();update(&gait,.zero,0)
            for i in 1...rate {let t=Double(i)/Double(rate);update(&gait,V2(x:6.4*t,y:0),t)}
            expect(close(gait.phase,expectedPhase) && close(gait.amount,1-exp(-14)),"actual distance and exponential blend agree at\(rate) updates")
            expect(gait.worldDirection==V2(x:1,y:0) && gait.localDirection(facing:V2(x:0,y:-1))==V2(x:1,y:0),"world-right stride remains a side step while aiming north at\(rate) updates")
        }
        var gait=CharacterLocomotion();update(&gait,.zero,0);update(&gait,V2(x:0.64,y:0),0.1)
        let phase=gait.phase,amount=gait.amount
        update(&gait,V2(x:0.64,y:0),0.1);update(&gait,V2(x:0.64,y:0),0.1)
        expect(gait.phase==phase && gait.amount==amount,"repeated frozen simulation clock cannot age or rotate the running pose")
        for i in 1...60 {update(&gait,V2(x:0.64,y:0),0.1+Double(i)/60)}
        expect(gait.phase==phase && gait.amount<0.000001,"blocked or stopped body blends to idle without running in place")
        update(&gait,V2(x:1.28,y:0),1.2);let moving=gait.phase
        update(&gait,V2(x:20,y:20),1.3)
        expect(gait.phase==moving && gait.amount==0,"teleport does not invent a huge running stride or leave moving limbs")
        update(&gait,V2(x:20.64,y:20),1.4,2)
        expect(gait.phase==moving && gait.amount==0,"new environment revision resets visual movement without a false map-crossing step")
        update(&gait,V2(x:21.28,y:20),1.5,2)
        expect(gait.amount>0.7 && gait.phase != moving,"first actual post-teleport displacement resumes ordinary gait")
        let beforeWarp=gait.phase;update(&gait,V2(x:21.3,y:20),4,2)
        expect(gait.phase==beforeWarp && gait.amount==0,"long unobserved render gap cannot catch up a burst of gait cycles")
        var snap=CharacterLocomotion();update(&snap,.zero,0);update(&snap,V2(x:0.64,y:0),0.1);let snapPhase=snap.phase;update(&snap,V2(x:10,y:10),0.1)
        expect(snap.phase==snapPhase && snap.amount==0,"same-clock teleport resets residual running pose without disturbing ordinary paused frames")
        var boost=CharacterLocomotion();update(&boost,.zero,0);update(&boost,V2(x:0.64,y:0),0.1)
        let prior=boost.phase,priorAmount=boost.amount;update(&boost,V2(x:2.64,y:0),0.2,1,true,true)
        expect(boost.phase==prior && boost.amount<priorAmount,"actual boost travel does not turn legs into a fast flickering treadmill")
        update(&boost,V2(x:2.64,y:0),0.3,1,false)
        expect(boost.phase==prior,"inactive physical body does not gain walking phase during recovery")
        let validPhase=boost.phase,validAmount=boost.amount
        boost.update(position:V2(x:.nan,y:0),clock:1,revision:1,speed:6.4,active:true,boosting:false)
        boost.update(position:.zero,clock:.infinity,revision:1,speed:6.4,active:true,boosting:false)
        boost.update(position:.zero,clock:1,revision:1,speed:0,active:true,boosting:false)
        expect(boost.phase==validPhase && boost.amount==validAmount,"nonfinite coordinates clocks and invalid speed cannot contaminate visible transforms")
        var heading=CharacterLocomotion();update(&heading,.zero,0);update(&heading,V2(x:0.64,y:0),0.1)
        expect(heading.localDirection(facing:V2(x:1,y:0))==V2(x:0,y:-1),"aiming in actual travel direction produces a forward local stride")
        expect(heading.localDirection(facing:V2(x:-1,y:0))==V2(x:0,y:1),"aiming opposite travel produces a backward local stride")
        expect(heading.localDirection(facing:.zero)==V2(x:1,y:0),"absent look direction uses finite north-oriented local basis")
        let forward=CharacterLegPose.plan(phase:Double.pi/2,amount:1,direction:V2(x:0,y:-1),left:true)
        let reverse=CharacterLegPose.plan(phase:Double.pi/2,amount:1,direction:V2(x:0,y:1),left:true)
        expect(forward.pitch>0.5 && close(forward.pitch,-reverse.pitch) && forward.roll==0,"forward and backward movement produce opposite hip pitch without lateral drift")
        let side=CharacterLegPose.plan(phase:Double.pi/2,amount:1,direction:V2(x:1,y:0),left:false)
        let inward=CharacterLegPose.plan(phase:Double.pi/2,amount:1,direction:V2(x:1,y:0),left:true)
        expect(side.pitch==0 && inward.pitch==0 && abs(side.roll)>0 && abs(inward.roll)<=0.075 && side.yaw<0,"real side steps use roll and bounded inward reach without forward-running hips")
        for angle in stride(from:0.0,to:2*Double.pi,by:Double.pi/4) {
            let direction=V2(x:cos(angle),y:sin(angle))
            for left in [true,false] {
                let pose=CharacterLegPose.plan(phase:1.1,amount:1,direction:direction,left:left)
                expect([pose.pitch,pose.roll,pose.yaw,pose.knee].allSatisfy(\.isFinite) && pose.knee>=0 && pose.knee<=0.68,"eight-direction leg pose keeps finite transforms and forward-only anatomical knee bend")
            }
        }
        let idle=CharacterLegPose.plan(phase:1,amount:0,direction:V2(x:1,y:1),left:true)
        expect(idle.pitch==0 && idle.roll==0 && idle.yaw==0 && idle.knee==0,"idle clears all hip and knee axes after a side or backward run")
        let bad=CharacterLegPose.plan(phase:.nan,amount:.infinity,direction:V2(x:.nan,y:0),left:true)
        expect([bad.pitch,bad.roll,bad.yaw,bad.knee].allSatisfy(\.isFinite),"invalid external pose values cannot create NaN scene matrices")
        for index in 0..<8 {
            let angle=Double(index)*Double.pi/4,direction=V2(x:cos(angle),y:sin(angle))
            let g=GameCore();g.reset();g.combatSpawningHeld=true;g.sourceLoot=nil;g.foes=[];g.pickups=[];g.hero=V2(x:-2,y:-2)
            let initial=g.hero;var real=CharacterLocomotion();update(&real,g.hero,g.elapsed)
            for _ in 0..<24 {g.step(1/60,input:Controls(move:direction,aim:V2(x:0,y:-1)));update(&real,g.hero,g.elapsed)}
            let traveled=g.hero-initial
            expect(close(traveled.length,6.4*0.4) && (traveled.unit-direction).length<1e-7 && (real.localDirection(facing:g.facing)-direction).length<1e-7,"actual world input\(index) drives local gait from reached displacement with gameplay speed unchanged")
            expect(g.facing==V2(x:0,y:-1) && !g.shots.isEmpty && g.shots.allSatisfy{abs($0.v.x)<1e-7 && $0.v.y<0},"actual strafe input\(index) retains independent weapon aim and real projectile heading")
        }
        let team=GameCore();team.reset(playerCount:2);team.combatSpawningHeld=true;team.sourceLoot=nil;team.foes=[];team.pickups=[]
        team.players[0].hero=V2(x:-2,y:-3);team.players[1].hero=V2(x:2,y:-3)
        var owners=[CharacterLocomotion(),CharacterLocomotion()]
        for i in 0..<2 {update(&owners[i],team.players[i].hero,team.elapsed)}
        for _ in 0..<12 {
            team.step(1/60,inputs:[Controls(move:V2(x:1,y:0)),Controls(move:V2(x:0,y:0.5))])
            for i in 0..<2 {update(&owners[i],team.players[i].hero,team.elapsed)}
        }
        expect(owners[0].worldDirection==V2(x:1,y:0) && owners[1].worldDirection==V2(x:0,y:1) && close(owners[0].phase,owners[1].phase*2),"two actual players retain separate directions analogue speed and per-role gait phase")
        print("\(count) character motion checks passed")
    }
}
