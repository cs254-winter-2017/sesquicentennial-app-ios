//
//  HistoricalDataService.swift
//  Carleton150

import Foundation
import Alamofire
import SwiftyJSON

/// Data Service that contains relevant endpoints for the Historical module.
final class HistoricalDataService {
	
	let alamofireManager : Alamofire.Manager?
	
	init() {
		let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
		configuration.timeoutIntervalForResource = 2 // seconds
		self.alamofireManager = Alamofire.Manager(configuration: configuration)
	}
    
    /**
        Request content from the server associated with a landmark on campus.

        - Parameters:
            - geofenceName: Name of the landmark for which to get content.
            - completion: function that will perform the behavior
                          that you want given a dictionary with all content
                          from the server.
     */
    class func requestContent(geofenceName: String, completion: (success: Bool, result: [Dictionary<String, String>?]) ->Void) {
        let parameters = [
            "geofences": [geofenceName]
        ]
        Alamofire.request(.POST, Endpoints.historicalInfo, parameters: parameters, encoding: .JSON).responseJSON() {
            (request, response, result) in
            if let result = result.value {
                let json = JSON(result)
				let answer = json["content"][geofenceName]
				if answer.count > 0 {
					var historicalEntries : [Dictionary<String, String>?] = []
					for i in 0 ..< answer.count {
						// if the result has a defined type
						if let type = answer[i]["type"].string {
							var result = Dictionary<String,AnyObject>()
							// add the type variable
							result["type"] = type
							// if just text returned
							if type == "text" {
								if let summary = answer[i]["summary"].string,
                                       data = answer[i]["data"].string {
									result["summary"] = summary
									result["desc"] = data
                                }
							} else if type == "image" {
								if let desc = answer[i]["desc"].string, data = answer[i]["data"].string, caption = answer[i]["caption"].string {
									result["desc"] = desc
									result["caption"] = caption
									result["data"] = data
								}
							}
							// checking for optional data
							if let year = answer[i]["year"].number {
								result["year"] = year.stringValue
							}
							if let month = answer[i]["month"].string {
								result["month"] = month
							}
							if let day = answer[i]["day"].string {
								result["day"] = day
							}
							historicalEntries.append(result as? Dictionary<String, String>)
							print("Data Successfully retrieved for the \(geofenceName)")
						} else {
							print("Data returned at endpoint: \(Endpoints.historicalInfo) is malformed. Geofence name: \(geofenceName)")
							completion(success: false, result: [])
							return
						}
					}
                    completion(success: true, result: historicalEntries)
                } else {
                    print("No results were found for Geofences.")
                    completion(success: false, result: [])
                }
            } else {
                print("Connection to server failed.")
                completion(success: false, result: [])
            }
        }
    }
    
    /**
        Request memories content on the server.

        - Parameters:
            - location: The current location of the user.
            - completion: function that will perform the behavior
                          that you want given a dictionary with all content
                          from the server.
     */
    class func requestMemoriesContent(location: CLLocationCoordinate2D,
        completion: (success: Bool, result: [Dictionary<String, String>?]) -> Void) {
        
            
        let parameters = [
            "lat" : location.latitude,
            "lng" : location.longitude,
            "rad" : 0.1
        ]
        
        Alamofire.request(.POST, Endpoints.memoriesInfo, parameters: parameters, encoding: .JSON).responseJSON() {
            (request, response, result) in
            if let result = result.value {
                let json = JSON(result)
                let answer = json["content"].arrayValue
                if answer.count > 0 {
                    var memoriesEntries : [Dictionary<String, String>?] = []
                    for i in 0 ..< answer.count {
                        if let image = answer[i]["image"].string,
                               caption = answer[i]["caption"].string,
                               desc = answer[i]["desc"].string,
                               uploader = answer[i]["uploader"].string,
                               takenTimestamp = answer[i]["timestamps"]["taken"].string,
                               postedTimestamp = answer[i]["timestamps"]["posted"].string {
                                
                            var result: Dictionary<String, String> = Dictionary()
                            result["data"] = image
                            result["type"] = "memory"
                            result["desc"] = desc
                            result["caption"] = caption
                            result["uploader"] = uploader
                            result["taken"] = takenTimestamp
                            let dateString = takenTimestamp
                                                .characters.split{$0 == " "}.map(String.init)
                            result["year"] = dateString[0]
                            result["posted"] = postedTimestamp
                            memoriesEntries.append(result)
                        } else {
                            print("Data returned at endpoint: \(Endpoints.memoriesInfo) is malformed.")
                            completion(success: false, result: [])
                            return
                        }
                    }
                    completion(success: true, result: memoriesEntries)
                } else {
                    print("No results were found for Memories.")
                    completion(success: false, result: [])
                }
            } else {
                print("Connection to server failed.")
                completion(success: false, result: [])
            }
        }
    }
    
