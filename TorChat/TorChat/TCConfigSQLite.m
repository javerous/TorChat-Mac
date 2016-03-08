/*
 *  TCConfigSQLite.m
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

#import <Cocoa/Cocoa.h>
#import <sqlite3.h>

#import "TCConfigSQLite.h"

#import "SMSQLiteCryptoVFS.h"
#import "TCImage.h"



/*
** Defines
*/
#pragma mark - Defines

#define TCCONF_KEY_TOR_ADDRESS		@"tor_address"
#define TCCONF_KEY_TOR_PORT			@"tor_socks_port"

#define TCCONF_KEY_IM_ADDRESS		@"im_address"
#define TCCONF_KEY_IM_PORT			@"im_in_port"

#define TCCONF_KEY_MODE				@"mode"

#define TCCONF_KEY_PROFILE_NAME		@"profile_name"
#define TCCONF_KEY_PROFILE_TEXT		@"profile_text"
#define TCCONF_KEY_PROFILE_AVATAR	@"profile_avatar"

#define TCCONF_KEY_UI_TITLE			@"title"

#define TCCONF_KEY_CLIENT_VERSION	@"client_version"
#define TCCONF_KEY_CLIENT_NAME		@"client_name"

// Paths
#define TCCONF_KEY_PATH_TOR_BIN				@"tor_bin"
#define TCCONF_KEY_PATH_TOR_DATA			@"tor_data"
#define TCCONF_KEY_PATH_TOR_IDENTITY		@"tor_identity"
#define TCCONF_KEY_PATH_DOWNLOADS			@"downloads"

#define TCCONF_VALUE_PATH_TYPE_REFERAL		@"<referal>"
#define TCCONF_VALUE_PATH_TYPE_STANDARD		@"<standard>"
#define TCCONF_VALUE_PATH_TYPE_ABSOLUTE		@"<absolute>"



/*
** TCConfigSQLite
*/
#pragma mark - TCConfigSQLite

@implementation TCConfigSQLite
{
	dispatch_queue_t	_localQueue;
	
	NSMutableDictionary *_pathObservers;
	
	NSString			*_dtbPath;
	void				*_dtbPassword;
	sqlite3				*_dtb;
	
	sqlite3_stmt		*_stmtInsertSetting;
	sqlite3_stmt		*_stmtSelectSetting;
	sqlite3_stmt		*_stmtDeleteSetting;

	sqlite3_stmt		*_stmtInsertBuddy;
	sqlite3_stmt		*_stmtInsertBuddyProperty;
	sqlite3_stmt		*_stmtSelectBuddyID;
	sqlite3_stmt		*_stmtSelectBuddyAll;
	sqlite3_stmt		*_stmtSelectBuddyProperty;
	sqlite3_stmt		*_stmtDeleteBuddy;
	
	sqlite3_stmt		*_stmtInsertBlocked;
	sqlite3_stmt		*_stmtSelectBlocked;
	sqlite3_stmt		*_stmtDeleteBlocked;
	
	sqlite3_stmt		*_stmtInsertPath;
	sqlite3_stmt		*_stmtSelectPath;
}


/*
** TCConfigSQLite - Instance
*/
#pragma mark - TCConfigSQLite - Instance

+ (void)initialize
{
	if (self == [TCConfigSQLite self])
	{
		SMSQLiteCryptoVFSRegister();
		SMSQLiteCryptoVFSDefaultsSetKeySize(SMCryptoFileKeySize256);
	}
}

- (id)initWithFile:(NSString *)filepath password:(NSString *)password
{
	self = [super init];
	
	if (self)
	{
		// Hold parameters.
		_dtbPath = filepath;
		
		if (!_dtbPath)
			return nil;
		
		// Check parameters.
		if ([[self class] isEncryptedFile:_dtbPath] && password == nil)
			return nil;
		
		// Copy password in 'safe' place.
		if (password)
		{
			vm_size_t hostPageSize = 0;
			
			if (host_page_size(mach_host_self(), &hostPageSize) != KERN_SUCCESS)
				hostPageSize = 4096;
			
			if (posix_memalign(&_dtbPassword, hostPageSize, hostPageSize) != 0)
				return nil;
			
			if (mlock(_dtbPassword, hostPageSize) != 0)
			{
				free(_dtbPassword);
				return nil;
			}
			
			strlcpy(_dtbPassword, password.UTF8String, hostPageSize);
			
			// Clean password.
			password = nil;
		}

		// Open database.
		if ([self _openDatabase] == NO)
			return nil;

		// Create queue.
		_localQueue = dispatch_queue_create("com.torchat.app.config-sqlite", DISPATCH_QUEUE_SERIAL);
	}
	
	return self;
}


- (void)dealloc
{
	// Close database.
	[self _closeDatabase];
	
	// Free password.
	free(_dtbPassword);
}



/*
** TCConfigSQLite - Tools
*/
#pragma mark - TCConfigSQLite - Tools

+ (BOOL)isEncryptedFile:(NSString *)filepath
{
	return SMCryptoFileCanOpen(filepath.fileSystemRepresentation);
}



/*
** TCConfigSQLite - SQLite
*/
#pragma mark - TCConfigSQLite - SQLite

#pragma mark Instance

