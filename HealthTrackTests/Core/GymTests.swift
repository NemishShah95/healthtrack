import Foundation
import Testing
@testable import HealthTrack

@Test func exerciseLinesParse() {
    let e = GymLog.parse("""
    Bench press 3x10 60kg
    - Squat 5 x 5 @ 100 kg
    Pull-ups 3 sets 12 reps
    Treadmill 20 min 3 km
    Run 5k
    Deadlift 1x5 225 lb
    Plank 3 x 1
    Bike 30 mins 10 mi

    """)
    #expect(e.count == 8)
    #expect(e[0] == ParsedExercise(name: "Bench press", sets: 3, reps: 10, weightKg: 60))
    #expect(e[1] == ParsedExercise(name: "Squat", sets: 5, reps: 5, weightKg: 100))
    #expect(e[2] == ParsedExercise(name: "Pull-ups", sets: 3, reps: 12))
    #expect(e[3] == ParsedExercise(name: "Treadmill", minutes: 20, distanceKm: 3))
    #expect(e[3].isCardio && !e[0].isCardio)
    #expect(e[4] == ParsedExercise(name: "Run", distanceKm: 5))
    #expect(e[5].weightKg == 102.1)
    #expect(e[6] == ParsedExercise(name: "Plank", sets: 3, reps: 1))
    #expect(e[7].distanceKm == 16.09 && e[7].minutes == 30)
}

@Test func exerciseLineRoundTripsAndVolume() {
    for text in ["Bench press 3x10 60 kg", "Treadmill 20 min 3 km", "Dips 3 sets", "Curl 12 reps 12.5 kg", "Stretching"] {
        let parsed = GymLog.parseLine(text)!
        #expect(GymLog.parseLine(parsed.line) == parsed, "\(text)")
    }
    #expect(GymLog.parseLine("Bench press 3x10 60 kg")?.volumeKg == 1800)
    #expect(GymLog.parseLine("Treadmill 20 min")?.volumeKg == nil)
    #expect(GymLog.parseLine("Bench press 3x10 60 kg")?.summary == "3×10 · 60 kg")
    #expect(GymLog.parseLine("   ") == nil)
    #expect(GymLog.parseLine("3x10")?.name == "Exercise")
}
