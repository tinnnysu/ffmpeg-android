#!/bin/bash

###############################################################################
#
# This script will build FFMPEG for android.
#
# Prerequisits:
#   - FFMPEG source checked out / copied to FFmpeg subfolder.
#
# Build steps:
#   - Patch the FFMPEG configure script to fix missing support for shared
#     library versioning on android.
#   - Configure FFMPEG
#   - Build FFMPEG
# Requirement:
#   - make
#   - patch
#   - bash
#   - diffutils
#
###############################################################################
SCRIPT=$(readlink -f $0)
BASE=$(dirname $SCRIPT)
NPROC=$(grep -c ^processor /proc/cpuinfo)


###############################################################################
#
# Argument parsing.
#  Allow some components to be overwritten by command line arguments.
#
###############################################################################
if [ -z $HOST_ARCH]; then
  HOST_ARCH=$(uname -m)
fi

if [ -z $PLATFORM ]; then
  PLATFORM=14
fi

if [ -z $MAKE_OPTS ]; then
  MAKE_OPTS="-j$(($NPROC+1))"
fi

function usage
{
  echo "$0 [-a <ndk>] [-h <host arch>] [-m <make opts>] [-p <android platform>]"
  echo -e "\tdefaults:"
  echo -e "\tHOST_ARCH=$HOST_ARCH"
  echo -e "\tPLATFORM=$PLATFORM"
  echo -e "\tMAKE_OPTS=$MAKE_OPTS"
  echo -e "\tANDROID_NDK must be set manually."
  echo ""
  echo -e "\tAll arguments can also be set as environment variables."
  exit -3
}

while getopts "a:h:m:p:" opt; do
  case $opt in
    a)
      ANDROID_NDK=$OPTARG
      ;;
    h)
      HOST_ARCH=$OPTARG
      ;;
    m)
      MAKE_OPTS=$OPTARG
      ;;
    p)
      PLATFORM=$OPTARG
      ;;
    \?)
      echo "Invalid option $OPTARG" >&2
      usage
      ;;
  esac
done

if [ -z $HOST_ARCH ]; then
  HOST_ARCH=$(uname -m)
fi

if [ -z $PLATFORM ]; then
  PLATFORM=14
fi

if [ -z $MAKE_OPTS ]; then
  MAKE_OPTS="-j3"
fi

if [ -z $ANDROID_NDK ]; then
  echo "ANDROID_NDK not set. Set it to the directory of your NDK installation."
  exit -1
fi
if [ ! -d $BASE/FFmpeg ]; then
  echo "Please copy or check out FFMPEG source to folder FFmpeg!"
  exit -2
fi

echo "Building with:"
echo "HOST_ARCH=$HOST_ARCH"
echo "PLATFORM=$PLATFORM"
echo "MAKE_OPTS=$MAKE_OPTS"
echo "ANDROID_NDK=$ANDROID_NDK"

cd $BASE/FFmpeg

## Save original configuration file
## or restore original before applying patches.
if [ ! -f configure.bak ]; then
  echo "Saving original configure file to configure.bak"
  cp configure configure.bak
else
  echo "Restoring original configure file from configure.bak"
  cp configure.bak configure
fi

patch -p1 < $BASE/patches/configure.patch

#if [ ! -f library.mak.bak ]; then
#  echo "Saving original library.mak file to library.mak.bak"
#  cp library.mak library.mak.bak
#else
#  echo "Restoring original library.mak file from library.mak.bak"
#  cp library.mak.bak library.mak
#fi
#
#patch -p1 < $BASE/patches/library.mak.patch

# Remove old build and installation files.
if [ -d $BASE/output ]; then
  rm -rf $BASE/output
fi
if [ -d $BASE/build ]; then
  rm -rf $BASE/build
fi

