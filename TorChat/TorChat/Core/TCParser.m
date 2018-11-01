/*
 *  TCParser.m
 *
 *  Copyright 2018 Avérous Julien-Pierre
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

#import "TCParser.h"

#import "TCTools.h"

#import "NSData+TCTools.h"
#import "NSArray+TCTools.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCParser - Private
*/
#pragma mark - TCParser - Private

@interface TCParser ()
{
	__weak id <TCParserCommand> _receiver;
}

@end



/*
** TCParser
*/
#pragma mark - TCParser

@implementation TCParser


/*
** TCParser - Instance
*/
#pragma mark - TCParser - Instance

- (instancetype)initWithParsingResult:(id <TCParserCommand>)receiver
{
	self = [super init];
	
	if (self)
	{
		NSAssert(receiver, @"receiver is nil");
		
		_receiver = receiver;
	}
	
	return self;
}



/*
** TCParser - Parsing
*/
#pragma mark - TCParser - Parsing

- (void)parseLine:(NSData *)line
{
	NSAssert(line, @"line is nil");
	
	// Unscape protocol special chars.
	NSMutableData *mutableLine = [line mutableCopy];
	
	[mutableLine replaceCStr:"\\n" withCStr:"\n"];
	[mutableLine replaceCStr:"\\/" withCStr:"\\"];
	
	// Eplode the line from spaces.
	NSArray *items = [mutableLine explodeWithMaxFields:1 fieldSeparator:" "];
	
	if (items.count == 0)
		return;
	
	[self parseCommand:items];
}

- (void)parseCommand:(NSArray *)items
{
	if (items.count == 0)
        return;
    
    NSString	*command = [[NSString alloc] initWithData:items[0] encoding:NSASCIIStringEncoding];
	NSData		*parameters = nil;
	
	if (items.count > 1)
		parameters = items[1];
		
    // Dispatch command
    if ([command isEqualToString:@"ping"])
		[self parsePing:parameters];
    else if ([command isEqualToString:@"pong"])
        [self parsePong:parameters];
    else if ([command isEqualToString:@"status"])
        [self parseStatus:parameters];
    else if ([command isEqualToString:@"version"])
        [self parseVersion:parameters];
	else if ([command isEqualToString:@"client"])
        [self parseClient:parameters];
	else if ([command isEqualToString:@"profile_name"])
        [self parseProfileName:parameters];
	else if ([command isEqualToString:@"profile_text"])
        [self parseProfileText:parameters];
	else if ([command isEqualToString:@"profile_avatar_alpha"])
		 [self parseProfileAvatarAlpha:parameters];
	else if ([command isEqualToString:@"profile_avatar"])
        [self parseProfileAvatar:parameters];
	else if ([command isEqualToString:@"message"])
        [self parseMessage:parameters];
	else if ([command isEqualToString:@"add_me"])
        [self parseAddMe:parameters];
	else if ([command isEqualToString:@"remove_me"])
        [self parseRemoveMe:parameters];
	else if ([command isEqualToString:@"filename"])
        [self parseFileName:parameters];
	else if ([command isEqualToString:@"filedata"])
        [self parseFileData:parameters];
	else if ([command isEqualToString:@"filedata_ok"])
        [self parseFileDataOk:parameters];
	else if ([command isEqualToString:@"filedata_error"])
        [self parseFileDataError:parameters];
	else if ([command isEqualToString:@"file_stop_sending"])
        [self parseFileStopSending:parameters];
	else if ([command isEqualToString:@"file_stop_receiving"])
        [self parseFileStopReceiving:parameters];
    else
	{
		NSString *error = [NSString stringWithFormat:@"Unknown command '%@'", command];

		[self parserError:TCParserErrorUnknownCommand withString:error];
	}
}


