/*
 *  TCParser.cpp
 *
 *  Copyright 2012 Avérous Julien-Pierre
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
#import "TCInfo.h"

#import "NSData+TCTools.h"
#import "NSArray+TCTools.h"



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

- (id)initWithParsedCommand:(id <TCParserCommand>)receiver
{
	self = [super init];
	
	if (self)
	{
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
	if (!line)
		return;
	
	// Unscape protocol special chars.
	NSMutableData *mutableLine = [line mutableCopy];
	
	[mutableLine replaceCStr:"\\n" withCStr:"\n"];
	[mutableLine replaceCStr:"\\/" withCStr:"\\"];

	// Eplode the line from spaces.
	NSArray *items = [mutableLine explodeWithCStr:" "];
	
	[self parseCommand:items];
}

- (void)parseCommand:(NSArray *)items
{
	if ([items count] == 0)
        return;
    
    NSString	*command = [[NSString alloc] initWithData:items[0] encoding:NSASCIIStringEncoding];
	NSArray		*subItems = [items subarrayWithRange:NSMakeRange(1, [items count] - 1)];
		
    // Dispatch command
    if ([command isEqualToString:@"ping"])
		[self parsePing:subItems];
    else if ([command isEqualToString:@"pong"])
        [self parsePong:subItems];
    else if ([command isEqualToString:@"status"])
        [self parseStatus:subItems];
    else if ([command isEqualToString:@"version"])
        [self parseVersion:subItems];
	else if ([command isEqualToString:@"client"])
        [self parseClient:subItems];
	else if ([command isEqualToString:@"profile_name"])
        [self parseProfileName:subItems];
	else if ([command isEqualToString:@"profile_text"])
        [self parseProfileText:subItems];
	else if ([command isEqualToString:@"profile_avatar_alpha"])
		 [self parseProfileAvatarAlpha:subItems];
	else if ([command isEqualToString:@"profile_avatar"])
        [self parseProfileAvatar:subItems];
	else if ([command isEqualToString:@"message"])
        [self parseMessage:subItems];
	else if ([command isEqualToString:@"add_me"])
        [self parseAddMe:subItems];
	else if ([command isEqualToString:@"remove_me"])
        [self parseRemoveMe:subItems];
	else if ([command isEqualToString:@"filename"])
        [self parseFileName:subItems];
	else if ([command isEqualToString:@"filedata"])
        [self parseFileData:subItems];
	else if ([command isEqualToString:@"filedata_ok"])
        [self parseFileDataOk:subItems];
	else if ([command isEqualToString:@"filedata_error"])
        [self parseFileDataError:subItems];
	else if ([command isEqualToString:@"file_stop_sending"])
        [self parseFileStopSending:subItems];
	else if ([command isEqualToString:@"file_stop_receiving"])
        [self parseFileStopReceiving:subItems];
    else
	{
		NSString *error = [NSString stringWithFormat:@"Unknown command '%@'", command];

		[self parserError:tcrec_unknown_command withString:error];
	}
}


- (void)parsePing:(NSArray *)args
{
	// Check args.
	if ([args count] != 2)
    {
		[self parserError:tcrec_cmd_ping withString:@"Bad ping argument"];
        return;
    }
	
	// Parse command.
	NSString *address = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	NSString *random = [[NSString alloc] initWithData:args[1] encoding:NSASCIIStringEncoding];
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedPingWithAddress:)])
		[receiver parser:self parsedPingWithAddress:address random:random];
	else
		[self parserError:tcrec_cmd_ping withString:@"Ping: Not handled"];
}

- (void)parsePong:(NSArray *)args
{
	// Check args.
	if ([args count] != 1)
    {
		[self parserError:tcrec_cmd_pong withString:@"Bad pong argument"];
        return;
	}
	
	// Parse command.
	NSString *random = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedPongWithRandom:)])
		[receiver parser:self parsedPongWithRandom:random];
	else
		[self parserError:tcrec_cmd_pong withString:@"Pong: Not handled"];
}

- (void)parseStatus:(NSArray *)args
{
	// Check args.
	if ([args count] != 1)
    {
		[self parserError:tcrec_cmd_status withString:@"Bad status argument"];
        return;
	}
	
	// Parse command.
	NSString *status = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedStatus:)])
		[receiver parser:self parsedStatus:status];
	else
		[self parserError:tcrec_cmd_status withString:@"Status: Not handled"];
}

- (void)parseVersion:(NSArray *)args
{
	// Check args.
	if ([args count] != 1)
    {
		[self parserError:tcrec_cmd_version withString:@"Bad version argument"];
        return;
	}
	
	// Parse command.
	NSString *version = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedVersion:)])
		[receiver parser:self parsedVersion:version];
	else
		[self parserError:tcrec_cmd_status withString:@"Version: Not handled"];
}

- (void)parseClient:(NSArray *)args
{
	// Check args.
	if ([args count] == 0)
	{
		[self parserError:tcrec_cmd_client withString:@"Empty client argument"];
        return;
	}

	// Parse command.
	NSString *client = [[NSString alloc] initWithData:[args joinWithCStr:" "] encoding:NSUTF8StringEncoding];
	
	if (!client)
		return;
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedClient:)])
		[receiver parser:self parsedClient:client];
	else
		[self parserError:tcrec_cmd_client withString:@"Client: Not handled"];
}

- (void)parseProfileText:(NSArray *)args
{
	// Parse command.
	NSString *text = [[NSString alloc] initWithData:[args joinWithCStr:" "] encoding:NSUTF8StringEncoding];
	
	if (!text)
		return;
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedProfileText:)])
		[receiver parser:self parsedProfileText:text];
	else
		[self parserError:tcrec_cmd_profile_text withString:@"Profile-Text: Not handled"];
}

- (void)parseProfileName:(NSArray *)args
{
	// Parse command.
	NSString *name = [[NSString alloc] initWithData:[args joinWithCStr:" "] encoding:NSUTF8StringEncoding];
	
	if (!name)
		return;
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedProfileName:)])
		[receiver parser:self parsedProfileName:name];
	else
		[self parserError:tcrec_cmd_profile_name withString:@"Profile-Name: Not handled"];
}

- (void)parseProfileAvatar:(NSArray *)args
{
	// Parse command.
	NSData *bitmap = [args joinWithCStr:" "];
	
	if (!bitmap)
		return;
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedProfileAvatar:)])
		[receiver parser:self parsedProfileAvatar:bitmap];
	else
		[self parserError:tcrec_cmd_profile_avatar withString:@"Profile-Avatar: Not handled"];
}

- (void)parseProfileAvatarAlpha:(NSArray *)args
{
	// Parse command.
	NSData *bitmap = [args joinWithCStr:" "];
	
	if (!bitmap)
		return;
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedProfileAvatarAlpha:)])
		[receiver parser:self parsedProfileAvatarAlpha:bitmap];
	else
		[self parserError:tcrec_cmd_profile_avatar_alpha withString:@"Profile-AvatarAlpha: Not handled"];
}

- (void)parseMessage:(NSArray *)args
{
	// Check args.
	if ([args count] == 0)
	{
		[self parserError:tcrec_cmd_message withString:@"Empty message content"];
        return;
	}
	
	// Parse command.
	NSString *message = [[NSString alloc] initWithData:[args joinWithCStr:" "] encoding:NSUTF8StringEncoding];
	
	if (!message)
		return;
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedMessage:)])
		[receiver parser:self parsedMessage:message];
	else
		[self parserError:tcrec_cmd_message withString:@"Message: Not handled"];
}

- (void)parseAddMe:(NSArray *)args
{
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parserParsedAddMe:)])
		[receiver parserParsedAddMe:self];
	else
		[self parserError:tcrec_cmd_addme withString:@"AddMe: Not handled"];
}

- (void)parseRemoveMe:(NSArray *)args
{
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parserparsedRemoveMe:)])
		[receiver parserparsedRemoveMe:self];
	else
		[self parserError:tcrec_cmd_removeme withString:@"RemoveMe: Not handled"];
}

- (void)parseFileName:(NSArray *)args
{
	// Check args.
	if ([args count] != 4)
    {
		[self parserError:tcrec_cmd_filename withString:@"Bad filename argument"];
        return;
	}
	
	// Parse command.
	NSString *uuid = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	NSString *fileSize = [[NSString alloc] initWithData:args[1] encoding:NSASCIIStringEncoding];
	NSString *blockSize = [[NSString alloc] initWithData:args[2] encoding:NSASCIIStringEncoding];
	NSString *fileName = [[NSString alloc] initWithData:args[3] encoding:NSUTF8StringEncoding];

	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedFileNameWithUUIDD:fileSize:blockSize:fileName:)])
		[receiver parser:self parsedFileNameWithUUIDD:uuid fileSize:fileSize blockSize:blockSize fileName:fileName];
	else
		[self parserError:tcrec_cmd_filename withString:@"FileName: Not handled"];
}

- (void)parseFileData:(NSArray *)args
{
	// Check args.
	if ([args count] < 4)
    {
		[self parserError:tcrec_cmd_filedata withString:@"Bad filedata argument"];
        return;
	}
	
	// Parse command.
	NSString	*uuid = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	NSString	*start = [[NSString alloc] initWithData:args[1] encoding:NSASCIIStringEncoding];
	NSString	*hash = [[NSString alloc] initWithData:args[2] encoding:NSASCIIStringEncoding];
	NSData		*data = [args joinFromIndex:3 withCStr:" "];
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedFileDataWithUUID:start:hash:data:)])
		[receiver parser:self parsedFileDataWithUUID:uuid start:start hash:hash data:data];
	else
		[self parserError:tcrec_cmd_filedata withString:@"FileData: Not handled"];
}

- (void)parseFileDataOk:(NSArray *)args
{
	// Check args.
	if ([args count] != 2)
    {
		[self parserError:tcrec_cmd_filedataok withString:@"Bad filedataok argument"];
        return;
	}
	
	// Parse command.
	NSString	*uuid = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	NSString	*start = [[NSString alloc] initWithData:args[1] encoding:NSASCIIStringEncoding];
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedFileDataOkWithUUID:start:)])
		[receiver parser:self parsedFileDataOkWithUUID:uuid start:start];
	else
		[self parserError:tcrec_cmd_filedataok withString:@"FileDataOk: Not handled"];
}

- (void)parseFileDataError:(NSArray *)args
{
	// Check args.
	if ([args count] != 2)
    {
		[self parserError:tcrec_cmd_filedataerror withString:@"Bad filedataerror argument"];
        return;
	}
	
	// Parse command.
	NSString	*uuid = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	NSString	*start = [[NSString alloc] initWithData:args[1] encoding:NSASCIIStringEncoding];
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedFileDataErrorWithUUID:start:)])
		[receiver parser:self parsedFileDataErrorWithUUID:uuid start:start];
	else
		[self parserError:tcrec_cmd_filedataerror withString:@"FileDataError: Not handled"];
}

- (void)parseFileStopSending:(NSArray *)args
{
	// Check args.
	if ([args count] != 1)
    {
		[self parserError:tcrec_cmd_filestopsending withString:@"Bad filestopsending argument"];
        return;
	}
	
	// Parse command.
	NSString *uuid = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedFileStopSendingWithUUID:)])
		[receiver parser:self parsedFileStopSendingWithUUID:uuid];
	else
		[self parserError:tcrec_cmd_filestopsending withString:@"FileStopSending: Not handled"];
}

- (void)parseFileStopReceiving:(NSArray *)args
{
	// Check args.
	if ([args count] != 1)
    {
		[self parserError:tcrec_cmd_filestopreceiving withString:@"Bad filestopreceiving argument"];
        return;
	}
	
	// Parse command.
	NSString *uuid = [[NSString alloc] initWithData:args[0] encoding:NSASCIIStringEncoding];
	
	// Give to receiver.
	id <TCParserCommand> receiver = _receiver;
	
	if ([receiver respondsToSelector:@selector(parser:parsedFileStopReceivingWithUUID:)])
		[receiver parser:self parsedFileStopReceivingWithUUID:uuid];
	else
		[self parserError:tcrec_cmd_filestopreceiving withString:@"FileStopReceiving: Not handled"];
}



/*
** TCParser - Error
*/
#pragma mark - TCParser - Error

- (void)parserError:(tcrec_error)errorCode withString:(NSString *)string
{
	TCInfo *err = new TCInfo(tcinfo_error, errorCode, [string UTF8String]);
	
	id <TCParserDelegate> delegate = _delegate;
	
	[delegate parser:self information:err];
	
	err->release();
}

@end
