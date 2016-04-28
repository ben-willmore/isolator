//
//  IsoController.m
//  Isolator
//
//  Created by Ben Willmore on 08/02/2007.
//  Copyright 2007 Ben Willmore. All rights reserved.
//

#import "Carbon/Carbon.h"
#import "HIToolbox/MacApplication.h"
#import "IsoController.h"

#ifndef NSAppKitVersionNumber10_4
	#define NSAppKitVersionNumber10_4 824
#endif

#ifndef NSAppKitVersionNumber10_5
	#define NSAppKitVersionNumber10_5 949
#endif

#ifndef NSAppKitVersionNumber10_6
	#define NSAppKitVersionNumber10_6 1038
#endif

#ifndef NSAppKitVersionNumber10_7
    #define NSAppKitVersionNumber10_7 1138
#endif

@implementation IsoController

static int kAppSwitched = 1;
static int kEnteredIsolateMode = 2;
//static kIsolatorModeChanged = 3;

static int kCentury = 100;

static NSString* kBetaFeedURL = @"http://willmore.eu/software/isolator/allversions.xml";
static NSString* kReleaseFeedURL = @"http://willmore.eu/software/isolator/releases.xml";

static IsoController *me;

pascal OSStatus appSwitched (EventHandlerCallRef nextHandler, EventRef theEvent, void* userData)
// handle change in frontmost app
{
	[me isolate:kAppSwitched];

	return noErr;
}

OSStatus hotKeyHandler(EventHandlerCallRef nextHandler,EventRef theEvent, void *userData)
// handle hotkey press
{
	EventHotKeyID hkCom;
	GetEventParameter(theEvent,kEventParamDirectObject,typeEventHotKeyID,NULL,sizeof(hkCom),NULL,&hkCom);
	int l = hkCom.id;
 
	switch (l) {
	case 1: // isolator hotkey
		[me toggle:NO];
		break;
	case 2: // prefs win hotkey
		[me openPrefs];
		break;
	case 3: // alternate hotkey
		[me toggle:YES];
		break;
	}
	
	return noErr;
}

