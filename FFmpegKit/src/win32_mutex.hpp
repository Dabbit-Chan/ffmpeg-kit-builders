/*
 * Copyright (c) 2025 Akash Patel
 *
 * This file is part of FFmpegKit.
 *
 * FFmpegKit is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FFmpegKit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with FFmpegKit.  If not, see <http://www.gnu.org/licenses/>.
 */

#pragma once
#ifdef _WIN32
#include <windows.h>

class Win32RecursiveMutex {
    CRITICAL_SECTION cs_;
public:
    Win32RecursiveMutex()  { InitializeCriticalSection(&cs_); }
    ~Win32RecursiveMutex() { DeleteCriticalSection(&cs_); }
    void lock()            { EnterCriticalSection(&cs_); }
    void unlock()          { LeaveCriticalSection(&cs_); }
    bool try_lock()        { return TryEnterCriticalSection(&cs_) != 0; }
};
using KitMutex = Win32RecursiveMutex;

#else
#include <mutex>
using KitMutex = std::recursive_mutex;
#endif