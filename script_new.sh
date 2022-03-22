#!/bin/bash

# Only tested on Ubuntu 17.10 x64 (This is because CMAKE Package 3.6 is required for Build OpenALPR Android Script)

########################################################################################################
# Script pieced together and tested by Kevin J. Petersen (Github: https://github.com/kevinjpetersen) ###
########################################################################################################

## Scripts used ##
# ubuntu-cli-install-android-sdk.sh by zhy0 (Github: https://github.com/zhy0)
# build_openalpr_android.sh by jav974 (Github: https://github.com/jav974)

# Steps:
# 1. Install CMAKE
# 2. Install OpenJDK
# 3. Run Android SDK and NDK with Script
# 4. Run Build OpenALPR Android Script

# Settings (Variables that need to be setuo)
SCRIPT=`realpath $0`
SCRIPTPATH=`dirname $SCRIPT`

# Cleans up if files already exists
rm -rf openalpr || true
rm -rf OpenCV-android-sdk || true
rm -rf tess2 || true
rm -rf android-sdk-linux || true
rm -rf android-ndk-r16b || true
rm -rf android-ndk-r16b-linux-x86_64.zip || true
rm -rf android-sdk_r24.4.1-linux.tgz || true

# Install CMAKE
sudo apt-get install cmake

# Install OpenJDK

sudo add-apt-repository ppa:openjdk-r/ppa
sudo apt-get update
sudo apt-get install openjdk-8-jdk

export PATH=$PATH:/usr/lib/jvm/java-8-openjdk-amd64/bin

# Install Android SDK Script

# Thanks to https://gist.github.com/wenzhixin/43cf3ce909c24948c6e7
# Execute this script in your home directory. Lines 17 and 21 will prompt you for a y/n

# Install Oracle JDK 8
add-apt-repository ppa:webupd8team/java
apt-get update
apt-get install -y oracle-java8-installer
apt-get install -y unzip make # NDK stuff

# Get SDK tools (link from https://developer.android.com/studio/index.html#downloads)
wget https://dl.google.com/android/android-sdk_r24.4.1-linux.tgz
tar xf android-sdk*-linux.tgz

# Get NDK (https://developer.android.com/ndk/downloads/index.html)
wget https://dl.google.com/android/repository/android-ndk-r16b-linux-x86_64.zip
unzip android-ndk*.zip

# Let it update itself and install some stuff
# Download every build-tools version that has ever existed
# This will save you time! Thank me later for this
cd android-sdk-linux/tools
./android update sdk --no-ui --all --filter 1,2,3,4,5,6,7,43,44,45,46,47,48,49

# If you need additional packages for your app, check available packages with:
# ./android list sdk --all

# install certain packages with:
# ./android update sdk --no-ui --all --filter 1,2,3,<...>,N
# where N is the number of the package in the list (see previous command)


# Add the directory containing executables in PATH so that they can be found
echo 'export ANDROID_HOME=$HOME/android-sdk-linux' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools' >> ~/.bashrc

source ~/.bashrc
echo y | sudo sdk manager --sdk_root=$ANDROID_HOME --licenses

# Make sure you can execute 32 bit executables if this is 64 bit machine, otherwise skip this
sudo dpkg --add-architecture i386
sudo apt-get update
sudo apt-get install -y libc6:i386 libstdc++6:i386 zlib1g:i386

# Add some swap space, useful if you've got less than 2G of RAM
sudo fallocate -l 2G /swapfile 
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Optionally run build system as daemon (speeds up build process)
mkdir ~/.gradle
echo 'org.gradle.daemon=true' >> ~/.gradle/gradle.properties
# See here: https://www.timroes.de/2013/09/12/speed-up-gradle/


# Build OpenALPR Android Script

#!/bin/bash

cd $SCRIPTPATH

# You should tweak this section to adapt the paths to your need
export ANDROID_HOME=$SCRIPTPATH/android-sdk-linux
export NDK_ROOT=$SCRIPTPATH/android-ndk-r16b

ANDROID_PLATFORM="android-21"

# In my case, FindJNI.cmake does not find java, so i had to manually specify these
# You could try without it and remove the cmake variable specification at the bottom of this file
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
JAVA_AWT_LIBRARY=$JAVA_HOME/jre/lib/amd64
JAVA_JVM_LIBRARY=$JAVA_HOME/jre/lib/amd64
JAVA_INCLUDE_PATH=$JAVA_HOME/include
JAVA_INCLUDE_PATH2=$JAVA_HOME/include/linux
JAVA_AWT_INCLUDE_PATH=$JAVA_HOME/include



####################################################################
# Prepare Tesseract and Leptonica, using rmtheis/tess-two repository
####################################################################


