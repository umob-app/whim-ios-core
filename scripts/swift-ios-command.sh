ROOT_DIR="$(dirname "$0")/.."
DEPLOYMENT=18.2
if [[ $1 == "--deployment" ]]
then
    DEPLOYMENT=$2
    shift
    shift
fi

COMMAND=$1
SDK="$(xcode-select -p)/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
TARGET="arm64-apple-ios$DEPLOYMENT"
shift

echo "Building for iOS $DEPLOYMENT"
swift "$COMMAND" --sdk "$SDK" --triple "$TARGET" --scratch-path "$ROOT_DIR/.build/$TARGET" "$@"
