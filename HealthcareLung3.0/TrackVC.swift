//
//  TrackVC.swift
//  HealthcareLung3.0
//
//  Created by Cynthia on 29/4/17.
//  Copyright © 2017 Cynthia. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import CoreMotion
import Alamofire
import LTMorphingLabel

class TrackVC: UIViewController, MKMapViewDelegate,CLLocationManagerDelegate,LTMorphingLabelDelegate{

    @IBOutlet weak var speedLbl: LTMorphingLabel!
    @IBOutlet weak var distanceLbl: LTMorphingLabel!
    @IBOutlet weak var timeLbl: LTMorphingLabel!
    @IBOutlet weak var upLbl: LTMorphingLabel!
    @IBOutlet weak var downLbl: LTMorphingLabel!
    @IBOutlet weak var stepLbl: LTMorphingLabel!
    
    @IBOutlet weak var speedlbl: LTMorphingLabel!
    @IBOutlet weak var distancelbl: LTMorphingLabel!
    @IBOutlet weak var timelbl: LTMorphingLabel!
    @IBOutlet weak var uplbl: LTMorphingLabel!
    @IBOutlet weak var downlbl: LTMorphingLabel!
    @IBOutlet weak var steplbl: LTMorphingLabel!
    
    @IBOutlet weak var stackLbl: UIStackView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var pauseBtn: UIButton!
    @IBOutlet weak var startBtn: UIButton!
    
    var lastWalkDate: String?
    var pid: String!
    var text: [String:Any]!
    var myGroup = DispatchGroup()
    
    weak var timer: Timer?
    var counter: Int = 0
    var coordinates = [Double]()

    let dformatter = DateFormatter()
    var startTime: NSDate!
    var startTimeStamp: TimeInterval!
    var date : String!
    
    var locationManager: CLLocationManager!
    var preLocation: CLLocation? = nil
    var currentLocation: CLLocation? = nil
    
    var speed : String?
    var up: String?
    var down: String?
    var step: String?
    
    var speedNum : Float = 0.0
    var upNum: Int = 0
    var downNum: Int = 0
    var stepNum: Int = 0
    var steps:Int = 0
    var ups: Int = 0
    var downs: Int = 0
    var distance: CLLocationDistance = 0.0
    var notSteps: Int = 0
    var notUp: Int = 0
    var notDown: Int = 0

    var isStarted: Bool = false
    var isPaused: Bool = false
    var isFirst: Bool = true
    
    
    let activityManager = CMMotionManager()
    let pedometer = CMPedometer()

    
    override func viewDidLoad() {
        super.viewDidLoad()

        dformatter.dateFormat = "yyyyMMdd"
        speedLbl.text = "0.00"
        timeLbl.text = "00:00:00"
        upLbl.text = "0"
        downLbl.text = "0"
        stepLbl.text = "0"
        distanceLbl.text = "0.00"
        view.bringSubview(toFront: stackLbl)
        speedlbl.text = "Speed (m/s)"
        distancelbl.text = "Distance (Km)"
        timelbl.text = "Time"
        uplbl.text = "Ascend"
        downlbl.text = "Descend"
        steplbl.text = "Steps"
        
        /*
         Set up the location manager.
         */
        locationManager = CLLocationManager()
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation;
        locationManager.disallowDeferredLocationUpdates()
        locationManager.activityType = .fitness
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.delegate = self
        mapView.delegate = self
        
        pid = text["id"] as! String
        requestLocation()
    }
    
    /*
     Request a permission to get the location data.
     */
    func requestLocation(){
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedAlways {
            locationManager.startUpdatingLocation()
            mapView.showsUserLocation = true
        } else {
            locationManager.requestAlwaysAuthorization()
            if status == .authorizedAlways{
                locationManager.startUpdatingLocation()
                mapView.showsUserLocation = true
            } else {
                alert("Need your permission to track walk.\nPlease turn on location service in settings")
            }
        }
    }
    
