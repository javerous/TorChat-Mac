/*
 *  TCTools.h
 *
 *  Copyright 2010 Avérous Julien-Pierre
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



#ifndef _TCTOOLS_H_
# define _TCTOOLS_H_

#include <string>
#include <vector>


// == Network ==
bool						doAsyncSocket(int sock);

// == Strings ==
std::vector<std::string> *	createExplode(const std::string &s, const std::string &e);

std::string *				createJoin(const std::vector<std::string> &items, const std::string &glue);
std::string *				createJoin(const std::vector<std::string> &items, size_t start, const std::string &glue);

std::string *				createReplaceAll(const std::string &s, const std::string &o, const std::string &r);

// == Data ==
ssize_t						memsearch(const uint8_t *token, size_t token_sz, const uint8_t *data, size_t data_sz);

// == Hash ==
std::string *				createMD5(const void *data, size_t size);

// == Encode ==
std::string *				createEncodeBase64(const void *data, size_t size);
bool						createDecodeBase64(const std::string &data, size_t *osize, void **odata);

#endif
