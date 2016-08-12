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

#import "TCFileHelper.h"


/*
** Defines
*/
#pragma mark - Defines

// Buddy.
#define TCConfigBuddyAliasKey		@"alias"
#define TCConfigBuddyNotesKey		@"notes"

#define TCConfigBuddyLastNameKey	@"lname"
#define TCConfigBuddyLastTextKey	@"ltext"
#define TCConfigBuddyLastAvatarKey	@"lavatar"

// General
#define TCConfigTorSocksAddressKey	@"tor_socks_address"
#define TCConfigTorSocksPortKey		@"tor_socks_port"

#define TCConfigSelfPrivateKey		@"self_privatekey"
#define TCConfigSelfIdentifierKey	@"self_identifier"
#define TCConfigSelfPortKey			@"self_port"

#define TCConfigTorModeKey			@"tor_mode"

#define TCConfigPofileNameKey		@"profile_name"
#define TCConfigPofileTextKey		@"profile_text"
#define TCConfigPofileAvatarKey		@"profile_avatar"

#define TCConfigUITitleKey			@"ui_title"

#define TCConfigClientVersionKey	@"client_version"
#define TCConfigClientNameKey		@"client_name"

// Paths
#define TCConfigPathTorBinKey		@"tor_bin"
#define TCConfigPathTorDataKey		@"tor_data"
#define TCConfigPathTorIdentityKey	@"tor_identity"
#define TCConfigPathDownloadsKey	@"downloads"

#define TCConfigPathTypeReferalKey	@"<referal>"
#define TCConfigPathTypeStandardKey	@"<standard>"
#define TCConfigPathTypeAbsoluteKey	@"<absolute>"

// Transcript.
#define TCConfigTranscriptSaveKey	@"transcript_save"



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
	const char			*_dtbUUID;
	sqlite3				*_dtb;
	
	sqlite3_stmt		*_stmtInsertSetting;
	sqlite3_stmt		*_stmtSelectSetting;
	sqlite3_stmt		*_stmtDeleteSetting;

	sqlite3_stmt		*_stmtInsertBuddy;
	sqlite3_stmt		*_stmtInsertBuddyProperty;
	sqlite3_stmt		*_stmtSelectBuddyID;
	sqlite3_stmt		*_stmtSelectBuddyIdentifiers;
	sqlite3_stmt		*_stmtSelectBuddyProperty;
	sqlite3_stmt		*_stmtDeleteBuddy;
	
	sqlite3_stmt		*_stmtInsertBlocked;
	sqlite3_stmt		*_stmtSelectBlocked;
	sqlite3_stmt		*_stmtDeleteBlocked;
	
	sqlite3_stmt		*_stmtInsertPath;
	sqlite3_stmt		*_stmtSelectPath;
	
	sqlite3_stmt		*_stmtInsertTranscript;
	sqlite3_stmt		*_stmtSelectIdentifiersTranscript;
	sqlite3_stmt		*_stmtSelectMsgTranscript;
	sqlite3_stmt		*_stmtSelectMinMaxIdTranscript;
	sqlite3_stmt		*_stmtDeleteIdentifierTranscript;
	sqlite3_stmt		*_stmtDeleteIdTranscript;
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

- (id)initWithFile:(NSString *)filepath password:(NSString *)password error:(NSError **)error
{
	self = [super init];
	
	if (self)
	{
		// Hold parameters.
		_dtbPath = filepath;
		
		if (!_dtbPath)
		{
			if (error)
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:1 userInfo:nil];
			return nil;
		}
		
		// Check parameters.
		if ([[self class] isEncryptedFile:_dtbPath] && password == nil)
		{
			if (error)
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:2 userInfo:nil];
			return nil;
		}
		
		// Copy password in 'safe' place.
		if (password)
		{
			vm_size_t hostPageSize = 0;
			
			if (host_page_size(mach_host_self(), &hostPageSize) != KERN_SUCCESS)
				hostPageSize = 4096;
			
			if (posix_memalign(&_dtbPassword, hostPageSize, hostPageSize) != 0)
			{
				if (error)
					*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:3 userInfo:nil];
				return nil;
			}
			
			if (mlock(_dtbPassword, hostPageSize) != 0)
			{
				if (error)
					*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:4 userInfo:nil];
				free(_dtbPassword);
				return nil;
			}
			
			strlcpy(_dtbPassword, password.UTF8String, hostPageSize);
			
			// Clean password.
			password = nil;
		}

		// Open database.
		if ([self _openDatabaseWithError:error] == NO)
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
	if (_dtbPassword)
	{
		vm_size_t hostPageSize = 0;
		
		if (host_page_size(mach_host_self(), &hostPageSize) != KERN_SUCCESS)
			hostPageSize = 4096;
		
		memset_s(_dtbPassword, hostPageSize, 0, hostPageSize);
		munlock(_dtbPassword, hostPageSize);
		free(_dtbPassword);
	}
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

- (BOOL)_openDatabaseWithError:(NSError **)error
{
	// > localQueue <
	
#define tc_sqlite3_exec(Database, Sql) do { \
	int __res = sqlite3_exec(Database, Sql, NULL, NULL, NULL);\
	if (__res != SQLITE_OK) {	\
		if (error)				\
			*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(__res) }];\
		return NO;				\
	}							\
} while (0)
	
