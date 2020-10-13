#!/bin/bash

# This script builds openssl+libcurl+nghttp2+ngtcp2+nghttp3 libraries for MacOS, iOS and tvOS
#
# Credits:
# Jason Cox, @jasonacox
#   https://github.com/jasonacox/Build-OpenSSL-cURL
# Bachue Zhou, @bachue
#   https://github.com/bachue/Build-cURL-nghttp2-nghttp3-ngtcp2
#

################################################
# EDIT this section to Select Default Versions #
################################################

LIBCURL="7.72.0"	# https://curl.haxx.se/download.html
QUICHE="0.5.1"	# https://nghttp2.org/

################################################

# Global flags
engine=""
buildquiche="-2"
disablebitcode=""
colorflag=""

# Formatting
default="\033[39m"
wihte="\033[97m"
green="\033[32m"
red="\033[91m"
yellow="\033[33m"

bold="\033[0m${white}\033[1m"
subbold="\033[0m${green}"
normal="${white}\033[0m"
dim="\033[0m${white}\033[2m"
alert="\033[0m${red}\033[1m"
alertdim="\033[0m${red}\033[2m"

usage ()
{
    echo
	echo -e "${bold}Usage:${normal}"
	echo
	echo -e "  ${subbold}$0${normal} [-c ${dim}<curl version>${normal}] [-n ${dim}<nghttp2 version>${normal}] [-q ${dim}<quiche version>${normal}] [-e] [-x] [-h]"
	echo
	echo "         -c <version>   Build curl version (default $LIBCURL)"
	echo "         -n <version>   Build nghttp2 version (default $NGHTTP2)"
	echo "         -q <version>   Build quiche version (default $QUICHE)"
	echo "         -e             Compile with OpenSSL engine support"
	echo "         -b             Compile without bitcode"
	echo "         -x             No color output"
	echo "         -h             Show usage"
	echo
    exit 127
}

while getopts "o:c:n:q:exh\?" o; do
    case "${o}" in
		c)
			LIBCURL="${OPTARG}"
			;;
		n)
			NGHTTP2="${OPTARG}"
			;;
		q)
			QUICHE="${OPTARG}"
			;;
		e)
			engine="-e"
			;;
		b)
			disablebitcode="-b"
			;;
		x)
			bold=""
			subbold=""
			normal=""
			dim=""
			alert=""
			alertdim=""
			colorflag="-x"
			;;
		*)
			usage
			;;
    esac
done
shift $((OPTIND-1))

## Welcome
echo -e "${bold}Build-cURL-nghttp2-quiche${dim}"
echo "This script builds OpenSSL, nghttp2, quiche and libcurl for MacOS (OS X), iOS and tvOS devices."
echo "Targets: x86_64, armv7, armv7s, arm64 and arm64e"
echo

set -e

## OpenSSL Build
echo
cd openssl
echo -e "${bold}Building OpenSSL${normal}"
./openssl-build.sh $engine $colorflag
cd ..

## Nghttp2 Build
buildnghttp2=""
if [ "$NGHTTP2" == "" ]; then
	NGHTTP2="NONE"
else
	buildnghttp2="-2"
	echo
	echo -e "${bold}Building nghttp2 for HTTP2 support${normal}"
	cd nghttp2
	./nghttp2-build.sh -v "$NGHTTP2" $colorflag
	cd ..
fi

## Quiche Build
buildquiche=""
if [ "$QUICHE" == "" ]; then
	QUICHE="NONE"
else
	buildquiche="-q"
	echo
	echo -e "${bold}Building quiche for HTTP3 support${normal}"
	cd quiche
	./quiche-build.sh $colorflag
	cd ..
fi

## Curl Build
echo
echo -e "${bold}Building Curl${normal}"
cd curl
./libcurl-build.sh -v "$LIBCURL" $disablebitcode $colorflag $buildnghttp2 $buildquiche
cd ..

