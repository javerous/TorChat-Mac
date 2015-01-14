//
//  TCConfigInterface.h
//  TorChat
//
//  Created by Julien-Pierre Avérous on 14/01/2015.
//  Copyright (c) 2015 SourceMac. All rights reserved.
//


#import "TCConfig.h"


/*
** Types
*/
#pragma mark - Types

typedef enum
{
	TCConfigTitleAddress	= 0,
	TCConfigTitleName		= 1
} TCConfigTitle;



/*
** TCConfigInterface
*/
#pragma mark - TCConfigInterface

@protocol TCConfigInterface <TCConfig>

// -- Title --
- (TCConfigTitle)modeTitle;
- (void)setModeTitle:(TCConfigTitle)mode;

@end