- (BOOL)_openDatabase
{
	// > localQueue <

	// Open database.
	int result;
	
	if (_dtbPassword)
	{
		const char	*uuid = SMSQLiteCryptoVFSSettingsAdd(_dtbPassword, SMCryptoFileKeySize256);
		const char	*uriPath = [[NSString stringWithFormat:@"file://%@?crypto-uuid=%s", _dtbPath, uuid] UTF8String];
		
		result = sqlite3_open_v2(uriPath, &_dtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
		
		if (result != SQLITE_OK)
		{
			NSLog(@"Can't open encrypted sqlite base (%i)", result);
			return NO;
		}
	}
	else
	{
		result = sqlite3_open_v2(_dtbPath.fileSystemRepresentation, &_dtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);
		
		if (result != SQLITE_OK)
		{
			NSLog(@"Can't open sqlite base (%i)", result);
			return NO;
		}
	}
	
	
	// Pragmas.
	sqlite3_exec(_dtb, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);

	
	// Create 'settings' table.
	// > Table.
	if (sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS settings (key TEXT NOT NULL, value, UNIQUE (key) ON CONFLICT REPLACE)", NULL, NULL, NULL) != SQLITE_OK)
		return NO;

	// > Index.
	if (sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS settings_idx ON settings(key)", NULL, NULL, NULL) != SQLITE_OK)
		return NO;
	
	// > Statements.
	if (sqlite3_prepare_v2(_dtb, "INSERT INTO settings (key, value) VALUES (?, ?)", -1, &_stmtInsertSetting, NULL) != SQLITE_OK)
		return NO;
	
	if (sqlite3_prepare_v2(_dtb, "SELECT value FROM settings WHERE key=? LIMIT 1", -1, &_stmtSelectSetting, NULL) != SQLITE_OK)
		return NO;
	
	if (sqlite3_prepare_v2(_dtb, "DELETE FROM settings WHERE key=? LIMIT 1", -1, &_stmtDeleteSetting, NULL) != SQLITE_OK)
		return NO;
	
	
	// Create 'buddies' table.
	// > Tables.
	if (sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS buddies (id INTEGER PRIMARY KEY AUTOINCREMENT, address TEXT NOT NULL, UNIQUE (address) ON CONFLICT ABORT)", NULL, NULL, NULL) != SQLITE_OK)
		return NO;

	if (sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS buddies_properties (buddy_id INTEGER, key TEXT NOT NULL, value, FOREIGN KEY(buddy_id) REFERENCES buddies(id) ON DELETE CASCADE, UNIQUE (buddy_id, key) ON CONFLICT REPLACE)", NULL, NULL, NULL) != SQLITE_OK)
		return NO;
	
	// > Indexes.
	if (sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS buddies_idx ON buddies(address)", NULL, NULL, NULL) != SQLITE_OK)
		return NO;
	
	if (sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS buddies_properties_idx ON buddies_properties(buddy_id, key)", NULL, NULL, NULL) != SQLITE_OK)
		return NO;
	
	// > Statements.
	if (sqlite3_prepare_v2(_dtb, "INSERT INTO buddies (address) VALUES (?)", -1, &_stmtInsertBuddy, NULL) != SQLITE_OK)
		return NO;
	
	if (sqlite3_prepare_v2(_dtb, "INSERT INTO buddies_properties (buddy_id, key, value) VALUES (?, ?, ?)", -1, &_stmtInsertBuddyProperty, NULL) != SQLITE_OK)
		return NO;
	
	if (sqlite3_prepare_v2(_dtb, "SELECT id FROM buddies WHERE address=? LIMIT 1", -1, &_stmtSelectBuddyID, NULL) != SQLITE_OK)
		return NO;
	
	if (sqlite3_prepare_v2(_dtb, "SELECT address, key, value FROM buddies LEFT OUTER JOIN buddies_properties ON buddies.id=buddies_properties.buddy_id", -1, &_stmtSelectBuddyAll, NULL) != SQLITE_OK)
		return NO;
	
	if (sqlite3_prepare_v2(_dtb, "SELECT value FROM buddies_properties WHERE buddy_id=? AND key=? LIMIT 1", -1, &_stmtSelectBuddyProperty, NULL) != SQLITE_OK)
		return NO;
	
	if (sqlite3_prepare_v2(_dtb, "DELETE FROM buddies WHERE address=? LIMIT 1", -1, &_stmtDeleteBuddy, NULL) != SQLITE_OK)
		return NO;
	
	
	// Create 'blocked' table.
	// > Table.
	if (sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS blocked (address TEXT NOT NULL, UNIQUE (address) ON CONFLICT ABORT)", NULL, NULL, NULL) != SQLITE_OK)
		return NO;
	
	// > Indexes.
	if (sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS blocked_idx ON blocked(address)", NULL, NULL, NULL) != SQLITE_OK)
		return NO;
	
	// > Statements.
	if (sqlite3_prepare_v2(_dtb, "INSERT INTO blocked (address) VALUES (?)", -1, &_stmtInsertBlocked, NULL) != SQLITE_OK)
		return NO;
	
	if (sqlite3_prepare_v2(_dtb, "SELECT address FROM blocked LIMIT 1", -1, &_stmtSelectBlocked, NULL) != SQLITE_OK)
		return NO;
	
	if (sqlite3_prepare_v2(_dtb, "DELETE FROM blocked WHERE address=?", -1, &_stmtDeleteBlocked, NULL) != SQLITE_OK)
		return NO;
	
	
	// Create 'paths' table.
	// > Table.
	if (sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS paths (component TEXT NOT NULL, type TEXT NOT NULL, path TEXT, UNIQUE (component) ON CONFLICT REPLACE)", NULL, NULL, NULL) != SQLITE_OK)
		return NO;
	
	// > Indexes.
	if (sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS paths_idx ON paths(component)", NULL, NULL, NULL) != SQLITE_OK)
		return NO;
	
	// > Statements.
	if (sqlite3_prepare_v2(_dtb, "INSERT INTO paths (component, type, path) VALUES (?, ?, ?)", -1, &_stmtInsertPath, NULL) != SQLITE_OK)
		return NO;
	
	if (sqlite3_prepare_v2(_dtb, "SELECT type, path FROM paths WHERE component=?", -1, &_stmtSelectPath, NULL) != SQLITE_OK)
		return NO;
	
	return YES;
}

- (void)_closeDatabase
{
	// > localQueue <
	
#define tc_sqlite3_finalize(Stmt) do { if (Stmt) { sqlite3_reset(Stmt); sqlite3_finalize(Stmt); Stmt = NULL; }  } while (0)
	
	// Finalize statements.
	tc_sqlite3_finalize(_stmtInsertSetting);
	tc_sqlite3_finalize(_stmtSelectSetting);
	tc_sqlite3_finalize(_stmtDeleteSetting);
	
	tc_sqlite3_finalize(_stmtInsertBuddy);
	tc_sqlite3_finalize(_stmtInsertBuddyProperty);
	tc_sqlite3_finalize(_stmtSelectBuddyID);
	tc_sqlite3_finalize(_stmtSelectBuddyAll);
	tc_sqlite3_finalize(_stmtSelectBuddyProperty);
	tc_sqlite3_finalize(_stmtDeleteBuddy);
	
	tc_sqlite3_finalize(_stmtInsertBlocked);
	tc_sqlite3_finalize(_stmtSelectBlocked);
	tc_sqlite3_finalize(_stmtDeleteBlocked);
	
	tc_sqlite3_finalize(_stmtInsertPath);
	tc_sqlite3_finalize(_stmtSelectPath);

	// Close db.
	if (_dtb)
	{
		sqlite3_close(_dtb);
		_dtb = NULL;
	}
}


#pragma mark Bridge

- (id)_sqliteValueForStatement:(sqlite3_stmt *)stmt column:(int)column
{
	if (!stmt)
		return nil;
	
	int type = sqlite3_column_type(stmt, column);
	
	switch (type)
	{
		case SQLITE_INTEGER:
		{
			return @(sqlite3_column_int64(stmt, column));
		}
			
		case SQLITE_FLOAT:
		{
			return @(sqlite3_column_double(stmt, column));
		}
			
		case SQLITE_BLOB:
		{
			const void	*data = sqlite3_column_blob(stmt, column);
			int			length = sqlite3_column_bytes(stmt, column);
			
			if (data && length >= 0)
				return [[NSData alloc] initWithBytes:data length:(NSUInteger)length];
			
			break;
		}
			
		case SQLITE_NULL:
		{
			break;
		}
			
		case SQLITE_TEXT:
		{
			const void	*txt = sqlite3_column_text(stmt, column);
			int			length = sqlite3_column_bytes(stmt, column);
			
			if (txt && length >= 0)
				return [[NSString alloc] initWithBytes:txt length:(NSUInteger)length encoding:NSUTF8StringEncoding];
			
			break;
		}
	}
	
	return nil;
}

- (id)_sqliteStepValueForStatement:(sqlite3_stmt *)stmt column:(int)column
{
	// > localQueue <
	
	if (!stmt)
		return nil;
	
	id	obj = nil;
	int	result = sqlite3_step(stmt);

	if (result == SQLITE_ROW)
		obj = [self _sqliteValueForStatement:stmt column:column];
	
	// Reset.
	sqlite3_reset(stmt);
	sqlite3_clear_bindings(stmt);
	
	// Return.
	return obj;
}

- (void)_sqliteStepSetValue:(id)value forStatement:(sqlite3_stmt *)stmt index:(int)index
{
	// > localQueue <
	
	if (!value || !stmt)
		return;

	// Bind.
	if ([value isKindOfClass:[NSString class]])
	{
		NSString *val = value;
		
		sqlite3_bind_text(stmt, index, val.UTF8String, -1, SQLITE_TRANSIENT);
	}
	else if ([value isKindOfClass:[NSNumber class]])
	{
		NSNumber *val = value;
		
		if (strcmp(val.objCType, @encode(float)) == 0 || strcmp(val.objCType, @encode(double)) == 0 || strcmp(val.objCType, @encode(long double)) == 0)
			sqlite3_bind_double(stmt, index, [val doubleValue]);
		else
			sqlite3_bind_int64(stmt, index, [val integerValue]);
	}
	else if ([value isKindOfClass:[NSData class]])
	{
		NSData *val = value;
		
		sqlite3_bind_blob(stmt, index, val.bytes, (int)val.length, SQLITE_TRANSIENT);
	}
	else
	{
		sqlite3_reset(stmt);
		sqlite3_clear_bindings(stmt);
		
		return;
	}
	
	// Exec.
	sqlite3_step(stmt);
	
	// Reset.
	sqlite3_reset(stmt);
	sqlite3_clear_bindings(stmt);
}


#pragma mark Settings

- (id)settingForKey:(NSString *)key
{
	if (!key)
		return nil;
	
	__block id obj = nil;
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_bind_text(_stmtSelectSetting, 1, key.UTF8String, -1, SQLITE_TRANSIENT);

		obj = [self _sqliteStepValueForStatement:_stmtSelectSetting column:0];
	});
	
	return obj;
}

- (void)setSetting:(id)value forKey:(NSString *)key
{
	if (!key)
		return;
	
	dispatch_async(_localQueue, ^{
		
		if (value)
		{
			sqlite3_bind_text(_stmtInsertSetting, 1, key.UTF8String, -1, SQLITE_TRANSIENT);
			
			[self _sqliteStepSetValue:value forStatement:_stmtInsertSetting index:2];
		}
		else
		{
			// Bind.
			sqlite3_bind_text(_stmtDeleteSetting, 1, key.UTF8String, -1, SQLITE_TRANSIENT);
			
			// Exec.
			sqlite3_step(_stmtDeleteSetting);
			
			// Reset.
			sqlite3_reset(_stmtDeleteSetting);
			sqlite3_clear_bindings(_stmtDeleteSetting);
		}
	});
}


#pragma mark Buddies

- (sqlite3_int64)_buddyIDForAddress:(NSString *)address
{
	if (!address)
		return -1;
	
	sqlite3_int64 result = -1;
	
	// Bind.
	sqlite3_bind_text(_stmtSelectBuddyID, 1, address.UTF8String, -1, SQLITE_TRANSIENT);

	// Execute.
	if (sqlite3_step(_stmtSelectBuddyID) == SQLITE_ROW)
		result = sqlite3_column_int64(_stmtSelectBuddyID, 0);
	
	// Reset.
	sqlite3_reset(_stmtSelectBuddyID);
	sqlite3_clear_bindings(_stmtSelectBuddyID);
	
	return result;
}

- (id)_getBuddyProperty:(sqlite3_int64)buddyID key:(NSString *)key
{
	// > localQueue <
	
	if (!key)
		return nil;
	
	sqlite3_bind_int64(_stmtSelectBuddyProperty, 1, buddyID);
	sqlite3_bind_text(_stmtSelectBuddyProperty, 2, key.UTF8String, -1, SQLITE_TRANSIENT);

	return [self _sqliteStepValueForStatement:_stmtSelectBuddyProperty column:0];
}

- (void)_setBuddyProperty:(sqlite3_int64)buddyID key:(NSString *)key value:(id)value
{
	// > localQueue <
	
	sqlite3_bind_int64(_stmtInsertBuddyProperty, 1, buddyID);
	sqlite3_bind_text(_stmtInsertBuddyProperty, 2, key.UTF8String, -1, SQLITE_TRANSIENT);
		
	[self _sqliteStepSetValue:value forStatement:_stmtInsertBuddyProperty index:3];
}



/*
** TCConfigSQLite - TCConfigInterface
*/
#pragma mark - TCConfigSQLite - TCConfigInterface

#pragma mark Tor

- (NSString *)torAddress
{
	NSString *result = [self settingForKey:TCCONF_KEY_TOR_ADDRESS];
	
	if (result)
		return result;
	
	return @"localhost";
}

- (void)setTorAddress:(NSString *)address
{
	[self setSetting:address forKey:TCCONF_KEY_TOR_ADDRESS];
}

- (uint16_t)torPort
{
	NSNumber *result = [self settingForKey:TCCONF_KEY_TOR_PORT];

	if (result)
		return [result unsignedShortValue];

	return 9050;
}

- (void)setTorPort:(uint16_t)port
{
	[self setSetting:@(port) forKey:TCCONF_KEY_TOR_PORT];
}


#pragma mark TorChat

- (NSString *)selfAddress
{
	NSString *result = [self settingForKey:TCCONF_KEY_IM_ADDRESS];
	
	if (result)
		return result;
	
	return @"xxx";
}

- (void)setSelfAddress:(NSString *)address
{
	[self setSetting:address forKey:TCCONF_KEY_IM_ADDRESS];
}

- (uint16_t)clientPort
{
	NSNumber *result = [self settingForKey:TCCONF_KEY_IM_PORT];
	
	if (result)
		return [result unsignedShortValue];
	
	return 11009;
}

- (void)setClientPort:(uint16_t)port
{
	[self setSetting:@(port) forKey:TCCONF_KEY_IM_PORT];
}


#pragma mark Mode

- (TCConfigMode)mode
{
	NSNumber *result = [self settingForKey:TCCONF_KEY_MODE];
	
	if (result)
	{
		int mode = [result unsignedShortValue];
		
		if (mode == TCConfigModeAdvanced)
			return TCConfigModeAdvanced;
		else if (mode == TCConfigModeBasic)
			return TCConfigModeBasic;
		
		return TCConfigModeAdvanced;
	}
	else
		return TCConfigModeAdvanced;
}

- (void)setMode:(TCConfigMode)mode
{
	[self setSetting:@(mode) forKey:TCCONF_KEY_MODE];
}


#pragma mark Profile

- (NSString *)profileName
{
	NSString *result = [self settingForKey:TCCONF_KEY_PROFILE_NAME];
	
	if (result)
		return result;
	
	return @"-";
}

- (void)setProfileName:(NSString *)name
{
	[self setSetting:name forKey:TCCONF_KEY_PROFILE_NAME];
}

- (NSString *)profileText
{
	NSString *result = [self settingForKey:TCCONF_KEY_PROFILE_TEXT];
	
	if (result)
		return result;
	
	return @"";
}

- (void)setProfileText:(NSString *)text
{
	[self setSetting:text forKey:TCCONF_KEY_PROFILE_TEXT];
}

- (TCImage *)profileAvatar
{
	NSData *result = [self settingForKey:TCCONF_KEY_PROFILE_AVATAR];
	
	if (result)
	{
		NSImage *image = [[NSImage alloc] initWithData:result];
		
		return [[TCImage alloc] initWithImage:image];
	}
	
	return nil;
}

- (void)setProfileAvatar:(TCImage *)picture
{
	if (picture)
	{
		// Get Cocoa image.
		NSImage *image = [picture imageRepresentation];
		
		if (!image)
			return;
		
		// Create PNG representation.
		NSData *tiffData = [image TIFFRepresentation];
		NSData *pngData;
		
		if (!tiffData)
			return;
		
		pngData = [[[NSBitmapImageRep alloc] initWithData:tiffData] representationUsingType:NSPNGFileType properties:@{ }];
		
		if (!pngData)
			return;
		
		// Save.
		[self setSetting:pngData forKey:TCCONF_KEY_PROFILE_AVATAR];
	}
	else
	{
		[self setSetting:nil forKey:TCCONF_KEY_PROFILE_AVATAR];
	}
}


#pragma mark Buddies

- (NSArray *)buddies
{
	__block NSMutableArray *result = [[NSMutableArray alloc] init];
	
	dispatch_sync(_localQueue, ^{
		
		NSString			*currentAddress = nil;
		NSMutableDictionary	*currentEntry = nil;

		while (sqlite3_step(_stmtSelectBuddyAll) == SQLITE_ROW)
		{
			const char	*address = (const char *)sqlite3_column_text(_stmtSelectBuddyAll, 0);
			const char	*key = (const char *)sqlite3_column_text(_stmtSelectBuddyAll, 1);
			id			value = [self _sqliteValueForStatement:_stmtSelectBuddyAll column:2];
			
			if (!address)
				continue;
			
			if ([currentAddress isEqualToString:@(address)] == NO)
			{
				currentEntry = [[NSMutableDictionary alloc] init];
				currentAddress = @(address);
				
				currentEntry[TCConfigBuddyAddress] = currentAddress;
				
				[result addObject:currentEntry];
			}
			
			if (key && value)
				currentEntry[@(key)] = value;
		}
		
		sqlite3_reset(_stmtSelectBuddyAll);
	});
	
	return result;
}

- (void)addBuddy:(NSString *)address alias:(NSString *)alias notes:(NSString *)notes
{
	if (!address)
		return;
	
	if (!alias)
		alias = @"";
	
	if (!notes)
		notes = @"";
	
	dispatch_async(_localQueue, ^{

		int result;

		// Bind.
		sqlite3_bind_text(_stmtInsertBuddy, 1, address.UTF8String, -1, SQLITE_TRANSIENT);
		
		// Execute
		result = sqlite3_step(_stmtInsertBuddy);
		
		// Reset.
		sqlite3_reset(_stmtInsertBuddy);
		
		if (result == SQLITE_DONE)
		{
			sqlite3_int64 buddyID = sqlite3_last_insert_rowid(_dtb);
			
			[self _setBuddyProperty:buddyID key:TCConfigBuddyAlias value:alias];
			[self _setBuddyProperty:buddyID key:TCConfigBuddyNotes value:notes];
		}
	});
}

- (void)removeBuddy:(NSString *)address
{
	if (!address)
		return;
	
	dispatch_async(_localQueue, ^{

		// Bind.
		sqlite3_bind_text(_stmtDeleteBuddy, 1, address.UTF8String, -1, SQLITE_TRANSIENT);

		// Execute
		sqlite3_step(_stmtDeleteBuddy);
		
		// Reset.
		sqlite3_reset(_stmtDeleteBuddy);
	});
}

- (void)setBuddy:(NSString *)address alias:(NSString *)alias
{
	if (!address)
		return;
	
	if (!alias)
		alias = @"";
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		[self _setBuddyProperty:buddyID key:TCConfigBuddyAlias value:alias];
	});
}

- (void)setBuddy:(NSString *)address notes:(NSString *)notes
{
	if (!address)
		return;
	
	if (!notes)
		notes = @"";
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		[self _setBuddyProperty:buddyID key:TCConfigBuddyNotes value:notes];
	});
}

- (void)setBuddy:(NSString *)address lastProfileName:(NSString *)lastName
{
	if (!address)
		return;
	
	if (!lastName)
		lastName = @"";
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		[self _setBuddyProperty:buddyID key:TCConfigBuddyLastName value:lastName];
	});
}

- (void)setBuddy:(NSString *)address lastProfileText:(NSString *)lastText
{
	if (!address)
		return;
	
	if (!lastText)
		lastText = @"";
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		[self _setBuddyProperty:buddyID key:TCConfigBuddyLastText value:lastText];
	});
}

- (void)setBuddy:(NSString *)address lastProfileAvatar:(TCImage *)lastAvatar
{
	if (!address || !lastAvatar)
		return;
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		// Create PNG representation.
		NSImage *image = [lastAvatar imageRepresentation];
		NSData	*tiffData = [image TIFFRepresentation];
		NSData	*pngData;
		
		if (!tiffData)
			return;
		
		pngData = [[[NSBitmapImageRep alloc] initWithData:tiffData] representationUsingType:NSPNGFileType properties:@{ }];
		
		if (!pngData)
			return;
		
		// Save
		[self _setBuddyProperty:buddyID key:TCConfigBuddyLastAvatar value:pngData];
	});
}

