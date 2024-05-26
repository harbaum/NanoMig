#!/bin/bash
EXT=
if [ "$#" -eq 1 ]; then
    EXT=_$1
fi

# run through grc to highlight NOTEs, WARNings and ERRORs
grc --config=gw_sh.grc gw_sh ./build${EXT}.tcl
