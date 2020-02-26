//
//  TrackWaveformCellView.swift
//  Trackomatic
//
//  Created by Tom Cowland on 25/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa

class TrackWaveformCellView: NSTableCellView {

    @IBOutlet weak var waveformView: TCWaveformView!
    
    weak var state: MultiPlayer.TrackState! {
        didSet {
            updateWaveform();
        }
    }
    
    private func updateWaveform()
    {
        let width = UInt32(NSWidth( self.frame ));
        let scale = Float( self.state.file.length ) / Float( self.state.projectLength );
        
        let defaultQueue = DispatchQueue.global(qos: .default)
        defaultQueue.async {
            
            let fileURL = self.state.file.url;
            
            let dataSource = WaveformCache.Shared.global.sourceFor( fileURL );
            dataSource.preDecimate( 256 );
            
            var numPoints: UInt32 = 0
            var pointDuration: Float = 0.0
            var data: UnsafeMutablePointer<Float>? = nil
            
            data = dataSource.getSampleData(
                withMaxPoints: width,
                storingNumDataPointsIn: &numPoints,
                pointLength: &pointDuration
            );
            
            if data != nil {
           
                DispatchQueue.main.async {
               
                    // Ensure that we're still supposed to be displaying the right track
                    if self.state.file.url == fileURL
                    {
                        self.waveformView.setSampleData( data, numSamples: numPoints, scale: scale );
                    }
                    free( data )
               }
            }
        }
    }
    
}
