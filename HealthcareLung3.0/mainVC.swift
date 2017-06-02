//
//  mainVC.swift
//  HealthcareLung3.0
//
//  Created by Cynthia on 27/4/17.
//  Copyright © 2017 Cynthia. All rights reserved.
//

import UIKit
import GTProgressBar
import CoreData
import Alamofire
import UserNotifications
import LTMorphingLabel
import UserNotifications


class mainVC: UIViewController, LTMorphingLabelDelegate {

    @IBOutlet weak var label: LTMorphingLabel!
    @IBOutlet weak var label1: LTMorphingLabel!
    @IBOutlet weak var label2: LTMorphingLabel!
    @IBOutlet weak var progressLbl: LTMorphingLabel!
    @IBOutlet weak var hisBtn: UIButton!
    @IBOutlet weak var newBtn: UIButton!
    @IBOutlet weak var hisIcon: UIImageView!
    @IBOutlet weak var newIcon: UIImageView!
    
    var text: [String:Any]!
    var todayRecord:NSDictionary?
    var pid: String!
    var target: Float!
    var name: String!
    var lastWalkTime: TimeInterval!
    var lastSetTime: TimeInterval!
    var date: Date!
    let dtformatter = DateFormatter()
    let dformatter = DateFormatter()
    var curDate:NSDate!
    var curDistance:Float?
    var todayCopy = [String:Any]()
    var webToken: String!
    
    let app = UIApplication.shared.delegate as! AppDelegate

    
    override func viewDidLoad() {
        super.viewDidLoad()

        let patient = text["patient"] as! [String:Any]
        pid = patient["_id"] as! String!
        target = patient["target"] as! Float
        name = patient["name"] as! String
        lastWalkTime = patient["lastWalkTime"] as! TimeInterval
        webToken = patient["deviceToken"] as? String
        
        /*
         Check whether have the permission to push notification. If got the permission, the
         application will register the remote notification service.
         */
        let notificationType = UIApplication.shared.currentUserNotificationSettings?.types
        if notificationType?.rawValue == 0 {
            alert("Not enable")
        } else {
            print("Enabled")
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        /*
         If device token has changed, make a HTTP request to update the newest device token
         to the server.
         */
        if deviceTokenString != nil {
            if (webToken != nil) {
                if webToken != deviceTokenString {
                    print("update")
                    var token = [String:Any]()
                    token["deviceToken"] = deviceTokenString
                    let urlToken = "https://webdevzero2hero-eaglegogogo.c9users.io/patients/\(self.pid!)/token"
                    
                    Alamofire.request( urlToken, method: .post, parameters: token, encoding: URLEncoding.default ).responseString{
                        (response) in
                        print(response.result)
                    }
                }else{
                    print("no update")
                }
            }else{
                print("update")
                var token = [String:Any]()
                token["deviceToken"] = deviceTokenString
                let urlToken = "https://webdevzero2hero-eaglegogogo.c9users.io/patients/\(self.pid!)/token"
                
                Alamofire.request( urlToken, method: .post, parameters: token, encoding: URLEncoding.default ).responseString{
                    (response) in
                    print(response.result)
                }
            }
        }
       
        
        date = Date(timeIntervalSince1970: lastWalkTime)
        dtformatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dformatter.dateFormat = "yyyyMMdd"
        /*
         Show the patient information in labels.
         */
        label.text = " Welcome \(name!)!"
        label1.text = " Your daily walking target is \(target!) Km."
        label2.text = " Last walk time is \(dtformatter.string(from: date! as Date))"
        
        getRecord()
        /*
         Save patient information in local database for auto login.
         */
        let patientFetch = NSFetchRequest<Patient>(entityName: "Patient")
        do{
            var patients = try context.fetch(patientFetch)
            if patients != [] {
                if patients[patients.count - 1].id != pid {
                    deletePatient()
                    savePatient()
                }
            }
            
        }catch {
            let nserror = error as NSError
            fatalError("error delete： \(nserror), \(nserror.userInfo)")
        }
    }

    /*
     Sign out this app and delete local patient imformation.
     */
    @IBAction func signout(_ sender: Any) {
        deletePatient()
        performSegue(withIdentifier: "backLogin", sender: nil)
    }
    
    /*
     Get patient information from the server and present in progress bar and labels.
     */
    func getRecord(){
        curDate = NSDate()
        let curDateString = dformatter.string(from: curDate as Date)
        let url = "https://webdevzero2hero-eaglegogogo.c9users.io/patients/\(self.pid!)/records/app/\(curDateString)"
        Alamofire.request(url).responseJSON { response in
            if (response.result.value != nil){
            
                if let info = response.result.value as? [String:Any]{
                    let record = info["record"] as! [[String:Any]]
                    if (record.count > 0){
                        self.curDistance = record[0]["distance"] as? Float
                        self.todayCopy["id"] = record[0]["patientid"] as? String
                        self.todayCopy["target"] = record[0]["target"] as? Float
                        self.todayCopy["distance"] = self.curDistance
                        
                        let progress = (self.curDistance!) / (self.target!)
                        if (progress >= 1.0){
                            self.showGreenProgress(CGFloat(progress))
                            self.progressLbl.text = "Congrats! Daily target completed!"
                        } else if (progress == 0){
                            self.showGreenProgress(0.0)
                            self.progressLbl.text = "No walking record today!"
                        } else{
                            self.showRedProgress(CGFloat(progress))
                            self.progressLbl.text = "You still have \(String(format: "%.2f",(self.target - self.curDistance!))) Km to walk."
                        }
                    } else {
                        self.progressLbl.text = "New walking session is not set!"
                        self.showRedProgress(0.0)
                   
                        self.todayCopy["id"] = self.pid
                        self.todayCopy["target"] = self.target
                        self.todayCopy["distance"] = 0.0000 as Float
                    }
                }
            }else{
                /*
                 If doctor does not set the walking session, there is no record that can be shown
                 in main menu scene.
                 */
                self.progressLbl.text = "New walking session is not set!"
                self.showRedProgress(0.0)
                
                self.todayCopy["id"] = self.pid
                self.todayCopy["target"] = self.target
                self.todayCopy["distance"] = 0.0000 as Float
            }
        }
    }
    
    /*
     Save patient information in local at the first time login.
     */
    func savePatient(){
        let patient = Patient(context: context)
        patient.id = self.pid
        patient.name = self.name
        patient.target = self.target
        patient.lastWalkTime = self.date! as NSDate
        appDelegate.saveContext()
    }
    
    /*
     Delete patient information from local database.
     */
    func deletePatient(){
        let patientFetch = NSFetchRequest<Patient>(entityName: "Patient")
        do{
            let patients = try context.fetch(patientFetch)
            for patient in patients{
                context.delete(patient)
                app.saveContext()
                print("delete success!")
            }
        }catch {
            let nserror = error as NSError
            fatalError("error delete： \(nserror), \(nserror.userInfo)")
        }
    }
    
    /*
     Turn to tracking scene
     */
    @IBAction func loadTrackVC(_ sender: Any) {
        performSegue(withIdentifier: "trackVC", sender: todayCopy)
    }
    
    /*
     Send information among scenes.
     */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let des = segue.destination as? TrackVC{
            if let info = sender as? [String:Any]{
                des.text = info
            }
        }
        
        if let des = segue.destination as? hisVC{
            if let info = sender as? String{
            des.text = info
            }
        }
    }

