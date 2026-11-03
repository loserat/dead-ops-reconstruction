import Foundation
import SceneKit
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
import Metal
final class AppDelegate:NSObject,NSApplicationDelegate,NSWindowDelegate {
    var window:NSWindow!,game:ArcadeGame!
    static func startingContentRect(visibleFrame:NSRect)->NSRect {
        let width=min(1280,max(1,visibleFrame.width-80),max(1,visibleFrame.height-100)*(16.0/9))
        return NSRect(x:0,y:0,width:width,height:width*(9.0/16))
    }
    func applicationDidFinishLaunching(_ notification:Notification) {
        let screen=NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:900)
        let rect=Self.startingContentRect(visibleFrame:screen)
        window=NSWindow(contentRect:rect,styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.delegate=self
        let version=Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "0.30"
        window.title="Dead Ops · Rekonstruktion \(version)"
        window.contentMinSize=NSSize(width:min(960,rect.width),height:min(540,rect.height))
        let v=GameView(frame:rect);window.contentView=v;game=ArcadeGame(view:v)
        game.testPilot=ProcessInfo.processInfo.arguments.contains("--test-pilot")
        window.center();window.makeKeyAndOrderFront(nil);window.makeFirstResponder(v)
        NSApplication.shared.activate(ignoringOtherApps:true)
        let menu=NSMenu();let app=NSMenuItem();menu.addItem(app);let sub=NSMenu();app.submenu=sub
        let settingsItem=sub.addItem(withTitle:"Einstellungen …",action:#selector(openSettings),keyEquivalent:",");settingsItem.target=self
        let musicItem=sub.addItem(withTitle:"Musik hinzufügen …",action:#selector(importMusic),keyEquivalent:"m");musicItem.target=self
        sub.addItem(NSMenuItem.separator())
        sub.addItem(withTitle:"Beenden",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");NSApplication.shared.mainMenu=menu
    }
    @objc func importMusic(){
        game.input.pendingSystemPause=true
        let panel=NSOpenPanel();panel.title="Musik hinzufügen";panel.message="Wähle vorhandene Musikdateien. Die Originaldateien bleiben erhalten."
        panel.allowedContentTypes=[.audio];panel.allowsMultipleSelection=true;panel.canChooseDirectories=false
        panel.beginSheetModal(for:window){[weak self] result in
            guard result == .OK else{return};self?.game.music.importFiles(panel.urls)
        }
    }
    @objc func openSettings(){game.input.pendingSettings=true}
    private func suspendGameAudio(){
        guard let game else{return}
        game.input.pendingSystemPause=true
        game.audio.setApplicationActive(false);game.music.setApplicationActive(false)
    }
    private func restoreAudioEligibility(){
        guard let game else{return}
        let active=window?.isMiniaturized != true
        game.audio.setApplicationActive(active);game.music.setApplicationActive(active)
    }
    func applicationWillResignActive(_ notification:Notification){suspendGameAudio()}
    func applicationDidBecomeActive(_ notification:Notification){restoreAudioEligibility()}
    func windowDidResignKey(_ notification:Notification){suspendGameAudio()}
    func windowDidMiniaturize(_ notification:Notification){suspendGameAudio()}
    func windowDidBecomeKey(_ notification:Notification){restoreAudioEligibility()}
    func windowDidDeminiaturize(_ notification:Notification){if NSApplication.shared.isActive {restoreAudioEligibility()}}
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool{true}
}
@main struct NativeLauncher {
    static func main() {
        let app=NSApplication.shared,args=ProcessInfo.processInfo.arguments
        if let index=args.firstIndex(of:"--verify-defeated-bodies") {
            app.setActivationPolicy(.prohibited)
            guard args.count==index+2 else{fputs("Usage: --verify-defeated-bodies OUTPUT_DIRECTORY\n",stderr);exit(2)}
            do{_ = try DefeatedBodyRenderVerification.run(URL(fileURLWithPath:args[index+1],isDirectory:true))}
            catch{fputs("Body fall rendering failed: \(error)\n",stderr);exit(1)}
            return
        }
        if let index=args.firstIndex(of:"--verify-package") {
            app.setActivationPolicy(.prohibited)
            guard args.count==index+2 else{fputs("Usage: --verify-package OUTPUT_DIRECTORY\n",stderr);exit(2)}
            do{try MacPackageVerification.run(URL(fileURLWithPath:args[index+1],isDirectory:true))}
            catch{fputs("Package verification failed: \(error)\n",stderr);exit(1)}
            return
        }
        if let index=args.firstIndex(of:"--verify-team-art") {
            app.setActivationPolicy(.prohibited)
            guard args.count==index+2 else{fputs("Usage: --verify-team-art OUTPUT_DIRECTORY\n",stderr);exit(2)}
            do{try TeamRenderVerification.run(URL(fileURLWithPath:args[index+1],isDirectory:true))}
            catch{fputs("Team rendering failed: \(error)\n",stderr);exit(1)}
            return
        }
        if let index=args.firstIndex(of:"--verify-opening-maps") {
            app.setActivationPolicy(.prohibited)
            guard args.count==index+2 else{fputs("Usage: --verify-opening-maps OUTPUT_DIRECTORY\n",stderr);exit(2)}
            do{try OpeningMapRenderVerification.run(URL(fileURLWithPath:args[index+1],isDirectory:true))}
            catch{fputs("Opening maps failed: \(error)\n",stderr);exit(1)}
            return
        }
        if let index=args.firstIndex(of:"--verify-character-art") {
            app.setActivationPolicy(.prohibited)
            guard args.count==index+2 else{fputs("Usage: --verify-character-art OUTPUT_DIRECTORY\n",stderr);exit(2)}
            do{try CharacterRenderVerification.run(URL(fileURLWithPath:args[index+1],isDirectory:true))}
            catch{fputs("Character rendering failed: \(error)\n",stderr);exit(1)}
            return
        }
        if let index=args.firstIndex(of:"--verify-camera-art") {
            app.setActivationPolicy(.prohibited)
            guard args.count==index+2 else{fputs("Usage: --verify-camera-art OUTPUT_DIRECTORY\n",stderr);exit(2)}
            do{try CameraRenderVerification.run(URL(fileURLWithPath:args[index+1],isDirectory:true))}
            catch{fputs("Camera rendering failed: \(error)\n",stderr);exit(1)}
            return
        }
        if let index=args.firstIndex(of:"--verify-look-art") {
            app.setActivationPolicy(.prohibited)
            guard args.count==index+2 else{fputs("Usage: --verify-look-art OUTPUT_DIRECTORY\n",stderr);exit(2)}
            do{try LookRenderVerification.run(URL(fileURLWithPath:args[index+1],isDirectory:true))}
            catch{fputs("Look rendering failed: \(error)\n",stderr);exit(1)}
            return
        }
        if let index=args.firstIndex(of:"--verify-boss-art") {
            app.setActivationPolicy(.prohibited)
            guard args.count==index+2 else{fputs("Usage: --verify-boss-art OUTPUT_DIRECTORY\n",stderr);exit(2)}
            do{try BossRenderVerification.run(URL(fileURLWithPath:args[index+1],isDirectory:true))}
            catch{fputs("Boss rendering failed: \(error)\n",stderr);exit(1)}
            return
        }
        if args.dropFirst().contains(where:{$0.hasPrefix("--verify-")}) {
            app.setActivationPolicy(.prohibited)
            fputs("Unknown verification mode; refusing a regular game launch.\n",stderr);exit(2)
        }
        let delegate=AppDelegate();app.delegate=delegate;app.setActivationPolicy(.regular);app.run();_ = delegate
    }
}
/// Explicit command-line verification of the actual built Mac app, with no window, input polling or audio.
private enum MacPackageVerification {
    static func run(_ output:URL)throws {
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let resources=Bundle.main.resourceURL!
        let graphics=try FileManager.default.contentsOfDirectory(at:resources.appendingPathComponent("Assets"),includingPropertiesForKeys:nil).filter{$0.pathExtension.lowercased()=="png"}
        guard graphics.count==14,graphics.allSatisfy({(NSImage(contentsOf:$0)?.size.width ?? 0)>0}),
              [ArenaKind.island,.courtyard].allSatisfy({OpeningTerrainSurface.readBaked(resources.appendingPathComponent("Assets/"+OpeningTerrainSurface.filename($0)),kind:$0) != nil}) else{throw NSError(domain:"DeadOpsPackage",code:1)}
        let game=ArcadeGame(view:GameView(frame:NSRect(x:0,y:0,width:1600,height:900)),defaults:nil)
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil);renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
        func snapshot(_ name:String)throws {
            game.lastTime=ProcessInfo.processInfo.systemUptime;game.tick(controls:Controls(),viewSize:CGSize(width:1600,height:900))
            let image=renderer.snapshot(atTime:ProcessInfo.processInfo.systemUptime,with:CGSize(width:1600,height:900),antialiasingMode:.multisampling4X)
            guard let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil),let data=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:]) else{throw NSError(domain:"DeadOpsPackage",code:2)}
            try data.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting)
        }
        for round in [1,9] {
            game.core.reset();game.core.round=round;game.core.pickups=[];game.core.beginRound();game.core.hero=game.core.layout.spawn;game.core.heroElevation=game.core.layout.height(game.core.hero)
            game.core.combatSpawningHeld=true;game.core.invulnerable=999;game.settings.playerColor = .blue
            try snapshot("arena-\(round)")
        }
        game.core.lives=1;game.core.invulnerable=0;game.core.loseLife()
        guard game.core.lives==1,game.core.players[0].isDown,game.core.players[0].respawnRemaining==2 else{throw NSError(domain:"DeadOpsPackage",code:10)}
        try snapshot("reserve-return-pending")
        game.core.stepTeamRecovery(2)
        guard game.core.lives==0,game.core.phase == .playing,game.core.isPlayerActive else{throw NSError(domain:"DeadOpsPackage",code:4)}
        try snapshot("reserve-zero")
        game.core.invulnerable=0;game.core.playerRoster.current.bodyShield=nil;game.core.loseLife()
        guard game.core.phase == .gameOver,game.core.players[0].isDown else{throw NSError(domain:"DeadOpsPackage",code:5)}
        game.core.step(3.7,input:Controls());try snapshot("ending")
        // Exercise the same render-owned input/menu route without polling real controllers.
        game.core.reset(playerCount:2);game.core.foes=[];game.core.pickups=[];game.core.combatSpawningHeld=true
        let pads=[InputDeviceStatus(token:"proof-a",name:"Synthetic pad A",connected:true),InputDeviceStatus(token:"proof-b",name:"Synthetic pad B",connected:true)]
        let positions=game.core.players.map(\.hero)
        func tick(_ players:[Controls],devices:[InputDeviceStatus]?=nil,operatorControls:Controls=Controls()) {
            game.lastTime=ProcessInfo.processInfo.systemUptime-0.02
            game.tick(players:players,devices:devices ?? pads,viewSize:CGSize(width:1600,height:900),availableControllers:2,operatorControls:operatorControls)
        }
        tick([Controls(move:V2(x:-1,y:0)),Controls(move:V2(x:1,y:0))])
        guard game.core.players[0].hero.x<positions[0].x,game.core.players[1].hero.x>positions[1].x,game.core.elapsed>0,game.core.elapsed<=0.05,game.inputMailbox.routing().count==2 else{throw NSError(domain:"DeadOpsPackage",code:6)}
        let elapsed=game.core.elapsed
        tick([Controls(),Controls(pause:true)])
        guard game.core.phase == .paused,game.core.elapsed==elapsed else{throw NSError(domain:"DeadOpsPackage",code:7)}
        let absent=[pads[0],InputDeviceStatus(token:"proof-b",name:"Synthetic pad B",connected:false)]
        tick([Controls(),Controls()],devices:absent,operatorControls:Controls(accept:true))
        guard game.core.phase == .paused else{throw NSError(domain:"DeadOpsPackage",code:8)}
        tick([Controls(),Controls(accept:true)])
        guard game.core.phase == .playing,game.core.elapsed==elapsed else{throw NSError(domain:"DeadOpsPackage",code:9)}
        tick([Controls(),Controls()],operatorControls:Controls(pause:true))
        guard game.core.phase == .paused else{throw NSError(domain:"DeadOpsPackage",code:10)}
        let host=AppDelegate();host.game=game
        for signal in 0..<3 {
            game.core.phase = .playing;game.input.pendingSystemPause=false
            switch signal {
            case 0:host.applicationWillResignActive(Notification(name:NSApplication.willResignActiveNotification))
            case 1:host.windowDidResignKey(Notification(name:NSWindow.didResignKeyNotification))
            default:host.windowDidMiniaturize(Notification(name:NSWindow.didMiniaturizeNotification))
            }
            guard game.input.pendingSystemPause,!game.audio.isApplicationActive,!game.music.isApplicationActive else{throw NSError(domain:"DeadOpsPackage",code:11)}
            tick([Controls(),Controls()],operatorControls:Controls(systemPause:game.input.pendingSystemPause));game.input.pendingSystemPause=false
            guard game.core.phase == .paused else{throw NSError(domain:"DeadOpsPackage",code:12)}
            host.applicationDidBecomeActive(Notification(name:NSApplication.didBecomeActiveNotification))
            guard game.core.phase == .paused,game.audio.isApplicationActive,game.music.isApplicationActive else{throw NSError(domain:"DeadOpsPackage",code:13)}
        }
        print("PASS native lifecycle callbacks:appresign/windowresign/minimize,immediateeffect/musicoutputgates,renderownedpause,nextappactivationdoesnotresumegame;synthetic notifications,no actual focus or hardware")
        guard game.audio.voiceCount==0,game.audio.playedCount==0,game.music.playedCount==0 else{throw NSError(domain:"DeadOpsPackage",code:3)}
        print("PASS built Mac package:version\(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") ?? "unknown"),14decodedPNGassets,5nativeScenes,two-second funded return then zero-reserve body,synthetic two-player render-input and missing-pad pause gate,0audio,no window or live-input polling;not physical/controller/windowFPS acceptance")
    }
}
#else
import UIKit
final class GameViewController:UIViewController {
    var game:ArcadeGame!
    override func loadView(){view=GameView(frame:UIScreen.main.bounds)}
    override func viewDidLoad(){super.viewDidLoad();game=ArcadeGame(view:view as! GameView)}
    override func pressesBegan(_ presses:Set<UIPress>,with event:UIPressesEvent?){
        if presses.contains(where:{$0.type == .select}){game.input.pendingAccept=true}
        else if presses.contains(where:{$0.type == .upArrow}){game.input.menuArrow(126)}
        else if presses.contains(where:{$0.type == .downArrow}){game.input.menuArrow(125)}
        else if presses.contains(where:{$0.type == .leftArrow}){game.input.menuArrow(123)}
        else if presses.contains(where:{$0.type == .rightArrow}){game.input.menuArrow(124)}
        else if presses.contains(where:{$0.type == .menu}){game.input.pendingPause=true}
        else{super.pressesBegan(presses,with:event)}
    }
    override func pressesEnded(_ presses:Set<UIPress>,with event:UIPressesEvent?){
        for p in presses {switch p.type {case .upArrow:game.input.keys.remove(126);case .downArrow:game.input.keys.remove(125);case .leftArrow:game.input.keys.remove(123);case .rightArrow:game.input.keys.remove(124);default:break}}
        super.pressesEnded(presses,with:event)
    }
    override func pressesCancelled(_ presses:Set<UIPress>,with event:UIPressesEvent?){game.input.keys=[];super.pressesCancelled(presses,with:event)}
}
@main final class AppDelegate:UIResponder,UIApplicationDelegate {
    var window:UIWindow?
    func application(_ application:UIApplication,didFinishLaunchingWithOptions launchOptions:[UIApplication.LaunchOptionsKey:Any]?)->Bool {
        let w=UIWindow(frame:UIScreen.main.bounds);w.rootViewController=GameViewController();w.makeKeyAndVisible();window=w
        application.isIdleTimerDisabled=true
        NotificationCenter.default.addObserver(forName:UIApplication.willResignActiveNotification,object:nil,queue:.main){[weak w] _ in
            if let c=w?.rootViewController as? GameViewController {
                c.game.input.pendingSystemPause=true
                c.game.audio.setApplicationActive(false);c.game.music.setApplicationActive(false)
            }
        }
        NotificationCenter.default.addObserver(forName:UIApplication.didBecomeActiveNotification,object:nil,queue:.main){[weak w] _ in
            if let c=w?.rootViewController as? GameViewController {
                c.game.audio.setApplicationActive(true);c.game.music.setApplicationActive(true)
            }
        }
        return true
    }
}
#endif
