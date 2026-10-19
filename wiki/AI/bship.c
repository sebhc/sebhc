/*
 * BSHIP.C  -  BattleShip (solo) for Zenith Z-89 / CP/M 2.2
 * =============================================================
 * CPU     : Z-80 @ 2 MHz
 * Terminal: H19 Heath/VT52 mode, 80x24
 * Base    : H19 primitives reused as-is from ssnake.c / spendu.c
 *           (already hardware-confirmed). Grid layout, ship shapes
 *           and AI logic ported from VAXBSHIP.C's solo attack_phase()
 *           / computer_fire() (no roster/multiplayer, no VT100
 *           arrow-key escape decoding, no real-time clock). Welcome
 *           and Hall of Fame screens match ssnake.c's own, with the
 *           game name swapped in.
 *
 * Controls during placement: 8/2/4/6 = move up/down/left/right
 *                             R       = rotate
 *                             ENTER   = confirm
 * Controls during combat:    8/2/4/6 = move targeting cursor
 *                             ENTER   = fire
 *                             ESC     = quit (confirm Y/N)
 *
 * RNG: no RTC on the Z-89 (confirmed - system clock always reads
 * 00:00:00), so the AI's shot selection can't be time-seeded. Same
 * fix as Super Snake/Super Pendu: a simple LCG, perturbed by every
 * keypress the player makes (get_key() folds each key's value into
 * the seed) - by the time the AI needs its first random shot, the
 * player has already pressed enough keys during ship placement to
 * make the sequence unpredictable game to game.
 *
 * Hall of Fame: binary file (BSHIP.DAT), same fgetc/fputc read/write
 * pattern as ssnake.c/spendu.c. Messages are built with the tiny
 * str_put()/uint_put() helpers (ssnake.c's put_uint_w()/put_str_lj())
 * rather than sprintf(), to avoid pulling in the full printf
 * formatting engine for a handful of short, fixed-shape messages.
 *
 * Status: hardware-confirmed working end to end (placement, combat,
 * Hall of Fame) on a real Zenith Z-89.
 *
 * Compile:
 *   zcc -mz80 +cpm -subtype=hz89 -O2 -o BSHIP.COM bship.c
 */

#include <stdio.h>
#include <cpm.h>    /* bdos() */

/* ------------------------------------------------------------------
 * 80x24 screen - same convention as Super Snake / Super Pendu
 * ------------------------------------------------------------------ */
#define COLS        80
#define ROW_TITLE    1
#define ROW_STATUS  24

/* ------------------------------------------------------------------
 * 10x10 grids - same geometry as VAXBSHIP.C (GRID_N/GRID_CW/...),
 * computed once here rather than at runtime (no division on every
 * call on a 2 MHz Z-80).
 * ------------------------------------------------------------------ */
#define GRID_N        10
#define GRID_CW        2     /* each cell = char + space */
#define GRID_IW       20     /* GRID_N * GRID_CW */
#define GRID_IH       10
#define GRID_GUTTER    2     /* row-letter column, left of the box */
#define BOX_TOP        7
#define LEFT1         15
#define LEFT2         47

/* Rows used below the grids for placement hints/ship name, and for
 * the sunk-count line under each grid - same fixed rows as
 * VAXBSHIP.C. */
#define LABEL_ROW     21
#define NAME_ROW      22
#define SUNK_ROW      (BOX_TOP + GRID_IH + 2)   /* row 19 */

/* ------------------------------------------------------------------
 * H19 graphic characters (same codes as ssnake.c / spendu.c)
 * ------------------------------------------------------------------ */
#define G_TL 'f'   /* top-left corner    */
#define G_TR 'c'   /* top-right corner   */
#define G_BL 'e'   /* bottom-left corner */
#define G_BR 'd'   /* bottom-right corner*/
#define G_HZ 'a'   /* horizontal line    */
#define G_VT '`'   /* vertical line      */

/* ------------------------------------------------------------------
 * H19 terminal primitives - reused from ssnake.c / spendu.c.
 * get_key() also folds every keypress into the RNG seed (see the
 * file header comment on why).
 * ------------------------------------------------------------------ */
static unsigned int rseed = 1;

/* Entered once, at the welcome screen: reused as the label above the
 * player's own grid and, on a win, as the Hall of Fame entry name -
 * same single-entry-point convention as ssnake.c/spendu.c. */
#define HOF_NAMELEN 16
static char player_name[HOF_NAMELEN + 1];

static unsigned int mrand(void)
{
    rseed = rseed * 31421u + 6927u;
    return rseed;
}

static void gotoxy(int col, int row)
{
    putchar(27); putchar('Y');
    putchar(row + 31);
    putchar(col + 31);
}

static void clrscr(void)   { bdos(2, 27); bdos(2, 'E'); }
static void cursor_off(void) { putchar(27); putchar('x'); putchar('5'); }
static void cursor_on(void)  { putchar(27); putchar('y'); putchar('5'); }
static void gfx_on(void)     { putchar(27); putchar('F'); }
static void gfx_off(void)    { putchar(27); putchar('G'); }
static void rev_on(void)     { putchar(27); putchar('p'); }
static void rev_off(void)    { putchar(27); putchar('q'); }

static int get_key(void)
{
    int c;
    do { c = bdos(6, 0xFF); } while (c == 0);
    rseed += (unsigned)c + 1u;
    return c;
}

/* Same character-by-character bdos(6,0xFF) name entry as the welcome
 * screens in ssnake.c/spendu.c - backspace supported, ENTER confirms. */
static void get_name(char *out)
{
    int pos = 0, nc;
    for (;;) {
        nc = get_key();
        if (nc == '\r' || nc == '\n') break;
        if ((nc == 8 || nc == 127) && pos > 0) {
            pos--;
            putchar('\b'); putchar(' '); putchar('\b');
            continue;
        }
        if (nc >= 0x20 && nc < 0x7F && pos < HOF_NAMELEN) {
            out[pos++] = (char)nc;
            putchar(nc);
        }
    }
    out[pos] = '\0';
}

/* Crude calibrated busy-wait, same technique as ssnake.c's
 * frame_delay() (for (d = 0; d < N; d++) ;). N is an INITIAL GUESS,
 * not yet confirmed on real hardware - flag if the pauses feel too
 * short/long and we'll retune it, same as ssnake_vax's own timing
 * constants were. d is volatile so -O2 can't prove the loop has no
 * observable effect and strip it out entirely. */
