//
//  DeviceController.swift
//  NovaliaBLE
//
//  Created by Andrew Sage on 14/06/2016.
//  Copyright © 2016 Andrew Sage. All rights reserved.
//

import UIKit
import NovaliaBLE

class DeviceController: UIViewController, NovaliaBLEInterfaceDelegate, NovaliaBLEDeviceEventDelegate {
    
    // NovaliaBLEInterface vars
    var interface: NovaliaBLEInterface!
    var previousBLEState: NovaliaBLEState!
    var launchDiscoveryTimer: Timer!
    var selectedDevices = [NovaliaBLEDevice]()
    var currentDevice: NovaliaBLEDevice!
    
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var connectionStatusLabel: UILabel!
    @IBOutlet weak var renameButton: UIButton!
    @IBOutlet weak var continousScanningSwitch: UISwitch!
    
    @IBOutlet weak var deviceNameLabel: UILabel!
    @IBOutlet weak var inputLabel: UILabel!
    @IBOutlet weak var macAddressLabel: UILabel!
    @IBOutlet weak var firmwareVersionLabel: UILabel!
    @IBOutlet weak var hardwareVersionLabel: UILabel!
    
    @IBOutlet weak var disconnectButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initInterfaceIfNeeded()
    }
    
    
    // MARK: Actions
    @IBAction func scanButtonTapped(_ sender: AnyObject) {
        startDiscovery()
    }
    
    @IBAction func disconnectButtonTapped(_ sender: AnyObject) {
        if currentDevice != nil {
            self.interface.disconnect(from: currentDevice)
        }
    }
    
    @IBAction func reconnectButtonTapped(_ sender: AnyObject) {
        if currentDevice != nil {
            self.interface.connect(to: currentDevice)
        }
    }
    
    @IBAction func renameButtonTapped(_ sender: AnyObject) {
        if currentDevice != nil {
            
            let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
            var randomString: String = ""
            
            for _ in 0..<10 {
                let randomValue = arc4random_uniform(UInt32(base.characters.count))
                randomString += "\(base[base.index(base.startIndex, offsetBy: Int(randomValue))])"
            }
            
            
            self.interface.writeDISSerialNumber(randomString, to: currentDevice)
        }
    }
    
    // MARK: NovaliaBLEInterface methods
    func initInterfaceIfNeeded() {
        
        if(interface == nil) {
            interface = NovaliaBLEInterface(delegate: self)
            interface.diagnosticsMode = false
            previousBLEState = BLEStateNotReady
            launchDiscoveryTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(startDiscovery), userInfo: nil, repeats: false)
        }
    }
    
    func startDiscovery() {
        
        self.scanButton.setTitle("Scanning", for: UIControlState())
        
        if self.continousScanningSwitch.isOn == false {
            launchDiscoveryTimer = Timer.scheduledTimer(timeInterval: 30.0, target: self, selector: #selector(stopDiscovery), userInfo: nil, repeats: false)
        }
        
        if currentDevice == nil {
            // Set a status message to indicate no device connected
        }
        
        // Set the device name to be searched for e.g. novppia1
        // Setting the device name to * searches for all devices
        // Allow devices to be rediscovered by setting allowDuplicates to true
        self.interface.startDeviceDiscovery(["suphero1"], allowDuplicates:true)
    }
    
    func stopDiscovery() {
        
        
        self.scanButton.setTitle("Start Scan", for: UIControlState())
        
        if currentDevice == nil {
            // Set a status message to indicate no device connected
        }
        
        launchDiscoveryTimer = nil
        self.interface.stopDeviceDiscovery()
    }
    
    // MARK: NovaliaBLEInterface Delegate methods
    func onDeviceDiscovered(_ device: NovaliaBLEDevice!) {
        
        print("Device discovered")
        if currentDevice == nil {
            // Set a status message to indicate connecting to device
        }
        
        var array = selectedDevices
        let index = array.index(of: device)
        
        if(index != nil) {
            array[index!] = device
        } else {
            array.append(device)
        }
        
        device.delegate = self
        selectedDevices = array
        interface.connect(to: device)
    }

    func onDeviceListChanged(_ newList: [NovaliaBLEDevice]) {
        
        var connected = 0
        var connecting = 0
        var disconnected = 0
        
        for device: NovaliaBLEDevice in newList {
            if(isDeviceConnected(device)) {
                print("\(device.uuid.uuidString) connected")
                connected += 1
            } else if(isDeviceConnecting(device)) {
                print("\(device.uuid.uuidString) connecting")
                connecting += 1
            } else if(isDeviceDisconnected(device)) {
                print("\(device.uuid.uuidString) disconnected")
                disconnected += 1
            }
        }
        
        // This is where an indicator of how many devices are connected, connecting, disconnected should be displayed
        print(String(format:"Connected %d Connecting %d Disconnected %d", connected, connecting, disconnected))
        
        self.connectionStatusLabel.text = "Connected \(connected)\nConnecting \(connecting) \nDisconnected \(disconnected)"
        
        let isConnecting = (connecting > 0)
        
        if(isConnecting) {
            // Start any connecting animation
        } else {
            // Stop any connecting animation
        }
    }
    
    func onDeviceConnected(_ device: NovaliaBLEDevice!) {
        // Set a status message to indicate device connected
        
        currentDevice = device
        
        self.deviceNameLabel.text = currentDevice.deviceName
        
        
        if(isDeviceConnected(currentDevice)) {
            print("\(currentDevice.uuid.uuidString) connected")
        } else if(isDeviceConnecting(currentDevice)) {
            print("\(currentDevice.uuid.uuidString) connecting")
        } else if(isDeviceDisconnected(currentDevice)) {
            print("\(currentDevice.uuid.uuidString) disconnected")
        }
    }
    
    func isDeviceConnected(_ device: NovaliaBLEDevice) -> Bool {
        return (device.status & NovaliaBLEDeviceConnected) == NovaliaBLEDeviceConnected
    }
    func isDeviceConnecting(_ device: NovaliaBLEDevice) -> Bool {
        return (device.status & NovaliaBLEDeviceConnecting) == NovaliaBLEDeviceConnecting
    }
    func isDeviceDisconnected(_ device: NovaliaBLEDevice) -> Bool {
        return isDeviceConnected(device) == false && isDeviceConnecting(device) == false
    }
    
    func onDeviceDisconnected(_ device: NovaliaBLEDevice!) {
        currentDevice = nil
        
        // Set a status message to indicate no device connected
        self.deviceNameLabel.text = "No device connected"
        self.macAddressLabel.text = ""
        
        // Try to reconnect
        interface.connect(to: device)
    }
    
    
    func onBLEStateChanged(_ state: NovaliaBLEState) {
        
        if(previousBLEState == state) {
            return
        }
        
        previousBLEState = state
        
        var title = ""
        var message = ""
        
        switch state.rawValue {
        case BLEStateOff.rawValue:
            title = "Bluettoth Power"
            message = "You must turn on Bluetooth in Settings in order to use this application"
        case BLEStateUnsupported.rawValue:
            title = "Bluetooth Unsupported"
            message = "Your device does not seem to be compatible with Bluetooth Low Energy standard."
        case BLEStateNotReady.rawValue:
            title = "Bluetooth Not Ready"
            message = "Bluetooth service on your device does not seem to be ready. It may be initialising or restarting."
        default: ()
        }
        
        if(!title.isEmpty) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func onButtonPressed(_ button: Int32, velocity: Int32, onDevice device: Any!) {
        let device = device as! NovaliaBLEDevice
        print("Button pressed \(button) on device \(device.uuid.uuidString)")
        
        // Now do something in response to a button being pressed
        self.inputLabel.text = "Velocity \(velocity) on button \(button) on device \(device.uuid.uuidString)"
    }
    
    
    // MARK: NovaliaBLEDeviceEventDelegate methods
    func onMACAddressUpdated(_ macAddress: String!, onDevice device: Any!) {
        print("MAC address \(macAddress) device \((device as AnyObject).macAddress)")
        self.macAddressLabel.text = (device as AnyObject).macAddress
    }
    
    func onFirmwareVersionUpdated(_ firmwareVersion: String!, onDevice device: Any!) {
        let device = device as! NovaliaBLEDevice
        self.firmwareVersionLabel.text = "Firmware \(device.firmwareVersion!)"
    }
    
    func onHardwareVersionUpdated(_ hardwareVersion: String!, onDevice device: Any!) {
        let device = device as! NovaliaBLEDevice
        self.hardwareVersionLabel.text =  "Hardware \(device.hardwareVersion!)"
    }
    
    func onNameUpdated(_ deviceName: String!, onDevice device: Any!) {
        let device = device as! NovaliaBLEDevice
        self.deviceNameLabel.text = deviceName
    }
}
