//
//  Photo+Extension.swift
//  VirtualTourist
//
//  Created by Kenneth Gutierrez on 6/30/22.
//

import CoreData

extension Photo {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Photo> {
        return NSFetchRequest<Photo>(entityName: "Photo")
    }

    @NSManaged public var id: String?
    @NSManaged public var photoData: Data?
    @NSManaged public var pin: Pin?
    
}

extension Photo: Identifiable { }