- (void)parsePing:(NSData *)parameters
{
	NSArray *args = [parameters explodeWithMaxFields:2 fieldSeparator:" "];
	
	// Check args.
	if (args.count != 2)
    {
		[self parserError:TCParserErrorCmdPing withString:@"Bad ping argument"];
        return;
    }
	
	// Parse command.
	NSString *identifier = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	NSString *random = [[NSString alloc] initWithData:args[1] encoding:NSASCIIStringEncoding];
	
	if (!identifier || !random)
	{
		[self parserError:TCParserErrorCmdPing withString:@"Ping: Bad data"];
		return;
	}
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedPingWithIdentifier:random:)])
		[receiver parser:self parsedPingWithIdentifier:identifier random:random];
	else
		[self parserError:TCParserErrorCmdPing withString:@"Ping: Not handled"];
}

- (void)parsePong:(NSData *)parameters
{
	// Check args.
	if (parameters.length == 0)
    {
		[self parserError:TCParserErrorCmdPong withString:@"Bad pong argument"];
        return;
	}
	
	// Parse command.
	NSString *random = [[NSString alloc] initWithData:parameters encoding:NSASCIIStringEncoding];
	
	if (!random)
	{
		[self parserError:TCParserErrorCmdPong withString:@"Pong: Bad data"];
		return;
	}
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedPongWithRandom:)])
		[receiver parser:self parsedPongWithRandom:random];
	else
		[self parserError:TCParserErrorCmdPong withString:@"Pong: Not handled"];
}

- (void)parseStatus:(NSData *)parameters
{
	// Check args.
	if (parameters.length == 0)
    {
		[self parserError:TCParserErrorCmdStatus withString:@"Bad status argument"];
        return;
	}
	
	// Parse command.
	NSString *status = [[NSString alloc] initWithData:parameters encoding:NSASCIIStringEncoding];
	
	if (!status)
	{
		[self parserError:TCParserErrorCmdStatus withString:@"Status: Bad data"];
		return;
	}
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedStatus:)])
		[receiver parser:self parsedStatus:status];
	else
		[self parserError:TCParserErrorCmdStatus withString:@"Status: Not handled"];
}

- (void)parseVersion:(NSData *)parameters
{
	// Check args.
	if (parameters.length == 0)
    {
		[self parserError:TCParserErrorCmdVersion withString:@"Bad version argument"];
        return;
	}
	
	// Parse command.
	NSString *version = [[NSString alloc] initWithData:parameters encoding:NSASCIIStringEncoding];
	
	if (!version)
	{
		[self parserError:TCParserErrorCmdStatus withString:@"Version: Bad data"];
		return;
	}
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedVersion:)])
		[receiver parser:self parsedVersion:version];
	else
		[self parserError:TCParserErrorCmdStatus withString:@"Version: Not handled"];
}

- (void)parseClient:(NSData *)parameters
{
	// Check args.
	if (parameters.length == 0)
	{
		[self parserError:TCParserErrorCmdClient withString:@"Empty client argument"];
        return;
	}

	// Parse command.
	NSString *client = [[NSString alloc] initWithData:parameters encoding:NSUTF8StringEncoding];
	
	if (!client)
	{
		[self parserError:TCParserErrorCmdClient withString:@"Client: Bad data"];
		return;
	}
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedClient:)])
		[receiver parser:self parsedClient:client];
	else
		[self parserError:TCParserErrorCmdClient withString:@"Client: Not handled"];
}

- (void)parseProfileText:(NSData *)parameters
{
	// Parse command.
	NSString *text = @"";
	
	if (parameters)
		text = [[NSString alloc] initWithData:parameters encoding:NSUTF8StringEncoding];
	
	if (!text)
		return;
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedProfileText:)])
		[receiver parser:self parsedProfileText:text];
	else
		[self parserError:TCParserErrorCmdProfileText withString:@"Profile-Text: Not handled"];
}

- (void)parseProfileName:(NSData *)parameters
{
	// Parse command.
	NSString *name = @"";
	
	if (parameters)
		name = [[NSString alloc] initWithData:parameters encoding:NSUTF8StringEncoding];
	
	if (!name)
		return;
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedProfileName:)])
		[receiver parser:self parsedProfileName:name];
	else
		[self parserError:TCParserErrorCmdProfileName withString:@"Profile-Name: Not handled"];
}