#define tc_sqlite3_prepare(Dtb, Sql, Stmt) do { \
	int __res = sqlite3_prepare_v2(Dtb, Sql, -1, Stmt, NULL);\
	if (__res != SQLITE_OK) {	\
		if (error)				\
			*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(__res) }];\
		return NO;				\
	}\
} while (0)

	// Open database.
	int result;
	
	if (_dtbPassword)
	{
		const char *uriPath;
		
		_dtbUUID = SMSQLiteCryptoVFSSettingsAdd(_dtbPassword, SMCryptoFileKeySize256);
		uriPath = [[NSString stringWithFormat:@"file://%@?crypto-uuid=%s", _dtbPath, _dtbUUID] UTF8String];
		
		result = sqlite3_open_v2(uriPath, &_dtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
		
		if (result != SQLITE_OK)
		{
			if (error)
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:5 userInfo:@{ TCConfigSQLiteErrorKey : @(result), TCConfigSMCryptoFileErrorKey : @(SMSQLiteCryptoVFSLastFileCryptoError()) }];
			
			return NO;
		}
	}
	else
	{
		result = sqlite3_open_v2(_dtbPath.fileSystemRepresentation, &_dtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);
		
		if (result != SQLITE_OK)
		{
			if (error)
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:6 userInfo:@{ TCConfigSQLiteErrorKey : @(result) }];

			return NO;
		}
	}
	
	
	// Pragmas.
	tc_sqlite3_exec(_dtb, "PRAGMA foreign_keys = ON");

	
	// Create 'settings' table.
	// > Table.
	tc_sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS settings (key TEXT NOT NULL, value, UNIQUE (key) ON CONFLICT REPLACE)");

	// > Index.
	tc_sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS settings_idx ON settings(key)");
	
	// > Statements.
	tc_sqlite3_prepare(_dtb, "INSERT INTO settings (key, value) VALUES (?, ?)", &_stmtInsertSetting);
	tc_sqlite3_prepare(_dtb, "SELECT value FROM settings WHERE key=? LIMIT 1", &_stmtSelectSetting);
	tc_sqlite3_prepare(_dtb, "DELETE FROM settings WHERE key=?", &_stmtDeleteSetting);
	
	
	// Create 'buddies' table.
	// > Tables.
	tc_sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS buddies (id INTEGER PRIMARY KEY AUTOINCREMENT, identifier TEXT NOT NULL, UNIQUE (identifier) ON CONFLICT ABORT)");
	tc_sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS buddies_properties (buddy_id INTEGER, key TEXT NOT NULL, value, FOREIGN KEY(buddy_id) REFERENCES buddies(id) ON DELETE CASCADE, UNIQUE (buddy_id, key) ON CONFLICT REPLACE)");
	
	// > Indexes.
	tc_sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS buddies_idx ON buddies(identifier)");
	tc_sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS buddies_properties_idx ON buddies_properties(buddy_id, key)");
	
	// > Statements.
	tc_sqlite3_prepare(_dtb, "INSERT INTO buddies (identifier) VALUES (?)", &_stmtInsertBuddy);
	tc_sqlite3_prepare(_dtb, "INSERT INTO buddies_properties (buddy_id, key, value) VALUES (?, ?, ?)", &_stmtInsertBuddyProperty);
	tc_sqlite3_prepare(_dtb, "SELECT id FROM buddies WHERE identifier=? LIMIT 1", &_stmtSelectBuddyID);
	tc_sqlite3_prepare(_dtb, "SELECT identifier FROM buddies", &_stmtSelectBuddyIdentifiers);
	tc_sqlite3_prepare(_dtb, "SELECT value FROM buddies_properties WHERE buddy_id=? AND key=? LIMIT 1", &_stmtSelectBuddyProperty);
	tc_sqlite3_prepare(_dtb, "DELETE FROM buddies WHERE identifier=?", &_stmtDeleteBuddy);
	
	
	// Create 'blocked' table.
	// > Table.
	tc_sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS blocked (identifier TEXT NOT NULL, UNIQUE (identifier) ON CONFLICT ABORT)");
	
	// > Indexes.
	tc_sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS blocked_idx ON blocked(identifier)");
	
	// > Statements.
	tc_sqlite3_prepare(_dtb, "INSERT INTO blocked (identifier) VALUES (?)", &_stmtInsertBlocked);
	tc_sqlite3_prepare(_dtb, "SELECT identifier FROM blocked LIMIT 1", &_stmtSelectBlocked);
	tc_sqlite3_prepare(_dtb, "DELETE FROM blocked WHERE identifier=?", &_stmtDeleteBlocked);
	
	// Create 'paths' table.
	// > Table.
	tc_sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS paths (component TEXT NOT NULL, type TEXT NOT NULL, path TEXT, UNIQUE (component) ON CONFLICT REPLACE)");
	
	// > Indexes.
	tc_sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS paths_idx ON paths(component)");
	
	// > Statements.
	tc_sqlite3_prepare(_dtb, "INSERT INTO paths (component, type, path) VALUES (?, ?, ?)", &_stmtInsertPath);
	tc_sqlite3_prepare(_dtb, "SELECT type, path FROM paths WHERE component=?", &_stmtSelectPath);
	
	// Create 'transcripts' table.
	// > Table.
	tc_sqlite3_exec(_dtb, "CREATE TABLE IF NOT EXISTS transcripts (id INTEGER PRIMARY KEY AUTOINCREMENT, buddy_id INTEGER NOT NULL, message TEXT NOT NULL, side INTEGER NOT NULL, timestamp REAL NOT NULL, error TEXT, FOREIGN KEY(buddy_id) REFERENCES buddies(id) ON DELETE CASCADE)");

	// > Indexes.
	tc_sqlite3_exec(_dtb, "CREATE INDEX IF NOT EXISTS transcripts_idx ON transcripts(buddy_id, id DESC)");
	
	// > Statements
	tc_sqlite3_prepare(_dtb, "INSERT INTO transcripts (buddy_id, message, side, timestamp, error) VALUES (?, ?, ?, ?, ?)", &_stmtInsertTranscript);
	tc_sqlite3_prepare(_dtb, "SELECT identifier, max(transcripts.id) AS mx FROM transcripts, buddies WHERE transcripts.buddy_id=buddies.id GROUP BY identifier ORDER by mx DESC", &_stmtSelectIdentifiersTranscript);
	tc_sqlite3_prepare(_dtb, "SELECT id, message, side, timestamp, error FROM transcripts WHERE buddy_id=? AND id<? ORDER BY id DESC LIMIT ?", &_stmtSelectMsgTranscript);
	tc_sqlite3_prepare(_dtb, "SELECT min(id), max(id) FROM transcripts WHERE buddy_id=?", &_stmtSelectMinMaxIdTranscript);
	tc_sqlite3_prepare(_dtb, "DELETE FROM transcripts WHERE buddy_id=?", &_stmtDeleteIdentifierTranscript);
	tc_sqlite3_prepare(_dtb, "DELETE FROM transcripts WHERE id=?", &_stmtDeleteIdTranscript);
	
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
	tc_sqlite3_finalize(_stmtSelectBuddyIdentifiers);
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
	
	// Remove VFS info.
	if (_dtbUUID)
	{
		SMSQLiteCryptoVFSSettingsRemove(_dtbUUID);
		_dtbUUID = NULL;
	}
}


