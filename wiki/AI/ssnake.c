/*
 * SSNAKE.C  -  Super Snake for Zenith Z-89 / CP/M 2.2  [v1.1]
 * =============================================================
 * CPU     : Z-80 @ 2 MHz
 * Terminal: H19 Heath/VT52 mode, 80x24
 *
 * Compile:
 *   zcc -mz80 +cpm -subtype=hz89 \
 *       -pragma-define:CLIB_DISABLE_FGETS_CURSOR=1 \
 *       -O2 -o SSNAKE.COM ssnake.c
 *
 * Controls: 8=Up  2=Down  4=Left  6=Right  P=Pause  ESC=Quit
 *
 * H19 graphic mode: ESC F = ON, ESC G = OFF
 *   Remaps ASCII 0x5E-0x7E to graphic symbols.
 *   Codes 0x20-0x5D (space, digits, uppercase) always display normally.
 *
 *   Chars used:
 *     'f' 0x66  top-left corner     ┏
 *     'c' 0x63  top-right corner    ┓
 *     'e' 0x65  bottom-left corner  ┗
 *     'd' 0x64  bottom-right corner ┛
 *     'a' 0x61  horizontal          ━  (border + horizontal snake body)
 *     '`' 0x60  vertical            ┃  (border + vertical snake body)
 *     '^' 0x5E  snake head          •
 *     'i' 0x69  obstacle / fill     ▒
 *     'w' 0x77  food                ╳
 *
 * Audio: BEL (0x07) - 1 beep on food eaten
 *
 * By Claude A.I. & RomaX ManiaX
 *
 * Changelog:
 *   v1.0 : initial release
 *   v1.1 : speed formula corrected (level 10 now reaches MIN_SLICE);
 *           "BONUS MOVES" renamed "BONUS TURNS"; doc fixes.
 */

#include <stdio.h>
#include <cpm.h>    /* bdos() ; try <arch/cpm.h> if missing */

/* ------------------------------------------------------------------
 * Screen layout (1-based coordinates, 80x24 terminal)
 *
 *   Row  1         : title bar (static)
 *   Row  2         : top game border (reverse-video spaces)
 *   Rows 3-22      : playfield interior (20 rows)
 *   Row 23         : bottom game border (reverse-video spaces)
 *   Row 24         : status bar (dynamic; reverse-video only during pause)
 *   Cols 1 and 80  : side borders (reverse-video spaces)
 *   Playfield      : cols 2-79, rows 3-22  (78 x 20 cells)
 * ------------------------------------------------------------------ */
#define BORDER_C1   1
#define BORDER_R1   2
#define BORDER_C2   80
#define BORDER_R2   23
#define BOARD_W     78      /* BORDER_C2 - BORDER_C1 - 1 */
#define BOARD_H     20      /* BORDER_R2 - BORDER_R1 - 1 */

#define ROW_TITLE   1       /* title bar row  */
#define ROW_STATUS  24      /* status bar row */

/* Playfield cell (0-based) -> screen coordinate (1-based) */
#define SCR_COL(x)  (BORDER_C1 + 1 + (x))
#define SCR_ROW(y)  (BORDER_R1 + 1 + (y))

/* ------------------------------------------------------------------
 * H19 graphic character codes
 * ------------------------------------------------------------------ */
#define GFX_CORNER_TL   'f'
#define GFX_CORNER_TR   'c'
#define GFX_CORNER_BL   'e'
#define GFX_CORNER_BR   'd'
#define GFX_HORIZ       'a'
#define GFX_VERT        '`'
#define GFX_HEAD        '^'
#define GFX_BODY        'i'
#define GFX_FOOD        'w'

/* ------------------------------------------------------------------
 * Snake
 * ------------------------------------------------------------------ */
#define MAX_LEN        500      /* absolute maximum snake length */
#define INIT_LEN         5      /* starting length               */
#define FOOD_PER_LEVEL  10      /* food items to eat per level */

/* ------------------------------------------------------------------
 * Hall of Fame
 * ------------------------------------------------------------------ */
#define HOF_NAMELEN     16      /* max name length (chars)       */

/* ------------------------------------------------------------------
 * Obstacles
 *
 * Each obstacle is a blob: a set of individual cells grown organically
 * from a random seed by randomly adding adjacent neighbours.
 * This produces irregular shapes instead of straight segments.
 *
 * Parameters scale with level; level 1 has no obstacles.
 *
 *   OBS_BLOBS(lv)    : number of blobs at level lv
 *   OBS_BLOB_MAX     : max cells per blob
 *   OBS_BLOB_MIN     : min cells per blob
 *   OBS_TOTAL_MAX    : hard upper bound on total cells (array size)
 *   OBS_SAFE_DIST    : min Chebyshev distance from start head (x=4,y=10)
 * ------------------------------------------------------------------ */
#define OBS_TOTAL_MAX  200     /* 5x30 blobs + 4x12 walls max          */
#define OBS_SAFE_DIST    6     /* min Chebyshev dist from start head   */
#define WALL_LEN_MIN     6     /* minimum wall length (cells)          */
#define WALL_LEN_MAX    12     /* maximum wall length (cells)          */
/* Per-level parameters: blobs, walls, blob min/max size */
#define OBS_BLOBS(lv)  ((lv) <= 1 ? 0 : ((lv) <= 4 ? 3 : ((lv) <= 7 ? 4 : 5)))
#define OBS_WALLS(lv)  ((lv) <= 1 ? 0 : ((lv) <= 4 ? 2 : ((lv) <= 7 ? 3 : 4)))
#define OBS_BMIN(lv)   10
#define OBS_BMAX(lv)   ((lv) <= 4 ? 20 : ((lv) <= 7 ? 25 : 30))

/* ------------------------------------------------------------------
 * Transition animation parameters
 * ------------------------------------------------------------------ */
#define CB_BW   6       /* checkerboard block width  (cols)  */
#define CB_BH   4       /* checkerboard block height (rows)  */
#define TF_NS   9       /* tetris_fill: number of piece shapes */
#define TF_MP 400       /* tetris_fill: max pieces in grid     */
#define SP_MAXLAYERS 10 /* spiral: max concentric layers       */
#define HT_SNK_LEN  7  /* heart_transition: snake length      */
#define HT_H_ROWS  13  /* heart_transition: heart height      */
#define HT_H_COLS  26  /* heart_transition: heart width       */

/* ------------------------------------------------------------------
 * Directions
 * ------------------------------------------------------------------ */
#define UP    0
#define DOWN  1
#define LEFT  2
#define RIGHT 3

/* ------------------------------------------------------------------
 * Types
 * ------------------------------------------------------------------ */
typedef struct { unsigned char x; unsigned char y; } Point;

/* ------------------------------------------------------------------
 * Globals
 * ------------------------------------------------------------------ */
static Point        snake[MAX_LEN]; /* circular ring buffer          */
static int          s_head;         /* index of head cell            */
static int          s_tail;         /* index of tail cell            */
static int          s_len;          /* current snake length          */
static int          dir;            /* current direction             */
static int          dir_queue[2];   /* buffered direction changes    */
static int          dir_qlen;       /* entries in dir_queue (0-2)    */
static Point        food;           /* food position                 */
static unsigned int     score;
static int          food_count;     /* food items eaten this level   */
static int          dir_changes;    /* direction changes this level  */
static int          status_pending; /* defer draw_status to delay    */
static int          esc_quit;       /* 1 = player pressed ESC        */
static int          game_complete;  /* 1 = all 10 levels finished    */
static int          running;
static unsigned int rseed;          /* PRNG seed                     */
static int          level;          /* current level (1-based)       */
static Point        obs[OBS_TOTAL_MAX]; /* flat obstacle+wall cell array */
static int          obs_count;      /* total obstacle+wall cells        */
static int          obs_wall_start; /* index where wall cells begin     */
static char         player_name[HOF_NAMELEN + 1]; /* entered at welcome screen */

/* ==================================================================
 * Terminal primitives (Heath/VT52)
 *
 * Cursor: ESC Y (row+31) (col+31)  -- 1-based, 0x20 offset
 *
 * H19 extensions:
 *   ESC x 5 / ESC y 5  cursor off / on
 *   ESC F   / ESC G    graphic mode on / off
 *   ESC p   / ESC q    reverse video on / off
 * ================================================================== */

static void gotoxy(int col, int row)
{
    putchar(27); putchar('Y');
    putchar(row + 31);
    putchar(col + 31);
}

/* clrscr - erase entire screen via BDOS fn 2, bypasses stdio buffer */
static void clrscr(void)
{
    bdos(2, 27); bdos(2, 'E');
}

static void cursor_off(void) { putchar(27); putchar('x'); putchar('5'); }
static void cursor_on(void)  { putchar(27); putchar('y'); putchar('5'); }
static void gfx_on(void)     { putchar(27); putchar('F'); }
static void gfx_off(void)    { putchar(27); putchar('G'); }
static void rev_on(void)     { putchar(27); putchar('p'); }
static void rev_off(void)    { putchar(27); putchar('q'); }

