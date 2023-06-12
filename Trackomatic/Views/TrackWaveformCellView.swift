//
//  Copyright (c) 2020, Tom Cowland. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//      * Redistributions of source code must retain the above
//        copyright notice, this list of conditions and the following
//        disclaimer.
//
//      * Redistributions in binary form must reproduce the above
//        copyright notice, this list of conditions and the following
//        disclaimer in the documentation and/or other materials provided with
//        the distribution.
//
//      * Neither the name of Tom Cowland nor the names of
//        any other contributors to this software may be used to endorse or
//        promote products derived from this software without specific prior
//        written permission.
//
//      * Any redistribution of the source code, it's binary form, or any
//        project derived from the source code must remain free of charge and
//        on a not for profit basis.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
//  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
//  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
//  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
//  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
//  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
//  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
//  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
//  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
        let scale = Float( track.duration ) / Float( track.parent.duration );
        
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
						self.waveformView.normalize();
                    }
                    free( data )
               }
            }
        }
    }
    
}
