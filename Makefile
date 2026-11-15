TARGET := disc-log
SOURCE := disc-log.asm
OBJECT := disc-log.o

NASM := nasm
CC := gcc
NASMFLAGS := -g -f elf64 -l disc-log.lst
LDFLAGS := -g -m64 -no-pie

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJECT)
	$(CC) $(LDFLAGS) -o $@ $<

$(OBJECT): $(SOURCE)
	$(NASM) $(NASMFLAGS) -o $@ $<

clean:
	rm -f $(TARGET) $(OBJECT) disc-log.lst
