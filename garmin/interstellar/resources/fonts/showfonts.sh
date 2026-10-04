#!/usr/bin/dash

magick four_${1:-30}_0.png \
   -filter point -resize 800% \
   /tmp/four-preview.png

/usr/bin/display /tmp/four-preview.png &

magick eight_${1:-30}_0.png \
   -filter point -resize 800% \
   /tmp/eight-preview.png

/usr/bin/display /tmp/eight-preview.png &

magick twelve_${1:-30}_0.png \
   -filter point -resize 800% \
   /tmp/twelve-preview.png

/usr/bin/display /tmp/twelve-preview.png &
