//
//  hisVC.swift
//  HealthcareLung3.0
//
//  Created by Cynthia on 30/4/17.
//  Copyright © 2017 Cynthia. All rights reserved.
//

import UIKit
import Charts
import RealmSwift
import Alamofire


class hisVC: UIViewController {
    var text : String!
    var recordDays : [String] = []
    var targetList = [Float]()
    var distanceList = [Float]()
    var realm : Realm!
    
    var myGroup = DispatchGroup()
    var dayList : [String] = []
    
    @IBOutlet weak var segmentControl: UISegmentedControl!

    @IBOutlet weak var chart: CombinedChartView!
    @IBOutlet weak var pie: PieChartView!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        initRealm()
        createRecordList(7)
        renderChart(recordDays)
    }

    /*
     Initiate Realms and Charts.
     */
    func initRealm(){
        do {
            realm = try Realm()
            try! realm.write {
                realm.deleteAll()
            }
        } catch let error as NSError {
            fatalError(error.localizedDescription)
        }
        chart.delegate = self as? ChartViewDelegate
        chart.chartDescription?.text = "Walking Histories"
        pie.chartDescription?.text = "Histories Summary"
        chart.noDataText = "No walking record."
        chart.drawBarShadowEnabled = false
        
        chart.xAxis.centerAxisLabelsEnabled = true
        segmentControl.selectedSegmentIndex = 0
    }
    
    /*
     According to current date, calculate certain days of dates by using calendar.
     */
    func createRecordList( _ num: Int){
        recordDays = []
        dayList = []
        
        let cal = Calendar.current
        var date = cal.startOfDay(for: Date())
        var days = [Int]()
        var months = [Int]()
        var years = [Int]()
        for _ in 1 ... num {
            let day = cal.component( .day, from: date)
            let month = cal.component(.month, from: date)
            let year = cal.component(.year, from: date)
            days.append(day)
            months.append(month)
            years.append(year)
            date = cal.date(byAdding: .day, value: -1, to: date)!
        }
        
        for i in 0 ..< num {
            var dayS: String!
            var monthS: String!
            if days[i] < 10 {
                dayS = "0\(String(days[i]))"
            }else{
                dayS = String(days[i])
                
            }
            if months[i] < 10 {
                monthS = "0\(String(months[i]))"
                
            }else{
                monthS = String(months[i])
                
            }
            let dateString = "\(String(years[i]))\(monthS!)\(dayS!)"
            recordDays.append(dateString)
            let dayInt = months[i]*100 + days[i]
            if dayInt < 1000 {
                dayList.append("0\(dayInt)")
            } else {
                dayList.append("\(dayInt)")
            }
            
        }
        recordDays.reverse()
        dayList.reverse()
    }

    /*
     Render records to the Charts.
     */
    func renderChart(_ dates: [String]){
        getRecords(dates)
    }

    /*
     Get records from the server.
     */
    func getRecords(_ dates: [String]){
        for i in 0 ..< dates.count {
           myGroup.enter()
            let url = "https://webdevzero2hero-eaglegogogo.c9users.io/patients/\(self.text!)/records/app/\(dates[i])"
            Alamofire.request(url).responseJSON { response in
                if (response.result.value != nil){
                    print(response.result.value!)
                    if let info = response.result.value as? [String:Any]{
                        let record = info["record"] as! [[String:Any]]
                        if (record.count > 0) {
                            self.readRecord(dates[i], record[0])
                            self.myGroup.leave()
                        }else{
                            // Not existed
                            self.nullData(dates[i])
                            self.myGroup.leave()
                        }
                    }
                }
            }
        }
        myGroup.notify(queue: .main) {
            print("Finished all requests.")
            self.updateChartWithData()
        }
    }

    /*
     Read and save record in Realms.
     */
    func readRecord(_ date: String, _ record: [String: Any]){
        let data = ChartData()
        data.date = date
        data.distance = record["distance"] as! Float
        data.target = record["target"] as! Float
        data.save()
    }
    
    /*
     Give a default value for non-walking day.
     */
    func nullData(_ date: String){
        
        let data = ChartData()
        data.date = date
        data.distance = 0.0
        data.target = 0.0
        data.save()
    }
    
    /*
     Read records and present charts to the patient.
     */
    func updateChartWithData() {
        var completed : Int = 0
        var incompleted: Int = 0
        let data:CombinedChartData = CombinedChartData()
        var barEntries: [BarChartDataEntry] = []
        var lineEntries: [ChartDataEntry] = []
        let recordCounts = getRecordCountsFromDatabase()
        var preTarget : Float = recordCounts[0].target
        
        print("put into chart... data count:\(recordCounts.count) \(getRecordCountsFromDatabase())")
        
        for i in 0..<recordCounts.count {
           
            if ((recordCounts[i].target != 0) && (recordCounts[i].distance >= recordCounts[i].target)){
                completed += 1
            } else{
                incompleted += 1
            }
            let barEntry = BarChartDataEntry(x: Double(i), y: Double(recordCounts[i].distance))
            barEntries.append(barEntry)
            
            if (recordCounts[i].target == 0 ){
                let lineEntry = ChartDataEntry(x: Double(i), y: Double(preTarget))
                lineEntries.append(lineEntry)

            } else {
                let lineEntry = ChartDataEntry(x: Double(i), y: Double(recordCounts[i].target))
                preTarget = recordCounts[i].target
                lineEntries.append(lineEntry)
            }
        }
        
        let barDataSet = BarChartDataSet(values: barEntries, label: "Walking distances")
        let barData = BarChartData(dataSet: barDataSet)
        let lineDataSet = LineChartDataSet(values: lineEntries, label: "Walking Targets")
        let lineData = LineChartData(dataSet: lineDataSet)
        lineDataSet.colors = [UIColor(red:1.00, green:0.33, blue:0.33, alpha:1.0)]
        lineDataSet.circleHoleRadius = 1
        lineDataSet.circleRadius = 2
        lineDataSet.circleColors = [UIColor(red:1.00, green:0.13, blue:0.44, alpha:1.0)]
        barDataSet.colors = ChartColorTemplates.joyful()
        
        data.barData = barData
        data.lineData = lineData
        
        chart.data = data
        
        chart.xAxis.valueFormatter = IndexAxisValueFormatter(values:dayList)
        chart.xAxis.granularity = 1
        chart.xAxis.labelPosition = .bottom
        chart.animate(xAxisDuration: 1.0, yAxisDuration: 1.0)
        
        let pieText = ["Completed", "Incompleted"]
        var pieEntries : [PieChartDataEntry] = []
        
        let com = PieChartDataEntry(value: Double(completed))
        com.label = pieText[0]
        let incom = PieChartDataEntry(value: Double(incompleted))
        incom.label = pieText[1]

        pieEntries.append(com)
        pieEntries.append(incom)
        
        let pieDataSet = PieChartDataSet(values: pieEntries, label: "Summary")
        
        let pieChartData = PieChartData(dataSet: pieDataSet)
        pie.drawEntryLabelsEnabled = true
        pie.entryLabelColor = UIColor.black
       
        pie.data = pieChartData
        
        var colors: [UIColor] = []
        colors.append(UIColor(red:0.00, green:0.80, blue:0.14, alpha:1.0))
        colors.append(UIColor(red:0.95, green:0.00, blue:0.30, alpha:1.0))
        pieDataSet.colors = colors
        
        refresh()
       
    }

    /*
     Sort the records by date.
     */
    func getRecordCountsFromDatabase() -> Results<ChartData> {
        do {
            let realm = try Realm()
            var data = realm.objects(ChartData.self)
            data = data.sorted(byProperty: "date", ascending: true)
          
            return data
        } catch let error as NSError {
            fatalError(error.localizedDescription)
        }
    }

    /*
     Clear records in Realms.
     */
    func refresh(){

        try! realm.write {
            realm.deleteAll()
        }
        print("deleted all data")
    }

    /*
     Present records according to the pressed segment unit.
     */
    @IBAction func segmentChanged(_ sender: Any) {
        
            if (segmentControl.selectedSegmentIndex  == 0){
                createRecordList(7)
                
            }else if (segmentControl.selectedSegmentIndex == 1){
                createRecordList(14)
                
            }else if (segmentControl.selectedSegmentIndex == 2){
                createRecordList(30)
                
            }else if (segmentControl.selectedSegmentIndex == 3){
                createRecordList(180)
                
            }else if (segmentControl.selectedSegmentIndex == 4){
                createRecordList(365)
            }
            renderChart(recordDays)
    }

    /*
     Back to main menu.
     */
    @IBAction func backBtn(_ sender: Any) {
        refresh()
        recordDays = []
        dayList = []
        dismiss(animated: true, completion: nil)
    }
}