static void pause_msg(void)
{
    volatile unsigned d;
    for (d = 0; d < 15000u; d++) ;
}

/* Same technique as pause_msg(), but roughly 1 full second instead of
 * a short log pause - used to hold "Game aborted." on screen before
 * falling through to the End Screen. Scaled from pause_msg()'s own
 * loop count using the Z-89<->TRS-80 loop-speed ratio documented in
 * bship_m4.c (12000 Z-89 loops ~= 650 ms there), so 1000 ms here is
 * about 18462 loops. */
static void pause_abort(void)
{
    volatile unsigned d;
    for (d = 0; d < 18462u; d++) ;
}

/* ------------------------------------------------------------------
 * Title bar (row 1) - plain centered text, same style as ssnake.c's
 * own draw_title() (a fixed string with the centering baked in via
 * leading spaces, no reverse video - not the VAX version, which
 * still uses a plain %-80s left-flush line).
 * ------------------------------------------------------------------ */
static void draw_title(void)
{
    int i = 0;
    const char *t =
        "     [[ BATTLESHIP V1.1 ]]         Zenith Z-89 / Heathkit H-89  |  CP/M 2.2";
    gotoxy(1, ROW_TITLE);
    fputs(t, stdout);
    while (t[i]) i++;
    for (; i < COLS; i++) putchar(' ');
}

/* Plain horizontal separator line (no corners) spanning the full
 * width - same role as VAXBSHIP.C's hline() (there: DEC graphics
 * 'q'; here: H19 graphics G_HZ, same character draw_grid()'s frame
 * uses). */
static void hline(int row)
{
    int i;
    gotoxy(1, row);
    gfx_on();
    for (i = 1; i <= COLS; i++) putchar(G_HZ);
    gfx_off();
}

/* ------------------------------------------------------------------
 * Cell markers.
 *   ship cell (placement)     : reverse-video space (proven, reused)
 *   miss ("coup dans l'eau")  : 'o' (plain) - VAX uses a diamond,
 *                                which the H19 charset has no
 *                                equivalent for
 *   hit ("touche")            : graphic-mode 'i' (checkerboard/
 *                                medium shade, same glyph ssnake.c
 *                                uses for GFX_BODY) in reverse video
 *                                - same combination as VAXBSHIP.C's
 *                                own put_hit() (DEC graphics 'a' +
 *                                reverse video), just with the H19
 *                                checkerboard character instead
 * ------------------------------------------------------------------ */
static void put_ship_cell(void) { rev_on(); putchar(' '); rev_off(); }
static void put_miss(void)      { putchar('o'); }
static void put_hit(void)       { gfx_on(); rev_on(); putchar('i'); rev_off(); gfx_off(); }

/* ------------------------------------------------------------------
 * 10x10 grid: graphic frame + column header (1-10) + row letters
 * (A-J) + water interior ('.'). Label is centered over the grid's
 * own column range (cline_range, defined further down).
 * ------------------------------------------------------------------ */
static void cline_range(int row, int left, int right, const char *txt);

static void draw_grid(int top, int left, const char *label)
{
    int r1 = top, c1 = left;
    int r2 = top + GRID_IH + 1;
    int c2 = left + GRID_IW + 1;
    int row, col;

    cline_range(top - 3, c1, c2, label);

    gotoxy(c1 + 1, top - 1);
    for (col = 1; col <= GRID_N; col++) {
        if (col < GRID_N) { putchar('0' + col); putchar(' '); }
        else              { putchar('1'); putchar('0'); }
    }

    gotoxy(c1, r1);
    gfx_on();
    putchar(G_TL);
    for (col = 0; col < GRID_IW; col++) putchar(G_HZ);
    gotoxy(c2, r1); putchar(G_TR);
    gfx_off();

    gotoxy(c1, r2);
    gfx_on();
    putchar(G_BL);
    for (col = 0; col < GRID_IW; col++) putchar(G_HZ);
    gotoxy(c2, r2); putchar(G_BR);
    gfx_off();

    for (row = 0; row < GRID_N; row++) {
        gotoxy(c1 - GRID_GUTTER, r1 + 1 + row);
        putchar('A' + row);

        gotoxy(c1, r1 + 1 + row);
        gfx_on(); putchar(G_VT); gfx_off();

        gotoxy(c1 + 1, r1 + 1 + row);
        for (col = 0; col < GRID_N; col++) {
            putchar('.');
            putchar(' ');
        }

        gotoxy(c2, r1 + 1 + row);
        gfx_on(); putchar(G_VT); gfx_off();
    }
}

typedef char board_t[GRID_N][GRID_N];

static void redraw_board(int top, int left, board_t board)
{
    int r, c;
    for (r = 0; r < GRID_N; r++) {
        for (c = 0; c < GRID_N; c++) {
            gotoxy(left + 1 + c * GRID_CW, top + 1 + r);
            if (board[r][c]) put_ship_cell();
            else putchar('.');
        }
    }
}

/* ------------------------------------------------------------------
 * Status bar (row 24) - same layout as VAXBSHIP.C's draw_status():
 * left = " Score : NNNN", right = "[ESC] : Quit", and an optional
 * centered message in between (pass "" for none). The right part
 * ends at column 79, not 80 - column 80 is left untouched, same
 * "don't write to the very last column" habit as draw_box()/hline().
 * ------------------------------------------------------------------ */
static int str_put(char *buf, int pos, const char *s);

static void draw_status(int score, const char *center_msg)
{
    char lft[16], rgt[16], digbuf[6];
    int i, p, sc, dn, pad, ll, rl, rp, cl, cp;

    sc = score > 0 ? score : 0;
    dn = 0;
    if (sc == 0) { digbuf[dn++] = '0'; }
    else { int t = sc; while (t) { digbuf[dn++] = (char)('0' + t % 10); t /= 10; } }
    pad = 4 - dn; if (pad < 0) pad = 0;

    p = str_put(lft, 0, " Score : ");
    for (i = 0; i < pad; i++) lft[p++] = ' ';
    for (i = dn - 1; i >= 0; i--) lft[p++] = digbuf[i];
    lft[p] = '\0'; ll = p;

    p = str_put(rgt, 0, "[ESC] : Quit");
    rgt[p] = '\0'; rl = p;
    rp = (COLS - 1) - rl;

    cl = 0; while (center_msg[cl]) cl++;

    gotoxy(1, ROW_STATUS);
    fputs(lft, stdout);
    if (cl > 0) {
        cp = (COLS - cl) / 2;
        for (i = ll; i < cp; i++) putchar(' ');
        fputs(center_msg, stdout);
        for (i = cp + cl; i < rp; i++) putchar(' ');
    } else {
        for (i = ll; i < rp; i++) putchar(' ');
    }
    fputs(rgt, stdout);
    gotoxy(COLS, ROW_STATUS);
    putchar(' ');
}