-(id) init
{
	[super init];
	
	if (getenv("NSZombieEnabled") || getenv("NSAutoreleaseFreedObjectCheckEnabled")) {
		NSLog(@"NSZombieEnabled/NSAutoreleaseFreedObjectCheckEnabled enabled!");
	}
	
	savedFrames = nil;
	lastAppActivated = nil;
	
	//sparkleUpdater = [[SUUpdater alloc] init];

	// register for Carbon event on app switching
    me = self;

    EventTypeSpec eventType;
    eventType.eventClass = kEventClassApplication;
    eventType.eventKind  = kEventAppFrontSwitched;
    EventHandlerUPP handlerUPP = NewEventHandlerUPP(appSwitched);
    InstallApplicationEventHandler (handlerUPP, 1, &eventType, self, NULL);
    DisposeEventHandlerUPP(appSwitched);
	
	// read preferences
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

	if (![defaults objectForKey:@"StartupMode"])
		[defaults setInteger:1 forKey:@"StartupMode"];
	
	flipMode = NO;
	suspended = NO;
	
	if ([defaults integerForKey:@"StartupMode"]==0) 
		active = YES;
	else
		active = NO;
	
	if (![defaults objectForKey:@"HideBackgroundApps"])
		[defaults setInteger:NO forKey:@"HideBackgroundApps"];

	if (![defaults objectForKey:@"SuspendWhenFinderIsActive"])
		[defaults setBool:NO forKey:@"SuspendWhenFinderIsActive"];	

	if (![defaults objectForKey:@"HideOnMainScreenOnly"]) {
		[defaults setBool:NO forKey:@"HideOnMainScreenOnly"];
	}
	else {
		// there IS an object for this key. We can reasonably assume that the user has used Isolator before
		// we will make sure the user isn't annoyed by the infoBox 
		// (even though the user hasn't actually seen the box because it wasn't introduced until 3.40beta)
		[defaults setBool:YES forKey:@"InfoBoxHasBeenShown"];
	}
		
	if ((floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4) && ![defaults boolForKey:@"TigerTest"]) {
		[defaults setBool:YES forKey:@"RunningOnLeopard"];
	}
	else {
		[defaults setBool:NO forKey:@"RunningOnLeopard"];
	}
	
	if ((floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_5) && ![defaults boolForKey:@"TigerTest"]) {
		[defaults setBool:YES forKey:@"RunningOnSnowLeopard"];
	}
	else {
		[defaults setBool:NO forKey:@"RunningOnSnowLeopard"];
	}

    if ((floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) && ![defaults boolForKey:@"TigerTest"]) {
		[defaults setBool:YES forKey:@"RunningOnLion"];
	}
	else {
		[defaults setBool:NO forKey:@"RunningOnLion"];
	}

	
	[self checkIfDisplaysAreHardwareAccelerated];
	
	if (![defaults objectForKey:@"HideDock"])
		[defaults setBool:NO forKey:@"HideDock"];

	if ([defaults integerForKey:@"Hotkey"]==0) {
		[defaults setInteger:34 forKey:@"Hotkey"]; // cmd-shift-i
		[defaults setInteger:NSCommandKeyMask+NSShiftKeyMask forKey:@"HotkeyFlags"];
	}

	if ([defaults integerForKey:@"PrefsHotkey"]==0) {
		[defaults setInteger:34 forKey:@"PrefsHotkey"]; // cmd-shift-option-i
		[defaults setInteger:NSCommandKeyMask+NSShiftKeyMask+NSAlternateKeyMask forKey:@"PrefsHotkeyFlags"];
	}
	
	// don't set alternate hotkey by default, but it is used if the user sets it
	
	if (![defaults objectForKey:@"ShowMenubarIcon"])
		[defaults setBool:YES forKey:@"ShowMenubarIcon"];	

	if (![defaults objectForKey:@"MouseClickEffect"])
		[defaults setInteger:1 forKey:@"MouseClickEffect"];	

	if (![defaults objectForKey:@"NumberOfTimesUsed"])
		[defaults setInteger:0 forKey:@"NumberOfTimesUsed"];	

	if (![defaults objectForKey:@"SUScheduledCheckInterval"])
		[defaults setInteger:86400 forKey:@"SUScheduledCheckInterval"];	
	
	if ( ![defaults objectForKey:@"MostRecentVersionUsed"] || ([defaults floatForKey:@"MostRecentVersionUsed"]<3.38) ) 
		[self migratePrefsTo338];

	[defaults setFloat:[[[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"] floatValue] forKey:@"MostRecentVersionUsed"];

	// set up hotkey for prefs window
	EventHotKeyID gMyHotKeyID;
	eventType.eventClass=kEventClassKeyboard;
	eventType.eventKind=kEventHotKeyPressed;
	gMyHotKeyID.signature='htk2';
	gMyHotKeyID.id=2;
	int keyCode = 0;
	unsigned int keyFlags = 0;
	if ([defaults objectForKey:@"PrefsHotkey"] && [defaults objectForKey:@"PrefsHotkeyFlags"]) {
		int keyCode = [defaults integerForKey:@"PrefsHotkey"];
		unsigned int keyFlags = SRCocoaToCarbonFlags([defaults integerForKey:@"PrefsHotkeyFlags"]);
		RegisterEventHotKey(keyCode, keyFlags, gMyHotKeyID, GetApplicationEventTarget(), 0, &gMyHotKeyRef);
	}
	
	if ([defaults objectForKey:@"AlternateHotkey"] && [defaults objectForKey:@"AlternateHotkeyFlags"]) {
		keyCode = [defaults integerForKey:@"AlternateHotkey"];
		keyFlags = SRCocoaToCarbonFlags([defaults integerForKey:@"AlternateHotkeyFlags"]);
		gMyHotKeyID.signature='htk3';
		gMyHotKeyID.id=3;
		RegisterEventHotKey(keyCode, keyFlags, gMyHotKeyID, GetApplicationEventTarget(), 0, &gMyHotKeyRef);
	}

	shownCenturyMessage = NO;
	if ([defaults integerForKey:@"NumberOfTimesUsed"]>=kCentury)
		shownCenturyMessage = YES;
	
	// startupitem
	startupItemController = [[StartupItemController alloc] init];
	
	// status bar control
	//[self setupStatusItem]; // now in awakeFromNib because we need the infoBox to have awoken

	gMyHotKeyRef = 0;

	// value transformer
	LessThanAboutOne *lessThanAboutOne;
	
	lessThanAboutOne = [[[LessThanAboutOne alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:lessThanAboutOne forName:@"LessThanAboutOne"];

	// register for notification on change of screen configuration
	[[NSDistributedNotificationCenter defaultCenter]
                addObserver:self
                selector:@selector(applicationDidChangeScreenParameters:)
                name:NSApplicationDidChangeScreenParametersNotification
                object:nil];
	
	[self setupAppleScripts];
	
	infoBox = nil;
	
	return self;
}

-(void) awakeFromNib
{
	[self setupBlackWindows];
	[self setKeyCombo];
	[self setupStatusItem];
}

-(void) setKeyCombo
{
	KeyCombo keyCombo;
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

	keyCombo.code = [defaults integerForKey:@"Hotkey"];
	keyCombo.flags = [defaults integerForKey:@"HotkeyFlags"];
	[shortcutRecorder setKeyCombo:keyCombo];
}

-(void) saveKeyCombo
{
	KeyCombo keyCombo = [shortcutRecorder keyCombo];
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	[defaults setInteger:keyCombo.code forKey:@"Hotkey"];
	[defaults setInteger:keyCombo.flags forKey:@"HotkeyFlags"];
	[self syncDefaults:self];
}

-(void) setupStatusItem
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"ShowMenubarIcon"]==NO) {
		if (statusItem) {
			[[NSStatusBar systemStatusBar] removeStatusItem:statusItem];
			[statusItem release];
		}
		statusItem = nil;
		return;
	}
	
	if (statusItem) {
		return;
	}
	
	[self initStatusMenu];
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];

	if (!statusItem) {
		NSLog(@"Could not create StatusItem");
		return;
	}

	NSRect theFrame = NSZeroRect; // Seems to work. Correct?? I dunno.
	
	IsoStatusItemView* siView = [[[IsoStatusItemView alloc] initWithFrame:theFrame isoController:self] autorelease];
	[statusItem setView:siView];
	[[statusItem view] setNeedsDisplay:YES];
	[statusItem setHighlightMode:YES];
	
	if (![defaults boolForKey:@"InfoBoxHasBeenShown"]) {
		theFrame = [[siView window] frame];
		NSPoint pt = NSMakePoint(NSMidX(theFrame), NSMinY(theFrame));
		[self showInfoBoxAtPoint:pt];
	}
}

-(NSStatusItem*) getStatusItem
{
	return statusItem;
}

-(void) initStatusMenu
{
	statusMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Isolator",nil)];

	[statusMenu setDelegate:self];
	
	if (active)
		toggleMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Turn Isolator Off",nil) action:@selector(toggle) keyEquivalent:@""];
	else
		toggleMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Turn Isolator On",nil) action:@selector(toggle) keyEquivalent:@""];
	
	[statusMenu insertItem:toggleMenuItem atIndex:0];

	[statusMenu insertItem:[NSMenuItem separatorItem] atIndex:1];
	
	NSMenuItem* prefsMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Preferences...",nil) action:@selector(openPrefs) keyEquivalent:@""] autorelease];
	[statusMenu insertItem:prefsMenuItem atIndex:2];
	
	[statusMenu insertItem:[NSMenuItem separatorItem] atIndex:3];

	NSMenuItem* updateMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Check for updates...",nil) action:@selector(checkForUpdates:) keyEquivalent:@""] autorelease];
	//[updateMenuItem setTarget:self];
	[statusMenu insertItem:updateMenuItem atIndex:4];

	NSMenuItem* aboutMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"About Isolator",nil) action:@selector(openAboutPanel) keyEquivalent:@""] autorelease];
	[statusMenu insertItem:aboutMenuItem atIndex:5];
	
	NSMenuItem* quitMenuItem = [[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quit",nil) action:@selector(exit) keyEquivalent:@""] autorelease];
	[statusMenu insertItem:quitMenuItem atIndex:6];
}

-(NSMenu*)getStatusMenu
{
	return statusMenu;
}

-(void)showStatusMenu
{
	[self bringWindowsForward];
	[statusItem popUpStatusItemMenu:statusMenu];
}

-(void) applicationDidChangeScreenParameters:(id)object
{
	[self checkIfDisplaysAreHardwareAccelerated];
	[self setupBlackWindows];
}

-(void) setupBlackWindows
{
	int i;
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	NSMutableArray* frames = [[NSMutableArray alloc] init];
	if ([defaults boolForKey:@"HideOnMainScreenOnly"]==YES) {
		[frames addObject:[NSValue valueWithRect:[[NSScreen mainScreen] frame]]];
	}
	else {
		for (i=0;i<[[NSScreen screens] count];i++) {
			[frames addObject:[NSValue valueWithRect:[[[NSScreen screens] objectAtIndex:i] frame]]];
		}
	}
	//NSLog(@"%@",frames);
	
	BOOL framesActuallyChanged = NO;
	if (!savedFrames) {
		framesActuallyChanged = YES;
	}
	else {
		if ([savedFrames count]!=[frames count]) {
			framesActuallyChanged = YES;
		}
		else {
			for (i=0;i<[frames count];i++) {
				if ( !NSEqualRects([[frames objectAtIndex:i] rectValue],[[savedFrames objectAtIndex:i] rectValue]) )
					framesActuallyChanged = YES;
			}
		}
	}

	if (savedFrames)
		[savedFrames release];
	savedFrames = [[NSArray alloc] initWithArray:frames copyItems:YES];
	
	// then the black windows already exist, and the screens didn't change, we don't need to do anything 
	if (blackWindows&&(!framesActuallyChanged)) {
		[frames release];
		return;
	}
		
	if (blackWindows) {
		NSEnumerator *blackEnumerator = [blackWindows objectEnumerator];
		BlackWindow *blackWindow = nil;
		while (blackWindow = [blackEnumerator nextObject]) {
			[blackWindow close];
		}
		[blackWindows release];
	}
	
	blackWindows = [[NSMutableArray alloc] init];
	NSEnumerator *enumerator = [frames objectEnumerator];
	NSValue* frame;
	BlackWindow* window;
	NSRect thisRect;
	
	while( frame = [enumerator nextObject] ) {
		thisRect = frame.rectValue;
		window = [[BlackWindow alloc] initWithFrame:[frame rectValue]];
		[blackWindows addObject:window];
	}
		
	if (active) {
		[self enterIsolateMode:NO];
	}
	else {
		NSEnumerator *enumerator = [blackWindows objectEnumerator];
		BlackWindow* window;
		while( window = [enumerator nextObject] ) {
			[window orderOut:self];
		}
	}
	[frames release];
}

-(void) checkIfDisplaysAreHardwareAccelerated
{
	// actually, we're only going to set this to YES on Leopard
	bool hwAccel;
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

	if (![defaults boolForKey:@"RunningOnLeopard"]) {
		hwAccel = NO;
	}
	else {
		NSNumber *screenID = nil;

		hwAccel = YES;
		
		if ([defaults boolForKey:@"HideOnMainScreenOnly"]==YES) {
			screenID = [[[NSScreen mainScreen] deviceDescription] objectForKey:@"NSScreenNumber"];
			if (!CGDisplayUsesOpenGLAcceleration((CGDirectDisplayID)[screenID intValue]))
				hwAccel = NO;
		}
		else {
			NSArray* screens;
			screens = [[NSScreen screens] copy];
		
			NSEnumerator *screenEnumerator = [screens objectEnumerator];
			NSScreen *screen = nil;
			NSNumber *screenID = nil;
			while (screen = [screenEnumerator nextObject]) {
				screenID = [[screen deviceDescription] objectForKey:@"NSScreenNumber"];
				if (!CGDisplayUsesOpenGLAcceleration((CGDirectDisplayID)[screenID intValue]))
					hwAccel = NO;
			}
			[screens release];
		}	
	}
	[defaults setBool:hwAccel forKey:@"DisplaysAreHardwareAccelerated"];
}

-(void) toggle
{	
	[self toggle:NO];
}

-(void) toggle:(BOOL)shouldFlip
{	
	if (active)
		[self leaveIsolateMode];
	else
		[self enterIsolateMode:shouldFlip];
}

-(void) enterIsolateMode:(BOOL)shouldFlip
{	
	// when isolate mode is turned on by hotkey or menu icon
	if (!shownCenturyMessage) {
		NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
		int numTimes = [defaults integerForKey:@"NumberOfTimesUsed"]+1;
		[defaults setInteger:numTimes forKey:@"NumberOfTimesUsed"];
		if (numTimes==kCentury) {
			[self showCenturyMessage];
			shownCenturyMessage = YES;
			return;
		}
	}

	active = YES;
	suspended = NO;
	flipMode = shouldFlip;
	
	[[statusItem view] setNeedsDisplay:YES];
	[toggleMenuItem setTitle:NSLocalizedString(@"Turn Isolator Off",nil)];

	// level depends on whether we're hiding other apps or not
	NSEnumerator *enumerator = [blackWindows objectEnumerator];
	BlackWindow* window;
	while( window = [enumerator nextObject] ) {
		[window setLevelAsAppropriate:flipMode];
	}
	
	[self isolate:kEnteredIsolateMode];

	didAffectDock = NO;
	[self hideDockAsAppropriate];
}

-(void) isolate:(int) reason
{
	if ( !active )
		return;
	
	// get details of the currently (newly?) active app
	NSDictionary* activeApp = [[[NSWorkspace sharedWorkspace] activeApplication] copy];

	int myPID = [[NSProcessInfo processInfo] processIdentifier];
	
	if (reason==kAppSwitched) {
		if ( ([[activeApp objectForKey:@"NSApplicationProcessIdentifier"] intValue]==myPID)
			// then Isolator became frontmost. Ignore.
			|| ([[activeApp objectForKey:@"NSApplicationProcessIdentifier"] isEqual:[lastAppActivated objectForKey:@"NSApplicationProcessIdentifier"]]) ) {
			// then we got an app switched message, but the active app didn't actually change. Ignore.

			[activeApp release];
			activeApp = nil;
			return;
		}
	}

	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

	BOOL fadingOut = NO;
	BOOL fadingIn = NO;
	if ( [defaults boolForKey:@"SuspendWhenFinderIsActive"] ) {
		if ( [[activeApp objectForKey:@"NSApplicationBundleIdentifier"] isEqual:@"com.apple.finder"] ) {
			[self fadeOutBlackWindows];
			fadingOut = YES;
			suspended = YES;
		}
		else if ( suspended ) {// [[lastAppActivated objectForKey:@"NSApplicationBundleIdentifier"] isEqual:@"com.apple.finder"]  ) {
			[self revealBlackWindows];
			fadingIn = YES;
			suspended = NO;
		}
	}
	
	if ( (reason!=kAppSwitched) && (!fadingOut) && (!fadingIn) ) {
		[self revealBlackWindows];
	}
	
	if (lastAppActivated)
		[lastAppActivated release];
	lastAppActivated = [activeApp retain];	

	if ( ([defaults boolForKey:@"HideBackgroundApps"]&&(!flipMode)) ||
		 ((![defaults boolForKey:@"HideBackgroundApps"])&&flipMode) ) {
		 
		// then hide all the background apps
		if ( (![defaults boolForKey:@"SuspendWhenFinderIsActive"]) || 
			(![[activeApp objectForKey:@"NSApplicationBundleIdentifier"] isEqual:@"com.apple.finder"]) ) { 
			[self hideAppsExcept:activeApp];

			// this kludge makes cmd-tabbing work correctly. without it, sometimes the frontmost application doesn't move to 
			// the left of the bar as it should            
            if (![defaults boolForKey:@"RunningOnLion"]) {
                  [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(toggleFrontmostApp:) userInfo:activeApp repeats:NO];
            }
		}
	}
	else {
		if (!fadingOut) {
			// bring all windows of frontmost app in front of others, and position black windows behind
			[self setFrontmostAppAndPositionBlackWindows:activeApp];
		}
	}
	[activeApp release];
}

-(void)revealBlackWindows
{
	NSEnumerator *enumerator = [blackWindows objectEnumerator];
	BlackWindow* window;
	while( window = [enumerator nextObject] ) {
		[window fadeInOrOut:YES];
	}
}

-(void) fadeOutBlackWindows
{
	NSEnumerator *enumerator = [blackWindows objectEnumerator];
	BlackWindow* window;
	while( window = [enumerator nextObject] ) {
		[window fadeInOrOut:NO];
	}
}


-(void)hideAppsExcept:(NSDictionary*)excludeApp
{
	NSNumber* excludePID = [excludeApp objectForKey:@"NSApplicationProcessIdentifier"];
	
	NSArray* launchedApps = [[[NSWorkspace sharedWorkspace] launchedApplications] copy];
	NSEnumerator* appEnum = [launchedApps objectEnumerator];
	NSDictionary* app = nil;
	NSNumber* pid = nil;
	ProcessSerialNumber psn;
		
	ProcessInfoRec info;
	info.processInfoLength = sizeof(ProcessInfoRec);
	info.processName = nil;
	FSSpec tempFSSpec;
	info.processAppSpec = &tempFSSpec;

	while (app = [appEnum nextObject]) {
		pid = [app objectForKey:@"NSApplicationProcessIdentifier"];
		
		if (![pid isEqual:excludePID]) {
			psn.highLongOfPSN = [[app objectForKey:@"NSApplicationProcessSerialNumberHigh"] longValue];
			psn.lowLongOfPSN = [[app objectForKey:@"NSApplicationProcessSerialNumberLow"] longValue];

			if (GetProcessInformation(&psn, &info) == noErr) {
				ShowHideProcess(&psn,FALSE);
			}
		}
	}
			
	[launchedApps release];
}

-(void) toggleFrontmostApp:(id)sender
{
	ProcessSerialNumber myPSN;
	GetCurrentProcess(&myPSN);
	SetFrontProcess(&myPSN);

	ProcessSerialNumber activePSN;
	activePSN.highLongOfPSN = [[[sender userInfo] objectForKey:@"NSApplicationProcessSerialNumberHigh"] intValue];
	activePSN.lowLongOfPSN = [[[sender userInfo] objectForKey:@"NSApplicationProcessSerialNumberLow"] intValue];
	SetFrontProcess(&activePSN);
}

-(void) setFrontmostAppAndPositionBlackWindows:(id)sender
{
	NSDictionary* theApp = nil;
	int counter = -1;
	
	if ( [sender isKindOfClass:[NSDictionary class]] ) {
		// then it's the first time we've been called
		theApp = sender;
		counter = 0;
	}
	else {
		// then we're being called by the timer
		theApp = [sender userInfo];
		counter = [[theApp objectForKey:@"counter"] intValue];
	}

	// check the relevant app is still frontmost (prevents infinite loops)
	NSDictionary* activeApp = [[[NSWorkspace sharedWorkspace] activeApplication] copy];
	if (![[theApp objectForKey:@"NSApplicationProcessIdentifier"] isEqual:[activeApp objectForKey:@"NSApplicationProcessIdentifier"]]) {
		[activeApp release];
		return;
	}
		
	[self setFrontmostApp:activeApp];
	[self positionBlackWindows:activeApp];
	
	counter++;

	if (counter<=5) {
		NSMutableDictionary* newActiveApp = [activeApp mutableCopy];
		[newActiveApp setObject:[NSNumber numberWithInt:counter] forKey:@"counter"];
		[NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(setFrontmostAppAndPositionBlackWindows:) userInfo:newActiveApp repeats:NO];	
		[newActiveApp release];
	}
	[activeApp release];
}

-(void) setFrontmostApp:(id)sender
{
	NSDictionary* activeApp = nil;
	
	if ([sender isKindOfClass:[NSDictionary class]])
		activeApp = sender;
	else
		activeApp = [sender userInfo];
		
	ProcessSerialNumber activePSN;
	activePSN.highLongOfPSN = [[activeApp objectForKey:@"NSApplicationProcessSerialNumberHigh"] intValue];
	activePSN.lowLongOfPSN = [[activeApp objectForKey:@"NSApplicationProcessSerialNumberLow"] intValue];
	SetFrontProcess(&activePSN);
}

-(void) positionBlackWindows:(id)sender
{
	NSDictionary* activeApp = nil;
	
	if ([sender isKindOfClass:[NSDictionary class]])
		activeApp = sender;
	else
		activeApp = [sender userInfo];

	ProcessSerialNumber activePSN;
	
	activePSN.highLongOfPSN = [[activeApp objectForKey:@"NSApplicationProcessSerialNumberHigh"] longValue];
	activePSN.lowLongOfPSN = [[activeApp objectForKey:@"NSApplicationProcessSerialNumberLow"] longValue];
	
	CGSConnection cid;
	CGSGetConnectionIDForPSN(0, &activePSN, &cid);

	ProcessSerialNumber myPSN;
	CGSConnection myCid;
	GetCurrentProcess(&myPSN);
	CGSGetConnectionIDForPSN(0, &myPSN, &myCid);

	int nWindowsIn,nWindows;
	
	CGSGetOnScreenWindowCount(myCid, cid, &nWindowsIn); 
	CGSWindow list[nWindowsIn];
	CGSGetOnScreenWindowList(myCid, cid, nWindowsIn, list, &nWindows);
	
	// Find windows at level 0
	int ii;
	int level;
	int nRelevantWindows = 0;
	CGSWindow relevantList[nWindows];
	
	OSStatus err;
	for (ii=0;ii<nWindows;ii++) {
		err = CGSGetWindowLevel(myCid, list[ii], &level);
		if (level==0) {
			relevantList[nRelevantWindows] = list[ii];
			nRelevantWindows++;
		}
	}
	
	NSEnumerator *enumerator = [blackWindows objectEnumerator];
	BlackWindow* window;
	while( window = [enumerator nextObject] ) {
		if (nRelevantWindows==0)
			[window orderFrontRegardless];
		else
			[window orderWindow:NSWindowBelow relativeTo:relevantList[nRelevantWindows-1]];
	}
}


-(void) leaveIsolateMode
{
	[lastAppActivated release];
	lastAppActivated = nil;
	
	active = NO;

	NSEnumerator *enumerator = [blackWindows objectEnumerator];
	BlackWindow* window;
	while( window = [enumerator nextObject] ) {
		[window fadeInOrOut:NO];
	}

	[self restoreDockAutohide];

	[[statusItem view] setNeedsDisplay:YES];
	[toggleMenuItem setTitle:NSLocalizedString(@"Turn Isolator On",nil)];
}

-(void) openPrefs
{
	[prefWindow setAutodisplay:YES];
	[self willChangeValueForKey:@"startupItemEnabled"];
	[self didChangeValueForKey:@"startupItemEnabled"];
	[NSApp activateIgnoringOtherApps:YES];
	[prefWindow makeKeyAndOrderFront:self];
}

-(IBAction)setBackgroundColor:(id)sender
{	
	[self syncDefaults:self];
	NSEnumerator *enumerator = [blackWindows objectEnumerator];
	BlackWindow* window;
	while( window = [enumerator nextObject] ) {
		[window setColor];
	}
	[[statusItem view] setNeedsDisplay:YES];
}

-(IBAction)setOpacity:(id)sender
{
	[self syncDefaults:self];
	NSEnumerator *enumerator = [blackWindows objectEnumerator];
	BlackWindow* window;
	while( window = [enumerator nextObject] ) {
		[window setOpacity];
	}
	[[statusItem view] setNeedsDisplay:YES];
}

-(IBAction)setBlur:(id)sender
{
	[self syncDefaults:self];
	NSEnumerator *enumerator = [blackWindows objectEnumerator];
	BlackWindow* window;
	while( window = [enumerator nextObject] ) {
		[window enableBlurAsAppropriate:1.0];
	}
}

-(IBAction)setClickThrough:(id)sender
{
	[self syncDefaults:self];
	NSEnumerator *enumerator = [blackWindows objectEnumerator];
	BlackWindow* window;
	while( window = [enumerator nextObject] ) {
		[window setClickThrough];
	}
}

-(IBAction)setMenuBarIcon:(id)sender
{
	[self syncDefaults:self];
	[self setupStatusItem];
}

-(IBAction)setHideBackgroundApps:(id)sender
{
	[self syncDefaults:self];
	[self leaveIsolateMode];
	[self enterIsolateMode:flipMode];
}

-(IBAction)setSuspendWhenFinderIsActive:(id)sender
{
	NSDictionary* activeApp = [[[NSWorkspace sharedWorkspace] activeApplication] copy];
	if ( [[activeApp objectForKey:@"NSApplicationBundleIdentifier"] isEqual:@"com.apple.finder"] ) {
		[self leaveIsolateMode];
		[self enterIsolateMode:flipMode];
	}
	[activeApp release];
}

-(void)setUpdatesIncludeBetaVersions:(BOOL)flag
{
	if (flag)
		[sparkleUpdater setFeedURL:[NSURL URLWithString:kBetaFeedURL]];
	else
		[sparkleUpdater setFeedURL:[NSURL URLWithString:kReleaseFeedURL]];
}

-(BOOL)updatesIncludeBetaVersions
{
	if ([[sparkleUpdater feedURL] isEqual:[NSURL URLWithString:kBetaFeedURL]])
		return YES;
	else
		return NO;
}

-(void) setNilValueForKey:(NSString *)theKey;
{
    if ([theKey isEqualToString:@"updatesIncludeBetaVersions"])
		[sparkleUpdater setFeedURL:[NSURL URLWithString:kReleaseFeedURL]];
}

-(IBAction)setWindow:(id)sender
{
	[self syncDefaults:self];
	if (!active)
		return;

	NSEnumerator *enumerator = [blackWindows objectEnumerator];
	BlackWindow* window;
	while( window = [enumerator nextObject] ) {
		[window fadeInOrOut:YES];
	}
}

-(void) registerHotkey:(KeyCombo)keyCombo
{
	if (gMyHotKeyRef>0) {
		UnregisterEventHotKey(gMyHotKeyRef);
	}
	
	// set up hotkey -- remember asynckeys for key codes
	EventHotKeyID gMyHotKeyID;
	EventTypeSpec eventType;
	eventType.eventClass=kEventClassKeyboard;
	eventType.eventKind=kEventHotKeyPressed;
	
	InstallApplicationEventHandler(&hotKeyHandler,1,&eventType,NULL,NULL);

	gMyHotKeyID.signature='htk1';
	gMyHotKeyID.id=1;
	
	RegisterEventHotKey([shortcutRecorder keyCombo].code, [shortcutRecorder cocoaToCarbonFlags:[shortcutRecorder keyCombo].flags], 
		gMyHotKeyID, GetApplicationEventTarget(), 0, &gMyHotKeyRef);
}

- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo;
{
	[self registerHotkey:newKeyCombo];
	[self saveKeyCombo];
}

- (void)syncDefaults:(id)sender
{
	[[NSUserDefaults standardUserDefaults] synchronize];
}

-(BOOL)startupItemEnabled
{
	return [startupItemController enabled];
}

-(void)setStartupItemEnabled:(BOOL)value
{
	[startupItemController setEnabled:value];
}

-(void)openAboutPanel
{
	[NSApp orderFrontStandardAboutPanel:self];
	[NSApp activateIgnoringOtherApps:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[[NSUserDefaults standardUserDefaults] synchronize];
	[self restoreDockAutohide];
}

-(BOOL)isActive
{
	return active;
}

-(void)showCenturyMessage {
	NSAlert* alert = [[NSAlert alloc] init];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"You have used Isolator %d times.",nil),kCentury]];
	[alert setInformativeText:NSLocalizedString(@"Please consider donating a few dollars to support its continued development. Either way, you won't see this message again.",nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"Go to Paypal donation page",nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"Don't donate",nil)];

	int result = [alert runModal];
	if (result==NSAlertFirstButtonReturn) {
		NSString* urlString = @"https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=bdeb%40willmore%2eeu&item_name=Isolator&no_shipping=2&no_note=1&tax=0&currency_code=GBP&bn=PP%2dDonationsBF&charset=UTF%2d8";
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
	}
	[alert release];
}