/* ==================================================================
 * Non-blocking keyboard input (BDOS function 6)
 * Returns the key pressed, or 0 if none available.
 * ================================================================== */
static int get_key(void)
{
    return bdos(6, 0xFF);
}

/* ==================================================================
 * Key processing - shared by frame_delay() and do_pause()
 *
 * enqueue_dir: validates and buffers a direction change.
 *   Anti-reversal check is done against the LAST queued direction
 *   (or current dir if queue empty) so that a rapid sequence like
 *   UP→RIGHT is correctly preserved even if UP hasn't been consumed yet.
 *   XOR trick: UP(0)^DOWN(1)=1, LEFT(2)^RIGHT(3)=1 only for true pairs.
 *
 * drain_keys: reads ALL available keys in one shot (B).
 * ================================================================== */
static void do_pause(void);         /* forward declaration */
static void draw_status(void);      /* forward declaration */
static int  obs_cell_used(int, int);/* forward declaration */

static void enqueue_dir(int d)
{
    int last = (dir_qlen > 0) ? dir_queue[dir_qlen - 1] : dir;
    if (d == last || ((d ^ last) == 1)) return; /* same or opposite: ignore */
    if (dir_qlen < 2) dir_queue[dir_qlen++] = d;
}

static void process_key(int k)
{
    switch (k) {
        case '8': enqueue_dir(UP);    break;
        case '2': enqueue_dir(DOWN);  break;
        case '4': enqueue_dir(LEFT);  break;
        case '6': enqueue_dir(RIGHT); break;
        case 'p': case 'P': do_pause();            break;
        case 0x1B: running = 0; esc_quit = 1; break;
    }
}

/* Drain all pending keystrokes in one call (B) */
static void drain_keys(void)
{
    int k;
    while ((k = get_key()) != 0)
        process_key(k);
}

/* ==================================================================
 * Frame delay with interleaved key polling
 *
 * Speed is distributed linearly over 10 levels:
 *   level 1  -> BASE_SLICE (slowest)
 *   level 10 -> MIN_SLICE  (fastest)
 *
 * SPEED_STEP = 7: at level 10, step = 9*7 = 63 >= (BASE_SLICE-MIN_SLICE) = 60,
 * so the clamp fires and slice = MIN_SLICE exactly.
 * ================================================================== */
#define BASE_SLICE      120u    /* ~12 ms/frame at level 1  */
#define MIN_SLICE        60u    /* ~6  ms/frame at level 10 */
#define POLLS_PER_FRAME  8u
#define SPEED_STEP        7u    /* 7*9=63 >= 60 -> level 10 hits MIN_SLICE */

static void frame_delay(void)
{
    unsigned int p, slice;
    volatile unsigned int i;
    unsigned int step;

    step  = (level - 1) * SPEED_STEP;
    slice = (step >= BASE_SLICE - MIN_SLICE) ? MIN_SLICE : BASE_SLICE - step;

    for (p = 0; p < POLLS_PER_FRAME; p++) {
        drain_keys();                    /* read keys before waiting   */
        if (!running) return;
        for (i = 0; i < slice; i++) ;   /* busy-wait                  */
        drain_keys();                    /* read keys after waiting    */
        if (!running) return;
        if (p == 0 && status_pending) { /* deferred status bar update */
            draw_status();
            status_pending = 0;
        }
    }
}

/* ==================================================================
 * Audio - single BEL (0x07) on food eaten
 * ================================================================== */
static void beep(void)
{
    putchar(7);
}

/* ==================================================================
 * 16-bit LCG pseudo-random number generator
 * Seeded by player reaction time on the welcome screen.
 * ================================================================== */
static unsigned int mrand(void)
{
    rseed = rseed * 31421u + 6927u;
    return rseed;
}

/* ==================================================================
 * Box primitives
 *
 * draw_box  - heavy-line graphic border (welcome/goodbye/transitions).
 * rev_box   - same geometry but every border cell is a reverse-video
 *             space (solid filled bar); used for the game border and
 *             flip_transition.
 * erase_box - overwrite only the four border sides with plain spaces;
 *             used in box_transition phase 2.
 * draw_game_border - rev_box at the playfield boundary.
 * ================================================================== */
static void draw_box(int c1, int r1, int c2, int r2)
{
    int i;
    if (c2 <= c1 || r2 <= r1) return;
    gfx_on();
    gotoxy(c1, r1);
    putchar(GFX_CORNER_TL);
    for (i = c1 + 1; i < c2; i++) putchar(GFX_HORIZ);
    putchar(GFX_CORNER_TR);
    gotoxy(c1, r2);
    putchar(GFX_CORNER_BL);
    for (i = c1 + 1; i < c2; i++) putchar(GFX_HORIZ);
    putchar(GFX_CORNER_BR);
    for (i = r1 + 1; i < r2; i++) {
        gotoxy(c1, i); putchar(GFX_VERT);
        gotoxy(c2, i); putchar(GFX_VERT);
    }
    gfx_off();
}

static void rev_box(int c1, int r1, int c2, int r2)
{
    int i;
    if (c2 <= c1 || r2 <= r1) return;
    rev_on();
    gotoxy(c1, r1); for (i = c1; i <= c2; i++) putchar(' ');
    gotoxy(c1, r2); for (i = c1; i <= c2; i++) putchar(' ');
    for (i = r1 + 1; i < r2; i++) {
        gotoxy(c1, i); putchar(' ');
        gotoxy(c2, i); putchar(' ');
    }
    rev_off();
}

static void erase_box(int c1, int r1, int c2, int r2)
{
    int i, j;
    if (c2 <= c1 || r2 <= r1) return;
    gotoxy(c1, r1); for (j = c1; j <= c2; j++) putchar(' ');
    gotoxy(c1, r2); for (j = c1; j <= c2; j++) putchar(' ');
    for (i = r1 + 1; i < r2; i++) {
        gotoxy(c1, i); putchar(' ');
        gotoxy(c2, i); putchar(' ');
    }
}

static void draw_game_border(void)
{
    rev_box(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);
}

/* ==================================================================
 * box_transition(c1, r1, c2, r2)
 *
 * Tunnel/zoom transition effect. Only used in welcome_screen.
 *
 * Phase 1 - Collapse: draws nested graphic-char boxes inward,
 *           building a full tunnel over the welcome screen content.
 *
 * Phase 2 - Clear: erases frames from innermost to second-to-last.
 *           The outermost frame is replaced by rev_box and stays
 *           as the game border.
 *
 * No artificial delay: terminal baud rate is the natural pacing.
 * ================================================================== */
static void box_transition(int c1, int r1, int c2, int r2)
{
    int s, steps;

    steps = (c2 - c1 - 1) / 2;
    if ((r2 - r1 - 1) / 2 < steps) steps = (r2 - r1 - 1) / 2;
    if (steps < 1) steps = 1;

    for (s = 1; s <= steps; s++) {
        draw_box(c1 + s, r1 + s, c2 - s, r2 - s);
    }
    /* Phase 2 - Clear: erase frames innermost to second-to-last */
    for (s = steps; s >= 1; s--) {
        erase_box(c1 + s, r1 + s, c2 - s, r2 - s);
    }
    /* Outermost frame -> game border (rev-video), stays in place */
    rev_box(c1, r1, c2, r2);
}

/* ==================================================================
 * Welcome screen
 *
 * Interior rows 3-22 (20 rows), perfectly filled:
 *
 *   3    : blank
 *   4-10 : SUPER SNAKE pixel logo (7 rows, rev-video blocks)
 *  11    : blank
 *  12    : By Claude A.I. & RomaX ManiaX
 *  13    : blank
 *  14    : controls (movement keys)
 *  15    : controls (pause / quit)
 *  16    : blank
 *  17    : legend (food / walls / blobs / yourself)
 *  18    : scoring + bonus rule
 *  19-20 : blank
 *  21    : Enter your name :
 *  22    : blank
 *
 * PRNG seed accumulated while player types their name.
 * ENTER triggers the box_transition.
 * ================================================================== */

/* Print text centred in the playfield interior (no border drawn) */
static void bv_cbox(int row, const char *txt)
{
    int len = 0, col;
    const char *p = txt; while (*p++) len++;
    col = BORDER_C1 + 1 + (BOARD_W - len) / 2;
    if (len > 0) { gotoxy(col, row); fputs(txt, stdout); }
}

/* ==================================================================
 * draw_logo()
 *
 * "SUPER SNAKE" in a 5x7 pixel font, reverse-video spaces.
 * Width = 62 chars, centred in 78-col interior. Rows 4-10.
 * Bitmaps: 5 bits/row, bit4=leftmost col.
 * ================================================================== */
