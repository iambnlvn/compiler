#! /bin/sh

nasm -f elf64 $1.asm -o $1.o
echo "executing $1.asm"
if [ $? -ne 0 ];  then
    echo "ERR: Not compiling $1"
    exit 1
fi

nasm -f elf64 print.asm  -o print.o

if [ $? -ne 0 ]; then
    echo "ERR: Not compiling print"
    exit 1 
fi


ld  print.o $1.o -o $1

if [ $? -ne 0 ]; then
    echo "ERR: Not Linking"
    exit 1
fi
echo "compiled $1 successfully"
./$1
rm $1 $1.o print.o

exit 0