-(void)setupAppleScripts
{
	// Dock preferences are only accessible by AppleScript on 10.5+
	NSDictionary** errorInfo = NULL;
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"RunningOnLeopard"]) {
		getDockAutohideScript = [[NSAppleScript alloc] initWithSource:@"tell application \"System Events\" to tell dock preferences to set foo to autohide"];
		[getDockAutohideScript compileAndReturnError:errorInfo];

		setDockAutohideTrueScript = [[NSAppleScript alloc] initWithSource:@"tell application \"System Events\" to tell dock preferences to set autohide to true"];
		[setDockAutohideTrueScript compileAndReturnError:errorInfo];

		setDockAutohideFalseScript = [[NSAppleScript alloc] initWithSource:@"tell application \"System Events\" to tell dock preferences to set autohide to false"];
		[setDockAutohideFalseScript compileAndReturnError:errorInfo];
	}
	
	if (!getDockAutohideScript || !setDockAutohideTrueScript || !setDockAutohideFalseScript) {
		[getDockAutohideScript release];
		getDockAutohideScript = nil;
		[setDockAutohideTrueScript release];
		setDockAutohideTrueScript = nil;
		[setDockAutohideFalseScript release];
		setDockAutohideFalseScript = nil;
	}
}

-(void)saveDockAutohide
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults boolForKey:@"RunningOnLeopard"]) {
		dockAutohide = NO;
		return;
	}

	NSDictionary** errorInfo;
	NSAppleEventDescriptor* result;
	if (result = [getDockAutohideScript executeAndReturnError:errorInfo])
		dockAutohide = [result booleanValue];
}