- (NSString *)getBuddyAlias:(NSString *)address
{
	if (!address)
		return @"";
	
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		result = [self _getBuddyProperty:buddyID key:TCConfigBuddyAlias];
	});
	
	return result;
}

- (NSString *)getBuddyNotes:(NSString *)address
{
	if (!address)
		return @"";
	
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		result = [self _getBuddyProperty:buddyID key:TCConfigBuddyNotes];
	});
	
	return result;
}

- (NSString *)getBuddyLastProfileName:(NSString *)address
{
	if (!address)
		return @"";
	
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		result = [self _getBuddyProperty:buddyID key:TCConfigBuddyLastName];
	});
	
	return result;
}

- (NSString *)getBuddyLastProfileText:(NSString *)address
{
	if (!address)
		return @"";
	
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		result = [self _getBuddyProperty:buddyID key:TCConfigBuddyLastText];
	});
	
	return result;
}

- (TCImage *)getBuddyLastProfileAvatar:(NSString *)address
{
	if (!address)
		return nil;
	
	__block TCImage *result;
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForAddress:address];
		
		if (buddyID < 0)
			return;
		
		NSData	*data = [self _getBuddyProperty:buddyID key:TCConfigBuddyLastAvatar];
		NSImage *image = [[NSImage alloc] initWithData:data];
		
		result = [[TCImage alloc] initWithImage:image];
	});
	
	return result;
}