    /*
     Back to main menu when "back" button has been pressed.
     */
    @IBAction func backBtn(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
 
    /*
     Start track walking when "Start" button has been pressed.
     */
    @IBAction func startTrack(_ sender: Any) {
        if self.isStarted == false{
            isStarted = true
            startTime = NSDate()
            startTimeStamp = startTime.timeIntervalSince1970
            date = dformatter.string(from: startTime as Date)
            startBtn.setTitle("Save", for: .normal)
            startBtn.backgroundColor = UIColor.darkGray
            if (CMPedometer.isPaceAvailable() && CMPedometer.isStepCountingAvailable() && CMPedometer.isFloorCountingAvailable()){
                self.startPedometerUpdates()
            }
            timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(UpdateTimer), userInfo: nil, repeats: true)
        }else{
            /*
             End and Save walking when "Save" button has been pressed.
             */
            locationManager.stopUpdatingLocation()

            timer?.invalidate()
            let preDistance = text["distance"] as! Float
            let curDis = distance
            var allCoordinates = [Double]()
            allCoordinates = []
            if text["coordinates"] != nil {
                allCoordinates.append(contentsOf: text["coordinates"] as! [Double])
            }
            allCoordinates.append(contentsOf: coordinates)
            var json = [String:Any]()
            json["distance"] = "\(Double(preDistance) + curDis)"
            json["lastWalkTime"] = "\(startTimeStamp!)"
            json["coordinates"] = allCoordinates
            /*
             Make a HTTP request to update walking data to the server.
             */
            let url = "https://webdevzero2hero-eaglegogogo.c9users.io/patients/\(self.pid!)/records/app/\(date!)"
            if allCoordinates != [] {
                self.myGroup.enter()
                Alamofire.request(url, method:.post, parameters: json, encoding: URLEncoding.default ).responseString{
                (response) in
                if (response.result.value! == "Failure") {
                        self.alert("Uploading failure!")
                }
                self.myGroup.leave()
                }
                self.myGroup.notify(queue: .main) {
                print("Finished all requests.")
                self.backToMain()
                }
            } else {
                self.backToMain()
            }
        }
    }

    /*
     After successfully saved walking data, the scene automatically back to main menu.
     */
    func backToMain(){
        let patientID = self.pid!
        let url = "https://webdevzero2hero-eaglegogogo.c9users.io/patients/app/\(patientID)"
 
        Alamofire.request(url).responseJSON { response in
            
            if (response.result.value != nil){
             
                if let info = response.result.value as? [String:Any]{
                   
                    if (info.count > 0){
                       
                        self.performSegue(withIdentifier: "backMainVC", sender: info)
                      
                    }
                }
            }
        }
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let des = segue.destination as? mainVC {
            if let info = sender as? NSDictionary{
                des.text = info as! [String : Any]
            }
        }
    }
    
    /*
     Get location data in real-time and filter the location with high accuracy.
     */
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let curLocation = locations[0]
        currentLocation = locations[0]

        if (self.preLocation != nil){

            if ((curLocation.horizontalAccuracy < 11 && curLocation.horizontalAccuracy > 0) ) {

                let preLocationCor = self.preLocation!.coordinate
                let curLocationCor = curLocation.coordinate
              
                if (isStarted == true && isPaused == false) {

                    coordinates.append(curLocation.coordinate.latitude)
                    coordinates.append(curLocation.coordinate.longitude)
                    self.distance += self.preLocation!.distance(from: curLocation)/1000
                    let area = [preLocationCor, curLocationCor]
                    let polyline = MKPolyline(coordinates: area, count: area.count)
                    self.mapView.add(polyline)
                    self.distanceLbl.text = "\(String(format: "%.2f",(distance as Double)))"
                    self.speedLbl.text = "\(String(format: "%.2f",(curLocation.speed)))"
                    self.view.bringSubview(toFront: distanceLbl)
                }
            }
        }