echo
echo -e "${bold}Libraries...${normal}"
echo
echo -e "${subbold}openssl${normal} [${dim}$OPENSSL${normal}]${dim}"
xcrun -sdk iphoneos lipo -info openssl/*/lib/*.a
echo
echo -e "${subbold}nghttp2 (rename to libnghttp2.a)${normal} [${dim}$NGHTTP2${normal}]${dim}"
xcrun -sdk iphoneos lipo -info nghttp2/lib/*.a
echo
echo -e "${subbold}libcurl (rename to libcurl.a)${normal} [${dim}$LIBCURL${normal}]${dim}"
xcrun -sdk iphoneos lipo -info curl/lib/*.a

EXAMPLE="examples/iOS Test App"
ARCHIVE="archive/libcurl-$LIBCURL-openssl-$OPENSSL-nghttp2-$NGHTTP2"

echo
echo -e "${bold}Creating archive for release v$LIBCURL...${dim}"
echo "  See $ARCHIVE"
mkdir -p "$ARCHIVE"
mkdir -p "$ARCHIVE/include/openssl"
mkdir -p "$ARCHIVE/include/curl"
mkdir -p "$ARCHIVE/lib/iOS"
mkdir -p "$ARCHIVE/lib/MacOS"
mkdir -p "$ARCHIVE/lib/tvOS"
mkdir -p "$ARCHIVE/bin"
# archive libraries
cp curl/lib/libcurl_iOS.a $ARCHIVE/lib/iOS/libcurl.a
cp curl/lib/libcurl_tvOS.a $ARCHIVE/lib/tvOS/libcurl.a
cp curl/lib/libcurl_Mac.a $ARCHIVE/lib/MacOS/libcurl.a
cp openssl/iOS/lib/libcrypto.a $ARCHIVE/lib/iOS/libcrypto.a
cp openssl/tvOS/lib/libcrypto.a $ARCHIVE/lib/tvOS/libcrypto.a
cp openssl/Mac/lib/libcrypto.a $ARCHIVE/lib/MacOS/libcrypto.a
cp openssl/iOS/lib/libssl.a $ARCHIVE/lib/iOS/libssl.a
cp openssl/tvOS/lib/libssl.a $ARCHIVE/lib/tvOS/libssl.a
cp openssl/Mac/lib/libssl.a $ARCHIVE/lib/MacOS/libssl.a
cp nghttp2/lib/libnghttp2_iOS.a $ARCHIVE/lib/iOS/libnghttp2.a
cp nghttp2/lib/libnghttp2_tvOS.a $ARCHIVE/lib/tvOS/libnghttp2.a
cp nghttp2/lib/libnghttp2_Mac.a $ARCHIVE/lib/MacOS/libnghttp2.a
# archive header files
cp openssl/iOS/include/openssl/* "$ARCHIVE/include/openssl"
cp curl/include/curl/* "$ARCHIVE/include/curl"
# archive root certs
curl -s https://curl.haxx.se/ca/cacert.pem > $ARCHIVE/cacert.pem
sed -e "s/ZZZLIBCURL/$LIBCURL/g" -e "s/ZZZOPENSSL/$OPENSSL/g" -e "s/ZZZNGHTTP2/$NGHTTP2/g" archive/release-template.md > $ARCHIVE/README.md
echo
echo -e "${bold}Copying libraries to Test App ...${dim}"
echo "  See $EXAMPLE"
cp openssl/iOS/lib/libcrypto.a "$EXAMPLE/libs/libcrypto.a"
cp openssl/iOS/lib/libssl.a "$EXAMPLE/libs/libssl.a"
cp openssl/iOS/include/openssl/* "$EXAMPLE/include/openssl/"
cp curl/include/curl/* "$EXAMPLE/include/curl/"
cp curl/lib/libcurl_iOS.a "$EXAMPLE/libs/libcurl.a"
cp nghttp2/lib/libnghttp2_iOS.a "$EXAMPLE/libs/libnghttp2.a"
cp ngtcp2/lib/libngtcp2_iOS.a "$EXAMPLE/libs/libngtcp2.a"
cp ngtcp2/lib/libngtcp2_crypto_openssl_iOS.a "$EXAMPLE/libs/libngtcp2_crypto_openssl.a"
cp $ARCHIVE/cacert.pem "$EXAMPLE/cacert.pem"
echo
echo -e "${bold}Archiving Mac binaries for curl and openssl...${dim}"
echo "  See $ARCHIVE/bin"
mv /tmp/curl $ARCHIVE/bin
mv /tmp/openssl $ARCHIVE/bin
echo
echo -e "${bold}Testing Mac curl binary...${dim}"
$ARCHIVE/bin/curl -V
echo
echo -e "${normal}Done"

rm -f $NOHTTP2