static void draw_logo(void)
{
    static const unsigned char glyph[8][7] = {
        {0x0E,0x10,0x10,0x0E,0x01,0x01,0x0E}, /* 0:S */
        {0x11,0x11,0x11,0x11,0x11,0x11,0x0E}, /* 1:U */
        {0x1E,0x11,0x11,0x1E,0x10,0x10,0x10}, /* 2:P */
        {0x1F,0x10,0x10,0x1E,0x10,0x10,0x1F}, /* 3:E */
        {0x1E,0x11,0x11,0x1E,0x14,0x12,0x11}, /* 4:R */
        {0x11,0x19,0x15,0x13,0x11,0x11,0x11}, /* 5:N */
        {0x0E,0x11,0x11,0x1F,0x11,0x11,0x11}, /* 6:A */
        {0x11,0x12,0x14,0x18,0x14,0x12,0x11}, /* 7:K */
    };
    /* SUPER SNAKE : -1 = word space (3 cols) */
    static const signed char seq[11] = {0,1,2,3,4,-1,0,5,6,7,3};
    /* width: 9 letters x(5+1gap) + 1 letter x5 + space x3 = 54+5+3=62 */
    int logo_start = BORDER_C1 + 1 + (BOARD_W - 62) / 2;
    int r, i, b, col, bits;

    for (r = 0; r < 7; r++) {
        col = logo_start;
        for (i = 0; i < 11; i++) {
            if (seq[i] < 0) { col += 3; continue; }
            bits = glyph[seq[i]][r];
            for (b = 4; b >= 0; b--) {
                if (bits & (1 << b)) {
                    gotoxy(col, BORDER_R1 + 2 + r);
                    rev_on(); putchar(' '); rev_off();
                }
                col++;
            }
            if (i < 10) col++;  /* inter-letter gap, not after last */
        }
    }
}

static void welcome_screen(void)
{
    const char *prompt;
    int plen, pcol, pos, nc, x;

    clrscr();
    cursor_off();
    draw_box(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);

    draw_logo();          /* rows 4-10, row 3 blank */
    bv_cbox(12, "By Claude A.I. & RomaX ManiaX");
    bv_cbox(14, "8 = Up  2 = Down  4 = Left  6 = Right");
    bv_cbox(15, "P = Pause     [ESC] = Quit");

    /* Row 17: mixed gfx/rev legend
     * content width = 60 chars, centred in 78 */
    x = BORDER_C1 + 1 + (BOARD_W - 60) / 2;
    gotoxy(x, 17); fputs("Eat food : ", stdout);   x += 11;
    gfx_on(); gotoxy(x, 17); putchar(GFX_FOOD); gfx_off(); x++;
    gotoxy(x, 17); fputs("  Avoid : Walls ", stdout); x += 16;
    rev_on(); putchar(' '); putchar(' '); putchar(' '); rev_off(); x += 3;
    gotoxy(x, 17); fputs("  &  Blobs ", stdout);   x += 11;
    gfx_on(); gotoxy(x, 17); putchar(GFX_BODY); gfx_off(); x++;
    gotoxy(x, 17); fputs("  & yourself ", stdout); x += 13;
    gfx_on();
    putchar(GFX_HEAD);
    putchar(GFX_HORIZ); putchar(GFX_HORIZ); putchar(GFX_HORIZ);
    gfx_off();

    bv_cbox(18, "Each food : +10 pts.  Bonus : up to +40 for fewer turns.");

    /* Row 21: name entry */
    prompt = "Enter your name : ";
    plen   = 0; { const char *p = prompt; while (*p++) plen++; }
    pcol   = BORDER_C1 + 1 + (BOARD_W - plen - HOF_NAMELEN) / 2;
    gotoxy(pcol, 21);
    fputs(prompt, stdout);
    cursor_on();

    rseed = 1;
    pos   = 0;
    for (;;) {
        nc = bdos(6, 0xFF);
        rseed += nc + 1u;
        if (nc == 0) continue;
        if (nc == 0x0D || nc == 0x0A) break;
        if ((nc == 0x08 || nc == 0x7F) && pos > 0) {
            pos--;
            gotoxy(pcol + plen + pos, 21);
            putchar(' ');
            gotoxy(pcol + plen + pos, 21);
            continue;
        }
        if (nc >= 0x20 && nc < 0x7F && pos < HOF_NAMELEN) {
            player_name[pos++] = (char)nc;
            putchar(nc);
        }
    }
    player_name[pos] = '\0';
    cursor_off();

    box_transition(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);
}

/* ==================================================================
 * Game drawing
 * ================================================================== */

/* Title bar - row 1, static */
static void draw_title(void)
{
    int i = 0;
    const char *t =
        "     [[ SUPER SNAKE V1.1 ]]        Zenith Z-89 / Heathkit H-89  |  CP/M 2.2";
    gotoxy(1, ROW_TITLE);
    fputs(t, stdout);
    while (t[i]) i++;
    for (; i < 80; i++) putchar(' ');
}

/* ==================================================================
 * Integer output helpers - no printf/sprintf overhead
 * ================================================================== */

/* Unsigned int, right-justified in a field of w chars (space-padded) */
static void put_uint_w(unsigned int v, int w)
{
    char tmp[6];
    int  n = 0, i;
    if (v == 0) { tmp[n++] = '0'; }
    else { unsigned int t = v; while (t) { tmp[n++] = '0' + t % 10; t /= 10; } }
    for (i = n; i < w; i++) putchar(' ');
    for (i = n - 1; i >= 0; i--) putchar(tmp[i]);
}

/* String, left-justified, padded with spaces to width w */
static void put_str_lj(const char *s, int w)
{
    int n = 0;
    while (*s) { putchar(*s++); n++; }
    while (n < w) { putchar(' '); n++; }
}

/* Status bar - row 24, dynamic
 * Left  : " Level : X/10"
 * Centre: "Score : XXXX"
 * Right : "[ESC] : Quit  [P] : Pause "            */
static void draw_status(void)
{
    char buf[81];
    int  i, n, rp;
    const char *rgt = "[ESC] : Quit  [P] : Pause ";
    const int   rl  = 26;
    char        sc[6];
    int         sn  = 0;
    unsigned    sv  = score;

    for (i = 0; i < 80; i++) buf[i] = ' ';
    buf[80] = '\0';

    /* Left: " Level : X/10" (12 or 13 chars) */
    n = 0;
    buf[n++]=' '; buf[n++]='L'; buf[n++]='e'; buf[n++]='v';
    buf[n++]='e'; buf[n++]='l'; buf[n++]=' '; buf[n++]=':'; buf[n++]=' ';
    if (level == 10) { buf[n++]='1'; buf[n++]='0'; }
    else buf[n++] = '0' + level;
    buf[n++]='/'; buf[n++]='1'; buf[n++]='0';

    /* Right */
    rp = 80 - rl;
    for (i = 0; i < rl; i++) buf[rp + i] = rgt[i];

    /* Centre: "Score : " (8) + score right-justified in 4 = 12 chars at col 34 */
    if (sv == 0) sc[sn++] = '0';
    else { unsigned int t = sv; while (t) { sc[sn++] = '0' + t % 10; t /= 10; } }
    n = 34;   /* (80 - 12) / 2 */
    buf[n++]='S'; buf[n++]='c'; buf[n++]='o'; buf[n++]='r';
    buf[n++]='e'; buf[n++]=' '; buf[n++]=':'; buf[n++]=' ';
    for (i = sn; i < 4; i++) buf[n++] = ' ';
    for (i = sn - 1; i >= 0; i--) buf[n++] = sc[i];

    gotoxy(1, ROW_STATUS);
    fputs(buf, stdout);
}

static void draw_food(void)
{
    gotoxy(SCR_COL(food.x), SCR_ROW(food.y));
    gfx_on(); putchar(GFX_FOOD); gfx_off();
}

static void place_food(void)
{
    int i, ok;
    unsigned int idx;
    do {
        food.x = (unsigned char)(mrand() % BOARD_W);
        food.y = (unsigned char)(mrand() % BOARD_H);
        ok = 1;
        for (i = 0; i < s_len; i++) {
            idx = (s_tail + i) % MAX_LEN;
            if (snake[idx].x == food.x && snake[idx].y == food.y) {
                ok = 0; break;
            }
        }
        if (ok && obs_cell_used(food.x, food.y)) ok = 0;
    } while (!ok);
    draw_food();
}

/* ==================================================================
 * seg_char - body character for a segment with two neighbours
 *
 * For each segment the two connections point from current toward
 * prev (tail side) and from current toward next (head side).
 * The character must have lines in exactly those two directions:
 *
 *   ━   LEFT  + RIGHT  (straight horizontal)
 *   ┃   UP    + DOWN   (straight vertical)
 *   ┓   LEFT  + DOWN   (top-right corner)
 *   ┛   LEFT  + UP     (bottom-right corner)
 *   ┏   RIGHT + DOWN   (top-left corner)
 *   ┗   RIGHT + UP     (bottom-left corner)
 * ================================================================== */
