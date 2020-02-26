//
//  WaveformView.h
//  WaveformTests
//
//  Created by Tom Cowland on 19/11/2013.
//  Copyright (c) 2013 Tom Cowland. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface TCWaveformView : NSView

- (void)initView;

- (void)setSampleData:(float *)sampleData numSamples:(unsigned int)numSamples scale:(float)scale;
@property float verticalScale;


@property CGPoint *pointData;
@property unsigned int numPoints;
@property float scale;
  
@property IBInspectable NSColor *backgroundColor;
@property IBInspectable NSColor *waveformColor;

@property BOOL dropShadow;


@end
