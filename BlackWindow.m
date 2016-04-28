//
//  BlackWindow.m
//  Isolator
//
//  Created by Ben Willmore on 09/02/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "BlackWindow.h"

const NSTimeInterval kMinFadeTime = 0.01;
const NSTimeInterval kMaxFadeTime = 0.8;
const float kIdealFadeStep = 0.001;
const NSTimeInterval kMinFadeRepeatTime= 0.01;

#ifndef kHIWindowExposeHidden
	#define kHIWindowExposeHidden 1 << 0
#endif

#ifndef kHIWindowVisibleInAllSpaces
	#define kHIWindowVisibleInAllSpaces 1 << 8
#endif

@implementation BlackWindow

- (id)initWithFrame:(NSRect)frame
{
	return [self initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
}

- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)styleMask backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation
{
	[super initWithContentRect:contentRect styleMask:styleMask backing:bufferingType defer:deferCreation];

	blackView = [[BlackView alloc] init];
	[self setReleasedWhenClosed:YES];
	[self setContentView:blackView];
	
	[self setLevelAsAppropriate:NO];

	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

	if (![defaults objectForKey:@"BackgroundOpacity"])
		[defaults setFloat:1.0 forKey:@"BackgroundOpacity"];

	//if (![defaults objectForKey:@"BackgroundClickThrough"])
	//	[defaults setBool:NO forKey:@"BackgroundClickThrough"];

	if (![defaults objectForKey:@"BackgroundFadeSpeed"])
		[defaults setFloat:0.2 forKey:@"BackgroundFadeSpeed"];

	if (![defaults objectForKey:@"BackgroundFilterType"])
		[defaults setInteger:0 forKey:@"BackgroundFilterType"];

	if (![defaults objectForKey:@"WindowBlurRadius"])
		[defaults setFloat:2 forKey:@"WindowBlurRadius"]; // only effective if backgroundfiltertype is >0

	[self setFlagsAppropriately]; // need to do this again after setting level, apparently

	[self setOpacity];
	filter = 0;
	[self enableBlurAsAppropriate:1.0];
	return self;
}