static char seg_char(unsigned int prv, unsigned int cur, unsigned int nxt)
{
    int d1h = (snake[prv].x != snake[cur].x); /* 1=horiz toward prev */
    int d2h = (snake[nxt].x != snake[cur].x); /* 1=horiz toward next */

    if (d1h == d2h)                            /* straight */
        return (char)(d1h ? GFX_HORIZ : GFX_VERT);

    /* corner: one direction horizontal, one vertical */
    if (d1h) {                                 /* prev is horizontal */
        if (snake[prv].x < snake[cur].x)       /* dir_to_prev = LEFT */
            return (char)(snake[nxt].y > snake[cur].y ? GFX_CORNER_TR : GFX_CORNER_BR);
        else                                    /* dir_to_prev = RIGHT */
            return (char)(snake[nxt].y > snake[cur].y ? GFX_CORNER_TL : GFX_CORNER_BL);
    } else {                                   /* prev is vertical */
        if (snake[prv].y < snake[cur].y)       /* dir_to_prev = UP */
            return (char)(snake[nxt].x < snake[cur].x ? GFX_CORNER_BR : GFX_CORNER_BL);
        else                                    /* dir_to_prev = DOWN */
            return (char)(snake[nxt].x < snake[cur].x ? GFX_CORNER_TR : GFX_CORNER_TL);
    }
}

static void draw_snake_full(void)
{
    int i;
    unsigned int idx, prv, nxt;
    gfx_on();
    for (i = 0; i < s_len; i++) {
        idx = (s_tail + i) % MAX_LEN;
        gotoxy(SCR_COL(snake[idx].x), SCR_ROW(snake[idx].y));
        if (i == s_len - 1) {
            putchar(GFX_HEAD);
        } else if (i == 0) {
            /* tail: only neighbour is toward head */
            nxt = (s_tail + 1) % MAX_LEN;
            putchar(snake[idx].x != snake[nxt].x ? GFX_HORIZ : GFX_VERT);
        } else {
            prv = (s_tail + i - 1) % MAX_LEN;
            nxt = (s_tail + i + 1) % MAX_LEN;
            putchar(seg_char(prv, idx, nxt));
        }
    }
    gfx_off();
}

/* ==================================================================
 * Game initialisation
 * ================================================================== */
static void init_game(void)
{
    int i;
    s_head     = INIT_LEN - 1;
    s_tail     = 0;
    s_len      = INIT_LEN;
    dir        = RIGHT;
    dir_qlen   = 0;
    score          = 0;
    food_count     = 0;
    dir_changes    = 0;
    status_pending = 0;
    esc_quit       = 0;
    game_complete  = 0;
    level          = 1;
    obs_count      = 0;
    obs_wall_start = 0;
    running        = 1;
    for (i = 0; i < INIT_LEN; i++) {
        snake[i].x = (unsigned char)i;
        snake[i].y = (unsigned char)(BOARD_H / 2);
    }
}

/* ==================================================================
 * Pause - blinks the status bar, no overlay on the playfield
 * ================================================================== */
static void do_pause(void)
{
    int blink = 0;
    volatile unsigned int d;

    for (;;) {
        int k;

        /* Blink: alternate between PAUSED bar and normal status bar */
        gotoxy(1, ROW_STATUS);
        if (blink) {
            rev_on();
            fputs("                                   [ PAUSED ]                                   ", stdout);
            rev_off();
        } else {
            draw_status();
        }
        blink = !blink;

        /* Busy-wait then poll key */
        for (d = 0; d < 12000u; d++) ;
        k = get_key();
        if (k == 'p' || k == 'P') break;
        if (k == 0x1B) { running = 0; esc_quit = 1; break; }
    }

    /* Restore normal status bar on resume; flush queued dirs (D) */
    if (running) {
        dir_qlen = 0;
        draw_status();
    }
}

/* ==================================================================
 * Obstacles - blobs and walls
 *
 * obs[]     : flat array of all obstacle cells (blobs + walls combined)
 * obs_count : total number of cells currently active
 *
 * obs_cell_used(x,y) : O(n) scan.
 *
 * Blobs: organic 4-connected growth from a random seed.
 * Walls: straight H or V segments, random length (WALL_LEN_MIN..MAX).
 *        Walls may touch blobs/walls but never cross them (obs_cell_used
 *        rejects any cell already occupied).
 *
 * Level groupings:
 *   2-4 : 3 blobs, 2 walls, blob size 10-20
 *   5-7 : 4 blobs, 3 walls, blob size 10-25
 *   8-10: 5 blobs, 4 walls, blob size 10-30
 * ================================================================== */
static int obs_cell_used(int x, int y)
{
    int i;
    for (i = 0; i < obs_count; i++)
        if (obs[i].x == x && obs[i].y == y) return 1;
    return 0;
}

/* Chebyshev distance check from start head (INIT_LEN-1, BOARD_H/2) */
static int obs_near_head(int x, int y)
{
    int dx = x - (INIT_LEN - 1);
    int dy = y - (BOARD_H / 2);
    if (dx < 0) dx = -dx;
    if (dy < 0) dy = -dy;
    return (dx > dy ? dx : dy) < OBS_SAFE_DIST;
}

static void place_obstacles(void)
{
    static const signed char ndx[4] = {  1, -1,  0,  0 };
    static const signed char ndy[4] = {  0,  0,  1, -1 };

    int b, w, n_blobs, n_walls, bmin, bmax;
    int blob_size, blob_target, att, d, sx, sy, bi, nx, ny;
    int horiz, wlen, wx, wy, k, ok;

    obs_count = 0;
    n_blobs = OBS_BLOBS(level);
    n_walls = OBS_WALLS(level);
    bmin    = OBS_BMIN(level);
    bmax    = OBS_BMAX(level);
    if (n_blobs <= 0 && n_walls <= 0) return;

    /* --- Blobs --- */
    for (b = 0; b < n_blobs; b++) {
        int global_att = 0;
        do {
            /* Pick seed */
            att = 0;
            do {
                sx = (mrand() % BOARD_W);
                sy = (mrand() % BOARD_H);
                att++;
            } while (att < 200 &&
                     (obs_near_head(sx, sy) || obs_cell_used(sx, sy)));
            if (att >= 200) break;

            bi = obs_count;
            obs[obs_count].x = (unsigned char)sx;
            obs[obs_count].y = (unsigned char)sy;
            obs_count++;

            /* Grow */
            blob_target = bmin + (mrand() % (bmax - bmin + 1));
            blob_size = 1;
            att = 0;
            while (blob_size < blob_target &&
                   obs_count < OBS_TOTAL_MAX && att < 100) {
                int origin = bi + (mrand() % blob_size);
                d  = (mrand() % 4);
                nx = obs[origin].x + ndx[d];
                ny = obs[origin].y + ndy[d];
                if (nx >= 0 && nx < BOARD_W &&
                    ny >= 0 && ny < BOARD_H &&
                    !obs_near_head(nx, ny) &&
                    !obs_cell_used(nx, ny)) {
                    obs[obs_count].x = (unsigned char)nx;
                    obs[obs_count].y = (unsigned char)ny;
                    obs_count++;
                    blob_size++;
                    att = 0;
                } else {
                    att++;
                }
            }

            /* Rollback if too small, try again */
            if (blob_size < bmin) obs_count = bi;
            global_att++;
        } while (blob_size < bmin && global_att < 20);
    }

    obs_wall_start = obs_count;  /* walls start here */

    /* --- Walls --- */
    for (w = 0; w < n_walls; w++) {
        att = 0;
        do {
            horiz = (mrand() % 2);  /* 1=horizontal, 0=vertical */
            wlen  = WALL_LEN_MIN + (mrand() % (WALL_LEN_MAX - WALL_LEN_MIN + 1));
            if (horiz) {
                wx = (mrand() % (BOARD_W - wlen));
                wy = (mrand() % BOARD_H);
            } else {
                wx = (mrand() % BOARD_W);
                wy = (mrand() % (BOARD_H - wlen));
            }
            /* Check all cells of the wall */
            ok = (obs_count + wlen <= OBS_TOTAL_MAX);
            for (k = 0; k < wlen && ok; k++) {
                nx = wx + (horiz ? k : 0);
                ny = wy + (horiz ? 0 : k);
                if (obs_near_head(nx, ny) || obs_cell_used(nx, ny))
                    ok = 0;
            }
            att++;
        } while (!ok && att < 200);

        if (!ok) continue;  /* give up on this wall */

        for (k = 0; k < wlen; k++) {
            obs[obs_count].x = (unsigned char)(wx + (horiz ? k : 0));
            obs[obs_count].y = (unsigned char)(wy + (horiz ? 0 : k));
            obs_count++;
        }
    }
}

static void draw_obstacles(void)
{
    int i;
    /* Blobs: GFX_BODY (▒) in graphic mode */
    gfx_on();
    for (i = 0; i < obs_wall_start; i++) {
        gotoxy(SCR_COL(obs[i].x), SCR_ROW(obs[i].y));
        putchar(GFX_BODY);
    }
    gfx_off();
    /* Walls: space in reverse video */
    rev_on();
    for (i = obs_wall_start; i < obs_count; i++) {
        gotoxy(SCR_COL(obs[i].x), SCR_ROW(obs[i].y));
        putchar(' ');
    }
    rev_off();
}

