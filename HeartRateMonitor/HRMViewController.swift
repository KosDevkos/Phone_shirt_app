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

//File type for CSV (named as headers of the CSV)
class CsvFile: NSObject {
    var time: String = ""
    var objFrontTemp: String = ""
    var objBackTemp: String = ""
    var ambFrontTemp: String = ""
    var ambBackTemp: String = ""
    var dutyCycleFront: String = ""
    var dutyCycleBack: String = ""
}

let OTACBUUID = CBUUID(string: "1D14D6EE-FD63-4FA1-BFA4-8F47B42119F0")
let BlueGeckoCBUUID = CBUUID(string: "77164E9F-48C3-19AF-8668-20DA0165359E")
let temperatureServiceCBUUID = CBUUID(string: "1b39bd78-2b85-4bdc-b469-385e1804deb4")
let ambient_GND_CharacteristicCBUUID = CBUUID(string: "4cd89f16-d93e-4a3e-b467-00e514a40d2e")
let object_GND_CharacteristicCBUUID = CBUUID(string: "7352ee73-925d-4142-94a3-cfe4ace393ae")
let ambient_VDD_CharacteristicCBUUID = CBUUID(string: "a12edede-a0c7-455a-8e46-6451e081426c")
let object_VDD_CharacteristicCBUUID = CBUUID(string: "f3422e08-a8d8-48c7-a3da-ee598987b28f")
let Front_TR_PWM_IN_CharacteristicCBUUID = CBUUID(string: "3d586659-fd18-43c7-88ad-d386dab601e3")
let Back_TR_PWM_IN_CharacteristicCBUUID = CBUUID(string: "c7bd8529-02ff-481f-a8bc-5b5c34357bc2")
let Front_TR_PWM_OUT_CharacteristicCBUUID = CBUUID(string: "f79f7794-bfd5-455d-a1ae-b97d4b17774a")
let Back_TR_PWM_OUT_CharacteristicCBUUID = CBUUID(string: "8eb124d6-afaf-4b75-a83f-a14b61b241a4")

let TimeStamp_CharacteristicCBUUID = CBUUID(string: "09dcd516-9e99-46bb-82b6-460838ae7c83")
let ModeOfOperation_CharacteristicCBUUID = CBUUID(string: "3e26de8c-9fdd-4b39-8b48-a93b90c0a93f")
let isRecording_CharacteristicCBUUID = CBUUID(string: "84a3a9a6-04d0-440a-ad72-1395572d8924")


/// Variables used to store detected characteristics in the required format for buletooth "write without responce" action
private var Front_TR_PWM_OUT_Characteristic: CBCharacteristic?
private var Back_TR_PWM_OUT_Characteristic: CBCharacteristic?

private var ModeOfOperation_Characteristic: CBCharacteristic?
private var isRecording_Characteristic: CBCharacteristic?


/// Variables required to generate CSV file
var csvFileArr = [CsvFile]()
var csvFile: CsvFile!




class HRMViewController: UIViewController {

    // Outlets, which allow to read data (eg. text) from user interface elements (ex. labels, switches)
    @IBOutlet weak var heatControllerTitle: UINavigationItem!
    @IBOutlet weak var frontObjectTemp: UILabel!
    @IBOutlet weak var backObjectTemp: UILabel!
    @IBOutlet weak var frontAmbientTemp: UILabel!
    @IBOutlet weak var backAmbientTemp: UILabel!
    @IBOutlet weak var frontDutyCycle: UILabel!
    @IBOutlet weak var backDutyCycle: UILabel!
   
    @IBOutlet weak var fileNameTextField: UITextField!
    @IBOutlet weak var dataRecordButton: UIButton!
    
    @IBOutlet weak var modeSwitch: UISegmentedControl!
    @IBOutlet weak var frontHeatSlider: UISlider!
    @IBOutlet weak var backHeatSlider: UISlider!
    
