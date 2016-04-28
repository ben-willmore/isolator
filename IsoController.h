//
//  IsoController.m
//  Isolator
//
//  Created by Ben Willmore on 08/02/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "Cocoa/Cocoa.h"
#import "Carbon/Carbon.h"
#import "Sparkle/SUUpdater.h"
#import "StartupItemController.h"
#import "BlackWindow.h"
#import "SRRecorderControl.h"
#import "BlackView.h"
#import "LessThanAboutOne.h"
#import "IsoStatusItemView.h"
#import "MAAttachedWindow.h"

@interface IsoController : NSObject
{
	StartupItemController* startupItemController;
	NSMutableArray* blackWindows;
	NSMenu* statusMenu;
	NSMenuItem* toggleMenuItem;
	NSStatusItem* statusItem;
	
	IBOutlet NSMenu* mainMenu;
	IBOutlet NSWindow* prefWindow;
	IBOutlet SRRecorderControl* shortcutRecorder;
	
	IBOutlet SUUpdater* sparkleUpdater;
	
	EventHotKeyRef gMyHotKeyRef;
	
	BOOL shownCenturyMessage;
	
	BOOL active;
	BOOL suspended;
	BOOL flipMode;
	BOOL enteringIsolateMode;
	BOOL dockAutohide;
	BOOL didAffectDock;

	NSAppleScript* getDockAutohideScript;
	NSAppleScript* setDockAutohideTrueScript;
	NSAppleScript* setDockAutohideFalseScript;

	NSArray* savedFrames;
	NSDictionary* lastAppActivated;

	MAAttachedWindow* infoBox;
	IBOutlet NSView* infoBoxView;
	IBOutlet NSTextField* infoBoxTextField;

}

-(void) setKeyCombo;
-(void) saveKeyCombo;
-(void) setupStatusItem;
-(NSStatusItem*) getStatusItem;
-(void) initStatusMenu;
-(NSMenu*) getStatusMenu;
-(void) showStatusMenu;
-(void) applicationDidChangeScreenParameters:(id)object;
-(void) setupBlackWindows;
-(void) checkIfDisplaysAreHardwareAccelerated;
-(void) isolate:(int) reason;
-(void) revealBlackWindows;
-(void) fadeOutBlackWindows;
-(void) hideAppsExcept:(NSDictionary*)excludeApp;
-(void) toggleFrontmostApp:(id)sender;
-(void) setFrontmostAppAndPositionBlackWindows:(id)sender;
-(void) setFrontmostApp:(id)sender;
-(void) positionBlackWindows:(id)sender;
-(void) enterIsolateMode:(BOOL)shouldFlip;
-(void) leaveIsolateMode;
-(void) toggle;
-(void) toggle:(BOOL)shouldFlip;
-(IBAction) setBackgroundColor:(id)sender;
-(IBAction) setOpacity:(id)sender;
-(IBAction) setBlur:(id)sender;
-(IBAction) setClickThrough:(id)sender;
-(IBAction) setMenuBarIcon:(id)sender;
-(IBAction) setHideBackgroundApps:(id)sender;
-(IBAction) setSuspendWhenFinderIsActive:(id)sender;
-(void) setUpdatesIncludeBetaVersions:(BOOL)flag;
-(BOOL) updatesIncludeBetaVersions;
-(void) setNilValueForKey:(NSString *)theKey;
-(void) registerHotkey:(KeyCombo)keyCombo;
-(void) syncDefaults:(id)sender;
-(BOOL) startupItemEnabled;
-(void) setStartupItemEnabled:(BOOL)value;
-(IBAction) setWindow:(id)sender;
-(void) openPrefs;
-(BOOL) isActive;
-(void) showCenturyMessage;
-(void) setupAppleScripts;
-(void) saveDockAutohide;
-(void) restoreDockAutohide;
-(void) setDockAutohide:(BOOL)hide;
-(IBAction) hideDockAsAppropriate;
-(IBAction) setDockHidingPref:(id)sender;
-(IBAction) checkForUpdates:(id)sender;
-(void)bringWindowsForward;
-(void) migratePrefsTo338;
-(void) showInfoBoxAtPoint:(NSPoint)pt;
-(void)closeInfoBox:(id)sender;


@end