/* ==================================================================
 * matrix_rain()
 *
 * Matrix-style character rain over the full 80x24 screen.
 * Columns activated in random order, speed driven by baud rate.
 * Characters: printable ASCII 0x21-0x5A (safe, no gfx mode).
 * Screen is NOT cleared before or after - caller's responsibility.
 * ================================================================== */
#define MAT_COLS   80
#define MAT_ROWS   24
#define MAT_TRAIL   6
#define MAT_CHAR() (0x21 + mrand() % 0x3A)

static void matrix_rain(void)
{
    static unsigned char head [MAT_COLS];
    static unsigned char timer[MAT_COLS];
    static unsigned char speed[MAT_COLS];
    static unsigned char order[MAT_COLS];
    int col, i, done, frame, tmp;

    for (i = 0; i < MAT_COLS; i++) order[i] = (unsigned char)i;
    for (i = MAT_COLS - 1; i > 0; i--) {
        int j = (mrand() % (i + 1));
        tmp = order[i]; order[i] = order[j]; order[j] = (unsigned char)tmp;
    }
    for (col = 0; col < MAT_COLS; col++) {
        head[col]  = 0;
        speed[col] = (unsigned char)(1 + (mrand() % 3));
        timer[col] = (unsigned char)((mrand() % 8));
    }

    frame = 0;
    for (;;) {
        i = frame / 3;
        if (i < MAT_COLS && head[order[i]] == 0)
            head[order[i]] = 1;

        done = 1;
        for (col = 0; col < MAT_COLS; col++) {
            if (head[col] == 0) { done = 0; continue; }
            if (head[col] > MAT_ROWS + MAT_TRAIL) continue;
            done = 0;

            if (timer[col] > 0) { timer[col]--; continue; }
            timer[col] = speed[col];

            if (head[col] <= MAT_ROWS) {
                gotoxy(col + 1, head[col]);
                putchar(MAT_CHAR());
            }
            if (head[col] > 1 && head[col] - 1 <= MAT_ROWS) {
                gotoxy(col + 1, head[col] - 1);
                putchar(MAT_CHAR());
            }
            if (head[col] - MAT_TRAIL > 0 &&
                head[col] - MAT_TRAIL <= MAT_ROWS) {
                gotoxy(col + 1, head[col] - MAT_TRAIL);
                putchar(' ');
            }
            head[col]++;
        }
        frame++;
        if (done) break;
    }
}

/* ==================================================================
 * flip_transition(c1, r1, c2, r2)
 *
 * Horizontal flip effect: top and bottom borders move toward the
 * centre while left and right borders shrink accordingly.
 *
 * Phase 1 - Close: top border moves down, bottom border moves up,
 *           one row per frame, until they meet at the centre.
 *           Each frame erases the previous border and draws the new one.
 *
 * Phase 2 - Open: reverse, expanding back to (c1,r1)-(c2,r2).
 *           The final frame restores the original border.
 * ================================================================== */
static void flip_transition(int c1, int r1, int c2, int r2)
{
    int step, half, tr, br, i;
    half = (r2 - r1) / 2;

    /* Phase 1 - close */
    for (step = 0; step <= half; step++) {
        tr = r1 + step;
        br = r2 - step;
        if (step > 0) {
            gotoxy(c1, tr - 1); for (i = c1; i <= c2; i++) putchar(' ');
            gotoxy(c1, br + 1); for (i = c1; i <= c2; i++) putchar(' ');
        }
        if (tr <= br) rev_box(c1, tr, c2, br);
    }

    /* Phase 2 - open */
    for (step = half - 1; step >= 0; step--) {
        tr = r1 + step;
        br = r2 - step;
        gotoxy(c1, tr + 1); for (i = c1; i <= c2; i++) putchar(' ');
        gotoxy(c1, br - 1); for (i = c1; i <= c2; i++) putchar(' ');
        rev_box(c1, tr, c2, br);
    }
}

/* ==================================================================
 * blinds(c1, r1, c2, r2)
 * Venetian blinds: GFX_BODY fill forward, clear backward.
 * Even rows first (pass 0), odd rows next (pass 1), then reverse.
 * ================================================================== */
static void blinds(int c1, int r1, int c2, int r2)
{
    int row, col, pass;
    /* Fill phase: even rows then odd rows */
    gfx_on();
    for (pass = 0; pass < 2; pass++) {
        for (row = r1 + 1 + pass; row < r2; row += 2) {
            gotoxy(c1 + 1, row);
            for (col = c1 + 1; col < c2; col++) putchar(GFX_BODY);
        }
    }
    gfx_off();
    /* Clear phase: odd rows then even rows */
    for (pass = 1; pass >= 0; pass--) {
        for (row = r1 + 1 + pass; row < r2; row += 2) {
            gotoxy(c1 + 1, row);
            for (col = c1 + 1; col < c2; col++) putchar(' ');
        }
    }
}

/* ==================================================================
 * checkerboard(c1, r1, c2, r2)
 * Checkerboard 6x4 blocks: fill with GFX_BODY ('i'=0x69) then clear.
 * 78/6=13 cols, 20/4=5 rows = 65 blocks, full interior coverage.
 * Pass 0: fill even blocks, pass 1: fill odd -> full screen.
 * Then reverse: clear odd, clear even -> screen empty.
 * ================================================================== */
static void checkerboard(int c1, int r1, int c2, int r2)
{
    int bc, br, r, c, pass;
    int n_bc = (c2 - c1 - 1) / CB_BW;   /* 13 */
    int n_br = (r2 - r1 - 1) / CB_BH;   /*  5 */

    /* Fill phase: even blocks then odd blocks */
    gfx_on();
    for (pass = 0; pass < 2; pass++) {
        for (br = 0; br < n_br; br++)
            for (bc = 0; bc < n_bc; bc++)
                if (((bc + br) & 1) == pass) {
                    int cs = c1 + 1 + bc * CB_BW;
                    int rs = r1 + 1 + br * CB_BH;
                    for (r = 0; r < CB_BH; r++) {
                        gotoxy(cs, rs + r);
                        for (c = 0; c < CB_BW; c++) putchar(GFX_BODY);
                    }
                }
    }
    gfx_off();

    /* Clear phase: odd blocks then even blocks */
    for (pass = 1; pass >= 0; pass--) {
        for (br = 0; br < n_br; br++)
            for (bc = 0; bc < n_bc; bc++)
                if (((bc + br) & 1) == pass) {
                    int cs = c1 + 1 + bc * CB_BW;
                    int rs = r1 + 1 + br * CB_BH;
                    for (r = 0; r < CB_BH; r++) {
                        gotoxy(cs, rs + r);
                        for (c = 0; c < CB_BW; c++) putchar(' ');
                    }
                }
    }
}

/* ==================================================================
 * rain_down(c1, r1, c2, r2)
 * Row by row top to bottom: GFX_BODY fill forward, clear backward.
 * ================================================================== */
static void rain_down(int c1, int r1, int c2, int r2)
{
    int row, col;
    /* Fill phase: top to bottom */
    gfx_on();
    for (row = r1 + 1; row < r2; row++) {
        gotoxy(c1 + 1, row);
        for (col = c1 + 1; col < c2; col++) putchar(GFX_BODY);
    }
    gfx_off();
    /* Clear phase: bottom to top */
    for (row = r2 - 1; row > r1; row--) {
        gotoxy(c1 + 1, row);
        for (col = c1 + 1; col < c2; col++) putchar(' ');
    }
}

/* ==================================================================
 * sablier(c1, r1, c2, r2)
 *
 * Hourglass: two rows fill simultaneously — one from top downward,
 * one from bottom upward — meeting in the middle with GFX_BODY.
 * Then the two fronts separate back toward the borders and clear.
 * ================================================================== */
static void sablier(int c1, int r1, int c2, int r2)
{
    int inner_h, half, step, rt, rb, col;
    inner_h = r2 - r1 - 1;     /* 20 */
    half    = inner_h / 2;      /* 10 */

    /* Fill phase: top row moves down, bottom row moves up */
    gfx_on();
    for (step = 0; step < half; step++) {
        rt = r1 + 1 + step;          /* top front   */
        rb = r2 - 1 - step;          /* bottom front */
        gotoxy(c1 + 1, rt);
        for (col = c1 + 1; col < c2; col++) putchar(GFX_BODY);
        gotoxy(c1 + 1, rb);
        for (col = c1 + 1; col < c2; col++) putchar(GFX_BODY);
    }
    /* Fill the middle row(s) if inner_h is odd */
    if (inner_h & 1) {
        gotoxy(c1 + 1, r1 + 1 + half);
        for (col = c1 + 1; col < c2; col++) putchar(GFX_BODY);
    }
    gfx_off();

    /* Clear phase: fronts separate back toward borders */
    for (step = half - 1; step >= 0; step--) {
        rt = r1 + 1 + step;
        rb = r2 - 1 - step;
        gotoxy(c1 + 1, rt);
        for (col = c1 + 1; col < c2; col++) putchar(' ');
        gotoxy(c1 + 1, rb);
        for (col = c1 + 1; col < c2; col++) putchar(' ');
    }
    if (inner_h & 1) {
        gotoxy(c1 + 1, r1 + 1 + half);
        for (col = c1 + 1; col < c2; col++) putchar(' ');
    }
}

