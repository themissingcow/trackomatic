//
//  WaveformDataSource.h
//  WaveformTests
//
//  Created by Tom Cowland on 19/11/2013.
//  Copyright (c) 2013 Tom Cowland. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TCWaveformDataSource : NSObject

@property NSURL *audioFile;

- (void)clearDecimationCache;
- (void)preDecimate:(UInt32)packetSize;

- (float *)getSampleData:(UInt32)packetSize storingNumDataPointsIn:(UInt32 *)numPoints pointLength:(float *)pointLength;
- (float *)getSampleDataWithMaxPoints:(UInt32)maxPoints storingNumDataPointsIn:(UInt32 *)numPoints pointLength:(float *)pointLength;

@end
