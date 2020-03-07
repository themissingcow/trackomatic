//
//  MultiPlayer+Export.swift
//  Trackomatic
//
//  Created by Tom Cowland on 07/03/2020.
//  Copyright © 2020 Tom Cowland. All rights reserved.
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
            play( atFrame: 0, offline: true );
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
        
        while engine.manualRenderingSampleTime < length
        {
            do
            {
                let frameCount = length - engine.manualRenderingSampleTime;
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