/* ==================================================================
 * diagonal(c1, r1, c2, r2)
 *
 * Fill: slices row+col=d, top-left -> bottom-right (longest bar near top).
 * Clear: slices (ih-1-row)+col=d, bottom-left -> top-right (inverse diagonal).
 * ================================================================== */
static void diagonal(int c1, int r1, int c2, int r2)
{
    int iw, ih, d, dmax, row, col;
    iw   = c2 - c1 - 1;    /* 78 */
    ih   = r2 - r1 - 1;    /* 20 */
    dmax = iw + ih - 2;     /* 96 */

    /* Fill phase: top-left -> bottom-right */
    gfx_on();
    for (d = 0; d <= dmax; d++) {
        for (row = 0; row < ih; row++) {
            col = d - row;
            if (col < 0 || col >= iw) continue;
            gotoxy(c1 + 1 + col, r1 + 1 + row);
            putchar(GFX_BODY);
        }
    }
    gfx_off();

    /* Clear phase: right -> left (slices col-row=offset, offset iw-1 -> -(ih-1)) */
    for (d = 0; d <= dmax; d++) {
        int offset = iw - 1 - d;
        for (row = 0; row < ih; row++) {
            col = row + offset;
            if (col < 0 || col >= iw) continue;
            gotoxy(c1 + 1 + col, r1 + 1 + row);
            putchar(' ');
        }
    }
}

/* ==================================================================
 * spiral(c1, r1, c2, r2)
 *
 * Fill interior in clockwise spiral from border inward with GFX_BODY
 * (top row L->R, right col T->B, bottom row R->L, left col B->T),
 * layer by layer. Then clear from innermost layer outward.
 *
 * Stores layer count; max layers = min(iw,ih)/2 = 10.
 * ================================================================== */
static void spiral(int c1, int r1, int c2, int r2)
{
    int t, b, l, r, i, layer;
    int layers = 0;
    int lt[SP_MAXLAYERS], lb[SP_MAXLAYERS];
    int ll[SP_MAXLAYERS], lr[SP_MAXLAYERS];

    /* Fill phase: spiral inward */
    gfx_on();
    t = r1 + 1; b = r2 - 1;
    l = c1 + 1; r = c2 - 1;
    while (t <= b && l <= r && layers < SP_MAXLAYERS) {
        lt[layers] = t; lb[layers] = b;
        ll[layers] = l; lr[layers] = r;
        layers++;

        /* Top row: l -> r */
        gotoxy(l, t);
        for (i = l; i <= r; i++) putchar(GFX_BODY);

        /* Right col: t+1 -> b */
        for (i = t + 1; i <= b; i++) { gotoxy(r, i); putchar(GFX_BODY); }

        /* Bottom row: r-1 -> l (only if distinct from top) */
        if (b > t) {
            for (i = r - 1; i >= l; i--) { gotoxy(i, b); putchar(GFX_BODY); }
        }

        /* Left col: b-1 -> t+1 (only if distinct from right) */
        if (l < r) {
            for (i = b - 1; i > t; i--) { gotoxy(l, i); putchar(GFX_BODY); }
        }

        t++; b--; l++; r--;
    }
    gfx_off();

    /* Clear phase: unwind outward, reverse order (left->bottom->right->top) */
    for (layer = layers - 1; layer >= 0; layer--) {
        t = lt[layer]; b = lb[layer];
        l = ll[layer]; r = lr[layer];

        if (l < r) {
            for (i = b - 1; i > t; i--) { gotoxy(l, i); putchar(' '); }
        }
        if (b > t) {
            for (i = l; i <= r - 1; i++) { gotoxy(i, b); putchar(' '); }
        }
        for (i = b; i >= t + 1; i--) { gotoxy(r, i); putchar(' '); }

        gotoxy(l, t);
        for (i = l; i <= r; i++) putchar(' ');
    }
}

/* ==================================================================
 * tetris_fill(c1, r1, c2, r2)
 *
 * 2x-scaled tetrominos: each logical cell = 2x2 physical chars.
 * Logical grid: 39x10. Greedy tiling (random shape order), then
 * shuffle display order. Erase phase re-shuffles and blanks.
 * ================================================================== */
static void tetris_fill(int c1, int r1, int c2, int r2)
{
    static const signed char tsh[TF_NS][8] = {
        { 0,0,  0,1,  1,0,  1,1},  /* 0: O   */
        { 0,0,  0,1,  0,2,  0,3},  /* 1: I-H */
        { 0,0,  1,0,  2,0,  3,0},  /* 2: I-V */
        { 0,0,  1,0,  2,0,  2,1},  /* 3: L   */
        { 0,0,  0,1,  0,2,  1,0},  /* 4: J   */
        { 0,0,  0,1,  0,2,  1,1},  /* 5: T   */
        { 0,0,  0,1,  0,0,  0,0},  /* 6: H-domino (nc=2) */
        { 0,0,  1,0,  0,0,  0,0},  /* 7: V-domino (nc=2) */
        { 0,0,  0,0,  0,0,  0,0},  /* 8: monomino (nc=1) */
    };
    static const unsigned char tnc[TF_NS] = {4,4,4,4,4,4,2,2,1};
    static unsigned char brd[10][39];
    static unsigned char t_r[TF_MP], t_c[TF_MP], t_s[TF_MP], t_o[TF_MP];
    unsigned char st[6];
    int lw, lh, row, col, s, k, c, fits, np, i, j, tmp;
    int idx, sv, p_row, p_col, dr, dc, px, py, rr, cc;

    lw = (c2 - c1 - 1) / 2;   /* 39 */
    lh = (r2 - r1 - 1) / 2;   /* 10 */
    np = 0;

    for (row = 0; row < lh; row++)
        for (col = 0; col < lw; col++)
            brd[row][col] = 0;

    for (row = 0; row < lh && np < TF_MP; row++) {
        for (col = 0; col < lw && np < TF_MP; col++) {
            if (brd[row][col]) continue;

            for (k = 0; k < 6; k++) st[k] = (unsigned char)k;
            for (k = 5; k > 0; k--) {
                j = (mrand() % (k + 1));
                tmp = st[k]; st[k] = st[j]; st[j] = (unsigned char)tmp;
            }

            fits = 0; sv = 8;
            for (s = 0; s < 6 && !fits; s++) {
                sv = st[s]; fits = 1;
                for (c = 0; c < 4 && fits; c++) {
                    rr = row + tsh[sv][c*2];
                    cc = col + tsh[sv][c*2+1];
                    if (rr >= lh || cc < 0 || cc >= lw || brd[rr][cc]) fits = 0;
                }
            }
            if (!fits && col+1 < lw && !brd[row][col+1]) { sv = 6; fits = 1; }
            if (!fits && row+1 < lh && !brd[row+1][col]) { sv = 7; fits = 1; }
            if (!fits) sv = 8;

            for (c = 0; c < tnc[sv]; c++) {
                rr = row + tsh[sv][c*2];
                cc = col + tsh[sv][c*2+1];
                brd[rr][cc] = 1;
            }
            t_r[np] = (unsigned char)row;
            t_c[np] = (unsigned char)col;
            t_s[np] = (unsigned char)sv;
            np++;
        }
    }

    for (i = 0; i < np; i++) t_o[i] = (unsigned char)i;
    for (i = np - 1; i > 0; i--) {
        j = (mrand() % (i + 1));
        tmp = t_o[i]; t_o[i] = t_o[j]; t_o[j] = (unsigned char)tmp;
    }

    /* Fill: each logical cell drawn as 2x2 physical block */
    gfx_on();
    for (k = 0; k < np; k++) {
        idx = t_o[k]; sv = t_s[idx];
        p_row = t_r[idx]; p_col = t_c[idx];
        for (c = 0; c < tnc[sv]; c++) {
            dr = tsh[sv][c*2]; dc = tsh[sv][c*2+1];
            px = c1 + 1 + (p_col + dc) * 2;
            py = r1 + 1 + (p_row + dr) * 2;
            gotoxy(px, py);     putchar(GFX_BODY); putchar(GFX_BODY);
            gotoxy(px, py + 1); putchar(GFX_BODY); putchar(GFX_BODY);
        }
    }
    gfx_off();

    for (i = np - 1; i > 0; i--) {
        j = (mrand() % (i + 1));
        tmp = t_o[i]; t_o[i] = t_o[j]; t_o[j] = (unsigned char)tmp;
    }

    /* Erase: same pieces blanked in new random order */
    for (k = 0; k < np; k++) {
        idx = t_o[k]; sv = t_s[idx];
        p_row = t_r[idx]; p_col = t_c[idx];
        for (c = 0; c < tnc[sv]; c++) {
            dr = tsh[sv][c*2]; dc = tsh[sv][c*2+1];
            px = c1 + 1 + (p_col + dc) * 2;
            py = r1 + 1 + (p_row + dr) * 2;
            gotoxy(px, py);     putchar(' '); putchar(' ');
            gotoxy(px, py + 1); putchar(' '); putchar(' ');
        }
    }
}