#pragma mark Blocked

- (NSArray *)blockedBuddies
{
	NSMutableArray *result = [[NSMutableArray alloc] init];
	
	dispatch_sync(_localQueue, ^{
		
		while (sqlite3_step(_stmtSelectBlocked) == SQLITE_ROW)
		{
			const char *address = (const char *)sqlite3_column_text(_stmtSelectBlocked, 0);
			
			if (address)
				[result addObject:@(address)];
		}
		
		sqlite3_reset(_stmtSelectBlocked);
	});
	
	return result;
}

- (void)addBlockedBuddy:(NSString *)address
{
	if (!address)
		return;
	
	dispatch_async(_localQueue, ^{
		
		// Bind.
		sqlite3_bind_text(_stmtInsertBlocked, 1, address.UTF8String, -1, SQLITE_TRANSIENT);

		// Execute.
		sqlite3_step(_stmtInsertBlocked);
		
		// Reset.
		sqlite3_reset(_stmtInsertBlocked);
	});
}

- (void)removeBlockedBuddy:(NSString *)address
{
	dispatch_async(_localQueue, ^{

		// Bind.
		sqlite3_bind_text(_stmtDeleteBlocked, 1, address.UTF8String, -1, SQLITE_TRANSIENT);
		
		// Execute.
		sqlite3_step(_stmtDeleteBlocked);
		
		// Reset.
		sqlite3_reset(_stmtDeleteBlocked);
	});
}


