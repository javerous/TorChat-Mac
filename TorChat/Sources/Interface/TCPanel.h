//
//  TCPanel.h
//  TorChat
//
//  Created by Julien-Pierre Avérous on 31/07/13.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import <Foundation/Foundation.h>


/*
** TCAssistantProxy
*/
#pragma mark - TCAssistantProxy

@protocol TCAssistantProxy <NSObject>

- (void)setNextPanelID:(NSString *)panelID;
- (void)setIsLastPanel:(BOOL)last;
- (void)setDisableContinue:(BOOL)disabled;

@end


/*
** TCAssistantPanel
*/
#pragma mark - TCAssistantPanel

@protocol TCAssistantPanel <NSObject>

+ (id <TCAssistantPanel>)panelWithProxy:(id <TCAssistantProxy>)proxy;

+ (NSString *)identifiant;
+ (NSString *)title;

- (NSView *)view;
- (id)content;

- (void)showPanel;

@end
