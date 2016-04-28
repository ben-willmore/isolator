//
//  StartupItemController.h
//  Isolator
//
//  Created by Ben Willmore on 12/02/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import "LoginItemsAE.h"

@interface StartupItemController : NSObject {

}

-(BOOL) enabled;
-(void) setEnabled:(BOOL)value;
-(void) removeStartupItem;
-(void) addStartupItem;

@end