#pragma mark UI

- (TCConfigTitle)modeTitle
{
	NSNumber *result = [self settingForKey:TCCONF_KEY_UI_TITLE];
	
	if (!result)
		return TCConfigTitleAddress;
	
	return (TCConfigTitle)[result unsignedShortValue];
}

- (void)setModeTitle:(TCConfigTitle)mode
{
	[self setSetting:@(mode) forKey:TCCONF_KEY_UI_TITLE];
}


#pragma mark Client

- (NSString *)clientVersion:(TCConfigGet)get
{
	switch (get)
	{
		case TCConfigGetDefault:
		{
			NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
			
			if (version)
				return version;
			
			return @"";
		}
			
		case TCConfigGetDefined:
		{
			NSString *value = [self settingForKey:TCCONF_KEY_CLIENT_VERSION];
			
			if (value)
				return value;
			
			return @"";
		}
			
		case TCConfigGetReal:
		{
			NSString *value = [self clientVersion:TCConfigGetDefined];
			
			if ([value length] == 0)
				value = [self clientVersion:TCConfigGetDefault];
			
			return value;
		}
	}
	
	return @"";
}

- (void)setClientVersion:(NSString *)version
{
	if (!version)
		return;
	
	[self setSetting:version forKey:TCCONF_KEY_CLIENT_VERSION];
}

