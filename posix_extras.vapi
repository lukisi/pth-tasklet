/* addendum to posix.vapi
 *
 * Copyright (c) 2011 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 * License: GNU LGPL v3 as published by the Free Software Foundation
 *
 */
namespace Posix {
	[CCode (cheader_filename = "sys/socket.h")]
	public const int SOL_SOCKET;
	[CCode (cheader_filename = "sys/socket.h")]
	public const int SO_BROADCAST;
	[CCode (cheader_filename = "sys/socket.h")]
	public const int SO_BINDTODEVICE;
}
