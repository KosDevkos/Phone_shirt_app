/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import CoreBluetooth
let OTACBUUID = CBUUID(string: "1D14D6EE-FD63-4FA1-BFA4-8F47B42119F0")
let BlueGeckoCBUUID = CBUUID(string: "77164E9F-48C3-19AF-8668-20DA0165359E")
let heartRateServiceCBUUID = CBUUID(string: "1b39bd78-2b85-4bdc-b469-385e1804deb4")
let ambient_GND_CharacteristicCBUUID = CBUUID(string: "4cd89f16-d93e-4a3e-b467-00e514a40d2e")
let object_GND_CharacteristicCBUUID = CBUUID(string: "7352ee73-925d-4142-94a3-cfe4ace393ae")
let ambient_VDD_CharacteristicCBUUID = CBUUID(string: "a12edede-a0c7-455a-8e46-6451e081426c")
let object_VDD_CharacteristicCBUUID = CBUUID(string: "f3422e08-a8d8-48c7-a3da-ee598987b28f")
let Front_TR_PWM_IN_CharacteristicCBUUID = CBUUID(string: "3d586659-fd18-43c7-88ad-d386dab601e3")
let Back_TR_PWM_IN_CharacteristicCBUUID = CBUUID(string: "c7bd8529-02ff-481f-a8bc-5b5c34357bc2")


class HRMViewController: UIViewController {

  @IBOutlet weak var frontObjectTemp: UILabel!
    @IBOutlet weak var backObjectTemp: UILabel!
    @IBOutlet weak var frontAmbientTemp: UILabel!
    @IBOutlet weak var backAmbientTemp: UILabel!
    @IBOutlet weak var frontDutyCycle: UILabel!
    @IBOutlet weak var backDutyCycle: UILabel!
    @IBOutlet weak var modeSwitch: UISegmentedControl!
    @IBAction func fronHeatSlider(_ sender: UISlider) {
    }
    @IBAction func backHeatSlider(_ sender: UISlider) {
    }
    
    
    
  var centralManager: CBCentralManager!
  var heartRatePeripheral: CBPeripheral!
  
  //var bleDevices: [BleDevice] = []
  var bleDevices: [CBPeripheral] = []


  override func viewDidLoad() {
    super.viewDidLoad()

    centralManager = CBCentralManager(delegate: self, queue: nil)
    
    // Make the digits monospaces to avoid shifting when the numbers change
   ///frontObjectTemp.font = UIFont.monospacedDigitSystemFont(ofSize: frontObjectTemp.font!.pointSize, weight: .regular)
  }

}



extension HRMViewController: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    switch central.state {
    case .unknown:
      print("central.state is .unknown")
    case .resetting:
      print("central.state is .resetting")
    case .unsupported:
      print("central.state is .unsupported")
    case .unauthorized:
      print("central.state is .unauthorized")
    case .poweredOff:
      print("central.state is .poweredOff")
    case .poweredOn:
      print("central.state is .poweredOn")
      centralManager.scanForPeripherals(withServices: [heartRateServiceCBUUID])
    @unknown default:
      print("fatal error")
    }
  }

//// TEEEEEEEEEEST
  
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                      advertisementData: [String : Any], rssi RSSI: NSNumber) {
    print(peripheral)
    heartRatePeripheral = peripheral
    heartRatePeripheral.delegate = self
    centralManager.stopScan()
    centralManager.connect(heartRatePeripheral)
  }
  
  // my func
  func addtoBleArray(peripheral: CBPeripheral){
    bleDevices.append(peripheral)
    
    
  }
  


  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("Connected!")
    heartRatePeripheral.discoverServices([heartRateServiceCBUUID])
  }
}

extension HRMViewController: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    guard let services = peripheral.services else { return }
    for service in services {
      print(service)
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    guard let characteristics = service.characteristics else { return }

    for characteristic in characteristics {
      print(characteristic)

      if characteristic.properties.contains(.read) {
        print("\(characteristic.uuid): properties contains .read")
        peripheral.readValue(for: characteristic)
      }
      if characteristic.properties.contains(.notify) {
        print("\(characteristic.uuid): properties contains .notify")
        peripheral.setNotifyValue(true, for: characteristic)
      }
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    switch characteristic.uuid {
    case ambient_VDD_CharacteristicCBUUID:
      let ambient_t_VDD = GetTemperature(from: characteristic)
      frontAmbientTemp.text = ambient_t_VDD
    case object_VDD_CharacteristicCBUUID:
      let object_t_VDD = GetTemperature(from: characteristic)
      frontObjectTemp.text = object_t_VDD
      //print(frontObjectTemp.text!)
    case ambient_GND_CharacteristicCBUUID:
      let ambient_t_GND = GetTemperature(from: characteristic)
      backAmbientTemp.text = ambient_t_GND
    case object_GND_CharacteristicCBUUID:
      let object_t_GND = GetTemperature(from: characteristic)
      backObjectTemp.text = object_t_GND
      //print(frontObjectTemp.text!)
    case Front_TR_PWM_IN_CharacteristicCBUUID:
      let front_TR_PWM = GetDutyCycle(from: characteristic)
      frontDutyCycle.text = front_TR_PWM
    case Back_TR_PWM_IN_CharacteristicCBUUID:
      let back_TR_PWM = GetDutyCycle(from: characteristic)
      backDutyCycle.text = back_TR_PWM
      print(backDutyCycle.text!)

    default:
      print("Unhandled Characteristic UUID: \(characteristic.uuid)")
    }
  }



  private func GetTemperature(from characteristic: CBCharacteristic) -> String {
    guard let characteristicData = characteristic.value else { return "error" }
    let byteArray = [UInt8](characteristicData)

    
    let MBS:UInt8 = UInt8(byteArray[0])  // gets received MSB bits
    let LBS:UInt8 = UInt8(byteArray[1])  // gets received LSB bits
    let decimalPoints:UInt8 = UInt8(byteArray[2]) // gets received decimal point bits
    let integer:Int16 = Int16( (MBS << 8) | LBS)  // combines MBS and LBS into integer
    let resultString:String = "\(String(integer)).\(String(decimalPoints))" //conv to str

    return resultString
  }
    
    private func GetDutyCycle(from characteristic: CBCharacteristic) -> String {
      guard let characteristicData = characteristic.value else { return "error" }
      let byteArray = [UInt8](characteristicData)
      let duty:UInt8 = UInt8(byteArray[0])
      let resultString:String = "\(String(duty))%" //conv to str

      return resultString
  }
}
