//
//  WaveformView.m
//  WaveformTests
//
//  Created by Tom Cowland on 19/11/2013.
//  Copyright (c) 2013 Tom Cowland. All rights reserved.
//

#import "TCWaveformView.h"


@implementation TCWaveformView


@synthesize verticalScale, pointData, numPoints, waveformColor, backgroundColor, dropShadow;


- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self)
    {
      [self initView];
    }
    return self;
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
      [self initView];
    }
    return self;
}


- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self setNeedsDisplay:true];
}


- (void) initView
{
    self.pointData = NULL;
    self.numPoints = 0;
    
    self.verticalScale = 1.0f;
  
    self.backgroundColor = [NSColor whiteColor];
    self.waveformColor = [NSColor grayColor];
    
    self.dropShadow = false;
}


- (void)setSampleData:(float *)sampleData numSamples:(unsigned int)numSamples scale:(float)scale
{
	if ( self.pointData )
	{
		free( self.pointData );
	}
	
	if (  !sampleData || numSamples == 0 )
	{
		self.pointData = NULL;
		self.numPoints = 0;
        [self setNeedsDisplay:true];
		return;
	}

	self.pointData = (CGPoint *)calloc(sizeof(CGPoint),numSamples);
	for ( unsigned int i=0; i<numSamples; i++ )
	{
		self.pointData[i] = CGPointMake( i, sampleData[i] );
	}
  
	self.numPoints = numSamples;
    self.scale = scale;
	
	[self setNeedsDisplay:true];
}



- (void)drawRect:(CGRect)rect
{
    CGContextRef context = [[NSGraphicsContext currentContext] CGContext];
 
	if( self.opaque )
	{
		CGContextSetFillColorWithColor(context, self.backgroundColor.CGColor);
		CGContextFillRect(context, self.bounds);
	}
	
	if ( !self.pointData || self.numPoints == 0 ) { return; }
  
    CGFloat xScale = (float)self.bounds.size.width / ((float)self.numPoints - 1) * self.scale;
    CGFloat yScale = self.bounds.size.height * self.verticalScale;
  
	// Offset by xScale as the waveform data points are the 'middle' not the left edge
    CGAffineTransform lowerXform = CGAffineTransformMake( 1, 0, 0, 1, xScale/2, rect.size.height/2);
    lowerXform = CGAffineTransformScale( lowerXform, xScale, yScale/2 );

    CGAffineTransform upperXform = CGAffineTransformMake( 1, 0, 0, -1, xScale/2, rect.size.height/2 );
    upperXform = CGAffineTransformScale( upperXform, xScale, yScale/2 );
  

	const CGPoint *data = self.pointData;
	const unsigned long nPoints = self.numPoints;
	
    CGMutablePathRef waveformPath = CGPathCreateMutable();
	CGPathMoveToPoint(waveformPath, &lowerXform, 0.0f, 0.0f);
	CGPathAddLineToPoint(waveformPath, &lowerXform, 0.0f, data[0].y);
	for (unsigned long i = 0; i < nPoints; i++)
	{
		CGPathAddLineToPoint(waveformPath, &lowerXform, data[i].x, data[i].y);
	}
  
	for (long i = nPoints-1; i >= 0; --i)
	{
		CGPathAddLineToPoint(waveformPath, &upperXform, data[i].x, data[i].y);
	}
	CGPathAddLineToPoint(waveformPath, &upperXform, 0.0f, 0.0f);
	
	
	// Fill this path
	[self.waveformColor setFill];
	
	CGContextAddPath(context, waveformPath);
	CGContextFillPath(context);
	
    if( self.dropShadow ) {
        
    	// Now create a larger rectangle, which we're going to subtract the visible path from
    	// and apply a shadow
    	CGMutablePathRef path = CGPathCreateMutable();
    	CGPathAddRect(path, NULL, rect);
    	
    	// Add the visible path (so that it gets subtracted for the shadow)
    	CGPathAddPath(path, NULL, waveformPath);
    	CGPathCloseSubpath(path);
    	
    	// Add the visible paths as the clipping path to the context
    	CGContextAddPath(context, waveformPath);
    	CGContextClip(context);
    	
    	// Now setup the shadow properties on the context
    	NSColor *aColor = [NSColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.5f];
    	CGContextSaveGState(context);
    	CGContextSetShadowWithColor(context, CGSizeMake(1.0f, 1.0f), 2.0f, [aColor CGColor]);
    	
    	// Now fill the rectangle, so the shadow gets drawn
    	[self.backgroundColor setFill];
    	CGContextSaveGState(context);
    	CGContextAddPath(context, path);
    	CGContextEOFillPath(context);
	
    	CGPathRelease(path);
    }
    
	CGPathRelease( waveformPath );
}


@end