#pragma mark Bridge

- (id)_sqliteValueForStatement:(sqlite3_stmt *)stmt column:(int)column
{
	if (!stmt || !_dtb)
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
	
	if (!stmt || !_dtb)
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
	
	if (!value || !stmt || !_dtb)
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
		
		if (!_dtb)
			return;
		
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
		
		if (!_dtb)
			return;
		
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

- (sqlite3_int64)_buddyIDForIdentifier:(NSString *)identifier
{
	if (!identifier || !_dtb)
		return -1;
	
	sqlite3_int64 result = -1;
	
	// Bind.
	sqlite3_bind_text(_stmtSelectBuddyID, 1, identifier.UTF8String, -1, SQLITE_TRANSIENT);

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
	
	if (!key || !_dtb)
		return nil;
	
	sqlite3_bind_int64(_stmtSelectBuddyProperty, 1, buddyID);
	sqlite3_bind_text(_stmtSelectBuddyProperty, 2, key.UTF8String, -1, SQLITE_TRANSIENT);

	return [self _sqliteStepValueForStatement:_stmtSelectBuddyProperty column:0];
}

- (void)_setBuddyProperty:(sqlite3_int64)buddyID key:(NSString *)key value:(id)value
{
	// > localQueue <
	
	if (!_dtb)
		return;
	
	sqlite3_bind_int64(_stmtInsertBuddyProperty, 1, buddyID);
	sqlite3_bind_text(_stmtInsertBuddyProperty, 2, key.UTF8String, -1, SQLITE_TRANSIENT);
		
	[self _sqliteStepSetValue:value forStatement:_stmtInsertBuddyProperty index:3];
}



/*
** TCConfigSQLite - TCConfig
*/
#pragma mark - TCConfigSQLite - TCConfig

#pragma mark Tor

- (NSString *)torAddress
{
	NSString *result = [self settingForKey:TCConfigTorSocksAddressKey];
	
	if (result)
		return result;
	
	return @"localhost";
}

- (void)setTorAddress:(NSString *)address
{
	[self setSetting:address forKey:TCConfigTorSocksAddressKey];
}

- (uint16_t)torPort
{
	NSNumber *result = [self settingForKey:TCConfigTorSocksPortKey];

	if (result)
		return [result unsignedShortValue];

	return 9050;
}

- (void)setTorPort:(uint16_t)port
{
	[self setSetting:@(port) forKey:TCConfigTorSocksPortKey];
}


#pragma mark TorChat

- (NSString *)selfPrivateKey
{
	return [self settingForKey:TCConfigSelfPrivateKey];
}

- (void)setSelfPrivateKey:(NSString *)selfPrivateKey
{
	[self setSetting:selfPrivateKey forKey:TCConfigSelfPrivateKey];
}

- (NSString *)selfIdentifier
{
	NSString *result = [self settingForKey:TCConfigSelfIdentifierKey];
	
	if (result)
		return result;
	
	return @"xxx";
}

- (void)setSelfIdentifier:(NSString *)identifier
{
	[self setSetting:identifier forKey:TCConfigSelfIdentifierKey];
}

- (uint16_t)selfPort
{
	NSNumber *result = [self settingForKey:TCConfigSelfPortKey];
	
	if (result)
		return [result unsignedShortValue];
	
	return 11009;
}

- (void)setSelfPort:(uint16_t)selfPort
{
	[self setSetting:@(selfPort) forKey:TCConfigSelfPortKey];
}


#pragma mark Mode

- (TCConfigMode)mode
{
	NSNumber *result = [self settingForKey:TCConfigTorModeKey];
	
	if (result)
	{
		int mode = [result unsignedShortValue];
		
		if (mode == TCConfigModeCustom)
			return TCConfigModeCustom;
		else if (mode == TCConfigModeBundled)
			return TCConfigModeBundled;
		
		return TCConfigModeCustom;
	}
	else
		return TCConfigModeCustom;
}

- (void)setMode:(TCConfigMode)mode
{
	[self setSetting:@(mode) forKey:TCConfigTorModeKey];
}


#pragma mark Profile

- (NSString *)profileName
{
	NSString *result = [self settingForKey:TCConfigPofileNameKey];
	
	if (result)
		return result;
	
	return @"-";
}

- (void)setProfileName:(NSString *)name
{
	[self setSetting:name forKey:TCConfigPofileNameKey];
}

- (NSString *)profileText
{
	NSString *result = [self settingForKey:TCConfigPofileTextKey];
	
	if (result)
		return result;
	
	return @"";
}

- (void)setProfileText:(NSString *)text
{
	[self setSetting:text forKey:TCConfigPofileTextKey];
}

- (TCImage *)profileAvatar
{
	NSData *result = [self settingForKey:TCConfigPofileAvatarKey];
	
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
		[self setSetting:pngData forKey:TCConfigPofileAvatarKey];
	}
	else
	{
		[self setSetting:nil forKey:TCConfigPofileAvatarKey];
	}
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
			NSString *value = [self settingForKey:TCConfigClientVersionKey];
			
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
	
	[self setSetting:version forKey:TCConfigClientVersionKey];
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
			NSString *value = [self settingForKey:TCConfigClientNameKey];
			
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
	
	[self setSetting:name forKey:TCConfigClientNameKey];
}