    // Action that triggers when mode switch has changed position
    @IBAction func modeChanged(_ sender: UISegmentedControl) {
        // Switch statement handles all possible modes of operation
        switch modeSwitch.selectedSegmentIndex
        {
        case 0: // Switched to automatic mode
            print("automatic mode Selected")
            modeOfOperation = 0
            // If the app is connected to the periphearal, then send an updated modeOfOperation to the peripheral.
            if ModeOfOperation_Characteristic != nil {
              writeToChar( withCharacteristic: ModeOfOperation_Characteristic!, withValue: Data([UInt8(modeOfOperation)]))
              // Disable sliders. It is inside of the if statemntet, since if the peripheral is disconnected
              // then sliders are handeled in a different place
              frontHeatSlider.isEnabled = false
              backHeatSlider.isEnabled = false
            }
        case 1: // Switched to manual mode
            print("manual mode Selected")
            modeOfOperation = 1
            // If the app is connected to the periphearal, then send an updated modeOfOperation to the peripheral.
            if ModeOfOperation_Characteristic != nil {
              writeToChar( withCharacteristic: ModeOfOperation_Characteristic!, withValue: Data([UInt8(modeOfOperation)]))
              // Enable sliders
              frontHeatSlider.isEnabled = true
              backHeatSlider.isEnabled = true
            }
          
        default:
            break
        }
    }
    // If "Record" button is tapped
    @IBAction func dataRecordButtonPushed(_ sender: UIButton) {
      // If current button state is "Record" AND chip is connected, update dataRecordingEnable
      if ((dataRecordButton.titleLabel!.text == "Record") && (isRecording_Characteristic != nil)){
        dataRecordingEnable = 1

        writeToChar( withCharacteristic: isRecording_Characteristic!, withValue: Data([UInt8(dataRecordingEnable)]))
        dataRecordButton.setTitle("Stop", for: .normal)
      }
      else if ((dataRecordButton.titleLabel!.text == "Stop") && (isRecording_Characteristic != nil)){
        // Change the fileName text color in textField to red TO REMIND TO CHANGE THE NAME FOR THE NEXT EXPRIMENT
        fileNameTextField.textColor = .red
        // Changing button title back to "Record"
        dataRecordButton.setTitle("Record", for: .normal)
        
        // Change dataRecordingEnable flag to 0
        dataRecordingEnable = 0
        // Send the flag to the peripheral
        writeToChar( withCharacteristic: isRecording_Characteristic!, withValue: Data([UInt8(dataRecordingEnable)]))
        // After all nessesary data is in the array, create and export a CSV file
        createCSV()
        //clean the CSV array
        csvFileArr = []
      }
    }
    @IBAction func frontHeatSliderDidChange(_ sender: UISlider) {
      if (modeOfOperation == 1){
        print("front:",frontHeatSlider.value);
        let slider:UInt8 = UInt8(frontHeatSlider.value)
        if Front_TR_PWM_OUT_Characteristic != nil{
          writeToChar( withCharacteristic: Front_TR_PWM_OUT_Characteristic!, withValue: Data([slider]))
        }
      }
    }
    @IBAction func backHeatSliderDidChange(_ sender: UISlider) {
      if (modeOfOperation == 1){
        print("back:",backHeatSlider.value);
        let slider:UInt8 = UInt8(backHeatSlider.value)
        if Back_TR_PWM_OUT_Characteristic != nil{
          writeToChar( withCharacteristic: Back_TR_PWM_OUT_Characteristic!, withValue: Data([slider]))
        }
      }
    }
    // This action is required to change the color of file name in the text filed back to black
    // after user did change the name of the previous experiment to a new one
    // !!! Consider blocking alert instad of red higligting!
    @IBAction func startedEditingFileNameTextFiled(_ sender: UITextField) {
        // Removes red color and sets default ones
        fileNameTextField.textColor = .label
        fileNameTextField.backgroundColor = .none
      // If the user left text filed empty, highlight it in RED to remind them to type the file name.
      // Note, .trimmingCharacters(in: .whitespacesAndNewlines) removes all spaces from string.
      // Hence, the if statement won't consider spaces as charaters
      if fileNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
          fileNameTextField.backgroundColor = .red
        }
    }
    // This action is required to hide keyboard by pressing "return". Yes, it is empty. I also have no idea why it works.
    @IBAction func exitOnReturnFileNameTextField(_ sender: UITextField) {
    }
    


  // the fuction sends the ducy cycle chosen by slider to the microcontroller via BLE
  private func writeToChar( withCharacteristic characteristic: CBCharacteristic, withValue value: Data) {
      // Check if it has the write property
      if characteristic.properties.contains(.writeWithoutResponse) && heartRatePeripheral != nil {
          heartRatePeripheral.writeValue(value, for: characteristic, type: .withoutResponse)
      }
  }
  
    

  
  //Variables for core BLE operation
  var centralManager: CBCentralManager!
  var heartRatePeripheral: CBPeripheral!
  
  //var bleDevices: [BleDevice] = []
  var bleDevices: [CBPeripheral] = []
  
  // Flag that enables data recording if the data recording button is tapped
  var dataRecordingEnable: UInt8 = 0
  // Mode of opearation variable (Auto=0; Manual=1)
  var modeOfOperation: UInt8 = 0
  
  
  
  // Variables for CSV data
  var timeStamp: String = "0"
  var objFrontTemp: String = "0"
  var objBackTemp: String = "0"
  var ambFrontTemp: String = "0"
  var ambBackTemp: String = "0"
  var dutyCycleFront: String = "0"
  var dutyCycleBack: String = "0"
  
  


  // viewDidLoad triggers when the app opens for the firs time
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // This variable of type ...gesture.. is needed to detect tap and hide the keyboard
    let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(HRMViewController.keyboardDismiss))
    // This gesture recognizer is nessesary to detect the tap and hide the keyboard when editing text fields
    view.addGestureRecognizer(tap)
    
    // Disable sliders at at sart-up, since automatic mode is defeault at start-up
    frontHeatSlider.isEnabled = false
    backHeatSlider.isEnabled = false
    modeSwitch.isEnabled = false


    // This manager will initiate BLE central manager
    centralManager = CBCentralManager(delegate: self, queue: nil)
    
    // Make the digits monospaces to avoid shifting when the numbers change [what? !!! check what it does]
   ///frontObjectTemp.font = UIFont.monospacedDigitSystemFont(ofSize: frontObjectTemp.font!.pointSize, weight: .regular)
  }
  
  
  
  // This objective-c object is nessesary to hide the keyboard when done typing to the text field
  @objc func keyboardDismiss(){
    view.endEditing(true)
  }

    
  // The fuction creates and exports the CSV file when data is collected
  // The fuction should be inside of a "class HRMViewController: UIViewController{}" due to self.present() function
  func createCSV() -> Void {
      //Created a default fileName string variable for CSV file name
      var fileName: String = "Unnamed.csv"
      // If anything is in the text field, rename the CSV file name
      if (fileNameTextField.text != ""){
          fileName = "\(fileNameTextField.text!).csv"
      }
      let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
      var csvText = "time,objFrontTemp,objBackTemp,ambFrontTemp,ambBackTemp,dutyCycleFront,dutyCycleBack\n"

      for csvFile in csvFileArr {
          let newLine = "\(csvFile.time),\(csvFile.objFrontTemp),\(csvFile.objBackTemp),\(csvFile.ambFrontTemp),\(csvFile.ambBackTemp),\(csvFile.dutyCycleFront),\(csvFile.dutyCycleBack)\n"
          csvText.append(newLine)
      }
      do {
          try csvText.write(to: path!, atomically: true, encoding: String.Encoding.utf8)
        // Create the Array which includes the files you want to share
          var filesToShare = [Any]()
          // Add the path of the file to the Array
          filesToShare.append(path!)
          // Make the activityViewContoller which shows the share-view
          let activityViewController = UIActivityViewController(activityItems: filesToShare, applicationActivities: nil)
          // Show the share-view
          self.present(activityViewController, animated: true, completion: nil)
      } catch {
          print("Failed to create file")
          print("\(error)")
      }
      print(path ?? "not found")
  }
  
}  // END OF: class HRMViewController: UIViewController {}



