#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
check_kind="${1:-logic}"
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/DeadOps-Checks-XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
sources=(Sources/TeslaOrbRetirement.swift Sources/CharacterLocomotion.swift Sources/TeslaDischarge.swift Sources/TeslaWorld.swift Sources/FlameAfterburn.swift Sources/HerdAudio.swift Sources/VehicleExitPulse.swift Sources/StampedeDirector.swift Sources/LootSpawnDirector.swift Sources/OpeningMapDesign.swift Sources/ScoreAwards.swift Sources/BossBattleWorld.swift Sources/BossBattleFlow.swift Sources/RareLifeTimer.swift Sources/CombatSpawning.swift Sources/TimedAttackWaves.swift Sources/ElectricHazards.swift Sources/ArenaTransitions.swift Sources/BodyShields.swift Sources/CombatRules.swift Sources/AudioCore.swift Sources/MusicCore.swift Sources/GameOverSequence.swift Sources/PlayerDamage.swift Sources/RunPlayer.swift Sources/LifeTransfers.swift Sources/TeamRecovery.swift Sources/TeamSimulation.swift Sources/GameCore.swift Sources/ArenaLayout.swift Sources/EnemyEntrances.swift Sources/PrisonLayout.swift Sources/Fates.swift Sources/FateRoom.swift Sources/Weapons.swift Sources/Vehicles.swift Sources/WeaponProjectiles.swift Sources/Marketplace.swift Sources/UrbanLayout.swift Sources/StreetLayout.swift Sources/FacilityLayout.swift Sources/ForestLayout.swift Sources/JungleLayout.swift Sources/SideRooms.swift Sources/Companions.swift Sources/SupportPowers.swift Sources/Treasure.swift Sources/RoundRules.swift Sources/TreasureRaider.swift Sources/PlayerReadability.swift Sources/FrameInput.swift Sources/ControllerRouting.swift Sources/SpawnDirector.swift Sources/PickupPresentation.swift Sources/GameSettings.swift Sources/TeamCamera.swift)
sources+=(Sources/DefeatedBodies.swift Tests/BossFixture.swift)
case "$check_kind" in
 all)
  harness=()
  all_main="$check_dir/AllChecks.swift"
  print '@main struct AllChecks { static func main() {' > "$all_main"
  for test_source in Tests/*Checks.swift; do
   test_name="${test_source:t:r}"
   sed 's/@main struct/struct/' "$test_source" > "$check_dir/$test_name.swift"
   harness+=("$check_dir/$test_name.swift")
   print "$test_name.main()" >> "$all_main"
  done
  print '} }' >> "$all_main"
  harness+=("$all_main") ;;
 opening | release-runs)
  harness=(Tests/VehiclePilot.swift Tests/NormalPilot.swift)
  runs=(FirstEight CooperativeEight)
  if [[ "$check_kind" == release-runs ]]; then runs+=(EightyRounds); fi
  for run_name in $runs; do
   sed 's/@main struct/struct/' "Tests/$run_name.swift" > "$check_dir/$run_name.swift"
   harness+=("$check_dir/$run_name.swift")
  done
  if [[ "$check_kind" == release-runs ]]; then
   print '@main struct OpeningChecks { static func main() { FirstEight.main(); CooperativeEight.main(); RunThroughEighty.main() } }' > "$check_dir/Opening.swift"
  else
   print '@main struct OpeningChecks { static func main() { FirstEight.main(); CooperativeEight.main() } }' > "$check_dir/Opening.swift"
  fi
  harness+=("$check_dir/Opening.swift") ;;
 performance) harness=(Tests/PerformanceTrace.swift) ;;
 players) harness=(Tests/PlayerChecks.swift) ;;
 recovery) harness=(Tests/RecoveryChecks.swift) ;;
 donations) harness=(Tests/DonationChecks.swift) ;;
 respawns) harness=(Tests/RespawnChecks.swift) ;;
 hounds) harness=(Tests/HoundChecks.swift) ;;
 character-motion) harness=(Tests/CharacterMotionChecks.swift) ;;
 tesla) harness=(Tests/TeslaChecks.swift) ;;
 orb-retirement) harness=(Tests/OrbRetirementChecks.swift) ;;
 flames) harness=(Tests/FlameBurnChecks.swift) ;;
 blasts) harness=(Tests/BlastChecks.swift) ;;
 treasure) harness=(Tests/TreasureChecks.swift) ;;
 fate-room) harness=(Tests/FateRoomChecks.swift) ;;
 cooperative) harness=(Tests/CooperativeChecks.swift) ;;
 input-routing) harness=(Tests/InputRoutingChecks.swift) ;;
 team-camera) harness=(Tests/TeamCameraChecks.swift) ;;
 camera-orientation) harness=(Tests/CameraOrientationChecks.swift) ;;
 team-lobby) harness=(Tests/TeamLobbyChecks.swift) ;;
 cooperative-eight) harness=(Tests/VehiclePilot.swift Tests/NormalPilot.swift Tests/CooperativeEight.swift) ;;
 presentation) harness=(Tests/PresentationChecks.swift) ;;
 audio) harness=(Tests/AudioChecks.swift) ;;
 audio-loops) harness=(Tests/AudioLoopChecks.swift) ;;
 ending) harness=(Tests/EndingChecks.swift) ;;
 visibility) harness=(Tests/VisibilityChecks.swift) ;;
 logic) harness=(Tests/CoreChecks.swift) ;;
 raider) harness=(Tests/RaiderChecks.swift) ;;
 boss-flow) harness=(Tests/BossFlowChecks.swift) ;;
 score-awards) harness=(Tests/ScoreAwardChecks.swift) ;;
 boss-world) harness=(Tests/BossWorldChecks.swift) ;;
 boss-victory) harness=(Tests/BossVictoryChecks.swift) ;;
 herd-audio) harness=(Tests/HerdAudioChecks.swift) ;;
 vehicle-exit) harness=(Tests/VehicleExitChecks.swift) ;;
 stampede) harness=(Tests/StampedeChecks.swift) ;;
 special-rounds) harness=(Tests/SpecialRoundChecks.swift) ;;
 loot-rooms) harness=(Tests/LootRoomChecks.swift) ;;
 loot-world) harness=(Tests/LootWorldChecks.swift) ;;
 loot-director) harness=(Tests/LootDirectorChecks.swift) ;;
 pickup-lifetimes) harness=(Tests/PickupLifetimeChecks.swift) ;;
 rare-lives) harness=(Tests/RareLifeChecks.swift) ;;
 timed-world) harness=(Tests/TimedSpawnWorldChecks.swift) ;;
 timed-waves) harness=(Tests/TimedWaveChecks.swift) ;;
 waves) harness=(Tests/WaveChecks.swift) ;;
 first-eight) harness=(Tests/VehiclePilot.swift Tests/NormalPilot.swift Tests/FirstEight.swift) ;;
 eighty) harness=(Tests/VehiclePilot.swift Tests/EightyRounds.swift) ;;
 forty) harness=(Tests/VehiclePilot.swift Tests/FortyRounds.swift) ;;
 *) print "Nutzung: Tests/check.sh all | opening | release-runs | logic | players | recovery | hounds | blasts | treasure | fate-room | input-routing | team-camera | team-lobby | cooperative | cooperative-eight | performance | ending | visibility | audio | presentation | raider | waves | timed-waves | first-eight | forty | eighty";exit 1 ;;
esac
xcrun --sdk macosx swiftc -O -swift-version 5 -module-cache-path "$check_dir/modules" -target arm64-apple-macosx14.0 $sources $harness -o "$check_dir/check"
if [[ "$check_kind" == performance ]]; then "$check_dir/check" "$check_dir/trace.bin"; else "$check_dir/check"; fi
