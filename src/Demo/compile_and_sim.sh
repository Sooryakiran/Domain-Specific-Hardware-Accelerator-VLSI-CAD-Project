#!/bin/bash
rm *.bo
rm *.ba
rm *.o
rm *.h
rm *.cxx
rm *.so
rm out
bsc -u -sim -simdir . -bdir . -info-dir . -keep-fires -p %/Prelude:%/Libraries:%/Libraries/BlueNoC:./../CPU:./../RAM:./../Bus:./../DebugConsole:./../VectorProcessor -g mkDemo $1
bsc -e mkDemo -sim -o ./out -simdir . -p %/Prelude:%/Libraries:%/Libraries/BlueNoC:./../CPU:./../RAM:./../Bus:./../DebugConsole:./../VectorProcessor -bdir . -keep-fires
echo "Running ./out"
./out