git clone --recursive https://github.com/rmtheis/tess-two.git tess2

cd tess2
echo "sdk.dir=$ANDROID_HOME
ndk.dir=$NDK_ROOT" > local.properties
./gradlew assemble
cd ..


####################################################################
# Download and extract OpenCV4Android
####################################################################

wget -O opencv-3.2.0-android-sdk.zip -- https://sourceforge.net/projects/opencvlibrary/files/opencv-android/3.2.0/opencv-3.2.0-android-sdk.zip/download 
unzip opencv-3.2.0-android-sdk.zip
rm opencv-3.2.0-android-sdk.zip

####################################################################
# Download and configure openalpr from jav974/openalpr forked repo
####################################################################

git clone https://github.com/kevinjpetersen/openalpr.git openalpr
mkdir openalpr/android-build

TESSERACT_SRC_DIR=$SCRIPTPATH/tess2/tess-two/jni/com_googlecode_tesseract_android/src

rm -rf openalpr/src/openalpr/ocr/tesseract
mkdir openalpr/src/openalpr/ocr/tesseract
shopt -s globstar
cd $TESSERACT_SRC_DIR

cp **/*.h $SCRIPTPATH/openalpr/src/openalpr/ocr/tesseract

cd $SCRIPTPATH

declare -a ANDROID_ABIS=("armeabi-v7a"
			 "arm64-v8a"
			 "x86"
			 "x86_64"
			)

cd openalpr/android-build

for i in "${ANDROID_ABIS[@]}"
do
    if [ "$i" == "armeabi-v7a with NEON" ]; then abi="armeabi-v7a"; else abi="$i"; fi
    TESSERACT_LIB_DIR=$SCRIPTPATH/tess2/tess-two/libs/$abi

    if [[ "$i" == armeabi* ]];
    then
	arch="arm"
	lib="lib"
    elif [[ "$i" == arm64-v8a ]];
    then
	arch="arm64"
	lib="lib"
    elif [[ "$i" == mips ]] || [[ "$i" == x86 ]];
    then
	arch="$i"
	lib="lib"
    elif [[ "$i" == mips64 ]] || [[ "$i" == x86_64 ]];
    then
	arch="$i"
	lib="lib64"
    fi
    
    echo "
######################################
Generating project for arch $i
######################################
"
    rm -rf "$i" && mkdir "$i"
    cd "$i"
    
    cmake \
	-DANDROID_TOOLCHAIN=clang \
	-DCMAKE_TOOLCHAIN_FILE=$NDK_ROOT/build/cmake/android.toolchain.cmake \
	-DANDROID_NDK=$NDK_ROOT \
	-DCMAKE_BUILD_TYPE=Release \
	-DANDROID_PLATFORM=$ANDROID_PLATFORM \
	-DANDROID_ABI="$i" \
	-DANDROID_STL=gnustl_static \
	-DANDROID_CPP_FEATURES="rtti exceptions" \
	-DTesseract_INCLUDE_BASEAPI_DIR=$TESSERACT_SRC_DIR/api \
	-DTesseract_INCLUDE_CCSTRUCT_DIR=$TESSERACT_SRC_DIR/ccstruct \
	-DTesseract_INCLUDE_CCMAIN_DIR=$TESSERACT_SRC_DIR/ccmain \
	-DTesseract_INCLUDE_CCUTIL_DIR=$TESSERACT_SRC_DIR/ccutil \
	-DTesseract_LIB=$TESSERACT_LIB_DIR/libtess.so \
	-DLeptonica_LIB=$TESSERACT_LIB_DIR/liblept.so \
	-DOpenCV_DIR=$SCRIPTPATH/OpenCV-android-sdk/sdk/native/jni \
	-DJAVA_AWT_LIBRARY=$JAVA_AWT_LIBRARY \
	-DJAVA_JVM_LIBRARY=$JAVA_JVM_LIBRARY \
	-DJAVA_INCLUDE_PATH=$JAVA_INCLUDE_PATH \
	-DJAVA_INCLUDE_PATH2=$JAVA_INCLUDE_PATH2 \
	-DJAVA_AWT_INCLUDE_PATH=$JAVA_AWT_INCLUDE_PATH \
	-DPngt_LIB=$TESSERACT_LIB_DIR/libpngt.so \
	-DJpgt_LIB=$TESSERACT_LIB_DIR/libjpgt.so \
	-DJnigraphics_LIB=$NDK_ROOT/platforms/$ANDROID_PLATFORM/arch-$arch/usr/$lib/libjnigraphics.so \
	-DANDROID_ARM_MODE=arm \
	../../src/

    cmake --build . -- -j 8
    
    cd ..
done

echo "Everything is done! You're welcome!"
