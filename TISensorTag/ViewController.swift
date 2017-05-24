//
//  ViewController.swift
//  TISensorTag
//
//  Created by Mark Illingworth on 24/5/17.
//  Copyright © 2017 Mark Illingworth. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {

    // MARK: - UI Labels
    
    var titleLabel: UILabel!
    var statusLabel: UILabel!
    var tempLabel: UILabel!
    
    // BLE
    var centralManager : CBCentralManager!
    var sensorTagPeripheral : CBPeripheral!
    
    // IR Temp UUIDs
    let IRTemperatureServiceUUID = CBUUID(string: "F000AA00-0451-4000-B000-000000000000")
    let IRTemperatureDataUUID   = CBUUID(string: "F000AA01-0451-4000-B000-000000000000")
    let IRTemperatureConfigUUID = CBUUID(string: "F000AA02-0451-4000-B000-000000000000")
    
    // MARK: - Intitialise the app
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        // Set up each of these labels and add them as a subview to the main view
    
        // Set up title label
        titleLabel = UILabel()
        titleLabel.text = "My SensorTag"
        titleLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 20)
        titleLabel.sizeToFit()
        titleLabel.center = CGPoint(x: self.view.frame.midX, y: self.titleLabel.bounds.midY+28)
        self.view.addSubview(titleLabel)
        
        // Set up status label
        statusLabel = UILabel()
        statusLabel.textAlignment = NSTextAlignment.center
        statusLabel.text = "Loading..."
        statusLabel.font = UIFont(name: "HelveticaNeue-Light", size: 12)
        statusLabel.sizeToFit()
        statusLabel.frame = CGRect(x: self.view.frame.origin.x, y: self.titleLabel.frame.maxY, width: self.view.frame.width, height: self.statusLabel.bounds.height)
        self.view.addSubview(statusLabel)
        
        // Set up temperature label
        tempLabel = UILabel()
        tempLabel.text = "00.00"
        tempLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 72)
        tempLabel.sizeToFit()
        tempLabel.center = self.view.center
        self.view.addSubview(tempLabel)
        
        
        // Initialize central manager on load
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Central Manager
    
    // Check status of BLE hardware
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Scan for peripherals if BLE is turned on
            central.scanForPeripherals(withServices: nil, options: nil)
            self.statusLabel.text = "Searching for BLE Devices"
        }
        else {
            // Can have different conditions for all states if needed - print generic message for now
            print("Bluetooth switched off or not initialized")
        }
    }

    // Check out the discovered peripherals to find Sensor Tag
    private func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        
        let deviceName = "SensorTag" as NSString!
        let nameOfDeviceFound = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? NSString
        
        if (nameOfDeviceFound == deviceName) {
            // Update Status Label
            self.statusLabel.text = "Sensor Tag Found"
            
            // Stop scanning
            self.centralManager.stopScan()
            // Set as the peripheral to use and establish connection
            self.sensorTagPeripheral = peripheral
            self.sensorTagPeripheral.delegate = self
            self.centralManager.connect(peripheral, options: nil)
        }
        else {
            self.statusLabel.text = "Sensor Tag NOT Found"
        }
    }
    
    // Discover services of the peripheral
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        self.statusLabel.text = "Discovering peripheral services"
        peripheral.discoverServices(nil)
    
        }

     // MARK: - Peripheral Delegate
    
    // Check if the service discovered is a valid IR Temperature Service
    private func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        self.statusLabel.text = "Looking at peripheral services"
        for service in peripheral.services! {
            let thisService = service as CBService
            if service.uuid == IRTemperatureServiceUUID {
                // Discover characteristics of IR Temperature Service
                peripheral.discoverCharacteristics(nil, for: thisService)
            }
            // Uncomment to print list of UUIDs
            print(thisService.uuid)
        }
    }
    
    // Enable notification and sensor for each characteristic of valid service
    private func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        
        // update status label
        self.statusLabel.text = "Enabling sensors"
        
        // 0x01 data byte to enable sensor
        var enableValue = 1
        let enablyBytes = NSData(bytes: &enableValue, length: MemoryLayout<UInt8>.size)
        
        // check the uuid of each characteristic to find config and data characteristics
        for charateristic in service.characteristics! {
            let thisCharacteristic = charateristic as CBCharacteristic
            // check for data characteristic
            if thisCharacteristic.uuid == IRTemperatureDataUUID {
                // Enable Sensor Notification
                self.sensorTagPeripheral.setNotifyValue(true, for: thisCharacteristic)
            }
            // check for config characteristic
            if thisCharacteristic.uuid == IRTemperatureConfigUUID {
                // Enable Sensor
                self.sensorTagPeripheral.writeValue(enablyBytes as Data, for: thisCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        }
        
    }
    
    // Get data values when they are updated
    private func peripheral(peripheral: CBPeripheral!, didUpdateValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        
        self.statusLabel.text = "Connected"
        
        if characteristic.uuid == IRTemperatureDataUUID {
            // Convert NSData to array of signed 16 bit values
            var dataBytes: Data = characteristic.value!
            let dataLength = dataBytes.count
            var dataArray = [Int8](repeating: 0, count: dataLength)
            dataBytes.getBytes(dataArray, length: dataArray.count)
            
            // Element 1 of the array will be ambient temperature raw value
            let ambientTemperature = Double(dataArray[1])/128
            
            // Display on the temp label
            self.tempLabel.text = NSString(format: "%.2f", ambientTemperature) as String
        }
    }
    
    // If disconnected, start searching again
    private func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        self.statusLabel.text = "Disconnected"
        central.scanForPeripherals(withServices: nil, options: nil)
    }
}