-(void)restoreDockAutohide
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"HideDock"] && didAffectDock)
		[self setDockAutohide:dockAutohide];
}

-(BOOL)getDockAutohide
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults boolForKey:@"RunningOnLeopard"])
		return NO;
	
	NSDictionary** errorInfo;
	NSAppleEventDescriptor* result;
	if (result = [getDockAutohideScript executeAndReturnError:errorInfo]) {
		return [result booleanValue];
	}
	else {
		return NO;
	}
}

-(void)setDockAutohide:(BOOL)hide
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults boolForKey:@"RunningOnLeopard"])
		return;

	NSDictionary** errorInfo;
	if (hide)
		[setDockAutohideTrueScript executeAndReturnError:errorInfo];
	else
		[setDockAutohideFalseScript executeAndReturnError:errorInfo];
}

-(void)hideDockAsAppropriate
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"HideDock"] && ![self getDockAutohide]) {
		didAffectDock = YES;
		[self saveDockAutohide];
		[self setDockAutohide:YES];
	}
	else {
		didAffectDock = NO;
	}
}

-(IBAction)setDockHidingPref:(id)sender
{
	if (!active)
		return;
		
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"HideDock"]) {
		[self saveDockAutohide];
		[self setDockAutohide:YES];
	}
	else {
		if (didAffectDock)
			[self setDockAutohide:dockAutohide];
	}
}

