#!/usr/bin/env bash
#
# This script builds the solidity binary using emscripten.
# Emscripten is a way to compile C/C++ to JavaScript.
#
# First run install_dependencies.sh OUTSIDE of docker and then
# run this script inside a docker image trzeci/emscripten

set -ev

if [ -z ${WORKSPACE} ]
then
	WORKSPACE=$(pwd)
fi
export WORKSPACE

# CryptoPP
cd "$WORKSPACE/cryptopp"
emcmake cmake -DCRYPTOPP_LIBRARY_TYPE=STATIC -DCRYPTOPP_RUNTIME_TYPE=STATIC && emmake make -j 4
ln -s . src/cryptopp || true
rm -rf .git

# Json-CPP
cd "$WORKSPACE/jsoncpp"
emcmake cmake -DJSONCPP_LIB_BUILD_STATIC=ON -DJSONCPP_LIB_BUILD_SHARED=OFF \
              -DJSONCPP_WITH_TESTS=OFF -DJSONCPP_WITH_POST_BUILD_UNITTEST=OFF \
              -G "Unix Makefiles" .
emmake make -j 4
rm -rf .git

# Boost
cd "$WORKSPACE"/boost_1_57_0
# if b2 exists, it is a fresh checkout, otherwise it comes from the cache
# and is already compiled
test -x b2 && (
sed -i 's|using gcc ;|using gcc : : /usr/local/bin/em++ ;|g' ./project-config.jam
sed -i 's|$(archiver\[1\])|/usr/local/bin/emar|g' ./tools/build/src/tools/gcc.jam
sed -i 's|$(ranlib\[1\])|/usr/local/bin/emranlib|g' ./tools/build/src/tools/gcc.jam
./b2 link=static variant=release threading=single runtime-link=static \
       thread system regex date_time chrono filesystem unit_test_framework program_options random
find . -name 'libboost*.a' -exec cp {} . \;
rm -rf b2 libs doc tools more bin.v2 status
)

# Build dependent components and solidity itself
for component in webthree-helpers/utils libweb3core solidity
do
cd "$WORKSPACE/$component"
mkdir build || true
cd build
emcmake cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DEMSCRIPTEN=1 \
  -DCMAKE_CXX_COMPILER=em++ \
  -DCMAKE_C_COMPILER=emcc \
  -DBoost_FOUND=1 \
  -DBoost_USE_STATIC_LIBS=1 \
  -DBoost_USE_STATIC_RUNTIME=1 \
  -DBoost_INCLUDE_DIR="$WORKSPACE"/boost_1_57_0/ \
  -DBoost_CHRONO_LIBRARY="$WORKSPACE"/boost_1_57_0/libboost_chrono.a \
  -DBoost_CHRONO_LIBRARIES="$WORKSPACE"/boost_1_57_0/libboost_chrono.a \
  -DBoost_DATE_TIME_LIBRARY="$WORKSPACE"/boost_1_57_0/libboost_date_time.a \
  -DBoost_DATE_TIME_LIBRARIES="$WORKSPACE"/boost_1_57_0/libboost_date_time.a \
  -DBoost_FILESYSTEM_LIBRARY="$WORKSPACE"/boost_1_57_0/libboost_filesystem.a \
  -DBoost_FILESYSTEM_LIBRARIES="$WORKSPACE"/boost_1_57_0/libboost_filesystem.a \
  -DBoost_PROGRAM_OPTIONS_LIBRARY="$WORKSPACE"/boost_1_57_0/libboost_program_options.a \
  -DBoost_PROGRAM_OPTIONS_LIBRARIES="$WORKSPACE"/boost_1_57_0/libboost_program_options.a \
  -DBoost_RANDOM_LIBRARY="$WORKSPACE"/boost_1_57_0/libboost_random.a \
  -DBoost_RANDOM_LIBRARIES="$WORKSPACE"/boost_1_57_0/libboost_random.a \
  -DBoost_REGEX_LIBRARY="$WORKSPACE"/boost_1_57_0/libboost_regex.a \
  -DBoost_REGEX_LIBRARIES="$WORKSPACE"/boost_1_57_0/libboost_regex.a \
  -DBoost_SYSTEM_LIBRARY="$WORKSPACE"/boost_1_57_0/libboost_system.a \
  -DBoost_SYSTEM_LIBRARIES="$WORKSPACE"/boost_1_57_0/libboost_system.a \
  -DBoost_THREAD_LIBRARY="$WORKSPACE"/boost_1_57_0/libboost_thread.a \
  -DBoost_THREAD_LIBRARIES="$WORKSPACE"/boost_1_57_0/libboost_thread.a \
  -DBoost_UNIT_TEST_FRAMEWORK_LIBRARY="$WORKSPACE"/boost_1_57_0/libboost_unit_test_framework.a \
  -DBoost_UNIT_TEST_FRAMEWORK_LIBRARIES="$WORKSPACE"/boost_1_57_0/libboost_unit_test_framework.a \
  -DJSONCPP_LIBRARY="$WORKSPACE"/jsoncpp/src/lib_json/libjsoncpp.a \
  -DJSONCPP_INCLUDE_DIR="$WORKSPACE"/jsoncpp/include/ \
  -DCRYPTOPP_LIBRARY="$WORKSPACE"/cryptopp/src/libcryptlib.a \
  -DCRYPTOPP_INCLUDE_DIR="$WORKSPACE"/cryptopp/src/ \
  -DDev_DEVCORE_LIBRARY="$WORKSPACE"/libweb3core/build/libdevcore/libdevcore.a \
  -DDev_DEVCRYPTO_LIBRARY="$WORKSPACE"/libweb3core/build/libdevcrypto/libdevcrypto.a \
  -DEth_EVMASM_LIBRARY="$WORKSPACE"/solidity/build/libevmasm/libevmasm.a \
  -DUtils_SCRYPT_LIBRARY="$WORKSPACE"/webthree-helpers/utils/build/libscrypt/libscrypt.a \
  -DETHASHCL=0 -DEVMJIT=0 -DETH_STATIC=1 -DSOLIDITY=1 -DGUI=0 -DFATDB=0 -DTESTS=0 -DTOOLS=0 \
  ..
emmake make -j 4
done

