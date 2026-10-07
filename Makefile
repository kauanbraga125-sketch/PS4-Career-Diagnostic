PROJECT := career_diag

TOOLCHAIN := $(OO_PS4_TOOLCHAIN)
GH_SDK := $(GOLDHEN_SDK)

SRC_DIR := source
COMMON_DIR := common
INCLUDE_DIR := include
BUILD_DIR := build
BIN_DIR := bin

TARGET := $(BIN_DIR)/$(PROJECT)
ELF := $(TARGET).elf
PRX := $(TARGET).prx

LIBS := -lSceLibcInternal -lGoldHEN_Hook -lkernel -lSceSysmodule -lScePad
CFLAGS := --target=x86_64-pc-freebsd12-elf -fPIC -funwind-tables -c -O2 -Wall \
          -D__FINAL__=1 -D__USE_PRINTF__ \
          -isysroot $(TOOLCHAIN) -isystem $(TOOLCHAIN)/include \
          -I$(GH_SDK)/include -I$(INCLUDE_DIR) -I$(COMMON_DIR)
LDFLAGS := -m elf_x86_64 -pie --script $(TOOLCHAIN)/link.x -e _init --eh-frame-hdr \
           -L$(TOOLCHAIN)/lib -L$(GH_SDK) $(LIBS)

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
CC := clang
LD := ld.lld
CDIR := linux
endif
ifeq ($(UNAME_S),Darwin)
CC := /usr/local/opt/llvm/bin/clang
LD := /usr/local/opt/llvm/bin/ld.lld
CDIR := macos
endif

SOURCES := $(wildcard $(SRC_DIR)/*.c) $(wildcard $(COMMON_DIR)/*.c)
OBJECTS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(SOURCES))

.PHONY: all sdk clean

all: sdk $(PRX)

sdk:
	$(MAKE) -C $(GH_SDK) PRINTF=1 DEBUGFLAGS=1

$(PRX): $(OBJECTS)
	@mkdir -p $(BIN_DIR)
	$(LD) $(GH_SDK)/build/crtprx.o $(OBJECTS) -o $(ELF) $(LDFLAGS)
	$(TOOLCHAIN)/bin/$(CDIR)/create-fself -in=$(ELF) -out=$(TARGET).oelf --lib=$(PRX) --paid 0x3800000000000011

$(BUILD_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)
