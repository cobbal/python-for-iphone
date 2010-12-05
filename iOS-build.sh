#!/bin/zsh
set -o errexit

# credit to:
# http://randomsplat.com/id5-cross-compiling-python-for-embedded-linux.html
# http://latenitesoft.blogspot.com/2008/10/iphone-programming-tips-building-unix.html

# download python and patch if they aren't there
if [[ ! -a Python-2.6.5.tar.bz2 ]]; then
    curl http://www.python.org/ftp/python/2.6.5/Python-2.6.5.tar.bz2 > Python-2.6.5.tar.bz2
fi

# get rid of old build
rm -rf Python-2.6.5

# build for native machine
tar -xjf Python-2.6.5.tar.bz2
pushd ./Python-2.6.5
CC="clang -m32" ./configure
make python.exe Parser/pgen
mv python.exe hostpython
mv Parser/pgen Parser/hostpgen
mv libpython2.6.a hostlibpython2.6.a
make distclean

# patch python to cross-compile
patch -p1 < ../Python-2.6.5-xcompile.patch

#set up environment variables for cross compilation
export DEVROOT="/Developer/Platforms/iPhoneOS.platform/Developer"
export SDKROOT="$DEVROOT/SDKs/iPhoneOS4.0.sdk"
export CPPFLAGS="-I$SDKROOT/usr/lib/gcc/arm-apple-darwin10/4.2.1/include/ -I$SDKROOT/usr/include/"
export CFLAGS="$CPPFLAGS -pipe -no-cpp-precomp -isysroot $SDKROOT"
export LDFLAGS="-isysroot $SDKROOT -Lextralibs/"
export CPP="/usr/bin/cpp $CPPFLAGS"

# make a link to a differently named library for who knows what reason
mkdir extralibs
ln -s "$SDKROOT/usr/lib/libgcc_s.1.dylib" extralibs/libgcc_s.10.4.dylib

# build for iPhone
./configure CC="$DEVROOT/usr/bin/arm-apple-darwin10-llvm-gcc-4.2" \
            LD="$DEVROOT/usr/bin/ld" --host=armv6-apple-darwin --prefix=/python

# comment out lines that break build (ugly hack)
sed -i.bak -e 's/MACHDEP_OBJS=/#&/' -e 's/LINKFORSHARED=/#&/' Makefile

make HOSTPYTHON=./hostpython HOSTPGEN=./Parser/hostpgen \
     CROSS_COMPILE_TARGET=yes

make install HOSTPYTHON=./hostpython CROSS_COMPILE_TARGET=yes prefix="$PWD/_install"

# package library files
pushd _install/lib/python2.6
zip -r -y python26.zip .
popd
pushd _install/lib
mv libpython2.6.a libpython2.6-arm.a
lipo -create -output libpython2.6.a ../../hostlibpython2.6.a libpython2.6-arm.a