#pragma mark Buddies

- (NSArray *)buddiesIdentifiers
{
	NSMutableArray *result = [[NSMutableArray alloc] init];
	
	dispatch_sync(_localQueue, ^{
		
		if (!_dtb)
			return;

		while (sqlite3_step(_stmtSelectBuddyIdentifiers) == SQLITE_ROW)
		{
			const char *identifier = (const char *)sqlite3_column_text(_stmtSelectBuddyIdentifiers, 0);
			
			if (!identifier)
				continue;
			
			[result addObject:@(identifier)];
		}
		
		sqlite3_reset(_stmtSelectBuddyIdentifiers);
	});
	
	return result;
}

- (void)addBuddyWithIdentifier:(NSString *)identifier alias:(NSString *)alias notes:(NSString *)notes
{
	if (!identifier)
		return;
	
	if (!alias)
		alias = @"";
	
	if (!notes)
		notes = @"";
	
	dispatch_async(_localQueue, ^{

		if (!_dtb)
			return;
		
		int result;

		// Bind.
		sqlite3_bind_text(_stmtInsertBuddy, 1, identifier.UTF8String, -1, SQLITE_TRANSIENT);
		
		// Execute
		result = sqlite3_step(_stmtInsertBuddy);
		
		// Reset.
		sqlite3_reset(_stmtInsertBuddy);
		
		if (result == SQLITE_DONE)
		{
			sqlite3_int64 buddyID = sqlite3_last_insert_rowid(_dtb);
			
			[self _setBuddyProperty:buddyID key:TCConfigBuddyAliasKey value:alias];
			[self _setBuddyProperty:buddyID key:TCConfigBuddyNotesKey value:notes];
		}
	});
}

- (void)removeBuddyWithIdentifier:(NSString *)identifier
{
	if (!identifier)
		return;
	
	dispatch_async(_localQueue, ^{

		if (!_dtb)
			return;
		
		// Bind.
		sqlite3_bind_text(_stmtDeleteBuddy, 1, identifier.UTF8String, -1, SQLITE_TRANSIENT);

		// Execute
		sqlite3_step(_stmtDeleteBuddy);
		
		// Reset.
		sqlite3_reset(_stmtDeleteBuddy);
	});
}

- (void)setBuddyAlias:(NSString *)alias forBuddyIdentifier:(NSString *)identifier
{
	if (!identifier)
		return;
	
	if (!alias)
		alias = @"";
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
		if (buddyID < 0)
			return;
		
		[self _setBuddyProperty:buddyID key:TCConfigBuddyAliasKey value:alias];
	});
}

- (void)setBuddyNotes:(NSString *)notes forBuddyIdentifier:(NSString *)identifier
{
	if (!identifier)
		return;
	
	if (!notes)
		notes = @"";
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
		if (buddyID < 0)
			return;
		
		[self _setBuddyProperty:buddyID key:TCConfigBuddyNotesKey value:notes];
	});
}

- (void)setBuddyLastName:(NSString *)lastName forBuddyIdentifier:(NSString *)identifier
{
	if (!identifier)
		return;
	
	if (!lastName)
		lastName = @"";
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
		if (buddyID < 0)
			return;
		
		[self _setBuddyProperty:buddyID key:TCConfigBuddyLastNameKey value:lastName];
	});
}

- (void)setBuddyLastText:(NSString *)lastText forBuddyIdentifier:(NSString *)identifier
{
	if (!identifier)
		return;
	
	if (!lastText)
		lastText = @"";
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
		if (buddyID < 0)
			return;
		
		[self _setBuddyProperty:buddyID key:TCConfigBuddyLastTextKey value:lastText];
	});
}

- (void)setBuddyLastAvatar:(TCImage *)lastAvatar forBuddyIdentifier:(NSString *)identifier
{
	if (!identifier || !lastAvatar)
		return;
	
	dispatch_async(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
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
		[self _setBuddyProperty:buddyID key:TCConfigBuddyLastAvatarKey value:pngData];
	});
}

- (NSString *)buddyAliasForBuddyIdentifier:(NSString *)identifier
{
	if (!identifier)
		return @"";
	
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
		if (buddyID < 0)
			return;
		
		result = [self _getBuddyProperty:buddyID key:TCConfigBuddyAliasKey];
	});
	
	return result;
}

- (NSString *)buddyNotesForBuddyIdentifier:(NSString *)identifier
{
	if (!identifier)
		return @"";
	
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
		if (buddyID < 0)
			return;
		
		result = [self _getBuddyProperty:buddyID key:TCConfigBuddyNotesKey];
	});
	
	return result;
}

- (NSString *)buddyLastNameForBuddyIdentifier:(NSString *)identifier
{
	if (!identifier)
		return @"";
	
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
		if (buddyID < 0)
			return;
		
		result = [self _getBuddyProperty:buddyID key:TCConfigBuddyLastNameKey];
	});
	
	return result;
}

