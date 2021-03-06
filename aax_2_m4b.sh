#!/usr/bin/env bash

##### Config #####
SOURCE_DIR="/input"
OUTPUT_DIR="/output"

AAX_FILE="$@"

##### Code ######

# Die function
die() {
  echo >&2 "[ERROR] The job ended in error."
  echo "[ERROR] $@"
  exit 1
}

if [ -z "${AAX_FILE}" ]; then
  die "No input aax file provided."
fi

if [ ! -f "${SOURCE_DIR}/${AAX_FILE}" ]; then
  echo "${SOURCE_DIR}/${AAX_FILE}"
  ls /input
  die "The file can not be found."
fi

check1=$(which ffmpeg)
if [ "$check1" = "" ]; then
  die "ffmpeg is missing -> e.g.: apt-get install ffmpeg"
fi

CHECKSUM=$(ffprobe "${SOURCE_DIR}/${AAX_FILE}" 2>&1 | grep checksum | sed 's/^.*== //'g)

if [ -z "${CHECKSUM}" ]; then
  die "No checksum found."
fi

if [ -f "./activation_bytes" ]; then
  ACTIVATION_BYTES=$(<./activation_bytes)
fi
if [ -z "${ACTIVATION_BYTES}"  ]; then
  echo "Searching for activation bytes..."
  RCRACK=$(./rcrack . -h "${CHECKSUM}")
  ACTIVATION_BYTES=$(echo "${RCRACK}" | grep "hex:" | sed 's/^.*hex://g')
  echo "${ACTIVATION_BYTES}">./activation_bytes
  echo "Your Activation bytes are: ${ACTIVATION_BYTES}"
fi

echo "Retrieving cover"
ffmpeg -y -v quiet -i "${SOURCE_DIR}/${AAX_FILE}" "./cover.png"
RETVAL=$?
[ $RETVAL -eq 0 ] || die "The ffmpeg command failed with exit code: $RETVAL"

ARTIST="$(ffprobe -v quiet -print_format json -show_format "${SOURCE_DIR}/${AAX_FILE}" | jq -r ".format.tags.artist")"
ALBUM_ARTIST="$(ffprobe -v quiet -print_format json -show_format "${SOURCE_DIR}/${AAX_FILE}" | jq -r ".format.tags.album_artist")"
TITLE="$(ffprobe -v quiet -print_format json -show_format "${SOURCE_DIR}/${AAX_FILE}" | jq -r ".format.tags.title")"
ALBUM="$(ffprobe -v quiet -print_format json -show_format "${SOURCE_DIR}/${AAX_FILE}" | jq -r ".format.tags.album")"
YEAR="$(ffprobe -v quiet -print_format json -show_format "${SOURCE_DIR}/${AAX_FILE}" | jq -r ".format.tags.date")"
GENRE="$(ffprobe -v quiet -print_format json -show_format "${SOURCE_DIR}/${AAX_FILE}" | jq -r ".format.tags.genre")"
COMMENT="$(ffprobe -v quiet -print_format json -show_format "${SOURCE_DIR}/${AAX_FILE}" | jq -r ".format.tags.comment")"

echo "Artist       : $ARTIST"
echo "Album Artist : $ALBUM_ARTIST"
echo "Title        : $TITLE"
echo "Album        : $ALBUM"
echo "Year         : $YEAR"
echo "Genre        : $GENRE"
echo "Comment      : $COMMENT"

echo "Converting to audio..."
ffmpeg -v quiet -activation_bytes "${ACTIVATION_BYTES}" -i "${SOURCE_DIR}/${AAX_FILE}" -vn -c:a copy -map_metadata 0 -map_metadata:s:a 0:s:a -movflags use_metadata_tags "./temp.m4a"
RETVAL=$?
[ $RETVAL -eq 0 ] || die "The ffmpeg command failed with exit code: $RETVAL"

AtomicParsley "./temp.m4a" --title "$TITLE" --album "$ALBUM" --artist "$ARTIST" --albumArtist "$ALBUM_ARTIST" --genre "$GENRE" --comment "$COMMENT" --year "$YEAR" --stik Audiobook --overWrite
RETVAL=$?
[ $RETVAL -eq 0 ] || die "The AtomicParsley command failed with exit code: $RETVAL"

if [ -f "./cover.png" ]; then
  mp4art --add "./cover.png" "./temp.m4b"
  RETVAL=$?
  [ $RETVAL -eq 0 ] || die "The mp4art command failed with exit code: $RETVAL"
else
  echo "No cover was found."
fi

mv -v ./temp.m4b "${OUTPUT_DIR}/${AAX_FILE%.*}.m4b"
RETVAL=$?
[ $RETVAL -eq 0 ] || die "The move failed with exit code: $RETVAL"

rm -rf ./cover.png ./temp.m4a 2>/dev/null
