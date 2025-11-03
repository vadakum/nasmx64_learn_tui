## Info - termbox2.h (v2.5.0) 

Build the static library:
```
make 
```

For now, I have copied the required file and updated the `Makefile` for our needs.
A supporting bash script, `./gen_def_externs.sh`, has been added to extract the constants and API. 

`termbox2.h` download instructions:

```
git clone https://github.com/termbox/termbox2.git
git tags
git checkout v2.5.0
# and then copied the required files. (A git submodule would also have worked).
```

> [!Note]
> We are building `termbox2` with the `-DTB_LIB_OPTS` flag. This enables `TB_OPT_ATTR_W` to be 64 (Integer width of `fg` and `bg` attributes) in the header file.
> This means we must be careful to use the appropriate constant values defined in `termbox2.h`. For example, to make text blink, we will use `0x10000000` and not `0x1000`
```
#if TB_OPT_ATTR_W == 16
#define TB_BLINK     0x1000

// `TB_OPT_ATTR_W` is 32 or 64
#define TB_BLINK               0x10000000

```