    @IBAction func loadHisVC(_ sender: Any) {
        performSegue(withIdentifier: "hisVC", sender: pid)
    }
    
    /*
     Show a green progess bar.
     */
    func showGreenProgress(_ pro:CGFloat){
        let progressBar = GTProgressBar(frame: CGRect(x: 0, y: 0, width: 250, height: 30))
        progressBar.barBorderColor = UIColor(red:0.35, green:0.80, blue:0.36, alpha:1.0)
        progressBar.barFillColor = UIColor(red:0.35, green:0.80, blue:0.36, alpha:1.0)
        progressBar.barBackgroundColor = UIColor(red:0.77, green:0.93, blue:0.78, alpha:1.0)
        progressBar.barBorderWidth = 1
        progressBar.barFillInset = 2
        progressBar.labelTextColor = UIColor(red:0.35, green:0.80, blue:0.36, alpha:1.0)
        progressBar.progressLabelInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        progressBar.font = UIFont.boldSystemFont(ofSize: 18)
        progressBar.labelPosition = GTProgressBarLabelPosition.right
        progressBar.barMaxHeight = 12
        progressBar.animateTo(progress: pro)
        progressBar.center = self.view.center;
        view.addSubview(progressBar)
    }
    
    /*
     Show a red progess bar.
     */
    func showRedProgress(_ pro:CGFloat){
        let progressBar = GTProgressBar(frame: CGRect(x: 0, y: 0, width: 250, height: 30))
        progressBar.barBorderColor = UIColor(red:1, green:0, blue:0, alpha:1.0)
        progressBar.barFillColor = UIColor(red:1, green:0, blue:0, alpha:1.0)
        progressBar.barBackgroundColor = UIColor(red:1, green:0, blue:0, alpha:0.3)
        progressBar.barBorderWidth = 1
        progressBar.barFillInset = 2
        progressBar.labelTextColor = UIColor(red:1, green:0, blue:0, alpha:1.0)
        progressBar.progressLabelInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        progressBar.font = UIFont.boldSystemFont(ofSize: 18)
        progressBar.labelPosition = GTProgressBarLabelPosition.right
        progressBar.barMaxHeight = 12
        progressBar.animateTo(progress: pro)
        progressBar.center = self.view.center;
        view.addSubview(progressBar)
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
}