- (void)enableBlurAsAppropriate:(float)fraction
{	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults boolForKey:@"DisplaysAreHardwareAccelerated"])
		return;

	int filterType;
	if ([defaults objectForKey:@"BackgroundFilterType"])
		filterType = [defaults integerForKey:@"BackgroundFilterType"];
	else
		filterType = 0;
	
	float paramVal;
	if ([defaults objectForKey:@"WindowBlurRadius"])
		paramVal = [defaults floatForKey:@"WindowBlurRadius"];
	else
		paramVal = 0.0;
	
	CGSConnection connection  = _CGSDefaultConnection();
		
	// CIPixellate CIGaussianBlur CIMotionBlur CICrystallize CIPointillize CIBloom
	NSString* filterName;
	
	// remove any existing filter
	CGSCIFilterID oldFilter = 0;
	
	if (filter) {
		//CGSRemoveWindowFilter(connection, [self windowNumber], filter);
		//CGSReleaseCIFilter(connection, filter);
		oldFilter = filter;
	}

	NSArray *optionNames = nil;
	NSArray *optionVals = nil;

	if (filterName = [defaults objectForKey:@"CustomFilter"]) {
		NSString* optionName;
		if (!(optionName = [defaults objectForKey:@"CustomFilterOptionName"]))
			optionName = @"inputRadius";
		optionNames = [NSArray arrayWithObjects:optionName, nil];
		float optionMultiplier;
		if (!(optionMultiplier = [defaults floatForKey:@"CustomFilterOptionMultiplier"]))
			optionMultiplier = 1;
		optionVals  = [NSArray arrayWithObjects:[NSNumber numberWithFloat:(paramVal*optionMultiplier)], nil];
	}
	else if (filterType==0) {
		// do nothing, we've just removed all filters which is all we need to do
		if (oldFilter) {
			CGSRemoveWindowFilter(connection, [self windowNumber], oldFilter);
			CGSReleaseCIFilter(connection, oldFilter);
		}
		return;
	}
	else if (filterType==1) {
		filterName = @"CIGaussianBlur";
		optionNames = [NSArray arrayWithObjects:@"inputRadius", nil];
		optionVals  = [NSArray arrayWithObjects:[NSNumber numberWithFloat:paramVal*fraction], nil];
	}
	else if (filterType==2) {
		filterName = @"CIBloom";
		if ([defaults boolForKey:@"RunningOnSnowLeopard"]) {
			optionNames = [NSArray arrayWithObjects:@"inputRadius", @"inputIntensity", nil];
			optionVals  = [NSArray arrayWithObjects:[NSNumber numberWithFloat:(paramVal*3)*fraction], [NSNumber numberWithFloat:0.75], nil];
		} else {
			optionNames = [NSArray arrayWithObjects:@"inputRadius", nil];
			optionVals  = [NSArray arrayWithObjects:[NSNumber numberWithFloat:(paramVal*3)*fraction], nil];
		}
	}
	else if (filterType==3) {
			filterName = @"CICrystallize";
			optionNames = [NSArray arrayWithObjects:@"inputRadius", nil];
			optionVals  = [NSArray arrayWithObjects:[NSNumber numberWithFloat:(paramVal*3)*fraction], nil];
	}
	else if (filterType==4) {
		filterName = @"CIColorControls";
		optionNames = [NSArray arrayWithObjects:@"inputSaturation", nil];
		optionVals  = [NSArray arrayWithObjects:[NSNumber numberWithFloat:0.0], nil];
	}
	
	CGError error = CGSNewCIFilterByName(connection, (CFStringRef)filterName, &filter);
	if (error != noErr) {
		NSLog(@"Error making window filter %@", filterName);
		return;
	}
	
	NSDictionary *optionsDict = [NSDictionary dictionaryWithObjects:optionVals forKeys:optionNames];
	error = CGSSetCIFilterValuesFromDictionary(connection, filter, (CFDictionaryRef)optionsDict);
	if (error != noErr) {
		NSLog(@"Error setting window filter parameters %@ for %@", optionsDict, filterName);
		return;
	}
	
	CGSAddWindowFilter(connection, [self windowNumber], filter, 0x2001); //0x3001
	
	if (oldFilter) {
		CGSReleaseCIFilter(connection, oldFilter);
	}
}

-(void) setLevelAsAppropriate:(BOOL)flipMode
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if ( ([defaults boolForKey:@"HideBackgroundApps"]&&(!flipMode)) ||
		 ((![defaults boolForKey:@"HideBackgroundApps"])&&flipMode) )
		[self setLevel:CGWindowLevelForKey(kCGDesktopIconWindowLevelKey)+1];
	else
		[self setLevel:CGWindowLevelForKey(kCGNormalWindowLevelKey)];

	[self setFlagsAppropriately];
}

- (void)setOpacity
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults objectForKey:@"BackgroundOpacity"])
		opacity = 1.0;
	else 
		opacity = [defaults floatForKey:@"BackgroundOpacity"]*0.9+0.1; 
	
	[self setAlphaValue:opacity];
	if (opacity<1.0)
		[self _setFlags:CGSTagTransparent clear:CGSTagNone];
	else
		[self _setFlags:CGSTagNone clear:CGSTagTransparent];
}

- (void)setClickThrough
{
	// this is now done in setOpacity
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults objectForKey:@"BackgroundClickThrough"])
		clickThrough = NO;
	else 
		clickThrough = [defaults boolForKey:@"BackgroundClickThrough"]; 
	
	if (clickThrough)
		[self _setFlags:CGSTagTransparent clear:CGSTagNone];
	else
		[self _setFlags:CGSTagNone clear:CGSTagTransparent];
}

- (void) setFlagsAppropriately {
	// this is all slightly mysterious, but I think:
	// CGSTagSticky makes the window not show up in F9
	// CGSTagExposeFade makes it not show up in F8 or F10
	// CGSTagNoShadow gets rid of shadow
	// kHIWindowExposeHidden does nothing ?!
	// kHIWindowVisibleInAllSpaces makes window visible in all spaces
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

	[self _setFlags:(CGSTagSticky | CGSTagNoShadow | CGSTagExposeFade) clear:0];
	
	// window is present on all spaces
	if ([defaults boolForKey:@"RunningOnLeopard"])
		HIWindowChangeAvailability((HIWindowRef) [self windowRef], kHIWindowExposeHidden | kHIWindowVisibleInAllSpaces, 0);
	
}

