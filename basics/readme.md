# Examples 

We cover some basics here. 
Each example is self-contained and includes a `Makefile` for easy compilation and linking.


## Table of Contents

- [Building and Running](#-building-and-running)
- [Fun Tui](#-fun-tui)
- [Resources](#-resources)

## 🚀 Building and Running

To build and run any of the examples, navigate to the example's directory and use the `make` command:

```bash
cd examples/<example_name>
make
./<program_name>.bin

```
For example, to run the "Hello World" program:
```bash
cd examples/ex_a2_hello
make
./hello.bin
```
>[!Note]
>Naming the executable with the `.bin` file extension is a convention used for convenience; it helps in filtering the build artifacts in `.gitignore` (as `*.bin`).

To clean up the generated object and binary files, use the `make clean` command:
```bash
make clean
```


## 🫐 Fun Tui

Let's assemble some fun TUI (Terminal User Interface) programs. [Fun Tui](../fun_tui/).


## 📚 Resources

- [Basic x86_64 Reference](../readme_x86_64_reference.md)
- [NASM Docs](https://www.nasm.us/doc/)
