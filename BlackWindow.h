//
//  BlackWindow.h
//  Isolator
//
//  Created by Ben Willmore on 09/02/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BlackView.h"
#include "CGSPrivate.h"
#import <QuartzCore/CIFilter.h>
#import <QuartzCore/CIVector.h>
#import <Cocoa/Cocoa.h>
#include <ApplicationServices/ApplicationServices.h>

@interface BlackWindow : NSWindow
{
	float opacity;
	bool clickThrough;
	NSTimer* fadeTimer;
	BlackView* blackView;
	float totalElapsed;
	float totalFadeTime;
	float fadeStep;
	NSTimeInterval fadeRepeatTime;
	NSTimeInterval timeOfLastStep;
	CGSCIFilterID filter;
}

- (id)initWithFrame:(NSRect)frame;
- (void)enableBlurAsAppropriate:(float)fraction;
- (void) setLevelAsAppropriate:(BOOL)flipMode;
- (void) setOpacity;
- (void) setClickThrough;
- (void) setColor;
- (void) setFlagsAppropriately;
- (void) _setFlags:(CGSWindowTag)toSet clear:(CGSWindowTag)toClear;
- (void) fadeInOrOut:(BOOL)inOrOut;

@end
