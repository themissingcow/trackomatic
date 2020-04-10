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

import Foundation
import AVFoundation

extension MultiPlayer {
 
    // MARK: - Export current mix
    
    func aiffSettings() -> [ String: Any ]
    {
        var settings: [ String: Any ] = [:];
        settings[ AVFormatIDKey ] = kAudioFormatLinearPCM;
        settings[ AVSampleRateKey ] = audioFormat.sampleRate;
        settings[ AVNumberOfChannelsKey ] = audioFormat.channelCount;
        settings[ AVLinearPCMBitDepthKey ] = 24;
        return settings;
    }
    
    func renderTo( output url: URL, settings: [ String: Any ] )
    {
        engine.stop();
        
        do {
            let maxFrames: AVAudioFrameCount = 4096;
            try engine.enableManualRenderingMode( .offline, format: audioFormat, maximumFrameCount: maxFrames );
            try engine.start();
            play( atTime: 0, offline: true );
        } catch {
            fatalError("Enabling manual rendering mode failed: \(error).")
        }
        
        let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: engine.manualRenderingMaximumFrameCount
        )!

        let outputFile: AVAudioFile
        do {
            outputFile = try AVAudioFile(
                forWriting: url,
                settings: settings
            );
        } catch {
            print("Unable to open output audio file: \(error).")
            return;
        }
        
        while engine.manualRenderingSampleTime < frameLength
        {
            do
            {
                let frameCount = frameLength - engine.manualRenderingSampleTime;
                let framesToRender = min( AVAudioFrameCount(frameCount), buffer.frameCapacity );
                
                let status = try engine.renderOffline( framesToRender, to: buffer );
                
                switch status {
                    
                case .success:
                    // The data rendered successfully. Write it to the output file.
                    try outputFile.write( from: buffer );
                    
                case .insufficientDataFromInputNode:
                    // Applicable only when using the input node as one of the sources.
                    break
                    
                case .cannotDoInCurrentContext:
                    // The engine couldn't render in the current render call.
                    // Retry in the next iteration.
                    break
                    
                case .error:
                    // An error occurred while rendering the audio.
                    fatalError("The manual rendering failed.");
                    
                @unknown default:
                    break;
                }
                
            } catch {
                print("The manual rendering failed: \(error).");
            }
        }

        // Stop the player node and engine.
        stop();
        engine.stop()

        engine.disableManualRenderingMode();
        
        do
        {
            try engine.start();
        }
        catch
        {
            print("Unable to restart audio engine: \(error).");
        }
    }
    
}
