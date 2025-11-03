# 🫐 Fun Tui

We will use `termbox2` to handle terminal input/output (it's added as a dependency in the `Makefile` and builds automatically). 
`termbox2` is a single-header file library alternative to `ncurses` and has built-in support for popular terminals. 

## Table of Contents

- [Building and Running](#-building-and-running)
- [Resources](#-resources)

## 🚀 Building and Running

Like the examples, each `.asm` file is standalone.
You can perform a full build by running the `make` command. This will build the required dependencies and compile all the `.asm` files into their corresponding `.bin` executables.
Alternatively, you can follow the `Build:` instruction within each `.asm` file.

```bash
make

# sample output
Building termbox2
make --quiet -C ./termbox2

nasm -g -f elf64 mobi_whale.asm -o mobi_whale.o
gcc mobi_whale.o -o mobi_whale.bin -g -m64 -L ./termbox2 -l termbox2
Executable: /home/nasm/Nasm64-TUI_0/fun_tui/mobi_whale.bin
nasm -g -f elf64 multi_segment_display.asm -o multi_segment_display.o
gcc multi_segment_display.o -o multi_segment_display.bin -g -m64 -L ./termbox2 -l termbox2
Executable: /home/nasm/Nasm64-TUI_0/fun_tui/multi_segment_display.bin

# run the binary
./mobi_whale.bin

```
>[!Note]
>Naming the executable with the `.bin` file extension is a convention used for convenience; it helps in filtering the build artifacts in `.gitignore` (as `*.bin`).

To clean up the generated object and binary files, use the `make clean` command:
```bash
make clean
```