        if ((curLocation.horizontalAccuracy < 11 && curLocation.horizontalAccuracy > 0)) {
                self.preLocation = curLocation
            }
        /*
         Show patient's location and keep following patient's location in map.
         */
        mapView.showsUserLocation = true
        mapView.setUserTrackingMode(.follow, animated: true)
        }
    
        /*
        Draw route in the MapView with different colors to indicate different speed.
        */
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if (overlay is MKPolyline) {
                let pr = MKPolylineRenderer(overlay: overlay)
                
                if (Double((currentLocation?.speed)!) < 0.3) {
                    pr.strokeColor = UIColor(red:0.04, green:0.55, blue:0.00, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 0.3 && Double((currentLocation?.speed)!) < 0.4) {
                    pr.strokeColor = UIColor(red:0.04, green:0.61, blue:0.00, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 0.4 && Double((currentLocation?.speed)!) < 0.5) {
                    pr.strokeColor = UIColor(red:0.05, green:0.71, blue:0.00, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 0.5 && Double((currentLocation?.speed)!) < 0.6) {
                    pr.strokeColor = UIColor(red:0.08, green:0.82, blue:0.02, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 0.6 && Double((currentLocation?.speed)!) < 0.7) {
                    pr.strokeColor = UIColor(red:0.10, green:0.95, blue:0.01, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 0.7 && Double((currentLocation?.speed)!) < 0.8) {
                    pr.strokeColor = UIColor(red:1.00, green:0.65, blue:0.34, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 0.8 && Double((currentLocation?.speed)!) < 0.9) {
                    pr.strokeColor = UIColor(red:1.00, green:0.60, blue:0.24, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 0.9 && Double((currentLocation?.speed)!) < 1.0) {
                    pr.strokeColor = UIColor(red:1.00, green:0.53, blue:0.12, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 1.0 && Double((currentLocation?.speed)!) < 1.1) {
                    pr.strokeColor = UIColor(red:1.00, green:0.47, blue:0.00, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 1.1 && Double((currentLocation?.speed)!) < 1.2) {
                    pr.strokeColor = UIColor(red:0.91, green:0.44, blue:0.00, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 1.2 && Double((currentLocation?.speed)!) < 1.3) {
                    pr.strokeColor = UIColor(red:0.84, green:0.42, blue:0.00, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 1.3 && Double((currentLocation?.speed)!) < 1.4) {
                    pr.strokeColor = UIColor(red:0.84, green:0.36, blue:0.00, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 1.4 && Double((currentLocation?.speed)!) < 1.5) {
                    pr.strokeColor = UIColor(red:0.98, green:0.32, blue:0.06, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 1.5 && Double((currentLocation?.speed)!) < 1.6) {
                    pr.strokeColor = UIColor(red:1.00, green:0.28, blue:0.00, alpha:1.0)
                } else if (Double((currentLocation?.speed)!) >= 1.6 && Double((currentLocation?.speed)!) < 1.7) {
                    pr.strokeColor = UIColor(red:0.87, green:0.24, blue:0.00, alpha:1.0)
                } else {
                    pr.strokeColor = UIColor(red:0.76, green:0.19, blue:0.00, alpha:1.0)
                }
              
                pr.lineWidth = 3
                return pr
            }
            return MKPolylineRenderer()
        }
        
        /*
        Start track the walking detail in pedometer.
        */
        func startPedometerUpdates() {

            self.pedometer.startUpdates (from: startTime as Date, withHandler: { pedometerData, error in
                guard error == nil else {
                    print(error!)
                    return
                }
                
                if let numberOfSteps = pedometerData?.numberOfSteps {
                    
                    if ((self.stepNum != 0) && (self.isFirst == true)){
                        self.isFirst = false
                        self.notSteps = Int(numberOfSteps) - self.stepNum
                    }

                    self.steps = Int(numberOfSteps) - self.notSteps
                    self.step = "\(self.steps)"
                }
                
                if let floorsAscended = pedometerData?.floorsAscended {
                    if ((self.upNum != 0) && (self.isFirst == true)){
                        self.isFirst = false
                        self.notUp = Int(floorsAscended) - self.upNum
                    }
                    self.ups = Int(floorsAscended) - self.notUp
                    self.up = "\(self.ups)"
                }
                
                if let floorsDescended = pedometerData?.floorsDescended {
                    if ((self.downNum != 0) && (self.isFirst == true)){
                        self.isFirst = false
                        self.notDown = Int(floorsDescended) - self.downNum
                    }
                    self.downs = Int(floorsDescended) - self.notDown
                    self.down = "\(self.downs)"
                }
                
                DispatchQueue.main.async{
                    self.stepLbl.text = self.step
                    self.upLbl.text = self.up
                    self.downLbl.text = self.down
                }
            })
        }
    
    /*
     Show alert when error happens.
     */
    func alert(_ message:String){
        let alert = UIAlertController(title: "Oops!", message: message, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Got it!", style: .destructive, handler: { (action) -> Void in })
            alert.addAction(cancel)
        self.present(alert, animated: true, completion: nil)
    }
    

    @IBAction func pauseTrack(_ sender: Any) {
        if isStarted == true{
            if self.isPaused == false {
                /*
                 When "Pause" button has been pressed, stop calculating the distance and other motion events.
                 */
                self.isFirst = true
                self.stepNum = self.steps
                self.upNum = self.ups
                self.downNum = self.downs
                self.isPaused = true
                pauseBtn.setTitle("Resume", for: .normal)
                pauseBtn.backgroundColor = UIColor.orange
                self.pedometer.stopUpdates()
                self.speedLbl.text = "0.0"
                timer?.invalidate()
                
            }else {
                /*
                 When "Resume" button has been pressed, start track and calculate walking data again.
                 */
                self.isPaused = false
                pauseBtn.setTitle("Pause", for:.normal)
                pauseBtn.backgroundColor = UIColor.red
                if (CMPedometer.isPaceAvailable() && CMPedometer.isStepCountingAvailable() && CMPedometer.isFloorCountingAvailable()){
                    self.startPedometerUpdates()
                }
                timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(UpdateTimer), userInfo: nil, repeats: true)
            }
        }
    }
    
    /*
     Counting the walking time.
     */
    func UpdateTimer() {
        counter = counter + 1
        
        var time = counter
        let hour = Int(time/3600)
        time -= hour*3600
        
        let min = Int(time/60)
        time -= min*60
        
        let sec = time
        
        let hourString = String(format: "%02d", hour)
        let minString = String(format: "%02d", min)
        let secString = String(format: "%02d", sec)
        
        timeLbl.text = String("\(hourString):\(minString):\(secString)")
    }

}
