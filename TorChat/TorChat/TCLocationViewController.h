//
//  TCLocationViewController.h
//  TorChat
//
//  Created by Julien-Pierre Avérous on 15/01/2015.
//  Copyright (c) 2016 SourceMac. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "TCConfig.h"


/*
** TCLocationViewController
*/
#pragma mark - TCLocationViewController

@interface TCLocationViewController : NSViewController

- (instancetype)initWithConfiguration:(id <TCConfig>)configuration component:(TConfigPathComponent)component;

- (void)addToView:(NSView *)view;

- (void)reloadConfiguration;

@end
