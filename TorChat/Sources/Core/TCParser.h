/*
 *  TCParser.h
 *
 *  Copyright 2014 Avérous Julien-Pierre
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
** Forward
*/
#pragma mark - Forward

@class TCParser;



/*
** Types
*/
#pragma mark - Types

typedef enum
{
	tcrec_unknown_command,
	tcrec_cmd_ping,
	tcrec_cmd_pong,
	tcrec_cmd_status,
	tcrec_cmd_version,
	tcrec_cmd_client,
	tcrec_cmd_profile_text,
	tcrec_cmd_profile_name,
	tcrec_cmd_profile_avatar,
	tcrec_cmd_profile_avatar_alpha,
	tcrec_cmd_message,
	tcrec_cmd_addme,
	tcrec_cmd_removeme,
	tcrec_cmd_filename,
	tcrec_cmd_filedata,
	tcrec_cmd_filedataok,
	tcrec_cmd_filedataerror,
	tcrec_cmd_filestopsending,
	tcrec_cmd_filestopreceiving
} tcrec_error;


/*
** Protocol
*/
#pragma mark - Protocol

@protocol TCParserCommand <NSObject>

@optional
- (void)parser:(TCParser *)parser parsedPingWithAddress:(NSString *)address random:(NSString *)random;
- (void)parser:(TCParser *)parser parsedPongWithRandom:(NSString *)random;
- (void)parser:(TCParser *)parser parsedStatus:(NSString *)status;
- (void)parser:(TCParser *)parser parsedMessage:(NSString *)message;
- (void)parser:(TCParser *)parser parsedVersion:(NSString *)version;
- (void)parser:(TCParser *)parser parsedClient:(NSString *)client;
- (void)parser:(TCParser *)parser parsedProfileText:(NSString *)text;
- (void)parser:(TCParser *)parser parsedProfileName:(NSString *)name;
- (void)parser:(TCParser *)parser parsedProfileAvatar:(NSData *)bitmap;
- (void)parser:(TCParser *)parser parsedProfileAvatarAlpha:(NSData *)bitmap;
- (void)parserParsedAddMe:(TCParser *)parser;
- (void)parserparsedRemoveMe:(TCParser *)parser;
- (void)parser:(TCParser *)parser parsedFileNameWithUUIDD:(NSString *)uuid fileSize:(NSString *)fileSize blockSize:(NSString *)blockSize fileName:(NSString *)filename;
- (void)parser:(TCParser *)parser parsedFileDataWithUUID:(NSString *)uuid start:(NSString *)start hash:(NSString *)hash data:(NSData *)data;
- (void)parser:(TCParser *)parser parsedFileDataOkWithUUID:(NSString *)uuid start:(NSString *)start;
- (void)parser:(TCParser *)parser parsedFileDataErrorWithUUID:(NSString *)uuid start:(NSString *)start;
- (void)parser:(TCParser *)parser parsedFileStopSendingWithUUID:(NSString *)uuid;
- (void)parser:(TCParser *)parser parsedFileStopReceivingWithUUID:(NSString *)uuid;

@end

@protocol TCParserDelegate <NSObject>

- (void)parser:(TCParser *)parser errorWithCode:(tcrec_error)error andInformation:(NSString *)information;

@end



/*
** TCParser
*/
#pragma mark - TCParser

@interface TCParser : NSObject

// -- Properties --
@property (weak, atomic) id <TCParserDelegate> delegate;

// -- Instance --
- (id)initWithParsingResult:(id <TCParserCommand>)receiver;

// -- Parsing --
- (void)parseLine:(NSData *)line;

@end