- (NSString *)buddyLastTextForBuddyIdentifier:(NSString *)identifier
{
	if (!identifier)
		return @"";
	
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
		if (buddyID < 0)
			return;
		
		result = [self _getBuddyProperty:buddyID key:TCConfigBuddyLastTextKey];
	});
	
	return result;
}

- (TCImage *)buddyLastAvatarForBuddyIdentifier:(NSString *)identifier
{
	if (!identifier)
		return nil;
	
	__block TCImage *result;
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
		if (buddyID < 0)
			return;
		
		NSData	*data = [self _getBuddyProperty:buddyID key:TCConfigBuddyLastAvatarKey];
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
		
		if (!_dtb)
			return;
		
		while (sqlite3_step(_stmtSelectBlocked) == SQLITE_ROW)
		{
			const char *identifier = (const char *)sqlite3_column_text(_stmtSelectBlocked, 0);
			
			if (identifier)
				[result addObject:@(identifier)];
		}
		
		sqlite3_reset(_stmtSelectBlocked);
	});
	
	return result;
}

- (void)addBlockedBuddyWithIdentifier:(NSString *)identifier
{
	if (!identifier)
		return;
	
	dispatch_async(_localQueue, ^{
		
		if (!_dtb)
			return;
		
		// Bind.
		sqlite3_bind_text(_stmtInsertBlocked, 1, identifier.UTF8String, -1, SQLITE_TRANSIENT);

		// Execute.
		sqlite3_step(_stmtInsertBlocked);
		
		// Reset.
		sqlite3_reset(_stmtInsertBlocked);
	});
}

- (void)removeBlockedBuddyWithIdentifier:(NSString *)identifier
{
	dispatch_async(_localQueue, ^{

		if (!_dtb)
			return;
		
		// Bind.
		sqlite3_bind_text(_stmtDeleteBlocked, 1, identifier.UTF8String, -1, SQLITE_TRANSIENT);
		
		// Execute.
		sqlite3_step(_stmtDeleteBlocked);
		
		// Reset.
		sqlite3_reset(_stmtDeleteBlocked);
	});
}


#pragma mark Paths

- (void)setPathForComponent:(TCConfigPathComponent)component pathType:(TCConfigPathType)pathType path:(NSString *)path
{
	dispatch_async(_localQueue, ^{
		
		if (!_dtb)
			return;
		
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
				[self _openDatabaseWithError:nil]; // re-open.
				return;
			}
			
			// Hold new path.
			_dtbPath = newPath;
			
			// Re-open on new path.
			[self _openDatabaseWithError:nil];
			
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
	
	if (!_dtb)
		return nil;
	
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
	
	if (!_dtb)
		return TCConfigPathTypeReferal;
	
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
	if ([pathTypeName isEqualToString:TCConfigPathTypeReferalKey])
		return TCConfigPathTypeReferal;
	else if ([pathTypeName isEqualToString:TCConfigPathTypeStandardKey])
		return TCConfigPathTypeStandard;
	else if ([pathTypeName isEqualToString:TCConfigPathTypeAbsoluteKey])
		return TCConfigPathTypeAbsolute;
	
	return TCConfigPathTypeReferal;
}

- (NSString *)pathTypeNameForPathType:(TCConfigPathType)pathType
{
	switch (pathType)
	{
		case TCConfigPathTypeReferal:
			return TCConfigPathTypeReferalKey;
			
		case TCConfigPathTypeStandard:
			return TCConfigPathTypeStandardKey;
			
		case TCConfigPathTypeAbsolute:
			return TCConfigPathTypeAbsoluteKey;
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
			return TCConfigPathTorBinKey;
			
		case TCConfigPathComponentTorData:
			return TCConfigPathTorDataKey;
			
		case TCConfigPathComponentTorIdentity:
			return TCConfigPathTorIdentityKey;
			
		case TCConfigPathComponentDownloads:
			return TCConfigPathDownloadsKey;
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


#pragma mark Synchronize

extern int sqlite3_db_cacheflush(sqlite3 *) __attribute__((weak_import));

- (BOOL)synchronize
{
	__block BOOL result = YES;
	
	dispatch_sync(_localQueue, ^{
		
		if (!_dtb)
			return;
		
		if (sqlite3_db_cacheflush != NULL)
			result = (sqlite3_db_cacheflush(_dtb) == SQLITE_OK);
	});
	
	return result;
}


#pragma mark Life

- (void)close
{
	dispatch_sync(_localQueue, ^{
		[self _closeDatabase];
	});
}



/*
** TCConfigSQLite - TCConfigInterface
*/
#pragma mark - TCConfigSQLite - TCConfigInterface

#pragma mark Title

- (TCConfigTitle)modeTitle
{
	NSNumber *result = [self settingForKey:TCConfigUITitleKey];
	
	if (!result)
		return TCConfigTitleIdentifier;
	
	return (TCConfigTitle)[result unsignedShortValue];
}

- (void)setModeTitle:(TCConfigTitle)mode
{
	[self setSetting:@(mode) forKey:TCConfigUITitleKey];
}


#pragma mark Transcript

- (BOOL)saveTranscript
{
	return [[self settingForKey:TCConfigTranscriptSaveKey] boolValue];
}

- (void)setSaveTranscript:(BOOL)saveTranscript
{
	[self setSetting:@(saveTranscript) forKey:TCConfigTranscriptSaveKey];
}

- (void)addTranscriptForBuddyIdentifier:(NSString *)identifier message:(TCChatMessage *)message completionHandler:(void (^)(int64_t msgID))handler
{
	if (!handler)
		handler = ^(int64_t msgID) { };
	
	if (!identifier || !message)
	{
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ handler(-1); });
		return;
	}
	
	dispatch_async(_localQueue, ^{
		
		// Check database.
		if (!_dtb)
		{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ handler(-1); });
			return;
		}
		
		// Search buddy.
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
		if (buddyID < 0)
		{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ handler(-1); });
			return;
		}
		
		// Bind.
		sqlite3_bind_int64(_stmtInsertTranscript, 1, buddyID);
		sqlite3_bind_text(_stmtInsertTranscript, 2, message.message.UTF8String, -1, SQLITE_TRANSIENT);
		sqlite3_bind_int(_stmtInsertTranscript, 3, message.side);
		sqlite3_bind_double(_stmtInsertTranscript, 4, message.timestamp);
		
		if (message.error)
			sqlite3_bind_text(_stmtInsertTranscript, 5, message.error.UTF8String, -1, SQLITE_TRANSIENT);
		else
			sqlite3_bind_null(_stmtInsertTranscript, 5);

		// Execute.
		sqlite_int64 rowID = -1;
		
		if (sqlite3_step(_stmtInsertTranscript) == SQLITE_DONE)
			rowID = sqlite3_last_insert_rowid(_dtb);
			
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			handler(rowID);
		});
		
		// Reset.
		sqlite3_clear_bindings(_stmtInsertTranscript);
		sqlite3_reset(_stmtInsertTranscript);
	});
}

