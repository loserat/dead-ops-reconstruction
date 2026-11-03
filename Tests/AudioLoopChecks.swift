import Foundation

@main struct AudioLoopChecks {
    static func main() {
        setbuf(stdout,nil);var passed=0
        func expect(_ yes:Bool,_ message:String) {guard yes else{fatalError(message)};passed+=1;print("PASS \(message)")}
        var payloads=Set<Data>()
        for kind in AudioLoopKind.allCases {
            let samples=AudioLoopSynth.samples(kind),data=AudioLoopSynth.wav(kind)
            let peak=samples.map{abs($0)}.max()!,rms=sqrt(samples.reduce(0){$0+$1*$1}/Double(samples.count))
            let step=zip(samples,samples.dropFirst()).map{abs($0-$1)}.max()!
            expect(samples.count==AudioSynth.rate && samples.allSatisfy{$0.isFinite} && peak<=0.650001 && rms>0.05,"loop\(kind) has one second of finite bounded signal with real energy")
            expect(abs(samples.first!-samples.last!)<=step*1.001,"loop\(kind) closes without an extra boundary discontinuity")
            expect(data==AudioLoopSynth.wav(kind) && data.count==samples.count*2+44,"loop\(kind) produces repeatable correctly sized WAV without world randomness")
            payloads.insert(data)
        }
        expect(payloads.count==7,"all seven powerup/vehicle/world loop payloads differ;listening acceptance remains separate")
        func request(_ slot:Int=0,_ kind:AudioLoopKind = .boots,_ pan:Double=0)->AudioLoopRequest {AudioLoopRequest(key:AudioLoopKey(slot:slot,kind:kind),pan:pan)}
        let one=request()
        for phase in [RunPhase.title,.paused,.gameOver,.checkpointComplete,.loopReturn] {
            expect(AudioLoopPolicy.normalized([one],enabled:true,phase:phase,level:1).isEmpty,"\(phase) cannot retain a hidden sustained powerup/engine sound")
        }
        for phase in [RunPhase.playing,.cleared,.bonusRoom,.transition] {
            expect(AudioLoopPolicy.normalized([one],enabled:true,phase:phase,level:1)==[one],"\(phase) keeps active carried equipment eligible for a sustained sound")
        }
        expect(AudioLoopPolicy.normalized([one],enabled:false,phase:.playing,level:1).isEmpty && AudioLoopPolicy.normalized([one],enabled:true,phase:.playing,level:0).isEmpty,"master mute and effect volume zero independently remove every sustained voice")
        let normalized=AudioLoopPolicy.normalized([request(-1),request(4),request(0,.boots,.nan),request(1,.hind,4)],enabled:true,phase:.playing,level:1)
        expect(normalized.count==2 && normalized.first{$0.key.slot==0}!.pan==0 && normalized.first{$0.key.slot==1}!.pan==1,"invalid roles are rejected and non-finite or extreme stereo values are bounded")
        let duplicate=AudioLoopPolicy.normalized([request(0,.boots,0.101),request(0,.boots,0.699)],enabled:true,phase:.playing,level:1)
        expect(duplicate.count==1 && duplicate[0].pan==0.7,"one role/kind owns one quantized stereo voice instead of duplicate player sounds")
        let many=(0..<4).flatMap{slot in AudioLoopKind.allCases.map{request(slot,$0)}}
        let capped=AudioLoopPolicy.normalized(many,enabled:true,phase:.playing,level:1)
        expect(capped.count==8 && Set(capped.map(\.key)).count==8 && capped.allSatisfy{$0.key.kind == .tank || $0.key.kind == .hind},"pathological mixed fixtures stay at eight active loops while preserving vehicle cues first")
        expect(AudioLoopPolicy.normalized(many.reversed(),enabled:true,phase:.playing,level:1)==capped,"loop ownership/order is stable regardless of dictionary or request order")
        var transport=AudioLoopTransport();let first=transport.update([one])
        expect(first.started==[one.key] && first.stopped.isEmpty,"a newly active powerup starts exactly one sustained voice")
        let moving=transport.update([request(0,.boots,0.6)])
        expect(moving.started.isEmpty && moving.stopped.isEmpty && transport.active[0].pan==0.6,"moving the same sound in stereo does not restart its waveform")
        let changed=transport.update([request(0,.hind)])
        expect(changed.started==[request(0,.hind).key] && changed.stopped==[one.key],"switching equipment retires only its former voice and starts its new type")
        expect(transport.update([]).stopped==[request(0,.hind).key] && transport.update([]).stopped.isEmpty,"cleanup retires each voice once without repeated stop events")
        let g=GameCore();g.reset(playerCount:4);g.foes=[];g.pickups=[];g.combatSpawningHeld=true
        let control=GameCore();control.reset(playerCount:4)
        g.withPlayer(0){g.boots=5;g.hero=V2(x:-5,y:0)}
        g.withPlayer(1){g.grantBarrelShield();g.hero=V2(x:5,y:0)}
        g.withPlayer(2){g.grantOrbs();g.teddyRemaining=5}
        g.withPlayer(3){g.beginVehicle(.helicopter)}
        let actual=g.loopAudioRequests()
        expect(actual.count==5 && Set(actual.map{$0.key.kind})==[.boots,.barrels,.orbs,.teddy,.hind],"real independent equipment states create the correct five per-owner loop requests")
        expect(actual.first{$0.key.slot==0}!.pan<0 && actual.first{$0.key.slot==1}!.pan>0,"world-left and world-right roles receive opposite stereo positions")
        let before=actual.first{$0.key.slot==0}!.pan;g.round=2
        expect(g.loopAudioRequests().first{$0.key.slot==0}!.pan == -before,"the rotated arena camera reverses stereo consistently with visible screen direction")
        expect(g.loopAudioRequests(centerX:.nan,halfWidth:.nan).allSatisfy{$0.pan.isFinite && abs($0.pan)<=1},"transient invalid camera values cannot become invalid audio pan")
        expect(g.random()==control.random(),"taking sustained sound snapshots never consumes the gameplay/drop random stream")
        g.players[3].isDown=true
        expect(!g.loopAudioRequests().contains{$0.key.slot==3},"a waiting body cannot keep its former vehicle sound alive")
        g.players[2].orbShields=[]
        expect(!g.loopAudioRequests().contains{$0.key.kind == .orbs} && g.loopAudioRequests().contains{$0.key.kind == .teddy},"consumed physical orbs stop their sound while independent teddy protection continues")
        let expiry=GameCore();expiry.reset();expiry.foes=[];expiry.pickups=[];expiry.combatSpawningHeld=true;expiry.boots=0.01
        expiry.step(0.02,input:Controls())
        expect(!expiry.loopAudioRequests().contains{$0.key.kind == .boots},"actual timer expiry removes the boots sound without a delayed UI refresh")
        expiry.apply(.helicopter);expiry.round=9;expiry.phase = .cleared;expiry.cleanupSourceRoundVehicles()
        expect(!expiry.loopAudioRequests().contains{$0.key.kind == .hind},"actual prison Hind cleanup also removes its engine sound request")
        let sentry=GameCore();sentry.reset();sentry.foes=[];_=sentry.takeAudioEvents();sentry.addSentry(at:.zero)
        expect(sentry.takeAudioEvents()==[.sentryArrival],"real turret grant emits the archived incoming-event replacement once")
        sentry.stepSentries(2)
        expect(sentry.takeAudioEvents()==[.sentryLand] && sentry.sentries[0].motion == .active,"actual physical landing emits one separate turret impact cue")
        sentry.stepSentries(0);expect(sentry.takeAudioEvents().isEmpty,"a resting turret cannot replay its landing cue every frame")
        sentry.phase = .cleared;sentry.stepSentries(0)
        expect(sentry.takeAudioEvents()==[.sentryDepart] && sentry.sentries[0].motion == .leaving,"real intermission departure emits a separate one-time outgoing cue")
        sentry.stepSentries(0.1);expect(sentry.takeAudioEvents().isEmpty,"continued departure does not repeatedly trigger the outgoing cue")
        let stowed=GameCore();stowed.reset();stowed.phase = .bonusRoom;_=stowed.takeAudioEvents();stowed.addSentry(at:.zero)
        expect(stowed.takeAudioEvents().isEmpty,"stowed room equipment cannot announce an incoming turret before deployment")
        stowed.deployStowedSupport();stowed.deployStowedSupport()
        expect(stowed.takeAudioEvents()==[.sentryArrival],"actual stowed deployment announces its first incoming turret only once")
        let bulls=GameCore();bulls.reset();_=bulls.takeAudioEvents();bulls.bulls=[Bull(id:90000,p:.zero,direction:V2(x:1,y:0)),Bull(id:90001,p:.zero,direction:V2(x:1,y:0),golden:true)]
        bulls.explodeBulls(at:.zero,radius:2);let bullCues=bulls.takeAudioEvents()
        expect(bullCues.filter{$0 == .explosion}.count==2 && bullCues.filter{$0 == .goldenBull}.count==1,"normal and sacred buffalo both explode while only the sacred one emits its distinct reward cue")
        let crowded=GameCore();crowded.reset();_=crowded.takeAudioEvents()
        for _ in 0..<100 {crowded.emitAudio(.minigun)}
        crowded.emitAudio(.life);crowded.emitAudio(.hurt);let important=crowded.takeAudioEvents()
        expect(important.count==32 && important.contains(.life) && important.contains(.hurt),"a full automatic-fire event queue cannot discard later life or damage notifications")
        var safe=true
        for loopCount in 0...16 {for shotCount in 0...AudioMix.maxVoices {for offset in 0..<AudioCue.allCases.count {
            let loops=(0..<loopCount).map{AudioLoopKind.allCases[$0%AudioLoopKind.allCases.count]},shots=(0..<shotCount).map{AudioCue.allCases[($0+offset)%AudioCue.allCases.count]}
            let weight=loops.reduce(0.0){$0+$1.gain}+shots.reduce(0.0){$0+$1.gain}
            let gain=loops.reduce(0.0){$0+Double(AudioMix.loopGain($1,totalWeight:weight,level:1,master:1))}+shots.reduce(0.0){$0+Double(AudioMix.voiceGain($1,totalWeight:weight,level:1,master:1))}
            safe = safe && gain<=AudioMix.effectBudget+0.00001 && gain*0.9+Double(AudioMix.musicGain(level:1,master:1,returning:false))<1
        }}}
        expect(safe,"eight active plus eight fading loops share one bounded effect budget with twelve shots and music")
        expect(AudioLoopPolicy.fadeOut==0.5,"powerup tails use the archived half-second stop-loop fade duration")
        print("\(passed) audio loop checks passed;seven own sustained signals,source event timing,role ownership/stereo/lifecycle/shared headroom;no audio output,not listening or hardware acceptance")
    }
}
