# ------------------------------------------------------------------
# File:   Makefile
# Author: (c) 2023 Jens Kallup - paule32
#         all rights reserved
#
# only for education, and non-profit usage !
#
# A simple makefile script for building pas2dox under Windows MSYS2
# ------------------------------------------------------------------
LEX=flex
LEX_OPTIONS=-o
CC=gcc $(FLAGSCC)
XX=g++ $(FLAGSXX)
FLAGSXX= -m64 -O2 -fPIC -std=c++17  \
    -DGETTEXT_DOMAIN=\"pas2dox\"    \
                                    \
    -Wno-pmf-conversions            \
    -Wno-deprecated                 \
    -Wno-register                   \
    -Wno-volatile                   \
    -Wno-write-strings              \
    -Wno-invalid-offsetof           \
                                    \
    -D__MINGW32__                   \
    -D__MINGW64__                   \
                                    \
    -D__USE_W32_SOCKETS             \
                                    \
    -DASMJIT_STATIC                 \
    -DASMJIT_BUILD_RELEASE          \
    -DASMJIT_NO_AARCH64             \
                                    \
    -DBOOST_ASIO_WINDOWS=1          \
    -DBOOST_ASIO_HAS_SECURE_RTL=1   \
    -DBOOST_ASIO_WINDOWS_APP=1      \
    -DBOOST_USE_WINAPI_VERSION=0x0A00 \
                                    \
    -D__USE_MINGW_ANSI_STDIO=0      \
                                    \
    -Wno-write-strings              \
    -I/E/msys64/mingw64/usr/include \
    -I/E/Projekte/tvision/include/tvision/compat/borland \
    -I/E/Projekte/tvision/include   \
    -I/E/Projekte/plog/include      \
    -I/E/Projekte/boost             \
    -I/E/Projekte/asmjit/src/asmjit \
    -I/E/Projekte/dwarf             \
    -I/E/Projekte/ini/include       \
    -I./include

FLAGSCC= -m64 -O2 -fPIC             \
    -DGETTEXT_DOMAIN=\"pas2dox\"    \
                                    \
    -D__MINGW32__                   \
    -D__MINGW64__                   \
                                    \
    -D__USE_W32_SOCKETS             \
                                    \
    -Wno-write-strings              \
    -I/E/msys64/mingw64/usr/include \
    -I/E/Projekte/dwarf             \
    -I./include

INSTALL_DIR=/usr/local/bin/

OBJECTS=dwarf.o TSyntaxFileEditor.o pas2dox.o

TSyntaxFileEditor.o: TSyntaxFileEditor.cc TSyntaxFileEditor.h
	$(XX) -o TSyntaxFileEditor.o -c TSyntaxFileEditor.cc

dwarf.o: dwarf.c
	$(CC) -o dwarf.o -c dwarf.c

pas2dox.cpp: pas2dox.l
	flex -i -o pas2dox.cpp pas2dox.l

pas2dox.o: pas2dox.cpp
	${XX} -o pas2dox.o -c pas2dox.cpp

pas2dox.exe: $(OBJECTS)
	${XX} -o pas2dox.exe  pas2dox.o \
    TSyntaxFileEditor.o             \
    -L./                            \
    -lz                             \
    -lasmjit                        \
    -ltvision                       \
    -lintl                          \
    -ldwarf64                       \
                                    \
    -lboost_system-mt               \
    -lboost_thread-mt               \
    -lboost_program_options-mt      \
    -lboost_date_time-mt            \
    -lboost_regex-mt                \
                                    \
    -static-libgcc                  \
    -static-libstdc++

.PHONY: all
all: pas2dox.exe
	strip ./pas2dox.exe
	cp    ./pas2dox.exe ./pas2dox.upx.exe
	upx                 ./pas2dox.upx.exe

.PHONY: clean
clean:
	rm -f ./pas2dox.cpp ./pas2dox.exe ./*.o

.PHONY: install
install:
	cp ./pas2dox.exe ${INSTALL_DIR}
