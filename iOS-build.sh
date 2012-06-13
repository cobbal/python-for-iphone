#!/bin/zsh
set -o errexit

# credit to:
# http://randomsplat.com/id5-cross-compiling-python-for-embedded-linux.html
# http://latenitesoft.blogspot.com/2008/10/iphone-programming-tips-building-unix.html

export MIN_IOS_VERSION="5.0"

# download python if it isn't there
if [[ ! -a Python-2.6.5.tar.bz2 ]]; then
    curl http://www.python.org/ftp/python/2.6.5/Python-2.6.5.tar.bz2 > Python-2.6.5.tar.bz2
fi

# get rid of old build
rm -rf Python-2.6.5

# build for native machine
tar -xjf Python-2.6.5.tar.bz2
pushd ./Python-2.6.5

./configure CC="xcrun clang"
xcrun make -j 3 python.exe Parser/pgen

mv python.exe hostpython
mv Parser/pgen Parser/hostpgen

xcrun make distclean

# patch python to cross-compile
patch -p1 < ../Python-2.6.5-xcompile.patch

# set up environment variables for simulator compilation
export SDK="iphonesimulator"
export SDKROOT=$(xcodebuild -version -sdk "$SDK" Path)
export IOS_COMPILER=$(xcrun -find -sdk "$SDK" llvm-gcc)
export LD=$(xcrun -find -sdk "$SDK" ld)

export CPPFLAGS="-I$SDKROOT/usr/lib/gcc/arm-apple-darwin11/4.2.1/include/ -I$SDKROOT/usr/include/"
export CFLAGS="$CPPFLAGS -m32 -pipe -no-cpp-precomp -isysroot $SDKROOT -miphoneos-version-min=$MIN_IOS_VERSION"
export LDFLAGS="-isysroot $SDKROOT -static-libgcc -miphoneos-version-min=$MIN_IOS_VERSION"
export CPP="/usr/bin/cpp $CPPFLAGS"

# build for iPhone Simulator
./configure CC="$IOS_COMPILER $CFLAGS" \
            --disable-toolbox-glue \
            --host=i386-apple-darwin

xcrun make -j 3 HOSTPYTHON=./hostpython HOSTPGEN=./Parser/hostpgen \
     CROSS_COMPILE_TARGET=yes

mv libpython2.6.a libpython2.6-i386.a

xcrun make distclean

# set up environment variables for cross compilation
export SDK="iphoneos"
export SDKROOT=$(xcodebuild -version -sdk "$SDK" Path)
export IOS_COMPILER=$(xcrun -find -sdk "$SDK" llvm-gcc)
export LD=$(xcrun -find -sdk "$SDK" ld)

if [ ! -d "$SDKROOT" ]; then
    echo "SDKROOT doesn't exist. SDKROOT=$SDKROOT"
    exit 1
fi

if [ ! -f "$IOS_COMPILER" ]; then
    echo "Error: compiler not found at $IOS_COMPILER"
    exit 1
fi

export CPPFLAGS="-I$SDKROOT/usr/lib/gcc/arm-apple-darwin11/4.2.1/include/ -I$SDKROOT/usr/include/"
export CFLAGS="$CPPFLAGS -pipe -no-cpp-precomp -isysroot $SDKROOT -miphoneos-version-min=$MIN_IOS_VERSION -arch armv6 -arch armv7"
export LDFLAGS="-isysroot $SDKROOT -static-libgcc -miphoneos-version-min=$MIN_IOS_VERSION -arch armv6 -arch armv7"
export CPP="/usr/bin/cpp $CPPFLAGS"

# build for iPhone
./configure CC="$IOS_COMPILER $CFLAGS" \
            --disable-toolbox-glue \
            --host=arm-apple-darwin

make -j 3 HOSTPYTHON=./hostpython HOSTPGEN=./Parser/hostpgen \
    CROSS_COMPILE_TARGET=yes

make install HOSTPYTHON=./hostpython CROSS_COMPILE_TARGET=yes prefix="$PWD/_install"

pushd _install/lib
mv libpython2.6.a libpython2.6-arm.a
lipo -create -output libpython2.6.a ../../libpython2.6-i386.a libpython2.6-arm.a
