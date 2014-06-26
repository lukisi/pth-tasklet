/*
 * libpth.vapi - Vala bindings for GNU Pth
 * Copyright (c) 2011 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 * License: GNU LGPL v3 as published by the Free Software Foundation
 */

[CCode (has_target = false)]
public delegate void * Native.LibPth.Spawnable (void* user_data);

