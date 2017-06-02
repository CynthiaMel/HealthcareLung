//
//  ChartData.swift
//  HealthcareLung3.0
//
//  Created by Cynthia on 1/5/17.
//  Copyright © 2017 Cynthia. All rights reserved.
//

import Foundation
import RealmSwift

class ChartData :Object {
    dynamic var date: String = String()
    dynamic var distance: Float = Float(0)
    dynamic var target: Float = Float(0)
    

    func save() {
        do {
            let realm = try Realm()
            try realm.write {
                realm.add(self)
            }
        } catch let error as NSError {
            fatalError(error.localizedDescription)
        }
    }
    
}

