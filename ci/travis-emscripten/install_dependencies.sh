#!/usr/bin/env bash

set -ev

test -x cryptopp || git clone https://github.com/mmoss/cryptopp.git
test -x jsoncpp || git clone https://github.com/open-source-parsers/jsoncpp.git
test -x boost_1_57_0 || (
wget 'http://downloads.sourceforge.net/project/boost/boost/'\
'1.57.0/boost_1_57_0.tar.bz2?r=http%3A%2F%2Fsourceforge.net%2F'\
'projects%2Fboost%2Ffiles%2Fboost%2F1.57.0%2F&ts=1421887207'\
 -O - | tar xj
cd boost_1_57_0
./bootstrap.sh --with-toolset=gcc --with-libraries=thread,system,regex,date_time,chrono,filesystem,program_options,random
)
