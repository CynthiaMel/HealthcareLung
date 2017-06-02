//
//  loginVC.swift
//  HealthcareLung3.0
//
//  Created by Cynthia on 27/4/17.
//  Copyright © 2017 Cynthia. All rights reserved.
//

import UIKit
import Alamofire
import CoreData

class loginVC: UIViewController {

    let app = UIApplication.shared.delegate as! AppDelegate
    @IBOutlet weak var typein: UITextField!
    override func viewDidLoad() {
        super.viewDidLoad()
        typein.text = ""
        isLoged()
    }
    
    /*
     Decide whether the patient has loged in.
     */
    func isLoged(){
        
        let patientFetch = NSFetchRequest<Patient>(entityName: "Patient")
        do{
            let patients = try context.fetch(patientFetch)
            if patients == []{
            } else {
                getInfo(patients[patients.count - 1].id!)
            }            
        }catch {
            let nserror = error as NSError
            fatalError("error delete： \(nserror), \(nserror.userInfo)")
        }
    }
    
    /*
     Turn to the main menu scene.
     */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let des = segue.destination as? mainVC {
            if let info = sender as? NSDictionary{
                des.text = info as! [String : Any]
            }            
        }
    }
    
    /*
     When "sign in" button has been pressed, decide the next action.
     */
    @IBAction func signIn(_ sender: Any) {
        if typein.text == ""{
            //Please enter your ID
            alert("Please enter your unique ID")
        }else{
            getInfo(typein.text!)
        }
    }
    
    /*
     Get patient information from the server.
     */
    func getInfo(_ id : String){
        let patientID = id
        let url = "https://webdevzero2hero-eaglegogogo.c9users.io/patients/app/\(patientID)"
    
        Alamofire.request(url).responseJSON { response in
                if ( response.result.value != nil ){
                    if let info = response.result.value as? [String:Any]{
                        if let content = info["patient"] as? [String:Any]{
                            self.performSegue(withIdentifier: "mainVC", sender: info)
                        }
                        else{
                            /* 
                             Show alert when ID is not existed
                             */
                            self.typein.text = ""
                            self.alert("Incorrect ID!\n Please try again!")
                        }
                    }
                } else {
                    /*
                     Show alert when server can not be connected.
                     */
                    self.alert("Can not connect to the server!")
            }
        }
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
