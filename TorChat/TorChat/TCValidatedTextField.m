/*
 *  TCValidatedTextField.m
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

#import "TCValidatedTextField.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCValidatedTextField
*/
#pragma mark - TCValidatedTextField

@interface TCValidatedTextField () <NSTextViewDelegate>

@end

@implementation TCValidatedTextField

- (BOOL)textShouldBeginEditing:(NSText *)textObject
{
	textObject.delegate = self;
	return YES;
}

- (void)textDidChange:(NSNotification *)notification
{
	if (_textDidChange)
		_textDidChange(self.stringValue);
}

- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(nullable NSString *)replacementString
{
	if (!replacementString)
		return YES;
	
	NSString *newString = [self.stringValue stringByReplacingCharactersInRange:affectedCharRange withString:replacementString];
	
	if (_validCharacterSet)
	{
		if ([newString rangeOfCharacterFromSet:[_validCharacterSet invertedSet]].location != NSNotFound)
			return NO;
	}
	
	if (_validateContent)
	{
		if (_validateContent(newString) == NO)
			return NO;
	}
	
	return YES;
}

@end


NS_ASSUME_NONNULL_END