/* Tiny string/number builders - same idea as ssnake.c's put_uint_w()/
 * put_str_lj(), used here to compose short messages into a buffer
 * without pulling in sprintf(). Returns the new write position. */
static int str_put(char *buf, int pos, const char *s)
{
    while (*s) buf[pos++] = *s++;
    return pos;
}

static int uint_put(char *buf, int pos, unsigned v)
{
    char tmp[6];
    int n = 0, i;
    if (v == 0) { tmp[n++] = '0'; }
    else { unsigned t = v; while (t) { tmp[n++] = (char)('0' + t % 10); t /= 10; } }
    for (i = n - 1; i >= 0; i--) buf[pos++] = tmp[i];
    return pos;
}

static void clear_field_row(int row)
{
    int k;
    gotoxy(2, row);
    for (k = 2; k < COLS; k++) putchar(' ');
}

static void clear_range(int row, int left, int right)
{
    int k;
    gotoxy(left, row);
    for (k = left; k <= right; k++) putchar(' ');
}

static void cline_range(int row, int left, int right, const char *txt)
{
    int len = 0, col;
    while (txt[len]) len++;
    col = left + ((right - left + 1) - len) / 2;
    gotoxy(col, row);
    fputs(txt, stdout);
}

/* ------------------------------------------------------------------
 * Ship shapes - ported verbatim from VAXBSHIP.C (pure data).
 * ------------------------------------------------------------------ */
#define MAX_SHIP_CELLS 6
#define NUM_ORIENT     4
#define SHIP_COUNT     5

typedef struct { int dr, dc; } cell_t;

typedef struct {
    const char *name;
    int ncells;
    int h[NUM_ORIENT];
    int w[NUM_ORIENT];
    cell_t cells[NUM_ORIENT][MAX_SHIP_CELLS];
    int points;
} ship_shape_t;

static const ship_shape_t SHIP_CARRIER = {
    "Aircraft Carrier", 6,
    { 2, 4, 2, 4 }, { 4, 2, 4, 2 },
    {
        { {0,1},{0,2},{0,3},{1,0},{1,1},{1,2} },
        { {0,0},{1,0},{1,1},{2,0},{2,1},{3,1} },
        { {0,1},{0,2},{0,3},{1,0},{1,1},{1,2} },
        { {0,0},{1,0},{1,1},{2,0},{2,1},{3,1} }
    },
    1000
};

static const ship_shape_t SHIP_BATTLESHIP = {
    "Battleship", 5,
    { 1, 5, 1, 5 }, { 5, 1, 5, 1 },
    {
        { {0,0},{0,1},{0,2},{0,3},{0,4} },
        { {0,0},{1,0},{2,0},{3,0},{4,0} },
        { {0,0},{0,1},{0,2},{0,3},{0,4} },
        { {0,0},{1,0},{2,0},{3,0},{4,0} }
    },
    800
};

static const ship_shape_t SHIP_SUBMARINE = {
    "Submarine", 4,
    { 2, 3, 2, 3 }, { 3, 2, 3, 2 },
    {
        { {0,1},{1,0},{1,1},{1,2} },
        { {0,0},{1,0},{1,1},{2,0} },
        { {0,0},{0,1},{0,2},{1,1} },
        { {0,1},{1,0},{1,1},{2,1} }
    },
    600
};

static const ship_shape_t SHIP_DESTROYER = {
    "Destroyer", 3,
    { 1, 3, 1, 3 }, { 3, 1, 3, 1 },
    {
        { {0,0},{0,1},{0,2} },
        { {0,0},{1,0},{2,0} },
        { {0,0},{0,1},{0,2} },
        { {0,0},{1,0},{2,0} }
    },
    400
};

static const ship_shape_t SHIP_TORPEDO = {
    "Torpedo Boat", 2,
    { 1, 2, 1, 2 }, { 2, 1, 2, 1 },
    {
        { {0,0},{0,1} },
        { {0,0},{1,0} },
        { {0,0},{0,1} },
        { {0,0},{1,0} }
    },
    200
};

static const ship_shape_t *SHIP_ORDER[SHIP_COUNT] = {
    &SHIP_CARRIER, &SHIP_BATTLESHIP, &SHIP_SUBMARINE, &SHIP_DESTROYER, &SHIP_TORPEDO
};

static int ship_points(const char *name)
{
    int s;
    for (s = 0; s < SHIP_COUNT; s++) {
        if (SHIP_ORDER[s]->name == name) return SHIP_ORDER[s]->points;
    }
    return 0;
}

static int ship_fits(board_t board, const ship_shape_t *ship, int orient, int ar, int ac)
{
    int i, r, c;
    if (ar < 0 || ac < 0) return 0;
    if (ar + ship->h[orient] > GRID_N) return 0;
    if (ac + ship->w[orient] > GRID_N) return 0;
    for (i = 0; i < ship->ncells; i++) {
        r = ar + ship->cells[orient][i].dr;
        c = ac + ship->cells[orient][i].dc;
        if (board[r][c]) return 0;
    }
    return 1;
}

static void ship_stamp(board_t board, const ship_shape_t *ship, int orient,
                       int ar, int ac, int ship_id)
{
    int i, r, c;
    for (i = 0; i < ship->ncells; i++) {
        r = ar + ship->cells[orient][i].dr;
        c = ac + ship->cells[orient][i].dc;
        board[r][c] = (char)(ship_id + 1);
    }
}

/* Places all 5 ships at random, non-overlapping - used only for the
 * Computer AI's own fleet (human always places manually). */
static void random_place_all(board_t board)
{
    int s, orient, ar, ac, tries, r, c;
    const ship_shape_t *ship;

    for (r = 0; r < GRID_N; r++)
        for (c = 0; c < GRID_N; c++) board[r][c] = 0;

    for (s = 0; s < SHIP_COUNT; s++) {
        ship = SHIP_ORDER[s];
        for (tries = 0; tries < 500; tries++) {
            orient = mrand() % NUM_ORIENT;
            ar = mrand() % GRID_N;
            ac = mrand() % GRID_N;
            if (ship_fits(board, ship, orient, ar, ac)) {
                ship_stamp(board, ship, orient, ar, ac, s);
                break;
            }
        }
    }
}