- (void)parseProfileAvatar:(NSData *)parameters
{
	// Check command.
	if (!parameters)
		return;
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedProfileAvatar:)])
		[receiver parser:self parsedProfileAvatar:parameters];
	else
		[self parserError:TCParserErrorCmdProfileAvatar withString:@"Profile-Avatar: Not handled"];
}

- (void)parseProfileAvatarAlpha:(NSData *)parameters
{
	// Check command.
	if (!parameters)
		return;
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedProfileAvatarAlpha:)])
		[receiver parser:self parsedProfileAvatarAlpha:parameters];
	else
		[self parserError:TCParserErrorCmdProfileAvatarAlpha withString:@"Profile-AvatarAlpha: Not handled"];
}

- (void)parseMessage:(NSData *)parameters
{
	// Check args.
	if (parameters.length == 0)
	{
		[self parserError:TCParserErrorCmdMessage withString:@"Empty message content"];
        return;
	}
	
	// Parse command.
	NSString *message = [[NSString alloc] initWithData:parameters encoding:NSUTF8StringEncoding];
	
	if (!message)
	{
		[self parserError:TCParserErrorCmdMessage withString:@"Message: Bad data"];
		return;
	}
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedMessage:)])
		[receiver parser:self parsedMessage:message];
	else
		[self parserError:TCParserErrorCmdMessage withString:@"Message: Not handled"];
}

- (void)parseAddMe:(NSData *)parameters
{
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parserParsedAddMe:)])
		[receiver parserParsedAddMe:self];
	else
		[self parserError:TCParserErrorCmdAddMe withString:@"AddMe: Not handled"];
}

- (void)parseRemoveMe:(NSData *)parameters
{
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parserparsedRemoveMe:)])
		[receiver parserparsedRemoveMe:self];
	else
		[self parserError:TCParserErrorCmdRemoveMe withString:@"RemoveMe: Not handled"];
}

- (void)parseFileName:(NSData *)parameters
{
	// Check args.
	NSArray *args = [parameters explodeWithMaxFields:3 fieldSeparator:" "];
	
	if (args.count != 4)
    {
		[self parserError:TCParserErrorCmdFileName withString:@"Bad filename argument"];
        return;
	}
	
	// Parse command.
	NSString *uuid = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	NSString *fileSize = [[NSString alloc] initWithData:args[1] encoding:NSASCIIStringEncoding];
	NSString *blockSize = [[NSString alloc] initWithData:args[2] encoding:NSASCIIStringEncoding];
	NSString *fileName = [[NSString alloc] initWithData:args[3] encoding:NSUTF8StringEncoding];

	if (!uuid || !fileSize || !blockSize || !fileName)
	{
		[self parserError:TCParserErrorCmdFileName withString:@"Name: Bad data"];
		return;
	}
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedFileNameWithUUIDD:fileSize:blockSize:fileName:)])
		[receiver parser:self parsedFileNameWithUUIDD:uuid fileSize:fileSize blockSize:blockSize fileName:fileName];
	else
		[self parserError:TCParserErrorCmdFileName withString:@"FileName: Not handled"];
}

- (void)parseFileData:(NSData *)parameters
{
	// Check args.
	NSArray *args = [parameters explodeWithMaxFields:3 fieldSeparator:" "];
	
	if (args.count != 4)
    {
		[self parserError:TCParserErrorCmdFileData withString:@"Bad filedata argument"];
        return;
	}
	
	// Parse command.
	NSString	*uuid = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	NSString	*start = [[NSString alloc] initWithData:args[1] encoding:NSASCIIStringEncoding];
	NSString	*hash = [[NSString alloc] initWithData:args[2] encoding:NSASCIIStringEncoding];
	NSData		*fileData = args[3];

	if (!uuid || !start || !hash)
	{
		[self parserError:TCParserErrorCmdFileData withString:@"FileData: Bad data"];
		return;
	}
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedFileDataWithUUID:start:hash:data:)])
		[receiver parser:self parsedFileDataWithUUID:uuid start:start hash:hash data:fileData];
	else
		[self parserError:TCParserErrorCmdFileData withString:@"FileData: Not handled"];
}

