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