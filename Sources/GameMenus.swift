import Foundation
import SpriteKit
import SceneKit

extension ArcadeGame {
    var controllersReady:Bool {inputDevices.isEmpty ? settingsDefaults==nil:inputDevices.count>=core.playerCount && inputDevices.prefix(core.playerCount).allSatisfy(\.connected)}
    var soloStartReady:Bool {
        #if os(macOS)
        return true
        #else
        return inputDevices.first?.connected==true
        #endif
    }
    var requestedInputRouting:InputRouting {InputRouting(count:menu.teamOpen ? menu.teamCount:core.playerCount,keyboardPlayer:menu.teamOpen ? menu.teamKeyboard:keyboardPlayer)}
    var teamStartReady:Bool {
        let routing=requestedInputRouting
        guard menu.teamOpen,inputMailbox.routing()==routing,inputDevices.count==routing.count else{return false}
        return inputDevices.prefix(routing.count).enumerated().allSatisfy{slot,device in
            device.connected && device.token != nil && ((device.token=="keyboard") == (slot==0 && routing.keyboardPlayer))
        }
    }
    func menuRowY(_ row:Int)->CGFloat {446-CGFloat(row)*(menu.teamOpen ? 42:50)}
    func buildMenus() {
        endingBars.zPosition=5;endingBars.isHidden=true;hudCanvas.addChild(endingBars)
        for (y,h) in [(665.0,130.0),(42.0,84.0)] {
            let bar=SKShapeNode(rectOf:CGSize(width:1280,height:h));bar.position=CGPoint(x:640,y:y)
            bar.fillColor=rgb(0x081316);bar.strokeColor = .clear;endingBars.addChild(bar)
        }
        for i in 0..<8 {
            let y=446-CGFloat(i)*50
            let highlight=SKShapeNode(rectOf:CGSize(width:760,height:40),cornerRadius:8)
            highlight.position=CGPoint(x:640,y:y+6);highlight.zPosition=6
            highlight.fillColor=rgb(0x24362b,0.95);highlight.strokeColor=rgb(0xd7c078);highlight.lineWidth=2
            hudCanvas.addChild(highlight);menuHighlights.append(highlight)
            let name=SKLabelNode(fontNamed:"AvenirNext-DemiBold"),value=SKLabelNode(fontNamed:"AvenirNext-Medium")
            label(name,23,0xe8e8d3,294,y,align:.left);label(value,23,0xe5ce86,982,y,align:.right)
            name.zPosition=7;value.zPosition=7;menuNames.append(name);menuValues.append(value)
        }
        label(modeLabel,16,0xffd476,30,32,align:.left)
        #if os(macOS)
        view.menuClick={ [weak self] point in
            guard let self else{return}
            // The main thread only publishes a virtual row. Render-owned state determines its meaning.
            if (260...1020).contains(point.x),point.y>=128 && point.y<=476 {
                input.pendingMenuPoint=V2(x:Double(point.x),y:Double(point.y))
            }
        }
        #endif
    }
    func handleMenus(_ controls:Controls,dt:Double,players:[Controls]?=nil) {
        if core.phase == .gameOver,core.gameOverSequence?.finished==false {
            core.step(dt,input:controls);menu.sync(core.phase);return
        }
        if controls.openSettings && (core.phase == .playing || core.phase == .cleared || core.phase == .bonusRoom || core.phase == .transition) {
            core.step(0,input:Controls(pause:true));menu.openSettings(phase:core.phase);return
        }
        let wasVisible=menu.visible(core.phase)
        #if os(macOS)
        let allowKeyboard=true
        #else
        let allowKeyboard=false
        #endif
        let action=menu.handle(controls,phase:core.phase,allowKeyboard:allowKeyboard,availableControllers:availableControllers)
        switch action {
        case .start:if soloStartReady {keyboardPlayer=false;core.reset(playerCount:1)}
        case .startTeam(let count,let keyboard):if teamStartReady {keyboardPlayer=keyboard;core.reset(playerCount:count)}
        case .teamColor(let slot,let delta):settings.adjustColor(slot:slot,delta:delta);settings.save(settingsDefaults)
        case .resume:if controllersReady {core.step(0,input:Controls(accept:true))}
        case .setting(let row,let delta):
            settings.adjust(row:row,delta:delta);settings.save(settingsDefaults)
            core.godMode=settings.godMode
            if core.godMode && core.phase != .title {core.usedGodMode=true}
        case .audioSetting(let row,let delta):settings.adjustAudio(row:row,delta:delta);settings.save(settingsDefaults)
        case .musicTrack(let delta):music.select(delta)
        case .none:if !wasVisible {
            var inputs=players ?? [controls]
            if inputs.isEmpty {inputs=[Controls()]}
            inputs[0].pause = inputs[0].pause || controls.pause
            inputs[0].systemPause = inputs[0].systemPause || controls.systemPause
            core.step(dt,inputs:inputs.map(core.viewOrientation.worldControls))
        }
        }
        menu.sync(core.phase)
    }
    func updateMenuHUD() {
        let ending=core.phase == .gameOver && core.gameOverSequence != nil
        endingBars.isHidden = !(ending && core.gameOverSequence?.finished==false)
        readabilityHUD.isHidden=ending
        for node in [stat,score,roundLabel,notice,weaponLabel,fateLabel,nextLifeLabel] {node.isHidden=ending}
        multiplierFill.isHidden=ending;supportLabel.isHidden=ending
        if ending {vehicleLabel.isHidden=true;pickupHintLabel.isHidden=true;bossHUD.isHidden=true}
        if ending,let sequence=core.gameOverSequence,!sequence.finished {
            curtain.isHidden=true;title.isHidden=false;sub.isHidden=false;hint.isHidden=false;modeLabel.isHidden=true
            title.text="GAME OVER";title.position.y=658
            sub.text="\(runScore) PUNKTE · RUNDE \(core.round)";sub.position.y=616
            hint.text=sequence.caption+" · \(acceptHint) "+(sequence.suspended ? "fortsetzen":"überspringen")
            hint.position.y=48
            for node in menuNames+menuValues {node.isHidden=true}
            for node in menuHighlights {node.isHidden=true}
            return
        }
        let overlay=menu.visible(core.phase)
        curtain.isHidden = !overlay;title.isHidden = !overlay;sub.isHidden = !overlay;hint.isHidden = !overlay
        title.position.y=565;sub.position.y=516;hint.position.y=menu.settingsOpen || menu.teamOpen ? 86:110
        modeLabel.isHidden = !core.godMode && !core.usedGodMode
        modeLabel.text=core.godMode ? "GODMODE · TREFFER \(core.trainingHits) · LEBEN VIRTUELL":"DURCHGANG MIT GODMODE · TREFFER \(core.trainingHits)"
        var names:[String]=[],values:[String]=[]
        if menu.teamOpen {
            title.text="ZUSAMMEN SPIELEN";sub.text="2–4 Spieler · eine Arena · eigene Leben und Ausrüstung"
            names=["Gemeinsam starten","Spieleranzahl"]
            values=[teamStartReady ? "BEREIT":"Controller fehlen","\(menu.teamCount)"]
            if menu.teamAllowsKeyboard {names.append("Spieler 1");values.append(menu.teamKeyboard ? "Tastatur":"Controller")}
            for slot in 0..<menu.teamCount {names.append("Farbe Spieler \(slot+1)");values.append(settings.color(for:slot).title)}
            names.append("Zurück");values.append("")
            if menu.selected==0 {
                hint.text=teamStartReady ? "Alle Spieler bereit · \(acceptHint) startet eine neue Runde.":"Verbinde \(menu.teamCount-(menu.teamKeyboard ? 1:0)) Controller\(menu.teamKeyboard ? " und spiele Spieler 1 mit der Tastatur":"") · \(availableControllers) verbunden."
            }else if menu.selected==1 {hint.text="← / → wählt zwei, drei oder vier Spieler."}
            else if menu.teamAllowsKeyboard && menu.selected==2 {hint.text="Tastatur für Spieler 1 oder ein eigener Controller für jeden Spieler."}
            else if menu.selected==menu.teamBackRow {hint.text="Zurück zum Startmenü."}
            else {hint.text="← / → ändert die Farbe · bereits belegte Farben werden getauscht."}
        }else if menu.audioOpen {
            let info=music.display
            title.text="TON UND MUSIK";sub.text=info.notice.isEmpty ? "Geräusche und Musik getrennt einstellen.":String(info.notice.prefix(90))
            names=["Gesamter Ton","Geräusche","Musik","Musiktitel","Zurück"]
            let track=info.count==0 ? "Keine Dateien":String(info.title.prefix(24))+(info.title.count>24 ? "…":"")
            values=[settings.soundEnabled ? "EIN":"AUS","\(settings.effectsVolume) %","\(settings.musicVolume) %",track,""]
            #if os(macOS)
            let emptyHint="Noch keine Musik geladen · App-Menü: Musik hinzufügen …"
            #else
            let emptyHint="Dieser Build enthält noch keine Musikdateien."
            #endif
            let descriptions=["Gesamten Ton ein- oder ausschalten.","Lautstärke der Waffen, Explosionen und Fundsignale.","Musiklautstärke · bei null bleibt die Wiedergabe angehalten.",info.count==0 ? emptyHint:"← / → wechselt den Titel · \(info.count) Titel · \(info.title)","Zurück zu den Einstellungen."]
            hint.text=descriptions[menu.selected]
        }else if menu.settingsOpen {
            title.text="EINSTELLUNGEN";sub.text="Die Kamera wählt den passenden Bildausschnitt automatisch."
            names=["Godmode","Bildhelligkeit","Ton","Spielerfarbe","Zurück"]
            values=[settings.godMode ? "EIN":"AUS",settings.brighter ? "Heller":"Normal","Öffnen …",settings.playerColor.title,""]
            let descriptions=[
                "Unsterblich · Treffer kosten virtuelle Leben, auch unter null.",
                "Heller erleichtert das Erkennen in den Nacht- und Regenrunden.",
                "Geräusche, Musiklautstärke und Musiktitel einstellen · öffnen.",
                "Deine Farbe für Uniform, Helm und Markierung · gilt sofort.",
                "Zurück zum vorherigen Menü."
            ]
            hint.text=descriptions[menu.selected]
        }else{
            names=[core.phase == .paused ? "Fortsetzen":core.playerCount>1 ? "Einzelspiel starten":core.phase == .title ? "Spiel starten":"Neuer Versuch","Einstellungen"]
            if core.phase != .paused {names.append("Zusammen spielen")}
            switch core.phase {
            case .title:title.text="DEAD OPS";sub.text="ARCADE · IMMER WEITER"
                hint.text="Linker Stick: Bewegen · rechter Stick: Schießen · R2: Boost · L2: Bombe"
            case .paused:title.text="PAUSE";sub.text="RUNDE \(core.round) · \(runScore) PUNKTE"
                hint.text="Steuerkreuz / ↑ ↓ wählen · \(acceptHint) bestätigen · Options / Esc fortsetzen"
            case .gameOver:title.text="GAME OVER";sub.text="\(runScore) PUNKTE · RUNDE \(core.round)"
                hint.text=core.playerCount>1 ? teamScoreLine:"Steuerkreuz / ↑ ↓ wählen · \(acceptHint) bestätigen"
            case .checkpointComplete:title.text="ETAPPE GESCHAFFT";sub.text=core.usedGodMode ? "DURCHGANG MIT GODMODE · \(core.trainingHits) GEWERTETE TREFFER":(ArenaLayout.lastRound==40 ? "SILVERBACK BESIEGT · \(core.score) PUNKTE":"\(core.score) PUNKTE · WEITERE ARENEN FOLGEN")
                hint.text="Steuerkreuz / ↑ ↓ wählen · \(acceptHint) bestätigen"
            default:break
            }
            if menu.selected==1 {hint.text="Helligkeit, Ton, Spielerfarbe und Godmode · \(acceptHint) öffnen"}
            else if menu.selected==2 {hint.text="Mit zwei bis vier Spielern an einem Bildschirm · \(acceptHint) öffnen."}
            else if !(core.phase == .paused ? controllersReady:soloStartReady) {hint.text="Controller fehlt · Verbinde alle Spieler, dann \(acceptHint) bestätigen."}
        }
        for i in menuNames.indices {
            let y=menuRowY(i)
            menuNames[i].position.y=y;menuValues[i].position.y=y;menuHighlights[i].position.y=y+6
            let shown=overlay && i<names.count
            menuHighlights[i].isHidden = !shown || i != menu.selected
            menuNames[i].isHidden = !shown;menuValues[i].isHidden = !shown
            if shown {menuNames[i].text=(i==menu.selected ? "› ":"  ")+names[i];menuValues[i].text=i<values.count ? values[i]:""}
        }
    }
}