-(IBAction)checkForUpdates:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[sparkleUpdater checkForUpdates:sender];
}

-(void)bringWindowsForward
{
	NSArray* windows = [NSApp windows];
	
	NSEnumerator *winEnumerator = [windows objectEnumerator];
	NSEnumerator *blackWinEnumerator;
	BOOL isABlackWin;
	
	NSWindow *window = nil;
	NSWindow *blackWindow = nil;
	
	while (window = [winEnumerator nextObject]) {
		blackWinEnumerator = [blackWindows objectEnumerator];
		isABlackWin = NO;
		while (blackWindow = [blackWinEnumerator nextObject]) {
			if (window==blackWindow)
				isABlackWin = YES;
		}
		if (!isABlackWin && [window isVisible]) {
			//	(@"%@: activating",window);
			[window orderFrontRegardless];
		}
	}
	
}

-(void) migratePrefsTo338
{
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];

	if (![defaults objectForKey:@"BackgroundFilterType"])
		return;
	
	int filterIdx = [defaults integerForKey:@"BackgroundFilterType"];
	if (filterIdx==5)
		filterIdx = 2;
	else if (filterIdx==2)
		filterIdx = 3;
	else if (filterIdx==3)
		filterIdx = 0;
	
	[defaults setInteger:filterIdx forKey:@"BackgroundFilterType"];
}

