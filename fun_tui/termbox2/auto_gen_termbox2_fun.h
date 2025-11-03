#include <stdint.h>
#include <stddef.h>

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
    uint8_t type;
    uint8_t mod;
    uint16_t key;
    uint32_t ch;
    int32_t w;
    int32_t h;
    int32_t x;
    int32_t y;
};
int tb_init(void);
int tb_init_file(const char *path);
int tb_init_fd(int ttyfd);
int tb_init_rwfd(int rfd, int wfd);
int tb_shutdown(void);
int tb_width(void);
int tb_height(void);
int tb_clear(void);
int tb_set_clear_attrs(uintattr_t fg, uintattr_t bg);
int tb_present(void);
int tb_invalidate(void);
int tb_set_cursor(int cx, int cy);
int tb_hide_cursor(void);
int tb_set_cell(int x, int y, uint32_t ch, uintattr_t fg, uintattr_t bg);
int tb_set_cell_ex(int x, int y, uint32_t *ch, size_t nch, uintattr_t fg,
    uintattr_t bg);
int tb_extend_cell(int x, int y, uint32_t ch);
int tb_set_input_mode(int mode);
int tb_set_output_mode(int mode);
int tb_peek_event(struct tb_event *event, int timeout_ms);
int tb_poll_event(struct tb_event *event);
int tb_get_fds(int *ttyfd, int *resizefd);
int tb_print(int x, int y, uintattr_t fg, uintattr_t bg, const char *str);
int tb_printf(int x, int y, uintattr_t fg, uintattr_t bg, const char *fmt, ...);
int tb_print_ex(int x, int y, uintattr_t fg, uintattr_t bg, size_t *out_w,
    const char *str);
int tb_printf_ex(int x, int y, uintattr_t fg, uintattr_t bg, size_t *out_w,
    const char *fmt, ...);
int tb_send(const char *buf, size_t nbuf);
int tb_sendf(const char *fmt, ...);
int tb_set_func(int fn_type, int (*fn)(struct tb_event *, size_t *));
int tb_utf8_char_length(char c);
int tb_utf8_char_to_unicode(uint32_t *out, const char *c);
int tb_utf8_unicode_to_char(char *out, uint32_t c);
int tb_last_errno(void);
const char *tb_strerror(int err);
struct tb_cell *tb_cell_buffer(void);
int tb_has_truecolor(void);
int tb_has_egc(void);
int tb_attr_width(void);
const char *tb_version(void);
