#!/bin/bash
ffmpeg -vcodec rawvideo -f rawvideo -pix_fmt abgr -s 456x313 -i $1 -f image2 -vcodec png "${1%.raw}.png"
