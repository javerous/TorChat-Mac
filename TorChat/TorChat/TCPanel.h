/*
 *  TCPanel.h
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
