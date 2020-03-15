//
//  TrackWaveformCellView.swift
//  Trackomatic
//
//  Created by Tom Cowland on 25/02/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
//

import Cocoa

class TrackWaveformCellView: TrackTableCellView {

    @IBOutlet weak var waveformView: TCWaveformView!
    @IBOutlet weak var commentView: TrackCommentsView!
    
    override var track: MultiPlayer.Track! {
        didSet {
            updateWaveform();
        }
    }
    
    private func updateWaveform()
    {
        self.waveformView.setSampleData( nil, numSamples: 0, scale: 1 );

        if( track == nil )
        {
            return;
        }
                
        let width = UInt32(NSWidth( self.frame ));
        let scale = Float( track.file.length ) / Float( track.parent.length );
        
        let defaultQueue = DispatchQueue.global(qos: .default)
        defaultQueue.async {
            
            let fileURL = self.track.file.url;
            
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
                    if self.track.file.url == fileURL
                    {
                        self.waveformView.setSampleData( data, numSamples: numPoints, scale: scale );
                    }
                    free( data )
               }
            }
        }
    }
    
}
