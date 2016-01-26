/*
 *  This file is part of Netsukuku.
 *  Copyright (C) 2016 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 *
 *  Netsukuku is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Netsukuku is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Netsukuku.  If not, see <http://www.gnu.org/licenses/>.
 */

/* addendum to posix.vapi
 */
namespace Posix {
	[CCode (cheader_filename = "sys/socket.h")]
	public const int SOL_SOCKET;
	[CCode (cheader_filename = "sys/socket.h")]
	public const int SO_BROADCAST;
	[CCode (cheader_filename = "sys/socket.h")]
	public const int SO_BINDTODEVICE;
}