- (NSString *)clientName:(TCConfigGet)get
{
	switch (get)
	{
		case TCConfigGetDefault:
		{
			return @"TorChat for Mac";
		}
			
		case TCConfigGetDefined:
		{
			NSString *value = [self settingForKey:TCCONF_KEY_CLIENT_NAME];
			
			if (value)
				return value;
			
			return @"";
		}
			
		case TCConfigGetReal:
		{
			NSString *value = [self clientName:TCConfigGetDefined];
			
			if ([value length] == 0)
				value = [self clientName:TCConfigGetDefault];
			
			return value;
		}
	}
	
	return @"";
}

- (void)setClientName:(NSString *)name
{
	if (!name)
		return;
	
	[self setSetting:name forKey:TCCONF_KEY_CLIENT_NAME];
}


#pragma mark Paths

- (void)setPathForComponent:(TCConfigPathComponent)component pathType:(TCConfigPathType)pathType path:(NSString *)path
{
	dispatch_async(_localQueue, ^{
		
		// Handle special referal component.
		if (component == TCConfigPathComponentReferal)
		{
			if (!path)
				return;
			
			// Check parameter.
			BOOL isDirectory = NO;
			
			if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory == NO)
				return;
			
			// Prepare move.
			NSString *configFileName = [_dtbPath lastPathComponent];
			NSString *newPath = [path stringByAppendingPathComponent:configFileName];
			
			[self _closeDatabase];
			
			// Move.
			if ([[NSFileManager defaultManager] moveItemAtPath:_dtbPath toPath:newPath error:nil] == NO)
			{
				[self _openDatabase]; // re-open.
				return;
			}
			
			// Hold new path.
			_dtbPath = newPath;
			
			// Re-open on new path.
			[self _openDatabase];
			
			// Notify this component.
			[self _notifyPathChangeForComponent:TCConfigPathComponentReferal];
			
			// Notify components using this component.
			[self componentsEnumerateWithBlock:^(TCConfigPathComponent aComponent) {
				if ([self _pathTypeForComponent:aComponent] == TCConfigPathTypeReferal)
					[self _notifyPathChangeForComponent:aComponent];
			}];
		}
		else
		{
			NSString *componentStr = [self componentNameForComponent:component];
			NSString *pathTypeStr = [self pathTypeNameForPathType:pathType];
			
			// Bind.
			sqlite3_bind_text(_stmtInsertPath, 1, componentStr.UTF8String, -1, SQLITE_TRANSIENT);
			sqlite3_bind_text(_stmtInsertPath, 2, pathTypeStr.UTF8String, -1, SQLITE_TRANSIENT);
			
			if (path)
				sqlite3_bind_text(_stmtInsertPath, 3, path.UTF8String, -1, SQLITE_TRANSIENT);
			else
				sqlite3_bind_null(_stmtInsertPath, 3);

			// Execute.
			sqlite3_step(_stmtInsertPath);
			
			// Reset.
			sqlite3_clear_bindings(_stmtInsertPath);
			sqlite3_reset(_stmtInsertPath);

			
			// Notify.
			[self _notifyPathChangeForComponent:component];
		}
	});
}

