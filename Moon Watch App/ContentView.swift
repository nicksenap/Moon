import Foundation
import Combine
import SwiftUI
import HealthKit
import CoreMotion


struct ContentView: View {
    private let motionManager = CMMotionManager()
    private let healthStore = HKHealthStore()
    @State private var isSleeping: Bool? = nil
    // Debugging
    @State private var heartRate: Double = 0
    @State private var roll: Double = 0
    @State private var pitch: Double = 0
    var body: some View {
        Text(isSleeping == nil ? "Determining sleep status..." : (isSleeping! ? "User is likely sleeping" : "User is likely not sleeping"))
            .padding()
        Text("Roll: \(roll, specifier: "%.5f")")
            .padding()
        Text("Pitch: \(pitch, specifier: "%.5f")")
            .padding()
        .onAppear {
            updateSleepStatus()
        }
    }
    
    func updateSleepStatus() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            estimateSleep { (isSleeping) in
                DispatchQueue.main.async {
                    self.isSleeping = isSleeping
                }
                if isSleeping {
                    timer.invalidate()
                }
            }
        }
    }
    
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    func fetchMotionData() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion is not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0
        
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { (deviceMotion, error) in
            guard let deviceMotion = deviceMotion, error == nil else {
                print("Error fetching device motion data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            let roll = deviceMotion.attitude.roll
            let pitch = deviceMotion.attitude.pitch
            
            DispatchQueue.main.async {
                self.roll = roll
                self.pitch = pitch
            }
        }
    }
    
    func fetchHeartRateData(completion: @escaping (Double?) -> Void) {
        let heartRateSampleType = HKSampleType.quantityType(forIdentifier: .heartRate)!
        let typesToShare: Set<HKSampleType> = []
        let typesToRead: Set<HKObjectType> = [heartRateSampleType]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            if let error = error {
                print("Error requesting HealthKit authorization: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if success {
                let now = Date()
                let startOfDay = Calendar.current.startOfDay(for: now)
                let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
                
                let query = HKSampleQuery(sampleType: heartRateSampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (_, samples, error) in
                    guard let samples = samples as? [HKQuantitySample], error == nil else {
                        print("Error fetching heart rate samples: \(error?.localizedDescription ?? "Unknown error")")
                        completion(nil)
                        return
                    }
                    
                    let totalHeartRate = samples.reduce(0) { (total, sample) in
                        total + sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    }
                    let averageHeartRate = totalHeartRate / Double(samples.count)
                    
                    DispatchQueue.main.async {
                        completion(averageHeartRate)
                    }
                }
                
                healthStore.execute(query)
            } else {
                print("Authorization not determined")
                completion(nil)
            }
        }
    }
    
    func isUserSleeping(roll: Double, pitch: Double, heartRate: Double) -> Bool {
        let sleepThreshold = 0.3
        let minRestingHeartRate = 50.0
        let maxRestingHeartRate = 100.0
        
        return abs(roll) < sleepThreshold && abs(pitch) < sleepThreshold && heartRate >= minRestingHeartRate && heartRate <= maxRestingHeartRate
    }
    
    func estimateSleep(completion: @escaping (Bool) -> Void) {
        fetchMotionData()
        fetchHeartRateData { (heartRate) in
            if let heartRate = heartRate {
                let isSleeping = isUserSleeping(roll: self.roll, pitch: self.pitch, heartRate: heartRate)
                completion(isSleeping)
            } else {
                completion(false)
            }
        }
    }

    struct ContentView_Previews: PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
}