static void draw_ship_at(int top, int left, const ship_shape_t *ship,
                         int orient, int ar, int ac)
{
    int i, r, c;
    for (i = 0; i < ship->ncells; i++) {
        r = ar + ship->cells[orient][i].dr;
        c = ac + ship->cells[orient][i].dc;
        gotoxy(left + 1 + c * GRID_CW, top + 1 + r);
        put_ship_cell();
    }
}

static void erase_ship_at(int top, int left, const ship_shape_t *ship,
                          int orient, int ar, int ac, board_t board)
{
    int i, r, c;
    for (i = 0; i < ship->ncells; i++) {
        r = ar + ship->cells[orient][i].dr;
        c = ac + ship->cells[orient][i].dc;
        gotoxy(left + 1 + c * GRID_CW, top + 1 + r);
        if (c >= 0 && c < GRID_N) {
            if (board[r][c]) put_ship_cell();
            else putchar('.');
        } else {
            putchar(' ');
        }
    }
}

/* ------------------------------------------------------------------
 * Manual ship placement: one ship at a time, in the fixed order
 * (Carrier, Battleship, Submarine, Destroyer, Torpedo Boat). Ported
 * from VAXBSHIP.C's manual_place(), solo/CP-M simplified: no roster,
 * no "waiting for other players" polling, no timed read - get_key()
 * blocks until a real key comes in, which is all a single local
 * player needs.
 * ------------------------------------------------------------------ */
static void place_ships(board_t board, int top, int left, int right_left)
{
    int s, orient, ar, ac, key, maxar, maxac, minac, rr;
    int norient, nar, nac, oorient, oar, oac;
    const ship_shape_t *ship;
    int c1 = left, c2 = left + GRID_IW + 1;
    int rc1 = right_left, rc2 = right_left + GRID_IW + 1;
    int margin_left, margin_right, margin_width, shape_w, icon_left_col;

    margin_left  = 2;
    margin_right = left - GRID_GUTTER - 1;
    margin_width = margin_right - margin_left + 1;

    for (rr = 0; rr < GRID_N; rr++)
        for (s = 0; s < GRID_N; s++) board[rr][s] = 0;

    cline_range(LABEL_ROW, rc1, rc2, "8/2/4/6 to move");
    cline_range(NAME_ROW, rc1, rc2, "R to rotate, ENTER to confirm");

    for (s = 0; s < SHIP_COUNT; s++) {
        ship = SHIP_ORDER[s];
        orient = 1;

        shape_w = (ship->w[orient] - 1) * GRID_CW + 1;
        icon_left_col = margin_left + (margin_width - shape_w) / 2;
        minac = (icon_left_col - left - 1) / GRID_CW;

        ac = minac;
        ar = (GRID_N - ship->h[orient]) / 2;

        redraw_board(top, left, board);
        for (rr = 0; rr < GRID_N; rr++) {
            gotoxy(left - GRID_GUTTER, top + 1 + rr);
            putchar('A' + rr);
        }
        draw_ship_at(top, left, ship, orient, ar, ac);
        clear_range(NAME_ROW - 1, c1, c2);
        cline_range(NAME_ROW - 1, c1, c2, "Place your :");
        clear_range(NAME_ROW, c1, c2);
        cline_range(NAME_ROW, c1, c2, ship->name);

        for (;;) {
            key = get_key();

            maxar = GRID_N - ship->h[orient];
            maxac = GRID_N - ship->w[orient];
            oorient = orient;
            oar = ar;
            oac = ac;

            if (key == '8' && ar > 0) {
                ar--;
            } else if (key == '2' && ar < maxar) {
                ar++;
            } else if (key == '4' && ac > minac) {
                ac--;
            } else if (key == '6' && ac < maxac) {
                ac++;
            } else if (key == 'r' || key == 'R') {
                norient = (orient + 1) % NUM_ORIENT;
                nar = ar;
                nac = ac;
                if (nar > GRID_N - ship->h[norient]) nar = GRID_N - ship->h[norient];
                if (nac > GRID_N - ship->w[norient]) nac = GRID_N - ship->w[norient];
                if (nar < 0) nar = 0;
                if (nac < minac) nac = minac;
                orient = norient;
                ar = nar;
                ac = nac;
            } else if (key == '\r') {
                if (ship_fits(board, ship, orient, ar, ac)) {
                    ship_stamp(board, ship, orient, ar, ac, s);
                    break;
                }
            }

            if (orient != oorient || ar != oar || ac != oac) {
                erase_ship_at(top, left, ship, oorient, oar, oac, board);
                draw_ship_at(top, left, ship, orient, ar, ac);
            }
        }
    }

    redraw_board(top, left, board);
    clear_field_row(LABEL_ROW);
    clear_field_row(NAME_ROW);
}

/* ------------------------------------------------------------------
 * Attack phase.
 * ------------------------------------------------------------------ */
#define SHOT_MISS 1
#define SHOT_HIT  2

typedef char shots_t[GRID_N][GRID_N];

static void draw_cell(int top, int left, int r, int c, int state)
{
    gotoxy(left + 1 + c * GRID_CW, top + 1 + r);
    if (state == SHOT_HIT) put_hit();
    else if (state == SHOT_MISS) put_miss();
    else putchar('.');
}

static int all_sunk(board_t board, shots_t shots)
{
    int r, c;
    for (r = 0; r < GRID_N; r++)
        for (c = 0; c < GRID_N; c++)
            if (board[r][c] && shots[r][c] != SHOT_HIT) return 0;
    return 1;
}

static const char *check_sunk(board_t board, shots_t shots, int r, int c)
{
    int ship_id = board[r][c] - 1;
    int rr, cc;

    if (ship_id < 0 || ship_id >= SHIP_COUNT) return 0;
    for (rr = 0; rr < GRID_N; rr++)
        for (cc = 0; cc < GRID_N; cc++)
            if (board[rr][cc] == ship_id + 1 && shots[rr][cc] != SHOT_HIT) return 0;
    return SHIP_ORDER[ship_id]->name;
}