- (void)parseFileDataOk:(NSData *)parameters
{
	// Check args.
	NSArray *args = [parameters explodeWithMaxFields:2 fieldSeparator:" "];
	
	if (args.count != 2)
    {
		[self parserError:TCParserErrorCmdFileDataOk withString:@"Bad filedataok argument"];
        return;
	}
	
	// Parse command.
	NSString	*uuid = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	NSString	*start = [[NSString alloc] initWithData:args[1] encoding:NSASCIIStringEncoding];
	
	if (!uuid || !start)
	{
		[self parserError:TCParserErrorCmdFileDataOk withString:@"FileDataOk: Bad data"];
		return;
	}
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedFileDataOkWithUUID:start:)])
		[receiver parser:self parsedFileDataOkWithUUID:uuid start:start];
	else
		[self parserError:TCParserErrorCmdFileDataOk withString:@"FileDataOk: Not handled"];
}

- (void)parseFileDataError:(NSData *)parameters
{
	// Check args.
	NSArray *args = [parameters explodeWithMaxFields:2 fieldSeparator:" "];

	if (args.count != 2)
    {
		[self parserError:TCParserErrorCmdFileDataError withString:@"Bad filedataerror argument"];
        return;
	}
	
	// Parse command.
	NSString	*uuid = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	NSString	*start = [[NSString alloc] initWithData:args[1] encoding:NSASCIIStringEncoding];
	
	if (!uuid || !start)
	{
		[self parserError:TCParserErrorCmdFileDataError withString:@"FileDataError: Bad data"];
		return;
	}
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedFileDataErrorWithUUID:start:)])
		[receiver parser:self parsedFileDataErrorWithUUID:uuid start:start];
	else
		[self parserError:TCParserErrorCmdFileDataError withString:@"FileDataError: Not handled"];
}

- (void)parseFileStopSending:(NSData *)parameters
{
	// Check args.
	if (parameters.length == 0)
    {
		[self parserError:TCParserErrorCmdFileStopSending withString:@"Bad filestopsending argument"];
        return;
	}
	
	// Parse command.
	NSString *uuid = [[NSString alloc] initWithData:parameters encoding:NSASCIIStringEncoding];
	
	if (!uuid)
	{
		[self parserError:TCParserErrorCmdFileStopSending withString:@"FileStopSending: Bad data"];
		return;
	}
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedFileStopSendingWithUUID:)])
		[receiver parser:self parsedFileStopSendingWithUUID:uuid];
	else
		[self parserError:TCParserErrorCmdFileStopSending withString:@"FileStopSending: Not handled"];
}

- (void)parseFileStopReceiving:(NSData *)parameters
{
	// Check args.
	if (parameters.length == 0)
    {
		[self parserError:TCParserErrorCmdFileStopReceiving withString:@"Bad filestopreceiving argument"];
        return;
	}
	
	// Parse command.
	NSString *uuid = [[NSString alloc] initWithData:parameters encoding:NSASCIIStringEncoding];
	
	if (!uuid)
	{
		[self parserError:TCParserErrorCmdFileStopReceiving withString:@"FileStopReceiving: Bad data"];
		return;
	}
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedFileStopReceivingWithUUID:)])
		[receiver parser:self parsedFileStopReceivingWithUUID:uuid];
	else
		[self parserError:TCParserErrorCmdFileStopReceiving withString:@"FileStopReceiving: Not handled"];
}



/*
** TCParser - Error
*/
#pragma mark - TCParser - Error

- (void)parserError:(TCParserError)errorCode withString:(NSString *)string
{
	id <TCParserDelegate> delegate = _delegate;
	
	[delegate parser:self errorWithErrorCode:errorCode errorInformation:string];
}

@end


NS_ASSUME_NONNULL_END