- (void)transcriptBuddiesIdentifiersWithCompletionHandler:(void (^)(NSArray *buddiesIdentifiers))handler
{
	if (!handler)
		return;
	
	NSMutableArray *identifiers = [[NSMutableArray alloc] init];
	
	dispatch_async(_localQueue, ^{
		
		// Check database.
		if (!_dtb)
		{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ handler(nil); });
			return;
		}

		// Fetch result.
		while (sqlite3_step(_stmtSelectIdentifiersTranscript) == SQLITE_ROW)
		{
			const char *identifier = (const char *)sqlite3_column_text(_stmtSelectIdentifiersTranscript, 0);
			
			if (!identifier)
				continue;
			
			[identifiers addObject:@(identifier)];
		}
		
		sqlite3_reset(_stmtSelectIdentifiersTranscript);
		
		// Give result.
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			handler(identifiers);
		});
	});
}

- (void)transcriptMessagesForBuddyIdentifier:(NSString *)identifier beforeMessageID:(NSNumber *)msgId limit:(NSUInteger)limit completionHandler:(void (^)(NSArray *messages))handler
{
	if (!identifier || !handler)
		return;
	
	dispatch_async(_localQueue, ^{
		
		// Check database.
		if (!_dtb)
		{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ handler(nil); });
			return;
		}
		
		// Search buddy.
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
		if (buddyID < 0)
		{
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ handler(nil); });
			return;
		}
		
		// Bind.
		sqlite3_bind_int64(_stmtSelectMsgTranscript, 1, buddyID);
		
		if (msgId)
			sqlite3_bind_int64(_stmtSelectMsgTranscript, 2, [msgId longLongValue]);
		else
			sqlite3_bind_int64(_stmtSelectMsgTranscript, 2, LONG_MAX);

		sqlite3_bind_int64(_stmtSelectMsgTranscript, 3, (sqlite3_int64)limit);

		// Execute.
		NSMutableArray *result = [[NSMutableArray alloc] init];

		while (sqlite3_step(_stmtSelectMsgTranscript) == SQLITE_ROW)
		{
			// > Get content.
			sqlite3_int64 msgID = sqlite3_column_int64(_stmtSelectMsgTranscript, 0);
			const char	*message = (const char *)sqlite3_column_text(_stmtSelectMsgTranscript, 1);
			int			side = sqlite3_column_int(_stmtSelectMsgTranscript, 2);
			double		timestamp = sqlite3_column_double(_stmtSelectMsgTranscript, 3);
			const char	*error = (const char *)sqlite3_column_text(_stmtSelectMsgTranscript, 4);

			if (!message)
				continue;
			
			// > Convert content.
			TCChatMessage *item = [[TCChatMessage alloc] init];
			
			item.messageID = msgID;
			item.message = @(message);
			item.side = (TCChatMessageSide)side;
			item.timestamp = timestamp;

			if (error)
				item.error = @(error);

			// > Insert content (we insert at 0 to reverse order).
			[result insertObject:item atIndex:0];
		}
		
		// Reset.
		sqlite3_clear_bindings(_stmtSelectMsgTranscript);
		sqlite3_reset(_stmtSelectMsgTranscript);
		
		// Give result.
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			handler(result);
		});
	});
}

- (void)transcriptRemoveMessagesForBuddyIdentifier:(NSString *)identifier
{
	if (!identifier)
		return;
	
	dispatch_async(_localQueue, ^{
		
		// Check database.
		if (!_dtb)
			return;
		
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];

		if (buddyID < 0)
			return;

		// Bind.
		sqlite3_bind_int64(_stmtDeleteIdentifierTranscript, 1, buddyID);
		
		// Execute.
		sqlite3_step(_stmtDeleteIdentifierTranscript);
		
		// Reset.
		sqlite3_reset(_stmtDeleteIdentifierTranscript);
	});
}

- (void)transcriptRemoveMessageForID:(int64_t)msgID
{
	dispatch_async(_localQueue, ^{
		
		if (!_dtb)
			return;
		
		// Bind.
		sqlite3_bind_int64(_stmtDeleteIdTranscript, 1, msgID);
		
		// Execute.
		sqlite3_step(_stmtDeleteIdTranscript);
		
		// Reset.
		sqlite3_reset(_stmtDeleteIdTranscript);
	});
}