static int count_sunk(board_t board, shots_t shots)
{
    int s, r, c, sunk, ok;
    sunk = 0;
    for (s = 0; s < SHIP_COUNT; s++) {
        ok = 1;
        for (r = 0; r < GRID_N; r++)
            for (c = 0; c < GRID_N; c++)
                if (board[r][c] == s + 1 && shots[r][c] != SHOT_HIT) ok = 0;
        if (ok) sunk++;
    }
    return sunk;
}

static void show_sunk_count(int row, int c1, int c2, int sunk)
{
    char msg[24];
    int p = str_put(msg, 0, "Ships sunk : ");
    p = uint_put(msg, p, (unsigned)sunk);
    msg[p++] = '/';
    p = uint_put(msg, p, (unsigned)SHIP_COUNT);
    msg[p] = '\0';
    clear_range(row, c1, c2);
    cline_range(row, c1, c2, msg);
}

/* Shows a Y/N quit-confirmation prompt in the status bar. Returns 1
 * if confirmed (Y), 0 if cancelled (N) - same pattern as
 * VAXBSHIP.C's confirm_quit(). */
static int confirm_quit(int score)
{
    int ans;
    draw_status(score, "Quit the game? (Y/N)");
    for (;;) {
        ans = get_key();
        if (ans == 'y' || ans == 'Y') return 1;
        if (ans == 'n' || ans == 'N') return 0;
    }
}

/* Targeting cursor on the opponent's grid: 8/2/4/6 move a single
 * cell (starts at A1 each turn), ENTER fires (only on a cell not
 * already fired at - otherwise ignored), ESC asks to quit. Returns 1
 * with *out_r/*out_c set on a fired shot, 0 if the player confirmed
 * quitting. turn_msg/score are redrawn if the player cancels the quit
 * prompt (N) - same reason as VAXBSHIP.C's own player_target(). */
static int player_target(int top, int left, shots_t shots, int *out_r, int *out_c,
                          const char *turn_msg, int score)
{
    int r = 0, c = 0, key, orow, ocol;

    gotoxy(left + 1 + c * GRID_CW, top + 1 + r);
    put_ship_cell();

    for (;;) {
        key = get_key();
        orow = r;
        ocol = c;

        if (key == '8' && r > 0) {
            r--;
        } else if (key == '2' && r < GRID_N - 1) {
            r++;
        } else if (key == '4' && c > 0) {
            c--;
        } else if (key == '6' && c < GRID_N - 1) {
            c++;
        } else if (key == '\r') {
            if (!shots[r][c]) {
                *out_r = r;
                *out_c = c;
                return 1;
            }
        } else if (key == 27) {
            if (confirm_quit(score)) return 0;
            draw_status(score, turn_msg);
        }

        if (r != orow || c != ocol) {
            draw_cell(top, left, orow, ocol, shots[orow][ocol]);
            gotoxy(left + 1 + c * GRID_CW, top + 1 + r);
            put_ship_cell();
        }
    }
}

/* Computer AI's targeting memory: cells adjacent to an unsunk hit,
 * tried before falling back to random - simple hunt-mode AI, ported
 * verbatim from VAXBSHIP.C's computer_fire(). */
#define HUNT_MAX 40

typedef struct {
    int r[HUNT_MAX];
    int c[HUNT_MAX];
    int n;
} hunt_stack_t;

static void hunt_push(hunt_stack_t *h, shots_t shots, int r, int c)
{
    int i;
    if (r < 0 || r >= GRID_N || c < 0 || c >= GRID_N) return;
    if (shots[r][c]) return;
    for (i = 0; i < h->n; i++)
        if (h->r[i] == r && h->c[i] == c) return;
    if (h->n < HUNT_MAX) {
        h->r[h->n] = r;
        h->c[h->n] = c;
        h->n++;
    }
}

static void computer_fire(board_t player_board, shots_t comp_shots,
                          hunt_stack_t *hunt, int top, int left,
                          int *out_r, int *out_c)
{
    int r = -1, c = -1, tries;

    while (hunt->n > 0 && r < 0) {
        hunt->n--;
        if (!comp_shots[hunt->r[hunt->n]][hunt->c[hunt->n]]) {
            r = hunt->r[hunt->n];
            c = hunt->c[hunt->n];
        }
    }

    if (r < 0) {
        for (tries = 0; tries < 200; tries++) {
            r = mrand() % GRID_N;
            c = mrand() % GRID_N;
            if (!comp_shots[r][c]) break;
        }
        if (comp_shots[r][c]) {
            int start = mrand() % (GRID_N * GRID_N);
            int idx, p, found = 0;
            for (idx = 0; idx < GRID_N * GRID_N; idx++) {
                p = (start + idx) % (GRID_N * GRID_N);
                r = p / GRID_N;
                c = p % GRID_N;
                if (!comp_shots[r][c]) { found = 1; break; }
            }
            if (!found) { r = 0; c = 0; }
        }
    }

    if (player_board[r][c]) {
        comp_shots[r][c] = SHOT_HIT;
        draw_cell(top, left, r, c, SHOT_HIT);
        if (check_sunk(player_board, comp_shots, r, c)) {
            hunt->n = 0;
        } else {
            hunt_push(hunt, comp_shots, r - 1, c);
            hunt_push(hunt, comp_shots, r + 1, c);
            hunt_push(hunt, comp_shots, r, c - 1);
            hunt_push(hunt, comp_shots, r, c + 1);
        }
    } else {
        comp_shots[r][c] = SHOT_MISS;
        draw_cell(top, left, r, c, SHOT_MISS);
    }

    *out_r = r;
    *out_c = c;
}

/* Copies a null-terminated string - the one bit of <string.h>-style
 * work push_log() needs; written out rather than pulling in
 * <string.h> for a single 3-line function. */
static void str_copy(char *dst, const char *src)
{
    while ((*dst++ = *src++) != '\0') ;
}

/* Grid cell in "letter+number" notation (row letter A-J, column
 * 1-10), e.g. (2,6) -> "C7" - same helper as VAXBSHIP.C's
 * cell_name(). */
static void cell_name(int r, int c, char *buf)
{
    int p = 0;
    buf[p++] = (char)('A' + r);
    p = uint_put(buf, p, (unsigned)(c + 1));
    buf[p] = '\0';
}

