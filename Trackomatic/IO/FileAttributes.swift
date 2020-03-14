//
//  FileAttributes.swift
//  Trackomatic
//
//  Created by Tom Cowland on 12/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Foundation

func LastModificationTime( url: URL ) -> Date?
{
    do {
        let values = try url.resourceValues( forKeys: [ .contentModificationDateKey ] );
        return values.contentModificationDate;
    }
    catch
    {
        print( "Error retrieving modification time: \(error)");
    }
    return nil;
}

private var modificationTimes: [ URL: Date ] = [:];
// Returns whether the modification time has changed since it was last cached
@discardableResult func HasBeenModified( url: URL ) -> Bool
{
    if let currentModificationTime = LastModificationTime( url: url )
    {
        if let lastModificationTime = modificationTimes[ url ]
        {
            if currentModificationTime == lastModificationTime
            {
                return false;
            }
        }
        modificationTimes[ url ] = currentModificationTime;
    }
    // Default to infering change unless we're sure of the contrary
    return true;
}
