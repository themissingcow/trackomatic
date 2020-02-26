//
//  WaveformCacme.swift
//  Trackomatic
//
//  Created by Tom Cowland on 25/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Foundation

class WaveformCache : NSObject
{
    struct Shared {
        static var global = WaveformCache()
    }
    
    typealias DataSourceMap = [URL: TCWaveformDataSource]
    var dataSources = DataSourceMap()

    func sourceFor( _ url: URL ) -> TCWaveformDataSource
    {
        if let source = dataSources[ url ] {
            return source
        } else {
            var source: TCWaveformDataSource?
            objc_sync_enter( dataSources )
            source = dataSources[ url ]
            if source == nil  {
                source = TCWaveformDataSource()
                source!.audioFile = url
                dataSources[ url ] = source!
            }
            objc_sync_exit( dataSources )
            return source!
        }
    }
    
    func clear( _ url: URL? = nil ) -> Void
    {
        objc_sync_enter( dataSources )
        if let u = url {
            if let s = dataSources[ u ] {
                s.clearDecimationCache()
                dataSources[ u ] = nil
            }
        } else {
            for s in dataSources.values {
                s.clearDecimationCache()
            }
            dataSources.removeAll( keepingCapacity: false )
        }
        objc_sync_exit( dataSources )
    }
}