/* Two-line scrolling hit/sunk log, rows LOG_ROW1/LOG_ROW2 (21/22,
 * framed by the hline() separators at rows 20/23): the newest entry
 * goes on LOG_ROW1, the previous one slides down to LOG_ROW2 - same
 * behavior as VAXBSHIP.C's push_log(), minus the "HH:MM:SS : "
 * timestamp prefix (no RTC on the Z-89 to source it from). Each line
 * is centered on its own (cline_range over the full row), so a full
 * clear_field_row() comes first - same reasoning as VAXBSHIP.C's own
 * push_log() comment: a shorter new message starting further right
 * than a longer previous one would otherwise leave that previous
 * message's leading characters on screen. */
#define LOG_ROW1 21
#define LOG_ROW2 22

static void push_log(const char *msg)
{
    static char line1[56] = "";
    static char line2[56] = "";

    str_copy(line2, line1);
    str_copy(line1, msg);

    clear_field_row(LOG_ROW1);
    cline_range(LOG_ROW1, 1, COLS, line1);
    clear_field_row(LOG_ROW2);
    if (line2[0]) cline_range(LOG_ROW2, 1, COLS, line2);
}

/* Orchestrates the whole attack phase, solo vs the Computer AI:
 * generates its fleet at random, then alternates turns (player
 * always first) until one side's whole fleet is sunk, or the player
 * quits (ESC, confirmed). *out_result is set to RES_WIN/RES_LOSE/
 * RES_QUIT; the return value is the final score (0 on a quit). */
#define RES_LOSE 0
#define RES_WIN  1
#define RES_QUIT 2

static int attack_phase(board_t my_board, int top, int left1, int left2, int *out_result)
{
    /* static, not stack-local: comp_board/my_shots/comp_shots/hunt
     * together are ~460 bytes, real pressure on the Z80's stack for
     * a single call - and the stack has no guard page on CP/M, so an
     * overflow just silently corrupts whatever sits above it.
     * attack_phase() is only ever called once, never recursively, so
     * static storage changes nothing about behavior, only where the
     * bytes live. */
    static board_t comp_board;
    static shots_t my_shots, comp_shots;
    static hunt_stack_t hunt;
    int r, c, win = 0, score = 0;
    char msg[56], cbuf[4];
    const char *sunk_name;
    int c1a = left1, c2a = left1 + GRID_IW + 1;
    int c1b = left2, c2b = left2 + GRID_IW + 1;

    { int rr, cc;
      for (rr = 0; rr < GRID_N; rr++)
        for (cc = 0; cc < GRID_N; cc++) { my_shots[rr][cc] = 0; comp_shots[rr][cc] = 0; }
    }
    hunt.n = 0;
    random_place_all(comp_board);

    show_sunk_count(SUNK_ROW, c1a, c2a, 0);
    show_sunk_count(SUNK_ROW, c1b, c2b, 0);

    for (;;) {
        int tp = str_put(msg, 0, "It's your turn to fire!");
        msg[tp] = '\0';
        draw_status(score, msg);

        if (!player_target(top, left2, my_shots, &r, &c, msg, score)) {
            *out_result = RES_QUIT;
            return 0;
        }

        if (comp_board[r][c]) {
            int p;
            my_shots[r][c] = SHOT_HIT;
            draw_cell(top, left2, r, c, SHOT_HIT);
            cell_name(r, c, cbuf);
            p = str_put(msg, 0, player_name[0] ? player_name : "You");
            p = str_put(msg, p, " hit COMPUTER's ship at ");
            p = str_put(msg, p, cbuf);
            msg[p++] = '!'; msg[p] = '\0';
            push_log(msg);
            pause_msg();

            sunk_name = check_sunk(comp_board, my_shots, r, c);
            if (sunk_name) {
                p = str_put(msg, 0, player_name[0] ? player_name : "You");
                p = str_put(msg, p, " sank COMPUTER's ");
                p = str_put(msg, p, sunk_name);
                msg[p++] = '!'; msg[p] = '\0';
                push_log(msg);
                score += ship_points(sunk_name);
                pause_msg();
                show_sunk_count(SUNK_ROW, c1b, c2b, count_sunk(comp_board, my_shots));
            }
        } else {
            int p;
            my_shots[r][c] = SHOT_MISS;
            draw_cell(top, left2, r, c, SHOT_MISS);
            cell_name(r, c, cbuf);
            p = str_put(msg, 0, player_name[0] ? player_name : "You");
            p = str_put(msg, p, " missed at ");
            p = str_put(msg, p, cbuf);
            msg[p++] = '.'; msg[p] = '\0';
            push_log(msg);
            if (score > 25) score -= 25; else score = 0;
            pause_msg();
        }

        if (all_sunk(comp_board, my_shots)) { win = 1; break; }

        draw_status(score, "COMPUTER's turn...");
        pause_msg();
        computer_fire(my_board, comp_shots, &hunt, top, left1, &r, &c);

        if (my_board[r][c]) {
            int p;
            cell_name(r, c, cbuf);
            p = str_put(msg, 0, "COMPUTER hit ");
            if (player_name[0]) { p = str_put(msg, p, player_name); p = str_put(msg, p, "'s ship at "); }
            else p = str_put(msg, p, "your ship at ");
            p = str_put(msg, p, cbuf);
            msg[p++] = '!'; msg[p] = '\0';
            push_log(msg);
            pause_msg();
            sunk_name = check_sunk(my_board, comp_shots, r, c);
            if (sunk_name) {
                p = str_put(msg, 0, "COMPUTER sank ");
                if (player_name[0]) { p = str_put(msg, p, player_name); p = str_put(msg, p, "'s "); }
                else p = str_put(msg, p, "your ");
                p = str_put(msg, p, sunk_name);
                msg[p++] = '!'; msg[p] = '\0';
                push_log(msg);
                pause_msg();
                show_sunk_count(SUNK_ROW, c1a, c2a, count_sunk(my_board, comp_shots));
            }
        } else {
            int p;
            cell_name(r, c, cbuf);
            p = str_put(msg, 0, "COMPUTER missed at ");
            p = str_put(msg, p, cbuf);
            msg[p++] = '.'; msg[p] = '\0';
            push_log(msg);
            pause_msg();
        }

        if (all_sunk(my_board, comp_shots)) break;
    }

    if (score < 0) score = 0;

    *out_result = win ? RES_WIN : RES_LOSE;
    return score;
}

/* ------------------------------------------------------------------
 * Hall of Fame - BSHIP.DAT
 * Same binary format and read/write pattern as ssnake.c/spendu.c:
 *   HOF_NAMELEN+1 bytes : name (null-terminated, zero-padded)
 *   2 bytes             : score (little-endian unsigned 16-bit)
 * Read/written one byte at a time via fgetc/fputc rather than a
 * single fread/fwrite of the whole struct - sidesteps any struct
 * padding differences between compilers/settings, same reasoning
 * as the original CP/M games.
 * ------------------------------------------------------------------ */
