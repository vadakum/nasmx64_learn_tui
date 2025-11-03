/*
 * Try out termbox2 without including any header file.
 * This is a step closer towards using termbox2 with nasm
 *
 * Build:
 * > cd termbox2 && make # build termbox2 once
 * > gcc -g try_extern_termbox.c -L ./termbox2 -l termbox2 -o try_extern_termbox.bin
 */


#include <stdint.h>
#include <stddef.h>
#include <locale.h>

/*
 * termbox2 api and constants
 * extracted from termbox2/termbox2.h into termbox2/auto_gen_* files
 * For api documentation we will have to go through termbox2/termbox2.h
 */ 
typedef uint64_t uintattr_t;
struct tb_cell {
    uint32_t ch;
    uintattr_t fg;
    uintattr_t bg;
    uint32_t *ech;
    size_t nech;
    size_t cech;
};
struct tb_event {
    uint8_t type; // one of `TB_EVENT_*` constants
    uint8_t mod;  // bitwise `TB_MOD_*` constants
    uint16_t key; // one of `TB_KEY_*` constants
    uint32_t ch;  // a Unicode codepoint
    int32_t w;    // resize width
    int32_t h;    // resize height
    int32_t x;    // mouse x
    int32_t y;    // mouse y
};

extern int tb_init(void);
extern int tb_shutdown(void);
extern int tb_width(void);
extern int tb_height(void);
extern int tb_clear(void);
extern int tb_set_clear_attrs(uintattr_t fg, uintattr_t bg);
extern int tb_present(void);
extern int tb_invalidate(void);
extern int tb_set_cursor(int cx, int cy);
extern int tb_hide_cursor(void);
extern int tb_set_cell(int x, int y, uint32_t ch, uintattr_t fg, uintattr_t bg);
extern int tb_set_cell_ex(int x, int y, uint32_t *ch, size_t nch, uintattr_t fg,
    uintattr_t bg);
extern int tb_extend_cell(int x, int y, uint32_t ch);
extern int tb_set_input_mode(int mode);
extern int tb_set_output_mode(int mode);
extern int tb_peek_event(struct tb_event *event, int timeout_ms);
extern int tb_poll_event(struct tb_event *event);
extern int tb_get_fds(int *ttyfd, int *resizefd);
extern int tb_print(int x, int y, uintattr_t fg, uintattr_t bg, const char *str);
extern int tb_printf(int x, int y, uintattr_t fg, uintattr_t bg, const char *fmt, ...);
extern int tb_print_ex(int x, int y, uintattr_t fg, uintattr_t bg, size_t *out_w,
    const char *str);
extern int tb_printf_ex(int x, int y, uintattr_t fg, uintattr_t bg, size_t *out_w,
    const char *fmt, ...);
extern int tb_send(const char *buf, size_t nbuf);
extern int tb_sendf(const char *fmt, ...);
extern int tb_set_func(int fn_type, int (*fn)(struct tb_event *, size_t *));
extern int tb_utf8_char_length(char c);
extern int tb_utf8_char_to_unicode(uint32_t *out, const char *c);
extern int tb_utf8_unicode_to_char(char *out, uint32_t c);
extern int tb_last_errno(void);
extern const char *tb_strerror(int err);
extern struct tb_cell *tb_cell_buffer(void);
extern int tb_has_truecolor(void);
extern int tb_has_egc(void);
extern int tb_attr_width(void);
extern const char *tb_version(void);

// Colors (numeric) and attributes (bitwise) 
// for tb_cell.fg and tb_cell.bg
#define TB_BLACK 0x0001
#define TB_RED 0x0002
#define TB_GREEN 0x0003
#define TB_YELLOW 0x0004
#define TB_BLUE 0x0005
#define TB_MAGENTA 0x0006
#define TB_CYAN 0x0007
#define TB_WHITE 0x0008

#define TB_BOLD 0x01000000
#define TB_UNDERLINE 0x02000000
#define TB_REVERSE 0x04000000
#define TB_ITALIC 0x08000000
#define TB_BLINK 0x10000000
#define TB_HI_BLACK 0x20000000
#define TB_BRIGHT 0x40000000
#define TB_DIM 0x80000000


int main(int argc, char **argv)
{
    struct tb_event ev;
    int x = 5;
    int y = 10;

    tb_init();
    // setlocale is required in termbox2 (for printing unicode chars like █) 
    setlocale(LC_ALL, "");
    
    tb_printf(x, y++, TB_WHITE, 0 , "tb_attr_width is %d", tb_attr_width());

    tb_printf(x, y++, TB_RED | TB_UNDERLINE, 0, "hello from termbox");
    tb_printf(x, y++, 0, 0, "width=%d height=%d", tb_width(), tb_height());
    tb_printf(x, y++, 0, 0, "press any key...");
    tb_present();

    tb_poll_event(&ev);

    y++;
    tb_printf(x, y++, 0, 0, "event type=%d key=%d ch=%c", ev.type, ev.key, ev.ch);
    tb_printf(x, y++, 0, 0, "press any key to quit...");
    tb_present();

    tb_poll_event(&ev);
    tb_shutdown();

    return 0;
}