- (NSString *)pathForComponent:(TCConfigPathComponent)component fullPath:(BOOL)fullPath
{
	__block NSString *result;
	
	dispatch_sync(_localQueue, ^{
		result = [self _pathForComponent:component fullPath:fullPath];
	});
	
	return result;
}

- (NSString *)_pathForComponent:(TCConfigPathComponent)component fullPath:(BOOL)fullPath
{
	// > localQueue <
	
	// Get default subpath.
	NSString	*standardSubPath = nil;
	NSString	*referalSubPath = nil;
	
	switch (component)
	{
		case TCConfigPathComponentReferal:
		{
			if (fullPath)
				return [_dtbPath stringByDeletingLastPathComponent];
			else
				return nil;
		}
			
		case TCConfigPathComponentTorBinary:
		{
			standardSubPath = @"/TorChat/Tor/";
			referalSubPath = @"/tor/bin/";
			break;
		}
			
		case TCConfigPathComponentTorData:
		{
			standardSubPath = @"/TorChat/TorData/";
			referalSubPath = @"/tor/data/";
			break;
		}
			
		case TCConfigPathComponentTorIdentity:
		{
			standardSubPath = @"/TorChat/TorIdentity/";
			referalSubPath = @"/tor/identity/";
			break;
		}
			
		case TCConfigPathComponentDownloads:
		{
			standardSubPath = @"/TorChat/";
			referalSubPath = @"/Downloads/";
			break;
		}
	}
	
	// Get component key.
	NSString *componentStr = [self componentNameForComponent:component];
	
	if (!componentStr)
		return nil;
	
	// Get component config.
	NSString *componentPathTypeStr = nil;
	NSString *componentPath = nil;

	// > Bind.
	sqlite3_bind_text(_stmtSelectPath, 1, componentStr.UTF8String, -1, SQLITE_TRANSIENT);
	
	// > Execute.
	if (sqlite3_step(_stmtSelectPath) == SQLITE_ROW)
	{
		const char *type = (const char *)sqlite3_column_text(_stmtSelectPath, 0);
		const char *path = (const char *)sqlite3_column_text(_stmtSelectPath, 1);

		if (type)
			componentPathTypeStr = @(type);
		
		if (path)
			componentPath = @(path);
	}
	
	// > Reset.
	sqlite3_reset(_stmtSelectPath);
	
	// Convert component config.
	TCConfigPathType componentPathType = [self pathTypeForPathTypeName:componentPathTypeStr];

	// Compose path according to path type.
	switch (componentPathType)
	{
		case TCConfigPathTypeReferal:
		{
			// > Get subpath.
			NSString *subPath;
			
			if (componentPath)
				subPath = componentPath;
			else
				subPath = referalSubPath;
			
			// > Compose path.
			if (fullPath)
			{
				NSString *path = [self _pathForComponent:TCConfigPathComponentReferal fullPath:YES];
				
				return [[path stringByAppendingPathComponent:subPath] stringByStandardizingPath];
			}
			else
				return subPath;
		}
			
		case TCConfigPathTypeStandard:
		{
			// > Compose path.
			if (fullPath)
			{
				// >> Get standard path directory.
				NSSearchPathDirectory standardPathDirectory;
				
				switch (component)
				{
					case TCConfigPathComponentReferal	: return nil; // never called.
					case TCConfigPathComponentTorBinary	: standardPathDirectory = NSApplicationSupportDirectory; break;
					case TCConfigPathComponentTorData	: standardPathDirectory = NSApplicationSupportDirectory; break;
					case TCConfigPathComponentTorIdentity: standardPathDirectory = NSApplicationSupportDirectory; break;
					case TCConfigPathComponentDownloads	: standardPathDirectory = NSDownloadsDirectory;	break;
				}
				
				// >> Get URL of the standard path directory.
				NSURL *url = [[NSFileManager defaultManager] URLForDirectory:standardPathDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
				
				if (!url)
					return nil;
				
				// >> Create full path.
				url = [url URLByAppendingPathComponent:standardSubPath isDirectory:YES];
				
				if (!url)
					return nil;
				
				return [[url path] stringByStandardizingPath];
			}
			else
				return standardSubPath;
		}
			
		case TCConfigPathTypeAbsolute:
		{
			if (fullPath)
				return [componentPath stringByStandardizingPath];
			else
				return componentPath;
		}
	}
	
	return nil;
}

#pragma mark > Type

- (TCConfigPathType)pathTypeForComponent:(TCConfigPathComponent)component
{
	__block TCConfigPathType result;
	
	dispatch_sync(_localQueue, ^{
		result = [self _pathTypeForComponent:component];
	});
	
	return result;
}

- (TCConfigPathType)_pathTypeForComponent:(TCConfigPathComponent)component
{
	// > localQueue <
	
	NSString *componentStr = [self componentNameForComponent:component];
	
	if (!componentStr)
		return TCConfigPathTypeReferal;
	
	// Get component config.
	NSString *componentPathTypeStr = nil;
	
	// > Bind.
	sqlite3_bind_text(_stmtSelectPath, 1, componentStr.UTF8String, -1, SQLITE_TRANSIENT);
	
	// > Execute.
	if (sqlite3_step(_stmtSelectPath) == SQLITE_ROW)
	{
		const char *type = (const char *)sqlite3_column_text(_stmtSelectPath, 0);
		
		if (type)
			componentPathTypeStr = @(type);
	}
	
	// > Reset.
	sqlite3_reset(_stmtSelectPath);
	
	// Convert component config.
	return [self pathTypeForPathTypeName:componentPathTypeStr];
}

- (TCConfigPathType)pathTypeForPathTypeName:(NSString *)pathTypeName
{
	if ([pathTypeName isEqualToString:TCCONF_VALUE_PATH_TYPE_REFERAL])
		return TCConfigPathTypeReferal;
	else if ([pathTypeName isEqualToString:TCCONF_VALUE_PATH_TYPE_STANDARD])
		return TCConfigPathTypeStandard;
	else if ([pathTypeName isEqualToString:TCCONF_VALUE_PATH_TYPE_ABSOLUTE])
		return TCConfigPathTypeAbsolute;
	
	return TCConfigPathTypeReferal;
}

- (NSString *)pathTypeNameForPathType:(TCConfigPathType)pathType
{
	switch (pathType)
	{
		case TCConfigPathTypeReferal:
			return TCCONF_VALUE_PATH_TYPE_REFERAL;
			
		case TCConfigPathTypeStandard:
			return TCCONF_VALUE_PATH_TYPE_STANDARD;
			
		case TCConfigPathTypeAbsolute:
			return TCCONF_VALUE_PATH_TYPE_ABSOLUTE;
	}
	
	return nil;
}

#pragma mark > Component

- (NSString *)componentNameForComponent:(TCConfigPathComponent)component
{
	switch (component)
	{
		case TCConfigPathComponentReferal:
			return nil;
			
		case TCConfigPathComponentTorBinary:
			return TCCONF_KEY_PATH_TOR_BIN;
			
		case TCConfigPathComponentTorData:
			return TCCONF_KEY_PATH_TOR_DATA;
			
		case TCConfigPathComponentTorIdentity:
			return TCCONF_KEY_PATH_TOR_IDENTITY;
			
		case TCConfigPathComponentDownloads:
			return TCCONF_KEY_PATH_DOWNLOADS;
	}
	
	return nil;
}

- (void)componentsEnumerateWithBlock:(void (^)(TCConfigPathComponent component))block
{
	block(TCConfigPathComponentTorBinary);
	block(TCConfigPathComponentTorData);
	block(TCConfigPathComponentTorIdentity);
	block(TCConfigPathComponentDownloads);
}

#pragma mark > Observers

- (id)addPathObserverForComponent:(TCConfigPathComponent)component queue:(dispatch_queue_t)queue usingBlock:(dispatch_block_t)block
{
	// Check parameters.
	if (!block)
		return nil;
	
	if (!queue)
		queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	// Create result object.
	NSDictionary *result = @{ @"component" : @(component), @"queue" : queue, @"block" : block };
	
	// Add to observers.
	dispatch_barrier_async(_localQueue, ^{
		
		// > Create master observers.
		if (!_pathObservers)
			_pathObservers = [[NSMutableDictionary alloc] init];
		
		// > Get observers for this component.
		NSMutableArray *observers = _pathObservers[@(component)];
		
		if (!observers)
		{
			observers = [[NSMutableArray alloc] init];
			_pathObservers[@(component)] = observers;
		}
		
		// > Add this observer to the list.
		[observers addObject:result];
	});
	
	return result;
}

- (void)removePathObserver:(id)observer
{
	if (!observer)
		return;
	
	NSDictionary	*info = observer;
	NSNumber		*component = info[@"component"];
	
	dispatch_barrier_async(_localQueue, ^{
		
		NSMutableArray *array = _pathObservers[component];
		
		[array removeObjectIdenticalTo:info];
	});
}

- (void)_notifyPathChangeForComponent:(TCConfigPathComponent)component
{
	// > localQueue <
	
	// Get observers for this component.
	NSArray *observers = _pathObservers[@(component)];
	
	if (!observers)
		return;
	
	// Notify each observers.
	for (NSDictionary *observer in observers)
	{
		dispatch_block_t block = observer[@"block"];
		dispatch_queue_t queue = observer[@"queue"];
		
		dispatch_async(queue, ^{
			block();
		});
	}
}


#pragma mark Strings

- (NSString *)localizedString:(TCConfigStringItem)stringItem
{
	switch (stringItem)
	{
		case TCConfigStringItemMyselfBuddy:
			return NSLocalizedString(@"core_mng_myself", @"");
	}
	
	return nil;
}


#pragma mark Synchronize

- (void)synchronize
{
	dispatch_sync(_localQueue, ^{ });
}

@end
