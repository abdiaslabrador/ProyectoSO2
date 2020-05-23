#/!bin/sh
OUT=VisorDeProcesos
mkdir BUILD
gcc -m32 -s -O3 -o BUILD/$OUT.out main.c -no-pie
i686-w64-mingw32-gcc -s -O3 -no-pie -static main.c -o BUILD/$OUT.exe
cp *.ps1 BUILD/.