###############################################################################
#
# build_one ... builds FFMPEG with provided arguments.
#
# Calling convention:
#
# build_one <PREFIX> <CROSS_PREFIX> <ARCH> <SYSROOT> <CFLAGS> <LDFLAGS> <EXTRA>
#
#  PREFIX       ... Installation directory
#  CROSS_PREFIX ... Full path with toolchain prefix
#  ARCH         ... Architecture to build for (arm, x86, mips)
#  SYSROOT      ... Android platform to build for, full path.
#  CFLAGS       ... Additional CFLAGS for building.
#  LDFLAGS      ... Additional LDFLAGS for linking
#  EXTRA        ... Any additional configuration flags, e.g. --cpu=XXX
#
###############################################################################
function build_one
{
  mkdir -p $1
  cd $1

  $BASE/FFmpeg/configure \
      --prefix=$2 \
      --enable-shared \
      --enable-pic \
      --enable-runtime-cpudetect \
      --enable-cross-compile \
      --disable-symver \
      --disable-static \
      --disable-programs \
      --disable-avdevice \
      --disable-doc \
      --cross-prefix=$3 \
      --target-os=linux \
      --arch=$4 \
      --sysroot=$5 \
      --extra-cflags="-Os $6" \
      --extra-ldflags="$7" \
      --disable-linux-perf \
      $8

  make clean
  make $MAKE_OPTS
  make install
}

NDK=$ANDROID_NDK

###############################################################################
#
# x86 build configuration
#
###############################################################################
PREFIX=$BASE/output/x86
BUILD_ROOT=$BASE/build/x86
SYSROOT=$NDK/platforms/android-$PLATFORM/arch-x86/
TOOLCHAIN=$NDK/toolchains/x86-4.8/prebuilt/linux-$HOST_ARCH
CROSS_PREFIX=$TOOLCHAIN/bin/i686-linux-android-
ARCH=x86
E_CFLAGS=
E_LDFLAGS=
EXTRA="--disable-asm"

build_one "$BUILD_ROOT" "$PREFIX" "$CROSS_PREFIX" "$ARCH" "$SYSROOT" \
    "$E_CFLAGS" "$E_LDFLAGS" "$EXTRA"

###############################################################################
#
# ARM build configuration
#
###############################################################################
PREFIX=$BASE/output/armeabi
BUILD_ROOT=$BASE/build/armeabi
SYSROOT=$NDK/platforms/android-$PLATFORM/arch-arm/
TOOLCHAIN=$NDK/toolchains/arm-linux-androideabi-4.8/prebuilt/linux-$HOST_ARCH
CROSS_PREFIX=$TOOLCHAIN/bin/arm-linux-androideabi-
ARCH=arm
E_CFLAGS=
E_LDFLAGS=
EXTRA=

build_one "$BUILD_ROOT" "$PREFIX" "$CROSS_PREFIX" "$ARCH" "$SYSROOT" \
    "$E_CFLAGS" "$E_LDFLAGS" "$EXTRA"

###############################################################################
#
# ARM-v7a build configuration
#
###############################################################################
PREFIX=$BASE/output/armeabi-v7a
BUILD_ROOT=$BASE/build/armeabi-v7a
SYSROOT=$NDK/platforms/android-$PLATFORM/arch-arm/
TOOLCHAIN=$NDK/toolchains/arm-linux-androideabi-4.8/prebuilt/linux-$HOST_ARCH
CROSS_PREFIX=$TOOLCHAIN/bin/arm-linux-androideabi-
ARCH=arm
E_CFLAGS="-march=armv7-a -mfloat-abi=softfp"
E_LDFLAGS=
EXTRA=

build_one "$BUILD_ROOT" "$PREFIX" "$CROSS_PREFIX" "$ARCH" "$SYSROOT" \
    "$E_CFLAGS" "$E_LDFLAGS" "$EXTRA"

###############################################################################
#
# MIPS build configuration
#
###############################################################################
##PREFIX=$BASE/output/mips
##BUILD_ROOT=$BASE/build/mips
##SYSROOT=$NDK/platforms/android-$PLATFORM/arch-mips/
##TOOLCHAIN=$NDK/toolchains/mipsel-linux-android-4.8/prebuilt/linux-$HOST_ARCH
##CROSS_PREFIX=$TOOLCHAIN/bin/mipsel-linux-android-
##ARCH=mips32
##E_CFLAGS=
##E_LDFLAGS=
##EXTRA=""
##
##build_one "$BUILD_ROOT" "$PREFIX" "$CROSS_PREFIX" "$ARCH" "$SYSROOT" \
##    "$E_CFLAGS" "$E_LDFLAGS" "$EXTRA"
##