/* ==================================================================
 * heart_transition(c1, r1, c2, r2)
 *
 * 1. Clear interior.
 * 2. Two snakes move toward each other on the widest heart row.
 * 3. At head-to-head meeting, heart grows row by row (top->bottom).
 *    Heart: 13 rows x 26 cols (~2/3 of BOARD_H), centred.
 * 4. Heart held ~0.5 s.
 * 5. Clear interior.
 * ================================================================== */
static void heart_transition(int c1, int r1, int c2, int r2)
{
    /* Per-row fill spans: col offsets (0-based) from h_left.
     * s[2] < 0 means single span; otherwise two separate spans. */
    static const signed char hs[HT_H_ROWS][4] = {
        { 3,  9, 17, 23},  /* row  0: two bumps (7 wide, gap 7) */
        { 0, 11, 14, 25},  /* row  1: wider, gap 2              */
        { 0, 25, -1, -1},  /* row  2: solid                     */
        { 0, 25, -1, -1},  /* row  3                            */
        { 1, 24, -1, -1},  /* row  4                            */
        { 3, 22, -1, -1},  /* row  5                            */
        { 5, 20, -1, -1},  /* row  6                            */
        { 7, 18, -1, -1},  /* row  7                            */
        { 9, 16, -1, -1},  /* row  8                            */
        {11, 14, -1, -1},  /* row  9                            */
        {11, 14, -1, -1},  /* row 10                            */
        {12, 13, -1, -1},  /* row 11                            */
        {13, 13, -1, -1},  /* row 12: single-char tip           */
    };

    int h_left, h_top, snk_row;
    int l_head, r_head;
    int i, col;
    volatile unsigned int d;

    /* Heart anchor (screen coords, 1-based) */
    h_left  = c1 + 1 + (BOARD_W - HT_H_COLS) / 2;  /* = 28 */
    h_top   = r1 + 1 + (BOARD_H - HT_H_ROWS) / 2;  /* =  6 */
    snk_row = h_top + 3;  /* heart row 3 = widest solid row = screen row 9 */

    /* ---- 1. Clear interior --------------------------------------- */
    for (i = r1 + 1; i < r2; i++) {
        gotoxy(c1 + 1, i);
        for (col = 0; col < BOARD_W; col++) putchar(' ');
    }

    /* ---- 2. Snake animation -------------------------------------- */
    l_head = c1 + 1 + HT_SNK_LEN - 1;   /* left  head screen col: 8  */
    r_head = c2 - 1 - HT_SNK_LEN + 1;   /* right head screen col: 73 */

    while (l_head < r_head) {
        /* Erase snake row */
        gotoxy(c1 + 1, snk_row);
        for (col = 0; col < BOARD_W; col++) putchar(' ');

        /* Left snake: body then head */
        gfx_on();
        for (i = l_head - HT_SNK_LEN + 1; i < l_head; i++) {
            gotoxy(i, snk_row); putchar(GFX_HORIZ);
        }
        gotoxy(l_head, snk_row); putchar(GFX_HEAD);

        /* Right snake: head then body */
        gotoxy(r_head, snk_row); putchar(GFX_HEAD);
        for (i = r_head + 1; i <= r_head + HT_SNK_LEN - 1; i++) {
            gotoxy(i, snk_row); putchar(GFX_HORIZ);
        }
        gfx_off();

        for (d = 0; d < 800u; d++) ;  /* inter-frame delay */
        l_head++;
        r_head--;
    }

    /* Clear snake row */
    gotoxy(c1 + 1, snk_row);
    for (col = 0; col < BOARD_W; col++) putchar(' ');

    /* ---- 3. Grow heart (row by row, top to bottom) --------------- */
    gfx_on();
    for (i = 0; i < HT_H_ROWS; i++) {
        int row = h_top + i;
        /* First span */
        gotoxy(h_left + hs[i][0], row);
        for (col = hs[i][0]; col <= hs[i][1]; col++)
            putchar(GFX_BODY);
        /* Second span (if any) */
        if (hs[i][2] >= 0) {
            gotoxy(h_left + hs[i][2], row);
            for (col = hs[i][2]; col <= hs[i][3]; col++)
                putchar(GFX_BODY);
        }
        for (d = 0; d < 3000u; d++) ;  /* delay per row */
    }
    gfx_off();

    /* ---- 4. Hold ~1 s ------------------------------------------- */
    { volatile unsigned int j;
      for (j = 0u; j < 18500u; j++) ; }

    /* ---- 5. Clear interior --------------------------------------- */
    for (i = r1 + 1; i < r2; i++) {
        gotoxy(c1 + 1, i);
        for (col = 0; col < BOARD_W; col++) putchar(' ');
    }
}

/* ==================================================================
 * Level transition
 *
 * Triggered when food_count reaches FOOD_PER_LEVEL.
 * After level 10: sets game_complete and returns without resetting.
 * Each level has its own transition animation:
 *   1->2  : checkerboard
 *   2->3  : blinds
 *   3->4  : flip_transition
 *   4->5  : rain_down
 *   5->6  : heart_transition
 *   6->7  : sablier
 *   7->8  : diagonal
 *   8->9  : spiral
 *   9->10 : tetris_fill
 * ================================================================== */
static void next_level(void)
{
    int i;

    level++;

    /* Level 10 complete: trigger matrix + goodbye in main() */
    if (level > 10) {
        game_complete = 1;
        running = 0;
        return;
    }

    /* Transition animation based on destination level */
    switch (level) {
        case 2:
            checkerboard(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);
            break;
        case 3:
            blinds(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);
            break;
        case 4:
            flip_transition(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);
            break;
        case 5:
            rain_down(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);
            break;
        case 6:
            heart_transition(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);
            break;
        case 7:
            sablier(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);
            break;
        case 8:
            diagonal(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);
            break;
        case 9:
            spiral(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);
            break;
        case 10:
            tetris_fill(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);
            break;
    }

    /* Reset snake buffer to horizontal centre, keep current s_len */
    s_head       = s_len - 1;
    s_tail       = 0;
    dir          = RIGHT;
    dir_qlen     = 0;
    food_count   = 0;
    dir_changes  = 0;
    for (i = 0; i < s_len; i++) {
        int x = INIT_LEN - 1 - (s_len - 1 - i);
        snake[i].x = (unsigned char)(x < 0 ? 0 : x);
        snake[i].y = (unsigned char)(BOARD_H / 2);
    }

    place_obstacles();
    draw_game_border();
    draw_snake_full();
    draw_obstacles();
    place_food();
    draw_status();
}

/* ==================================================================
 * Game step - advance the snake by one cell
 * ================================================================== */
static void update(void)
{
    int nx, ny, eating, i, start, lim, prev_head;
    unsigned int idx;

    /* Consume next queued direction (D) */
    if (dir_qlen > 0) {
        int nd = dir_queue[0];
        dir_queue[0] = dir_queue[1];
        dir_qlen--;
        if (nd != dir) { dir_changes++; dir = nd; }
    }

    nx = snake[s_head].x;
    ny = snake[s_head].y;
    switch (dir) {
        case UP:    ny--; break;
        case DOWN:  ny++; break;
        case LEFT:  nx--; break;
        case RIGHT: nx++; break;
    }

    /* Wall collision */
    if (nx < 0 || nx >= BOARD_W || ny < 0 || ny >= BOARD_H) {
        running = 0; return;
    }

    /* Obstacle collision */
    if (obs_cell_used(nx, ny)) { running = 0; return; }

    eating = (nx == food.x && ny == food.y);

    /* Self-collision
     * Eating: tail stays this step -> check all s_len segments.
     * Moving: tail frees its cell  -> skip it (s_len-1 segments). */
    start = eating ? s_tail             : (s_tail + 1) % MAX_LEN;
    lim   = eating ? s_len              : s_len - 1;
    for (i = 0; i < lim; i++) {
        idx = (start + i) % MAX_LEN;
        if (snake[idx].x == nx && snake[idx].y == ny) {
            running = 0; return;
        }
    }

    prev_head = s_head;

    if (eating) {
        score += 10;
        food_count++;
        s_len++;                        /* tail stays this step -> +1 segment */
        if (s_len >= MAX_LEN) { running = 0; return; }
    } else {
        gotoxy(SCR_COL(snake[s_tail].x), SCR_ROW(snake[s_tail].y));
        putchar(' ');
        s_tail = (s_tail + 1) % MAX_LEN;
    }

    s_head = (s_head + 1) % MAX_LEN;
    snake[s_head].x = (unsigned char)nx;
    snake[s_head].y = (unsigned char)ny;

    gfx_on();
    gotoxy(SCR_COL(snake[prev_head].x), SCR_ROW(snake[prev_head].y));
    putchar(seg_char((prev_head + MAX_LEN - 1) % MAX_LEN,
                     prev_head,
                     s_head));
    gotoxy(SCR_COL(snake[s_head].x), SCR_ROW(snake[s_head].y));
    putchar(GFX_HEAD);
    gfx_off();

    if (eating) {
        status_pending = 1;
        beep();
        if (food_count >= FOOD_PER_LEVEL) {
            /* Bonus: 40 - dir_changes; min 0, max 40 (zero turns). */
            int bonus = 40 - dir_changes;
            if (bonus < 0) bonus = 0;
            score += bonus;
            /* Flush status and show bonus before transition */
            status_pending = 0;
            draw_status();
            {
                int blen, bcol, brow;
                blen = 16 + (bonus >= 10 ? 2 : 1) + 9;
                bcol = BORDER_C1 + 1 + (BOARD_W - blen) / 2;
                brow = BORDER_R1 + 1 + (BOARD_H / 2) - 1;
                gotoxy(bcol, brow);
                rev_on();
                fputs("  BONUS TURNS = ", stdout);
                if (bonus >= 10) putchar('0' + bonus / 10);
                putchar('0' + bonus % 10);
                fputs(" POINTS  ", stdout);
                rev_off();
            }
            next_level();
            return;
        }
        place_food();
    }
}

