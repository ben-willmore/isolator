//
//  IsoStatusItemView.h
//  Isolator
//
//  Created by Ben Willmore on 06/03/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IsoController.h"

@class IsoController;

@interface IsoStatusItemView : NSView {
	IsoController* isoController;
	BOOL highlighted;
}

- (id) initWithFrame:(NSRect)frame isoController:(IsoController*)theIsoController;

@end
