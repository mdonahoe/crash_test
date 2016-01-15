#! /bin/sh

# Using gcc 4.9 also crashes.
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
# Running the executable crashes immediately with SIGSEGV