- (void)_setFlags:(CGSWindowTag)toSet clear:(CGSWindowTag)toClear
{
	CGSConnection cid;
	CGSWindow wid;
	wid = [self windowNumber];
	cid = _CGSDefaultConnection();
	CGSWindowTag tags[2] = {0,0};

	CGSGetWindowTags(cid, wid, tags, 32);
	tags[0] = tags[0] | toSet;	
	CGSSetWindowTags(cid, wid, tags, 32);
	tags[0] = toClear;	
	CGSClearWindowTags(cid, wid, tags, 32);
}

- (void) setColor
{
	[blackView setColor];
}

- (void)fadeInOrOut:(BOOL)inOrOut
{
	if (fadeTimer) {
		[fadeTimer invalidate];
		fadeTimer = nil;
	}
	
	if (inOrOut) {
		[self setAlphaValue:0.];
		[self orderFront:self];
	}
	
	float fadeSpeed;
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults objectForKey:@"BackgroundFadeSpeed"])
		fadeSpeed = 0.2;
	else
		fadeSpeed = [defaults floatForKey:@"BackgroundFadeSpeed"];
	
	totalFadeTime = fadeSpeed*(kMaxFadeTime-kMinFadeTime)+kMinFadeTime;
	
	fadeRepeatTime = totalFadeTime*kIdealFadeStep;
	
	if (fadeRepeatTime<kMinFadeRepeatTime)
		fadeRepeatTime = kMinFadeRepeatTime;
	
	fadeStep = fadeRepeatTime/totalFadeTime;
	//NSLog(@"%5.5f %5.5f",fadeRepeatTime,fadeStep);
	totalElapsed = 0.0;
	
	SEL fadeSelector = inOrOut ? @selector(_fadeIn) : @selector(_fadeOut);
	timeOfLastStep = [NSDate timeIntervalSinceReferenceDate];
	fadeTimer = [NSTimer scheduledTimerWithTimeInterval:fadeRepeatTime target:self selector:fadeSelector userInfo:nil repeats:YES];
}

- (void)_fadeIn
{
    if ([self alphaValue] >= opacity) {
        [fadeTimer invalidate];
		fadeTimer = nil;
		return;
    }
	NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];
	NSTimeInterval elapsed = time - timeOfLastStep;
	timeOfLastStep = time;

	float newAlpha = [self alphaValue] + (elapsed/fadeRepeatTime)*fadeStep*opacity;
	if (newAlpha>opacity)
		newAlpha = opacity;
    [self setAlphaValue:newAlpha];
	//[self setAlphaValue:0.5];
	totalElapsed = totalElapsed + elapsed;
	//NSLog(@"%5.2f",(elapsed/totalFadeTime));
	float frac = (totalElapsed/totalFadeTime);
	if (frac<.1) frac=.1;
	[self enableBlurAsAppropriate:frac];
}

- (void)_fadeOut
{
    if ([self alphaValue] <= 0.) {
        [fadeTimer invalidate];
		fadeTimer = nil;
        [self orderOut:self];
        return;
    }
	NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];
	NSTimeInterval elapsed = time - timeOfLastStep;
	timeOfLastStep = time;

	float newAlpha = [self alphaValue] - (elapsed/fadeRepeatTime)*fadeStep*opacity;
	if (newAlpha<0.)
		newAlpha = 0.;
    [self setAlphaValue:newAlpha];
	//[self setAlphaValue:0.0];
	totalElapsed = totalElapsed + elapsed;
	float frac = (totalElapsed/totalFadeTime);
	if (frac>.9) frac=.9;
	[self enableBlurAsAppropriate:1-frac];
}

- (BOOL) canBecomeKeyWindow
{
	return YES;
}

- (BOOL) canBecomeMainWindow
{
	return YES;
}

- (BOOL)performKeyEquivalent:(NSEvent *)anEvent
{
	return YES;
}

- (void) dealloc
{	
	[fadeTimer release];
	[blackView release];
	[super dealloc];
}

@end