#define HOF_FILE     "BSHIP.DAT"
#define HOF_SIZE     5

typedef struct {
    char     name[HOF_NAMELEN + 1];
    unsigned score;
} HofEntry;

static void hof_read(HofEntry hof[HOF_SIZE])
{
    FILE *f;
    int i, j;
    for (i = 0; i < HOF_SIZE; i++) { hof[i].name[0] = '\0'; hof[i].score = 0; }
    f = fopen(HOF_FILE, "rb");
    if (!f) return;
    for (i = 0; i < HOF_SIZE; i++) {
        int lo, hi;
        for (j = 0; j <= HOF_NAMELEN; j++) {
            int c = fgetc(f);
            if (c == EOF) { fclose(f); return; }
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
    FILE *f;
    int i, j;
    unsigned s;
    f = fopen(HOF_FILE, "wb");
    if (!f) return;
    for (i = 0; i < HOF_SIZE; i++) {
        for (j = 0; j <= HOF_NAMELEN; j++) fputc(hof[i].name[j], f);
        s = hof[i].score;
        fputc((int)(s & 0xFF), f);
        fputc((int)(s >> 8), f);
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
    for (j = HOF_SIZE - 1; j > i; j--) hof[j] = hof[j - 1];
    for (j = 0; j < HOF_NAMELEN && name[j]; j++) hof[i].name[j] = name[j];
    hof[i].name[j] = '\0';
    hof[i].score = sc;
}

/* Right-justified unsigned int in a field of w chars (space-padded) -
 * same helper as ssnake.c's put_uint_w(). */
static void put_uint_w(unsigned v, int w)
{
    char tmp[6];
    int n = 0, i;
    if (v == 0) { tmp[n++] = '0'; }
    else { unsigned t = v; while (t) { tmp[n++] = (char)('0' + t % 10); t /= 10; } }
    for (i = n; i < w; i++) putchar(' ');
    for (i = n - 1; i >= 0; i--) putchar(tmp[i]);
}

static void put_str_lj(const char *s, int w)
{
    int n = 0;
    while (*s) { putchar(*s++); n++; }
    while (n < w) { putchar(' '); n++; }
}

#define HOF_COL_NO    25
#define HOF_COL_NAME  29
#define HOF_COL_SCORE 50

static void hof_draw_entries(HofEntry hof[HOF_SIZE])
{
    int i;
    for (i = 0; i < HOF_SIZE; i++) {
        gotoxy(HOF_COL_NO, 16 + i);
        putchar((char)('0' + i + 1)); putchar('.');
        if (hof[i].name[0] != '\0') {
            gotoxy(HOF_COL_NAME, 16 + i);  put_str_lj(hof[i].name, 16);
            gotoxy(HOF_COL_SCORE, 16 + i); put_uint_w(hof[i].score, 5);
        } else {
            fputs("  ---", stdout);
        }
    }
}

/* Goodbye box - rows 2-9, same box/text layout as ssnake.c's own
 * goodbye_screen() (GBY_BC/BW/BR, gcbox_line()), just with the game
 * name swapped in, one row taller (7 interior rows instead of 6, for
 * the 5-line win/lose paragraph below instead of the original
 * 4-line one) and wider (62 columns instead of 50): the win message
 * with the longest possible name and a 4-digit score ("YOU WIN
 * <16-char name>! Your final score is NNNN points.") runs up to 58
 * characters, well past the original 50-column interior - GBY_BW is
 * sized to comfortably fit that worst case. */
#define GBY_BC   8
#define GBY_BW  62
#define GBY_BR   2

static void draw_box(int c1, int r1, int c2, int r2);

static void gcbox_line(int row, const char *txt)
{
    int l = 0, p;
    const char *q = txt; while (*q++) l++;
    p = (GBY_BW - l) / 2;
    gfx_on();
    gotoxy(GBY_BC, row); putchar(G_VT);
    gotoxy(GBY_BC + GBY_BW + 1, row); putchar(G_VT);
    gfx_off();
    if (l > 0) { gotoxy(GBY_BC + 1 + p, row); fputs(txt, stdout); }
}

/* Result + Hall of Fame screen - shown once, at the very end. Same
 * screen structure as ssnake.c's goodbye_screen() (box + HOF table,
 * same table rows/columns), but the box's first content line is now
 * the win/lose announcement (with the player's name, and the score
 * on a win) rather than a plain "Goodbye !" - "Goodbye." moved to
 * the last line instead. Only a real win is offered a Hall of Fame
 * entry - same rule as VAXBSHIP.C's hof_submit_if_win() (losers
 * never get one, whatever their score). The name is the one entered
 * at the welcome screen, not asked again here. Returns with the
 * screen left on - like ssnake.c, the caller exits right after, no
 * "press any key" pause and no final clear. */
static void end_screen(int score, int win)
{
    static HofEntry hof[HOF_SIZE];
    int in_top5;
    char line1[64];

    clrscr();
    cursor_off();

    hof_read(hof);
    in_top5 = win && hof_in_top5(hof, (unsigned)score);

    {
        const char *name = player_name[0] ? player_name : "You";
        int p;
        if (win) {
            p = str_put(line1, 0, "YOU WIN ");
            p = str_put(line1, p, name);
            p = str_put(line1, p, "! Your final score is ");
            p = uint_put(line1, p, (unsigned)score);
            p = str_put(line1, p, " points.");
        } else {
            p = str_put(line1, 0, "YOU LOOSE ");
            p = str_put(line1, p, name);
            p = str_put(line1, p, "!");
        }
        line1[p] = '\0';
    }

    draw_box(GBY_BC, GBY_BR, GBY_BC + GBY_BW + 1, GBY_BR + 8);
    gcbox_line(GBY_BR + 1, "");
    gcbox_line(GBY_BR + 2, line1);
    gcbox_line(GBY_BR + 3, "");
    gcbox_line(GBY_BR + 4, "Thank you for playing BattleShip.");
    gcbox_line(GBY_BR + 5, "Hope to see you again soon.");
    gcbox_line(GBY_BR + 6, "Goodbye.");
    gcbox_line(GBY_BR + 7, "");

    {
        const char *htitle = "*** HALL OF FAME - TOP 5 ***";
        gotoxy((80 - 28) / 2, 12);
        rev_on(); fputs(htitle, stdout); rev_off();
    }
    gotoxy(HOF_COL_NO, 14);    fputs("No", stdout);
    gotoxy(HOF_COL_NAME, 14);  fputs("Name", stdout);
    gotoxy(HOF_COL_SCORE, 14); fputs("Score", stdout);
    gotoxy(HOF_COL_NO, 15);
    { int k; for (k = 0; k < (HOF_COL_SCORE - HOF_COL_NO + 5); k++) putchar('-'); }
    hof_draw_entries(hof);

    if (in_top5) {
        const char *name = player_name[0] ? player_name : "???";
        hof_insert(hof, name, (unsigned)score);
        hof_write(hof);
        hof_draw_entries(hof);
    }

    cursor_on();
}

/* ------------------------------------------------------------------
 * Welcome screen - full-screen frame (same as ssnake.c's welcome
 * screen: draw_box() at BORDER_C1/R1/C2/R2), the "BattleShip" part
 * of VAXBSHIP.C's own "SuperBattleShip" figlet title (the "Super"
 * portion dropped, same 6 rows, re-centered), credits at the same
 * spot as VAXBSHIP.C's, then the ASCII-art ship, then the name
 * prompt at the same column as ssnake.c's Zenith welcome screen.
 * ------------------------------------------------------------------ */
#define BORDER_C1  1
#define BORDER_R1  1
#define BORDER_C2 80
#define BORDER_R2 24

static void draw_box(int c1, int r1, int c2, int r2)
{
    int i;
    gfx_on();
    gotoxy(c1, r1); putchar(G_TL);
    for (i = c1 + 1; i < c2; i++) putchar(G_HZ);
    putchar(G_TR);
    gotoxy(c1, r2); putchar(G_BL);
    for (i = c1 + 1; i < c2; i++) putchar(G_HZ);
    putchar(G_BR);
    for (i = r1 + 1; i < r2; i++) {
        gotoxy(c1, i); putchar(G_VT);
        gotoxy(c2, i); putchar(G_VT);
    }
    gfx_off();
}

/* "BattleShip" - just that part of VAXBSHIP.C's row-2..7 figlet
 * "SuperBattleShip" title (the "Super" glyphs, and the blank column
 * that followed them, dropped) - same 6 rows (2-7, matching
 * VAXBSHIP.C's own row numbers), same characters, re-centered for
 * our narrower 48-column-wide remainder.
 *
 * All 6 lines share ONE fixed start column (TITLE_COL) rather than
 * each being centered on its own via cline_range() - the 6 figlet
 * rows don't all have the same length once trailing spaces are
 * dropped, so centering each independently gave each row a
 * different starting column and broke the vertical alignment
 * between rows. The block is 48 columns
 * wide (its widest row); TITLE_COL centers that fixed width once,
 * inside the box's 78-column interior (columns 2..79). */
#define TITLE_ROW1 2
#define TITLE_BW   48
#define TITLE_COL  (BORDER_C1 + 1 + ((BORDER_C2 - BORDER_C1 - 1) - TITLE_BW) / 2)

static void draw_title_art(void)
{
    static const char *line[6] = {
        " ____        _   _   _      ____  _     _",
        "| __ )  __ _| |_| |_| | ___/ ___|| |__ (_)_ __",
        "|  _ \\ / _` | __| __| |/ _ \\___ \\| '_ \\| | '_ \\",
        "| |_) | (_| | |_| |_| |  __/___) | | | | | |_) |",
        "|____/ \\__,_|\\__|\\__|_|\\___|____/|_| |_|_| .__/",
        "                                         |_|"
    };
    int i;
    for (i = 0; i < 6; i++) { gotoxy(TITLE_COL, TITLE_ROW1 + i); fputs(line[i], stdout); }
}

static void draw_ship_art(void)
{
    gotoxy(44, 10); fputs("# #  ( )", stdout);
    gotoxy(41, 11); fputs("___#_#___|__", stdout);
    gotoxy(37, 12); fputs("_  |____________|  _", stdout);
    gotoxy(30, 13); fputs("_=====| | |            | | |==== _", stdout);
    gotoxy(24, 14); fputs("=====| |.---------------------------. | |====", stdout);
    gotoxy(10, 15); fputs("<--------------------'   .  .  .  .  .  .  .  .   '---------------/", stdout);
    gotoxy(13, 16); fputs("\\                                                             /", stdout);
    gotoxy(14, 17); fputs("\\___________________________________________________________/", stdout);
    gotoxy(6,  18); fputs("wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww", stdout);
    gotoxy(5,  19); fputs("wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww", stdout);
    gotoxy(6,  20); fputs("wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww", stdout);
}

static void welcome_screen(void)
{
    draw_box(BORDER_C1, BORDER_R1, BORDER_C2, BORDER_R2);

    draw_title_art();

    /* Credits - same column VAXBSHIP.C uses (27). */
    gotoxy(27, TITLE_ROW1 + 6);
    fputs("By Claude A.I. & RomaX ManiaX", stdout);

    draw_ship_art();

    /* Same column as ssnake.c's Zenith welcome screen prompt (the
     * 'E' of "Enter your name" at column 24, for
     * BORDER_C1=1/BOARD_W=78/HOF_NAMELEN=16). */
    gotoxy(24, 22);
    fputs("Enter your name : ", stdout);
    cursor_on();
    get_name(player_name);
    cursor_off();
}

int main(void)
{
    static board_t board;
    int result, score;

    clrscr();
    cursor_off();

    welcome_screen();

    clrscr();
    draw_title();
    hline(2);
    hline(20);
    hline(23);
    draw_grid(BOX_TOP, LEFT1, player_name[0] ? player_name : "You");
    draw_grid(BOX_TOP, LEFT2, "COMPUTER");

    place_ships(board, BOX_TOP, LEFT1, LEFT2);
    score = attack_phase(board, BOX_TOP, LEFT1, LEFT2, &result);

    if (result == RES_QUIT) {
        /* Hold "Game aborted." for ~1 s, then fall through to the End
         * Screen as a loss (no Hall of Fame entry) - same behavior as
         * bship_m4.c's RES_QUIT branch on the TRS-80. */
        draw_status(score, "Game aborted.");
        pause_abort();
        end_screen(score, 0);
    } else {
        end_screen(score, result == RES_WIN);
    }

    return 0;
}