// At first, BLE central manager will update its status
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
      // If the phone's BLE is ON, then look for a peripheral that advertises a temperatureServiceCBUUID service
      centralManager.scanForPeripherals(withServices: [temperatureServiceCBUUID])
    @unknown default:
      print("fatal error")
    }
  }

  // If a desired peipheral is found
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                      advertisementData: [String : Any], rssi RSSI: NSNumber) {
    print(peripheral)
    // Record the peripheral
    heartRatePeripheral = peripheral
    heartRatePeripheral.delegate = self
    // Stop BLE scanning
    centralManager.stopScan()
    // Connect to desired peripheral
    centralManager.connect(heartRatePeripheral)
  }
  
  
  
  // Function triggers when the peripheral did connect to the app
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    print("Connected!")
    // Update the top label
    heatControllerTitle.title = "Heat controller (ON)"
    // Not sure. Does it check for other services that were not advertised?
    heartRatePeripheral.discoverServices([temperatureServiceCBUUID])
  }
  
  
  // Function triggers when the peripheral did disconnect
  func centralManager(_ central: CBCentralManager,
  didDisconnectPeripheral peripheral: CBPeripheral,
  error: Error?){
    print("Disconnected :(")
    
    // Update the top label
    heatControllerTitle.title = "Heat controller (OFF)"
    
    // Reset characteristics, so the app know that it can not send anything
    Front_TR_PWM_OUT_Characteristic = nil
    Back_TR_PWM_OUT_Characteristic = nil
    ModeOfOperation_Characteristic = nil
    isRecording_Characteristic = nil
    
    // Disable user inputs
    frontHeatSlider.isEnabled = false
    backHeatSlider.isEnabled = false
    modeSwitch.isEnabled = false
    dataRecordButton.setTitleColor(.opaqueSeparator, for: .normal)
    
    // If data is recording, finish recording and export CSV
    if dataRecordButton.titleLabel!.text == "Stop"{
      
      // Change the fileName text color in textField to red TO REMIND TO CHANGE THE NAME FOR THE NEXT EXPRIMENT
      fileNameTextField.textColor = .red
      // Changing button title back to "Record"
      dataRecordButton.setTitle("Record", for: .normal)
      
      dataRecordingEnable = 0
      // Finish data recording, if disconnedted and export CSV
      // After all nessesary data is in the array, create and export a CSV file
      createCSV()
      //clean the CSV array
      csvFileArr = []
    }
    // It will try to reconnect to the peripheral
    centralManager.connect(heartRatePeripheral)
  }
  
} // END OF: extension HRMViewController: CBCentralManagerDelegate {}



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
      //print(characteristic)

      if characteristic.properties.contains(.read) {
        //print("\(characteristic.uuid): properties contains .read")
        peripheral.readValue(for: characteristic)
      }
      if characteristic.properties.contains(.notify) {
        //print("\(characteristic.uuid): properties contains .notify")
        peripheral.setNotifyValue(true, for: characteristic)
      }
      else if characteristic.uuid == Front_TR_PWM_OUT_CharacteristicCBUUID {
          // Set the characteristic
          Front_TR_PWM_OUT_Characteristic = characteristic
          if modeOfOperation == 0 {
            frontHeatSlider.isEnabled = false
          }else if modeOfOperation == 1{
            frontHeatSlider.isEnabled = true
          }
      } else if characteristic.uuid == Back_TR_PWM_OUT_CharacteristicCBUUID {
          // Set the characteristic
          Back_TR_PWM_OUT_Characteristic = characteristic
          if modeOfOperation == 0 {
            backHeatSlider.isEnabled = false
          }else if modeOfOperation == 1{
            backHeatSlider.isEnabled = true
          }
      } else if characteristic.uuid == isRecording_CharacteristicCBUUID {
          // Set the characteristic
          isRecording_Characteristic = characteristic
          dataRecordButton.setTitleColor(.systemBlue, for: .normal)
          // Send current
          writeToChar( withCharacteristic: isRecording_Characteristic!, withValue: Data([UInt8(dataRecordingEnable)]))
       }else if characteristic.uuid == ModeOfOperation_CharacteristicCBUUID {
          // Set the characteristic
          ModeOfOperation_Characteristic = characteristic
          // Activate thwe mode switch segmented controller
          modeSwitch.isEnabled = true
          // Send the current mode of operation to the chip, once it is connencted
          writeToChar( withCharacteristic: ModeOfOperation_Characteristic!, withValue: Data([UInt8(dataRecordingEnable)]))
       }
      
    }
    
  } // END OF:   func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {}
  
  // NEW DATA IS RECEIVED BY THE APP FROM THE PHERIPHERAL
  // The function triggers when the pheripheral send an updated value for one of the characteristics
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    switch characteristic.uuid {
      case TimeStamp_CharacteristicCBUUID:
        let gotTime = GetTime(from: characteristic)
        timeStamp = gotTime
        
        // If data recording is enabled, append new reading to the array for CSV.
        // Since all data is sent at the same time, all other values are updated as well by this point.
        if dataRecordingEnable == 1 {
          // Creating a NEW varible that will be appended to an array, important!
          // If csvFile variable was instad a global variable, then the folllowing code will rewrite all instances of csvFile each time to the latest value.
          csvFile = CsvFile()
          // assiging new readings to that variable
          csvFile.time = timeStamp
          csvFile.objFrontTemp = objFrontTemp
          csvFile.objBackTemp = objBackTemp
          csvFile.ambFrontTemp = ambFrontTemp
          csvFile.ambBackTemp = ambBackTemp
          csvFile.dutyCycleFront = dutyCycleFront
          csvFile.dutyCycleBack = dutyCycleBack
          // Appending that new variable to the array
          csvFileArr.append(csvFile!)
        }
        print("timeStamp is \(timeStamp)")
    case ambient_VDD_CharacteristicCBUUID:
      let ambient_t_VDD = GetTemperature(from: characteristic)
      // updating a label on the screen
      frontAmbientTemp.text = ambient_t_VDD
      // updating a global variable for later use in CSV
      ambFrontTemp = ambient_t_VDD
    case object_VDD_CharacteristicCBUUID:
      let object_t_VDD = GetTemperature(from: characteristic)
      // updating a label on the screen
      frontObjectTemp.text = object_t_VDD
      // updating a global variable for later use in CSV
      objFrontTemp = object_t_VDD
      print("obje front is \(objFrontTemp)")
    case ambient_GND_CharacteristicCBUUID:
      let ambient_t_GND = GetTemperature(from: characteristic)
      // updating a label on the screen
      backAmbientTemp.text = ambient_t_GND
      // updating a global variable for later use in CSV
      ambBackTemp = ambient_t_GND
    case object_GND_CharacteristicCBUUID:
      let object_t_GND = GetTemperature(from: characteristic)
      // updating a label on the screen
      backObjectTemp.text = object_t_GND
      // updating a global variable for later use in CSV
      objBackTemp = object_t_GND
    case Front_TR_PWM_IN_CharacteristicCBUUID:
      let front_TR_PWM = GetDutyCycle(from: characteristic)
      // updating a label on the screen
      frontDutyCycle.text = front_TR_PWM
      // updating a global variable for later use in CSV
      dutyCycleFront = front_TR_PWM
    case Back_TR_PWM_IN_CharacteristicCBUUID:
      let back_TR_PWM = GetDutyCycle(from: characteristic)
      // updating a label on the screen
      backDutyCycle.text = back_TR_PWM
      // updating a global variable for later use in CSV
      dutyCycleBack = back_TR_PWM
      print("back duty is \(dutyCycleBack)")
    default:
      print("Unhandled Characteristic UUID: \(characteristic.uuid)")
    }
  }


