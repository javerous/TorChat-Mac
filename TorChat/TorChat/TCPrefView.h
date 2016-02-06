<<<<<<< HEAD
//
//  TCPrefsView.h
//  TorChat
//
//  Created by Julien-Pierre Avérous on 14/01/2015.
//  Copyright (c) 2015 SourceMac. All rights reserved.
//
=======
/*
 *  TCPrefView.h
 *
 *  Copyright 2016 Avérous Julien-Pierre
 *
 *  This file is part of TorChat.
 *
 *  TorChat is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  TorChat is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with TorChat.  If not, see <http://www.gnu.org/licenses/>.
 *
 */
>>>>>>> javerous/master

#import <Foundation/Foundation.h>

#import "TCConfigInterface.h"


/*
<<<<<<< HEAD
=======
** Forward
*/
#pragma mark - Forward

@class TCCoreManager;



/*
>>>>>>> javerous/master
** TCPrefsView
*/
#pragma mark - TCPrefsView

@interface TCPrefView : NSViewController

<<<<<<< HEAD
@property (strong, nonatomic) id <TCConfigInterface> config;

- (void)loadConfig;
- (void)saveConfig;
=======
@property (strong, nonatomic) id <TCConfigInterface>	config;
@property (strong, nonatomic) TCCoreManager				*core;

- (void)loadConfig;
- (BOOL)saveConfig;
>>>>>>> javerous/master

@end