/* ==================================================================
 * Hall of Fame  -  SSNAKE.DAT
 *
 * Binary format: 5 entries x 19 bytes
 *   17 bytes : name (null-terminated, zero-padded)
 *    2 bytes : score (little-endian unsigned 16-bit)
 * ================================================================== */
#define HOF_FILE    "SSNAKE.DAT"
#define HOF_SIZE    5

typedef struct {
    char     name[HOF_NAMELEN + 1];
    unsigned score;
} HofEntry;

static void hof_read(HofEntry hof[HOF_SIZE])
{
    FILE *f;
    int   i, j;
    for (i = 0; i < HOF_SIZE; i++) { hof[i].name[0] = '\0'; hof[i].score = 0; }
    f = fopen(HOF_FILE, "rb");
    if (!f) return;
    for (i = 0; i < HOF_SIZE; i++) {
        int lo, hi;
        for (j = 0; j <= HOF_NAMELEN; j++) {
            int c = fgetc(f); if (c == EOF) { fclose(f); return; }
            hof[i].name[j] = (char)c;
        }
        lo = fgetc(f); if (lo == EOF) { fclose(f); return; }
        hi = fgetc(f); if (hi == EOF) { fclose(f); return; }
        hof[i].score = (unsigned)lo | ((unsigned)hi << 8);
    }
    fclose(f);
}

static void hof_write(HofEntry hof[HOF_SIZE])
{
    FILE    *f;
    int      i, j;
    unsigned s;
    f = fopen(HOF_FILE, "wb");
    if (!f) return;
    for (i = 0; i < HOF_SIZE; i++) {
        for (j = 0; j <= HOF_NAMELEN; j++) fputc(hof[i].name[j], f);
        s = hof[i].score;
        fputc(s & 0xFF, f);
        fputc(s >> 8,   f);
    }
    fclose(f);
}

static int hof_in_top5(HofEntry hof[HOF_SIZE], unsigned sc)
{
    int i;
    for (i = 0; i < HOF_SIZE; i++)
        if (sc > hof[i].score) return 1;
    return 0;
}

static void hof_insert(HofEntry hof[HOF_SIZE], const char *name, unsigned sc)
{
    int i, j;
    for (i = 0; i < HOF_SIZE; i++)
        if (sc > hof[i].score) break;
    if (i == HOF_SIZE) return;
    for (j = HOF_SIZE - 1; j > i; j--) hof[j] = hof[j-1];
    for (j = 0; j < HOF_NAMELEN && name[j]; j++) hof[i].name[j] = name[j];
    hof[i].name[j] = '\0';
    hof[i].score = sc;
}

/* ==================================================================
 * Goodbye screen
 *
 * Thank-you box: rows 2-9.
 * HOF: centred on 80 cols, rows 12-20.
 * If score is top-5 and show_entry=1, saves player_name (entered
 * at welcome screen) and redraws HOF with new entry.
 * ================================================================== */
#define GBY_BC  14
#define GBY_BW  50
#define GBY_BR   2
#define HOF_COL_NO    25    /* column: entry number */
#define HOF_COL_NAME  29    /* column: player name  */
#define HOF_COL_SCORE 50    /* column: score        */

static void hof_draw_entries(HofEntry hof[HOF_SIZE])
{
    int i;
    for (i = 0; i < HOF_SIZE; i++) {
        gotoxy(HOF_COL_NO, 16 + i);
        putchar('0' + i + 1); putchar('.');
        if (hof[i].name[0] != '\0') {
            gotoxy(HOF_COL_NAME,  16 + i); put_str_lj(hof[i].name, 16);
            gotoxy(HOF_COL_SCORE, 16 + i); put_uint_w(hof[i].score, 5);
        } else {
            fputs("  ---", stdout);
        }
    }
}

/* Draw one interior row of the goodbye box: vertical borders + centred text */
static void gcbox_line(int row, const char *txt)
{
    int l = 0, p;
    const char *q = txt; while (*q++) l++;
    p = (GBY_BW - l) / 2;
    gfx_on();
    gotoxy(GBY_BC,              row); putchar(GFX_VERT);
    gotoxy(GBY_BC + GBY_BW + 1, row); putchar(GFX_VERT);
    gfx_off();
    if (l > 0) { gotoxy(GBY_BC + 1 + p, row); fputs(txt, stdout); }
}

static void goodbye_screen(unsigned sc, int show_entry)
{
    HofEntry hof[HOF_SIZE];
    int i, k, in_top5;

    clrscr();

    hof_read(hof);
    in_top5 = hof_in_top5(hof, sc);

    cursor_off();

    /* Thank-you box: rows 2-9 */
    draw_box(GBY_BC, GBY_BR, GBY_BC + GBY_BW + 1, GBY_BR + 7);
    gcbox_line(GBY_BR + 1, "");
    gcbox_line(GBY_BR + 2, "Goodbye !");
    gcbox_line(GBY_BR + 3, "");
    gcbox_line(GBY_BR + 4, "Thanks for playing Super Snake.");
    gcbox_line(GBY_BR + 5, "Hope to see you again soon !");
    gcbox_line(GBY_BR + 6, "");

    /* HOF - always at row 12
     * 12: title   13: (blank)   14: headers   15: separator   16-20: entries */
    {
        const char *htitle = "*** HALL OF FAME - TOP 5 ***";
        gotoxy((80 - 28) / 2, 12);
        rev_on(); fputs(htitle, stdout); rev_off();
    }
    gotoxy(HOF_COL_NO,    14); fputs("No",    stdout);
    gotoxy(HOF_COL_NAME,  14); fputs("Name",  stdout);
    gotoxy(HOF_COL_SCORE, 14); fputs("Score", stdout);
    gotoxy(HOF_COL_NO,    15);
    for (k = 0; k < (HOF_COL_SCORE - HOF_COL_NO + 5); k++) putchar('-');
    hof_draw_entries(hof);

    /* Save score if top-5 and game over (not ESC) */
    if (in_top5 && show_entry) {
        const char *name = player_name[0] ? player_name : "???";
        hof_insert(hof, name, sc);
        hof_write(hof);
        hof_draw_entries(hof);
    }

    cursor_on();
}

/* ==================================================================
 * Entry point
 * ================================================================== */
int main(void)
{
    welcome_screen();

    init_game();
    draw_title();
    draw_game_border();
    draw_snake_full();
    place_food();
    draw_status();

    while (running) {
        drain_keys();            /* B: read all pending keys       */
        if (!running) break;
        update();
        frame_delay();           /* timed delay with dense polling */
    }

    gfx_off();

    /* ESC pressed: no animation, no name entry */
    if (esc_quit) {
        goodbye_screen(score, 0);
        return 0;
    }

    /* All 10 levels completed: matrix rain then full goodbye */
    if (game_complete) {
        matrix_rain();
        goodbye_screen(score, 1);
        return 0;
    }

    /* Game over (collision): GAME OVER message + matrix + full goodbye */
    {
        const char *gomsg = "  GAME OVER  ";  /* 13 chars */
        int gcol = BORDER_C1 + 1 + (BOARD_W - 13) / 2;
        int grow = BORDER_R1 + 1 + (BOARD_H / 2) - 1;
        gotoxy(gcol, grow);
        rev_on(); fputs(gomsg, stdout); rev_off();
    }

    matrix_rain();
    goodbye_screen(score, 1);

    return 0;
}
