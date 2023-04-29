//
//  MoonApp.swift
//  Moon Watch App
//
//  Created by Nick Song on 2023-04-29.
//

import SwiftUI
import HealthKit

class HealthKitManager: ObservableObject {
    let healthStore = HKHealthStore()
    
    init() {
        requestHealthKitAuthorization()
    }

    func requestHealthKitAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let dataTypesToRead: Set<HKObjectType> = [heartRateType]

        healthStore.requestAuthorization(toShare: nil, read: dataTypesToRead) { (success, error) in
            if let error = error {
                print("Error requesting HealthKit authorization: \(error)")
            }
        }
    }
}

@main
struct Moon_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
