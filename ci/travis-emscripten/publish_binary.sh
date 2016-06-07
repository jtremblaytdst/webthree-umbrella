#!/usr/bin/env bash
#

set -e

cd solidity
VER=$(cat CMakeLists.txt | grep 'set(PROJECT_VERSION' | sed -e 's/.*set(PROJECT_VERSION "\(.*\)".*/\1/')
test -n "$VER"
VER="v$VER"
COMMIT=$(git rev-parse --short HEAD)
DATE=$(date --date="$(git log -1 --date=iso --format=%ad HEAD)" --utc +%F)
cp build/solc/soljson.js "../soljson-$VER-$DATE-$COMMIT.js"
cd ..


ENCRYPTED_KEY_VAR="encrypted_${ENCRYPTION_LABEL}_key"
ENCRYPTED_IV_VAR="encrypted_${ENCRYPTION_LABEL}_iv"
ENCRYPTED_KEY=${!ENCRYPTED_KEY_VAR}
ENCRYPTED_IV=${!ENCRYPTED_IV_VAR}
openssl aes-256-cbc -K $ENCRYPTED_KEY -iv $ENCRYPTED_IV -in ci/travis-emscripten/deploy_key.enc -out deploy_key -d
chmod 600 deploy_key
eval `ssh-agent -s`
ssh-add deploy_key

git clone --depth 2 git@github.com:ethereum/solc-bin.git
cd solc-bin
git config user.name "travis"
git config user.email "chris@ethereum.org"
git checkout -B gh-pages origin/gh-pages
git clean -f -d -x
cp ../soljson-*.js ./bin/
./update-index.sh
cd bin
LATEST=$(ls -r soljson-v* | head -n 1)
cp "$LATEST" soljson-latest.js
cp soljson-latest.js ../soljson.js
git add .
git add ../soljson.js
git commit -m "Added compiler version $LATEST"
find .
echo git push origin gh-pages