- (BOOL)transcriptMessagesIDBoundariesForBuddyIdentifier:(NSString *)identifier firstMessageID:(int64_t *)firstID lastMessageID:(int64_t *)lastID
{
	__block BOOL result = NO;
	
	dispatch_sync(_localQueue, ^{
		
		sqlite3_int64 buddyID = [self _buddyIDForIdentifier:identifier];
		
		if (buddyID < 0)
			return;
		
		// Bind.
		sqlite3_bind_int64(_stmtSelectMinMaxIdTranscript, 1, buddyID);
		
		// Execute.
		if (sqlite3_step(_stmtSelectMinMaxIdTranscript) == SQLITE_ROW)
		{
			if (sqlite3_column_type(_stmtSelectMinMaxIdTranscript, 0) == SQLITE_INTEGER && sqlite3_column_type(_stmtSelectMinMaxIdTranscript, 1) == SQLITE_INTEGER)
			{
				if (firstID)
					*firstID = sqlite3_column_int64(_stmtSelectMinMaxIdTranscript, 0);
				
				if (lastID)
					*lastID = sqlite3_column_int64(_stmtSelectMinMaxIdTranscript, 1);
				
				result = YES;
			}
		}
		
		// Reset.
		sqlite3_reset(_stmtSelectMinMaxIdTranscript);
	});
	
	return result;
}



/*
** TCConfigSQLite - TCConfigEncryptable
*/
#pragma mark - TCConfigSQLite - TCConfigEncryptable

- (BOOL)isEncrypted
{
	__block BOOL result = NO;
	
	dispatch_sync(_localQueue, ^{
		result = (_dtbPassword != NULL);
	});
	
	return result;
}

- (void)changePassword:(NSString *)newPassword completionHandler:(void (^)(NSError *error))handler
{
	if (!handler)
		handler = ^(NSError *error) { };
	
	dispatch_async(_localQueue, ^{
		
		dispatch_queue_t	queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		NSError				*error = nil;
		
		if ([self _changePassword:newPassword error:&error])
		{
			dispatch_async(queue, ^{
				handler(nil);
			});
		}
		else
		{
			dispatch_async(queue, ^{
				handler(error);
			});
		}
	});
}

