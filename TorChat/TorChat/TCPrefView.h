//
//  TCPrefsView.h
//  TorChat
//
//  Created by Julien-Pierre Avérous on 14/01/2015.
//  Copyright (c) 2016 SourceMac. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "TCConfigInterface.h"


/*
** TCPrefsView
*/
#pragma mark - TCPrefsView

@interface TCPrefView : NSViewController

@property (strong, nonatomic) id <TCConfigInterface> config;

- (void)loadConfig;
- (void)saveConfig;

@end