-(void) showInfoBoxAtPoint:(NSPoint)pt
{
	if (infoBox) {
		// it's already open?!
		return;
	}
	//NSLog(@"%@ %@ %5.2f %5.2f", infoBoxView, infoBoxTextField,pt.x,pt.y);

	infoBox = [[MAAttachedWindow alloc] initWithView:infoBoxView 
									 attachedToPoint:pt 
											inWindow:nil 
											  onSide:MAPositionBottom 
										  atDistance:24.0];
	[infoBoxTextField setTextColor:[infoBox borderColor]];
	//[infoBoxTextField setStringValue:@"Your text goes here..."];
	[NSApp activateIgnoringOtherApps:YES];
	[infoBox makeKeyAndOrderFront:self];
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	[defaults setBool:YES forKey:@"InfoBoxHasBeenShown"];
	[NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(closeInfoBox:) userInfo:nil repeats:NO];
}

-(void)closeInfoBox:(id)sender
{
	[infoBox orderOut:self];
	[infoBox release];
	infoBox = nil;
}

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key
{
    if ([key isEqual:@"active"]) {
        return YES;
    } else {
        return NO;
    }
}

- (void)setActive:(NSNumber *)activate
{
	BOOL shouldActivate = [activate boolValue];
	
	if (shouldActivate && !active) {
		[self enterIsolateMode:NO];
	}
	else if (!shouldActivate && active) {
		[self leaveIsolateMode];
	}
}

-(void) dealloc
{
	//[sparkleUpdater release];
	[startupItemController release];
	[blackWindows release];
	[statusMenu release];
	[toggleMenuItem release];
	[statusItem release];
	
	[mainMenu release];
	[prefWindow release];
	[shortcutRecorder release];
	
	[getDockAutohideScript release];
	[setDockAutohideTrueScript release];
	[setDockAutohideFalseScript release];
	
	[savedFrames release];
	[infoBox release];
	[super dealloc];
}

-(void) exit
{
	[NSApp terminate:self];
}

@end