// Fuction handles and encodes teperature data received from an updated charasteristic
  private func GetTemperature(from characteristic: CBCharacteristic) -> String {
    guard let characteristicData = characteristic.value else { return "error" }
    let byteArray = [UInt8](characteristicData)

    // !!! Temperature might be negative, consider using Int8 instead UInt8 for MSB
    let MSB:UInt8 = UInt8(byteArray[0])  // covert single array value MSB byte to usigned integer
    let LSB:UInt8 = UInt8(byteArray[1])  // covert single array value LSB byte to usigned integer
    let decimalPoints:UInt8 = UInt8(byteArray[2]) // gets received decimal point bits
    let integer:Int16 = Int16( (MSB << 8) | LSB)  // megres MBS and LBS into a single integer
    let resultString:String = "\(String(integer)).\(String(decimalPoints))" //conv interger to string

    return resultString
  }
  
    // Fuction handles and encodes Duty Cycle data received from an updated charasteristic
    private func GetDutyCycle(from characteristic: CBCharacteristic) -> String {
      guard let characteristicData = characteristic.value else { return "error" }
      let byteArray = [UInt8](characteristicData)
      let duty:UInt8 = UInt8(byteArray[0])      // covert single array value to usigned integer
      let resultString:String = "\(String(duty))" //conv interger to string

      return resultString
  }
  
  
    // Fuction handles and encodes Time Stamp data received from an updated charasteristic
    private func GetTime(from characteristic: CBCharacteristic) -> String {
      guard let characteristicData = characteristic.value else { return "error" }
      let byteArray = [UInt8](characteristicData)
      let MSB3:UInt32 = UInt32(byteArray[0])    // covert single array value to usigned integer
      let BS2:UInt32 = UInt32(byteArray[1])    //
      let BS1:UInt32 = UInt32(byteArray[2])   //
      let LSB0:UInt32 = UInt32(byteArray[3]) //
      let integer:UInt32 = UInt32( (MSB3 << 24) | (BS2 << 16) | (BS1 << 8) | LSB0)  // Bitwise merge all separate integers into a single one
      let resultString:String = "\(String(integer))" //conv interger to string
      return resultString
  }
}





