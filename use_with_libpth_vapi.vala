/*
 * libpth.vapi - Vala bindings for GNU Pth
 * Copyright (c) 2011 Luca Dionisi aka lukisi <luca.dionisi@gmail.com>
 * License: GNU LGPL v3 as published by the Free Software Foundation
 */

[CCode (has_target = false)]
public delegate void * FunctionDelegate (void* user_data);

[CCode (has_target = false)]
public delegate void FunctionDelegateV (void* user_data);

