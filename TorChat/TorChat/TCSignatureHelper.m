/*
 *  TCSignatureHelper.m
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

#import "TCSignatureHelper.h"


/*
** TCSignatureHelper
*/
#pragma mark - TCSignatureHelper

@implementation TCSignatureHelper

+ (SecKeyRef)copyKeyFromData:(NSData *)data isPrivate:(BOOL)private
{
	if (!data)
		return NULL;
	
	// Set import settings.
	CFArrayRef							attributes = NULL;
	SecItemImportExportKeyParameters	params;
	
	attributes = (__bridge_retained CFArrayRef)@[ @(CSSM_KEYATTR_EXTRACTABLE) ];
	
	params.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;
	params.flags = 0;
	params.passphrase = NULL;
	params.alertTitle = NULL;
	params.alertPrompt = NULL;
	params.accessRef = NULL;
	params.keyUsage =  NULL;
	params.keyAttributes = attributes;
	
	// Import the key from data.
	OSStatus			err;
	CFArrayRef			items = NULL;
	SecExternalFormat	externalFormat = kSecFormatOpenSSL;
	SecExternalItemType	externalType;
	
	if (private)
		externalType = kSecItemTypePrivateKey;
	else
		externalType = kSecItemTypePublicKey;
	
	err = SecItemImport((__bridge CFDataRef)data, NULL, &externalFormat, &externalType, 0, &params, NULL, &items);
	
	CFRelease(attributes);
	
	if (err != noErr)
		return nil;
	
	// Cast to NSArray.
	NSArray *result;
	
	result = (__bridge_transfer NSArray *)items;
	
	if ([result count] == 0)
		return nil;
	
	// Give result.
	return (__bridge_retained SecKeyRef)result[0];
}

@end
