ROOT_DIR="$(dirname "$0")/.."
DEPLOYMENT=15.2
if [[ $1 == "--deployment" ]]
then
    DEPLOYMENT=$2
    shift
    shift
fi

COMMAND=$1
SDK="$(xcode-select -p)/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
TARGET="arm64-apple-macosx$DEPLOYMENT"
shift

echo "Building for macOS $DEPLOYMENT"
swift "$COMMAND" --sdk "$SDK" --triple "$TARGET" --scratch-path "$ROOT_DIR/.build/$TARGET" "$@"
