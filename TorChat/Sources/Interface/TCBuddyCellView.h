//
//  TCBuddyCellView.h
//  TorChat
//
//  Created by Julien-Pierre Avérous on 05/08/13.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import <Cocoa/Cocoa.h>


/*
** Forward
*/
#pragma mark - Forward 

@class TCBuddy;



/*
** TCBuddyCellView
*/
#pragma mark - TCBuddyCellView

@interface TCBuddyCellView : NSTableCellView

- (void)setBuddy:(TCBuddy *)buddy;

@end