    class func uploadMemory(memory: Memory, completion: (success: Bool) -> Void) {
        // build the base64 representation of the image
        let imageData = UIImageJPEGRepresentation(memory.image, 0.1)
        let base64Image: String = imageData!.base64EncodedStringWithOptions(.Encoding64CharacterLineLength)
        
        let parameters: [String : AnyObject] = [
            "title" : memory.title,
            "desc" : memory.desc,
            "timestamp" :  memory.timestamp,
            "uploader" : memory.uploader,
            "location" : [
                "lat": memory.location.latitude,
                "lng": memory.location.longitude
            ],
            "image" : base64Image
        ]
        
    
        Alamofire.request(.POST, Endpoints.addMemory, parameters: parameters , encoding: .JSON).responseJSON() {
            (request, response, result) in
            
            
            if let result = result.value {
                let json = JSON(result)
                if json["status"] != nil {
                    if json["status"] == "Success!" {
                        completion(success: true)
                    } else {
                        print("Upload failed.")
                        completion(success: false)
                    }
                } else {
                    print("Upload failed.")
                    completion(success: false)
                }
            } else {
                print("Upload failed.")
                completion(success: false)
            }
        }
    }
    
    /**
        Request nearby geofences based on current location.

        - Parameters:
            - location: The user's current location.
            - completion: function that will perform the behavior
                          that you want given a list with all geofences
                          from the server.
     */
    class func requestNearbyGeofences(location: CLLocationCoordinate2D,
          completion: (success: Bool, result: [(name: String, radius: Int, center: CLLocationCoordinate2D)]?) -> Void) {
        let parameters = [
            "geofence": [
                "location" : [
                    "lat" : location.latitude,
                    "lng" : location.longitude
                ],
                "radius": 100
            ]
        ]
            
        Alamofire.request(.POST, Endpoints.geofences, parameters: parameters, encoding: .JSON).responseJSON() {
            (request, response, result) in
            var final_result: [(name: String, radius: Int, center: CLLocationCoordinate2D)] = []
            
            if let result = result.value {
                let json = JSON(result)
                if let answer = json["content"].array {
                    for i in 0 ..< answer.count {
                        let location = answer[i]["geofence"]["location"]
                        if let fenceName = answer[i]["name"].string,
                               rad = answer[i]["geofence"]["radius"].int,
                               latitude = location["lat"].double,
                               longitude = location["lng"].double {
                                
                                let center = CLLocationCoordinate2D(
                                    latitude: latitude,
                                    longitude: longitude
                                )
                                final_result.append((name: fenceName, radius: rad, center: center))
                        } else {
                            print("Data returned at endpoint: \(Endpoints.geofences) is malformed.")
                            completion(success: false, result: nil)
                            return
                        }
                    }
					print("Data Successfully retrieved for the Geofences")
                    completion(success: true, result: final_result)
                } else {
                    print("No results were found.")
                    completion(success: false, result: nil)
                }
            } else {
                print("Connection to server failed.")
                completion(success: false, result: nil)
            }
        }
    }
}