- (BOOL)_changePassword:(NSString *)newPassword error:(NSError **)error
{
	// > localQueue <
	
	if (!_dtb)
		return NO;
	
	if (_dtbPassword)
	{
		// Is encrypted + new password : change password.
		if (newPassword)
		{
			SMCryptoFileError	smError;
			BOOL				result;
			
			result = SMSQLiteCryptoVFSChangePassword(_dtb, newPassword.UTF8String, &smError);
			
			if (result == NO && error)
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSMCryptoFileErrorKey : @(smError) }];
			
			return result;
		}
		
		// Is encrypted + no new password  : deactivate encryption.
		else
		{
			NSFileManager	*mng = [NSFileManager defaultManager];
			NSString		*tpath = [_dtbPath stringByAppendingString:@"-tmp"];
			int				sres;
			
			sqlite3			*ndtb = NULL;
			sqlite3			*odtb = NULL;
			void			*odtbPassword = NULL;
			const char		*odtbUUID = NULL;
			
			sqlite3_backup	*backup = NULL;
			
			// Close database.
			[self _closeDatabase];
			
			// Move encrypted database to tmp base.
			if ([mng moveItemAtPath:_dtbPath toPath:tpath error:error] == NO)
				goto errDec;
			
			// Open encrypted moved database.
			const char *uriPath;
			
			odtbUUID = SMSQLiteCryptoVFSSettingsAdd(_dtbPassword, SMCryptoFileKeySize256);
			uriPath = [[NSString stringWithFormat:@"file://%@?crypto-uuid=%s", tpath, odtbUUID] UTF8String];
			
			sres = sqlite3_open_v2(uriPath, &odtb, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
			
			if (sres != SQLITE_OK)
			{
				if (error)
					*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(sres), TCConfigSMCryptoFileErrorKey : @(SMSQLiteCryptoVFSLastFileCryptoError()) }];
				goto errDec;
			}
			
			sqlite3_exec(odtb, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);
			
			// Open new clear database.
			sres = sqlite3_open_v2(_dtbPath.fileSystemRepresentation, &ndtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);
			
			if (sres != SQLITE_OK)
			{
				if (error)
					*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(sres) }];
				goto errDec;
			}
			
			sqlite3_exec(ndtb, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);
			
			
			// Create backup.
			backup = sqlite3_backup_init(ndtb, "main", odtb, "main");
			
			if (!backup)
			{
				if (error)
					*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"can't create backup object" }];
				goto errDec;
			}
			
			// Backup.
			sres = sqlite3_backup_step(backup, -1);
			
			if (sres != SQLITE_DONE)
			{
				if (error)
					*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(sres) }];
				goto errDec;
			}
			
			sqlite3_backup_finish(backup);
			backup = NULL;
			
			// Close databases.
			sqlite3_close(odtb);
			sqlite3_close(ndtb);
			
			odtb = NULL;
			ndtb = NULL;
			
			// Free UUID.
			SMSQLiteCryptoVFSSettingsRemove(odtbUUID);
			odtbUUID = NULL;
			
			// Move crypto info.
			odtbPassword = _dtbPassword;
			_dtbPassword = NULL;
			
			// Re-open database.
			if ([self _openDatabaseWithError:error] == NO)
				goto errDec;
			
			// Free password.
			vm_size_t hostPageSize = 0;
			
			if (host_page_size(mach_host_self(), &hostPageSize) != KERN_SUCCESS)
				hostPageSize = 4096;
			
			memset_s(odtbPassword, hostPageSize, 0, hostPageSize);
			munlock(odtbPassword, hostPageSize);
			free(odtbPassword);
			
			odtbPassword = NULL;
			
			// Remove old file.
			[mng removeItemAtPath:tpath error:error];
			
			// Everything is ok.
			return YES;
			
		errDec:
			
			if (backup)
				sqlite3_backup_finish(backup);
			
			// Close new)database.
			if (ndtb)
				sqlite3_close(ndtb);
			
			// Close old-database.
			if (odtb)
				sqlite3_close(odtb);
			
			// Remove crypto setting.
			if (odtbUUID)
			{
				SMSQLiteCryptoVFSSettingsRemove(odtbUUID);
				odtbUUID = NULL;
			}
			
			// Move back database.
			if ([mng fileExistsAtPath:tpath] && [mng fileExistsAtPath:_dtbPath])
			{
				[mng removeItemAtPath:_dtbPath error:nil];
				[mng moveItemAtPath:tpath toPath:_dtbPath error:nil];
			}
			
			// Re-set password.
			if (odtbPassword)
				_dtbPassword = odtbPassword;
			
			// Re-open database.
			if (!_dtb)
				[self _openDatabaseWithError:nil];
			
			return NO;
		}
	}
	else
	{
		// Is not encrypted + new password : activate encryption.
		if (newPassword)
		{
			NSFileManager	*mng = [NSFileManager defaultManager];
			NSString		*tpath = [_dtbPath stringByAppendingString:@"-tmp"];
			int				sres;
			
			void		*ndtbPassword = NULL;
			const char	*ndtbUUID = NULL;
			sqlite3		*ndtb = NULL;
			sqlite3		*odtb = NULL;
			
			sqlite3_backup *backup = NULL;
			
			// Copy password.
			vm_size_t hostPageSize = 0;
			
			if (host_page_size(mach_host_self(), &hostPageSize) != KERN_SUCCESS)
				hostPageSize = 4096;
			
			if (posix_memalign(&ndtbPassword, hostPageSize, hostPageSize) != 0)
			{
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"can't allocate password buffer" }];
				goto errEnc;
			}
			
			if (mlock(ndtbPassword, hostPageSize) != 0)
			{
				*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"can't mlock password buffer" }];
				goto errEnc;
			}
			
			strlcpy(ndtbPassword, newPassword.UTF8String, hostPageSize);
			
			// Close database.
			[self _closeDatabase];
			
			// Move clear database to tmp base.
			if ([mng moveItemAtPath:_dtbPath toPath:tpath error:error] == NO)
				goto errEnc;
			
			// Open moved clear database.
			sres = sqlite3_open_v2(tpath.fileSystemRepresentation, &odtb, SQLITE_OPEN_READONLY, NULL);
			
			if (sres != SQLITE_OK)
			{
				if (error)
					*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(sres) }];
				goto errEnc;
			}
			
			sqlite3_exec(odtb, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);
			
			
			// Open new encrypted database.
			const char *uriPath;
			
			ndtbUUID = SMSQLiteCryptoVFSSettingsAdd(ndtbPassword, SMCryptoFileKeySize256);
			uriPath = [[NSString stringWithFormat:@"file://%@?crypto-uuid=%s", _dtbPath, ndtbUUID] UTF8String];
			
			sres = sqlite3_open_v2(uriPath, &ndtb, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_URI, SMSQLiteCryptoVFSName());
			
			if (sres != SQLITE_OK)
			{
				if (error)
					*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(sres), TCConfigSMCryptoFileErrorKey : @(SMSQLiteCryptoVFSLastFileCryptoError()) }];
				goto errEnc;
			}
			
			sqlite3_exec(ndtb, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);
			
			// Create backup.
			backup = sqlite3_backup_init(ndtb, "main", odtb, "main");
			
			if (!backup)
			{
				if (error)
					*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ NSLocalizedDescriptionKey : @"can't create backup object" }];
				goto errEnc;
			}
			
			// Backup.
			sres = sqlite3_backup_step(backup, -1);
			
			if (sres != SQLITE_DONE)
			{
				if (error)
					*error = [NSError errorWithDomain:TCConfigSQLiteErrorDomain code:-1 userInfo:@{ TCConfigSQLiteErrorKey : @(sres) }];
				goto errEnc;
			}
			
			sqlite3_backup_finish(backup);
			backup = NULL;
			
			// Close databases.
			sqlite3_close(odtb);
			sqlite3_close(ndtb);
			
			odtb = NULL;
			ndtb = NULL;
			
			// Hold crypto info.
			_dtbPassword = ndtbPassword;
			_dtbUUID = ndtbUUID;
			
			// Re-open database.
			if ([self _openDatabaseWithError:error] == NO)
				goto errEnc;
			
			// Remove old clear file.
			TCFileSecureRemove(tpath);
			
			// Everything is ok.
			return YES;
			
		errEnc:
			
			// Free backup.
			if (backup)
				sqlite3_backup_finish(backup);
			
			// Close new-database.
			if (ndtb)
				sqlite3_close(ndtb);
			
			// Close old-database.
			if (odtb)
				sqlite3_close(odtb);
			
			// Free new-password.
			if (ndtbPassword)
			{
				memset_s(ndtbPassword, hostPageSize, 0, hostPageSize);
				munlock(ndtbPassword, hostPageSize);
				free(ndtbPassword);
				
				_dtbPassword = NULL;
			}
			
			// Remove new-setting.
			if (ndtbUUID)
			{
				SMSQLiteCryptoVFSSettingsRemove(ndtbUUID);
				_dtbUUID = NULL;
			}
			
			// Move back database.
			if ([mng fileExistsAtPath:tpath] && [mng fileExistsAtPath:_dtbPath])
			{
				[mng removeItemAtPath:_dtbPath error:nil];
				[mng moveItemAtPath:tpath toPath:_dtbPath error:nil];
			}
			
			// Re-open database.
			if (!_dtb)
				[self _openDatabaseWithError:nil];
			
			return NO;
		}
		
		// Is not encrypted + no new password : nop.
		else
		{
			// Nothing to do.
			return YES;
		}
	}
}

@end
