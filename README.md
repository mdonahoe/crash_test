Spent all day investigating this bug, and my colleagues are saying it looks like a linker or library bug. I've never had anything like that before, so I am here to document it and ask for help!

My executable segfaults before main is called

    Program received signal SIGSEGV, Segmentation fault.
    0x0000000000000000 in ?? ()
    (gdb) bt
    #0  0x0000000000000000 in ?? ()
    #1  0x00007ffff7b47901 in ?? () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #2  0x00007ffff7b47943 in std::locale::locale() () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #3  0x00007ffff7b44724 in std::ios_base::Init::Init() () from /usr/lib/x86_64-linux-gnu/libstdc++.so.6
    #4  0x0000000000400c1c in __static_initialization_and_destruction_0 (__initialize_p=1, __priority=65535)
        at /usr/include/c++/4.8/iostream:74
    #5  0x0000000000400c45 in _GLOBAL__sub_I__ZN9CrashTestC2Ev () at crash_test.cc:8
    #6  0x0000000000400c9d in __libc_csu_init ()
    #7  0x00007ffff7512e55 in __libc_start_main (main=0x400bea <main()>, argc=1, argv=0x7fffffffdca8, 
        init=0x400c50 <__libc_csu_init>, fini=<optimized out>, rtld_fini=<optimized out>, stack_end=0x7fffffffdc98)
        at libc-start.c:246
    #8  0x0000000000400ad9 in _start ()
    (gdb) 

The resulting crash seems similar to [this question][1] which leads to [this bug report][2], but my code is different and very sensitive to changes. I narrowed down the issue to 5 requirements:

1. Have an class implemented in a shared library.
2. Declare an instance of that class in another, immediately following  a std::string member declaration.
3. Include iostream
4. Link with pthreads
5. Use g++-4.8 (or 4.9) and the [gold linker][3]

That's it. Change or omit any requirement, and the segfault does not occur.

I've created a minimal test case. Here is the executable header

    // crash_test.h
    #pragma once
    #include <string>
    #include "crash.h"
    
    class CrashTest {
      CrashTest();  // must have a constructor
    
      std::string first_;  // must be a string declared before Crash object
      Crash crash_;  // must be a value, not pointer
    };

And the main function is empty. I don't even construct the class I defined!

    #include "crash_test.h"
    #include <iostream>  // required
    
    CrashTest::CrashTest() { }  // must be here, not header
    
    int main() {
      return 0;
    }

The Crash class can't get much simpler

    // crash.h
    #pragma once
    struct Crash {
      Crash();
    };

But it does require an implementation to create a shared library.


    #include "crash.h"
    Crash::Crash() {}  // must be here, not header



I've also tested this in a Docker container on a fresh install of Ubuntu 14.04, with g++-4.8 installed via apt-get.

Here is the build script.

    #! /bin/sh
    COMPILE="/usr/bin/x86_64-linux-gnu-g++-4.8 -Wall -Wextra -Wno-sign-compare -Wno-unused-parameter -Wno-missing-field-initializers -Werror -std=c++11 -O0 -g "
    
    # Segfault only occurs using the gold linker.
    LINKER="-fuse-ld=gold"
    
    # Compile a shared library and then an executable.
    # If the latter is linked with pthread, it segfaults when run.
    # If the shared library is removed, there is no segfault.
    $COMPILE -fPIC -o crash.o -c crash.cc \
    && $COMPILE -o crash_test.o -c crash_test.cc \
    && $COMPILE -fPIC $LINKER -shared -Wl,-soname,libcrash.so -o libcrash.so crash.o -Wl,-rpath=. \
    && $COMPILE $LINKER crash_test.o -o crash_test -rdynamic libcrash.so -pthread -Wl,-rpath=. \
    && echo "Compiled and linked..." \
    && ./crash_test \
    && echo "Did not crash!"


Advice appreciated!


  [1]: http://stackoverflow.com/questions/29786161/why-does-linking-with-pthread-cause-a-segmentation-fault
  [2]: https://sourceware.org/bugzilla/show_bug.cgi?id=16417
  [3]: https://en.wikipedia.org/wiki/Gold_(linker)
