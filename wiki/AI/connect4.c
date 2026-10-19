/*
 * CONNECT4.C  -  Connect 4 (Puissance 4) - solo vs AI - for Zenith Z-89 / CP/M 2.2
 * =================================================================================
 * Version : 1.5 (production build - see version history below)
 * CPU     : Z-80 @ 2 MHz
 * Terminal: H19 Heath/VT52 mode, 80x24
 *
 * Ported from CONNECT4_VAX.C (VAX/OpenVMS, VT220), SOLO MODE ONLY - the network
 * multiplayer lobby (C4_ROSTER.DAT) is not part of this port. Per an explicit
 * decision with RomaX ManiaX, this version also has NO Hall of Fame and NO name
 * entry, matching CONNECT4_VAX.C's own original choice on that point ("no name
 * entry, no separate lobby/waiting-room screen ... no Hall of Fame either").
 *
 * What transfers essentially unchanged from CONNECT4_VAX.C:
 *   - All board/AI logic: check_win(), count_dir(), board_full(), window_open(),
 *     line_potential(), ai_choose_column() with its 4-step priority (win now /
 *     block / block a fork / weighted scoring, center-biased, ties random). Pure
 *     C, no terminal dependency - ported with only rand()->mrand() changed.
 *   - Board geometry (7 cols x 6 rows, 5x2 cell size, GRID_W=43/GRID_H=19) and
 *     screen layout (title row 1, cursor row 3, grid rows 5-23, status row 24) -
 *     already an 80x24 design, drops onto the H19 screen without changes.
 *
 * What's ported from BSHIP.C / SSNAKE.C / SPENDU.C (already hardware-confirmed
 * on this Z-89) instead of from the VAX file:
 *   - The welcome->game transition (quad_transition()) and the end-of-match
 *     transition (tri_transition() - see design notes below for both) are
 *     CONNECT4.C's own; CONNECT4_VAX.C has no equivalent to either (it just
 *     cuts straight to the board, and straight from the result to the
 *     Hall-of-Fame screen it doesn't have here).
 *   - H19 terminal primitives (gotoxy/clrscr/cursor/gfx/rev), get_key(), mrand(),
 *     pause_msg() - identical to bship.c.
 *   - RNG seeding: no RTC on the Z-89 (confirmed - see bship.c's own header), so
 *     rseed is perturbed by every keypress via get_key(), plus by the welcome
 *     screen's "press Space" polling loop (same technique as SPENDU.C's
 *     ecran_bienvenue()). ai_choose_column() only calls mrand() for tie-breaking
 *     in step 4 (weighted scoring) and for the fork-check loop order, which is
 *     low-stakes even with a modestly-seeded generator - nothing like bship.c's
 *     own random ship placement that needed a well-perturbed seed up front.
 *   - Controls: CONNECT4_VAX.C used VT220 arrow keys with escape-sequence
 *     decoding. This port drops that entirely in favor of the digit-key
 *     convention already used throughout this whole family of ports: 4/6 move
 *     the column cursor, Space drops the token, ESC quits (Y/N confirm, same
 *     confirm_quit() pattern as bship.c).
 *   - draw_box()/gcbox_line() goodbye-box helpers - same as bship.c/ssnake.c,
 *     just without the Hall-of-Fame table underneath.
 *
 * Design notes (why things look the way they do):
 *
 *   - Arrow keys vs ESC: the H19 in VT52 mode sends ESC as the lead byte
 *     of every arrow key (ESC + one or two more bytes), and none of
 *     ssnake.c/spendu.c/bship.c's get_key() ever had to deal with that
 *     because they never asked the player to press arrows in the first
 *     place - reaching for one here by habit was getting misread as a
 *     genuine Escape keypress and popping the quit prompt. get_key()
 *     below gives the terminal a brief window after any ESC byte to
 *     deliver a follow-up byte (polled via the same non-blocking
 *     bdos(6,0xFF) used everywhere else, no blocking read added); if one
 *     arrives within that window, the whole sequence is swallowed (still
 *     folded into the RNG) instead of being treated as Escape, and
 *     get_key() goes back for a real key. A genuine, lone Escape keypress
 *     has nothing following it, so after the window closes it's returned
 *     exactly as before. ESC_WAIT_LOOPS is how long that window is - long
 *     enough to catch the terminal's own follow-up bytes, short enough
 *     that a deliberate ESC still feels instant; untouched across every
 *     hardware test round below, so it reads as correctly sized.
 *
 *   - No native blink attribute: checked against this terminal's own ESC
 *     command reference - only reverse video (ESC p/q) and graphics mode
 *     (ESC F/G) exist, nothing like VT100's ESC[5m (which CONNECT4_VAX.C
 *     uses for its own status-bar blink). Every "blink" here is therefore
 *     simulated - plain text alternated against a blank line, timed by a
 *     busy-wait loop - in two places: blink_pause() (end-of-match result,
 *     in the status bar) and welcome_screen()'s "Press Space to start"
 *     (in its own key-polling loop, since it can't block on a delay loop
 *     of its own without also blocking the keyboard read).
 *
 *   - Grid-junction glyphs: CONNECT4_VAX.C draws a full spreadsheet-style
 *     grid, with a cross ('+') where an internal row separator crosses an
 *     internal column separator, and a top-tee ('T') where a column
 *     separator meets the top border. Neither glyph is used - or
 *     confirmed - anywhere in bship.c/ssnake.c/spendu.c; the only
 *     junction glyphs those files actually exercise on real hardware are
 *     the left/right/bottom tees (G_LT/G_RT/G_BT, used in SPENDU.C's
 *     gallows and panel frame). Rather than guess at an unconfirmed H19
 *     code, hline_row() below just lets the horizontal line run straight
 *     through (plain G_H) at those two specific junction spots -
 *     everywhere else uses only glyphs already proven on this hardware.
 *
 *   - quad_transition() (welcome->game transition): RomaX ManiaX's own
 *     design (V1.4), not ported from anywhere. The 80x24 screen splits
 *     into four 40x12 quadrants, each swept row by row in one
 *     direction - top-left top-down and bottom-right bottom-up in
 *     reverse-video spaces, then top-right top-down and bottom-left
 *     bottom-up in graphics checkerboard - then the same four sweeps
 *     again with plain spaces, erasing back to a blank screen. See
 *     quad_transition()'s own comment for the exact order.
 *
 *   - tri_transition() (end-of-match transition): RomaX ManiaX's own
 *     design too, a triangular sibling of quad_transition() replacing
 *     the old tetris_fill() piece-tiling animation. The same 80x24
 *     screen is split by an X instead of a cross - the two full
 *     corner-to-corner diagonals - into four triangles (North/South/
 *     West/East, all meeting at dead centre) instead of four
 *     rectangles. North and South sweep top-down/bottom-up in graphics
 *     checkerboard, West and East sweep left-to-right/right-to-left in
 *     reverse-video spaces, then the same four sweeps again with plain
 *     spaces. See tri_transition()'s own comment for the exact order
 *     and how each triangle's row/column span is worked out.
 *
 * Timing constants (busy-wait loop counts - no RTC on this Z-89 to
 * calibrate against): pause_msg()'s 15000, ESC_WAIT_LOOPS, BLINK_TOGGLES/
 * BLINK_HALF_LOOPS. None of these were ever flagged as wrong across every
 * hardware test round in the version history below, so they read as
 * correctly sized, but (unlike WELCOME_BLINK_LOOPS, which was measured
 * and retuned twice) were never explicitly confirmed either - flag any
 * of them if they ever read as too short or too long.
 *
 * Version history:
 *   V1.0 - Initial CP/M port from CONNECT4_VAX.C. Pre-hardware-test
 *          cleanup pass: arrow-key/ESC fix, tetris_fill()'s tiling moved
 *          from a runtime computation to precomputed static data (fixing
 *          a multi-second delay before the animation started), the
 *          missing end-of-match blink/tetris_fill()/goodbye sequence
 *          added (CONNECT4_VAX.C's finish_match() beat), a doubled
 *          AI-turn pause removed, end_screen()'s exit made clean (no
 *          clear/home), wording pass.
 *   V1.1 - First real hardware test on the Z-89, and everything it
 *          turned up: welcome-screen centering and spacing fixed, the
 *          welcome->game transition swapped from tetris_fill() to
 *          box_transition() (see design notes above), "Press Space to
 *          start" now blinks and no longer leaves a stray cursor beside
 *          it, a drop gong (BEL) added on every token drop for both
 *          players, end-screen wording/box height/centering fixed and
 *          its exit pause dropped entirely, and the welcome-screen
 *          blink retimed twice against the real screen (6000 -> 2000 ->
 *          1000 loop counts).
 *   V1.2 - The V1.1 drop gong is gone again, everywhere (both players'
 *          drops, the full-column rejection, and the welcome screen's
 *          stray-keypress beep). Turned out this Z-89's own keyboard
 *          makes its own click on every keypress, distinct from CP/M's
 *          BEL - so the player's beep() was landing right on top of
 *          that physical click (making the player's drop sound
 *          "doubled/jittery") while the computer's identical beep(),
 *          with no keypress behind it, sounded clean - not a bug in the
 *          code (both calls were always a single identical putchar(7)),
 *          just an unwanted combination on this specific hardware.
 *          RomaX ManiaX asked for all BEL output removed rather than
 *          worked around.
 *   V1.3 - The three end-of-match status-bar messages dropped their
 *          "CONNECT 4 - " prefix ("YOU WIN!" / "YOU LOSE!" / "DRAW
 *          GAME!" - the game only shows one screen at a time, so
 *          naming it in every message was redundant). For a real win
 *          or loss (not a draw), the 4 winning tokens on the board now
 *          blink in ALTERNATION with the status message (hidden while
 *          it shows, shown while it's blank) instead of sitting there
 *          static - check_win() records the winning line's cells
 *          (win_cells[]) whenever it finds one, and blink_pause()
 *          blanks/redraws those same 4 cells out of phase with the
 *          message toggle.
 *   V1.4 - The welcome->game transition is no longer box_transition()
 *          (V1.1's ported-from-SSNAKE.C shrinking tunnel of nested
 *          boxes) - replaced with quad_transition(), RomaX ManiaX's
 *          own design: see the design notes above and
 *          quad_transition()'s own comment for the four-quadrant
 *          sweep sequence. box_transition()/erase_box() are gone,
 *          having no other caller.
 *   V1.5 - The end-of-match transition is no longer tetris_fill()
 *          (the precomputed tetromino-tiling animation, TF_ROW/TF_COL/
 *          TF_SHAPE and all) - replaced with tri_transition(), a
 *          triangular sibling of quad_transition(): the same 80x24
 *          screen split by an X (the two corner-to-corner diagonals)
 *          into four triangles instead of four rectangles. See the
 *          design notes above and tri_transition()'s own comment for
 *          the exact order and how each triangle's span is computed.
 *          Full re-read/cleanup pass over the whole file alongside
 *          this change; no other bugs or behaviour changes found -
 *          see the two notes below the version marker at the very
 *          bottom of this history for the small, currently-harmless
 *          things that turned up but weren't worth changing code for.
 *          This is the current production build.
 *
 * Two things noticed during the V1.5 read-through, neither a live bug
 * (both currently unreachable with this file's own message strings),
 * left as-is rather than "fixed" for something that can't happen yet:
 *   - draw_status(): if a center_msg were ever long enough that its
 *     centered start column landed to the LEFT of where turn_label's
 *     text ends, the padding loop before it would simply not run
 *     (its condition is already false) and the message would print
 *     right after the label instead of centered - not a crash, just
 *     not centered. Every center_msg this file actually uses is short
 *     enough that this can't trigger (checked by hand); flag it if a
 *     longer status message is ever added.
 *   - ai_choose_column()'s fork check (step 2b) also re-examines the
 *     same column c it just gave the opponent, as one of the columns
 *     they could win in "next" - modelling the opponent playing c
 *     twice in a row, which can't really happen (the AI gets a move
 *     in between). Harmless - it can only make the fork check a
 *     little more cautious than strictly necessary, never wrong in a
 *     way that costs a game - but noted here in case it's ever worth
 *     excluding c from that inner loop for a purer heuristic.
 *
 * Compile:
 *   zcc -mz80 +cpm -subtype=hz89 -O2 -o CONNECT4.COM connect4.c
 *
 * Controls: 4/6 = move column cursor, Space = drop token, ESC = quit (Y/N confirm)
 *
 * By Claude A.I. & RomaX ManiaX
 */

#include <stdio.h>
#include <cpm.h>    /* bdos() */

/* ------------------------------------------------------------------
 * 80x24 screen
 * ------------------------------------------------------------------ */
#define COLS        80
#define ROW_TITLE    1
#define ROW_CURSOR   3
#define ROW_STATUS  24

/* ------------------------------------------------------------------
 * Board geometry - same as CONNECT4_VAX.C: 7x6 cells, 5x2 chars each,
 * full grid lines between cells. Already sized for an 80x24 screen.
 * ------------------------------------------------------------------ */
#define BOARD_COLS   7
#define BOARD_ROWS   6
#define CELL_W       5
#define CELL_H       2

#define GRID_W  (BOARD_COLS * CELL_W + (BOARD_COLS - 1) + 2)   /* 43 */
#define GRID_H  (BOARD_ROWS * CELL_H + (BOARD_ROWS - 1) + 2)   /* 19 */
#define GRID_LEFT   19          /* (80-43)/2+1, centers the board  */
#define GRID_TOP     5

/* ------------------------------------------------------------------
 * H19 graphic characters - same codes as bship.c/ssnake.c/spendu.c.
 * G_LT/G_RT/G_BT (tees) are the ones SPENDU.C actually exercises on
 * real hardware (gallows base, panel frame); no top-tee/cross glyph
 * is proven anywhere in this family of ports - see file header.
 * ------------------------------------------------------------------ */
#define G_TL 'f'   /* top-left corner    */
#define G_TR 'c'   /* top-right corner   */
#define G_BL 'e'   /* bottom-left corner */
#define G_BR 'd'   /* bottom-right corner*/
#define G_H  'a'   /* horizontal line    */
#define G_V  '`'   /* vertical line      */
#define G_LT 'v'   /* left tee  (branches right, up, down) */
#define G_RT 't'   /* right tee (branches left, up, down)  */
#define G_BT 'u'   /* bottom tee (branches left, right, up)*/
#define G_SH 'i'   /* checkerboard/shade - player 2 token  */

/* ------------------------------------------------------------------
 * H19 terminal primitives - reused as-is from bship.c/ssnake.c.
 * get_key() also folds every keypress into the RNG seed (no RTC on
 * the Z-89 - see bship.c's own header for why) and filters out
 * arrow-key escape sequences so they can't be mistaken for a real
 * Escape keypress - see the file header for why/how.
 * ------------------------------------------------------------------ */
static unsigned int rseed = 1;

/* How long get_key() waits, after seeing an ESC byte, for a follow-up
 * byte before concluding it was a genuine lone Escape keypress - an
 * initial guess, not yet confirmed on real hardware (see file header).
 * Busy-wait loop iterations, same style as pause_msg(). */
#define ESC_WAIT_LOOPS 3000u

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

static void clrscr(void)     { bdos(2, 27); bdos(2, 'E'); }
static void cursor_off(void) { putchar(27); putchar('x'); putchar('5'); }
static void cursor_on(void)  { putchar(27); putchar('y'); putchar('5'); }
static void gfx_on(void)     { putchar(27); putchar('F'); }
static void gfx_off(void)    { putchar(27); putchar('G'); }
static void rev_on(void)     { putchar(27); putchar('p'); }
static void rev_off(void)    { putchar(27); putchar('q'); }

static int get_key(void)
{
    int c;

    for (;;) {
        do { c = bdos(6, 0xFF); } while (c == 0);
        rseed += (unsigned)c + 1u;

        if (c != 27) return c;

        /* Saw an ESC byte: briefly poll (non-blocking) for a follow-up
         * byte. Arrow keys on this terminal send ESC immediately
         * followed by one or two more bytes; a genuine lone Escape
         * keypress has nothing after it. */
        {
            unsigned wait;
            int c2 = 0;

            for (wait = 0; wait < ESC_WAIT_LOOPS; wait++) {
                c2 = bdos(6, 0xFF);
                if (c2 != 0) break;
            }

            if (c2 == 0) return c;    /* nothing followed: genuine ESC */

            rseed += (unsigned)c2 + 1u;
            c2 = bdos(6, 0xFF);       /* swallow a possible 3rd byte   */
            if (c2 != 0) rseed += (unsigned)c2 + 1u;
            /* fall through: loop back and wait for a real key */
        }
    }
}

/* Crude calibrated busy-wait, same technique/same initial guess as
 * bship.c's pause_msg() - not yet confirmed on real hardware. */
static void pause_msg(void)
{
    volatile unsigned d;
    for (d = 0; d < 15000u; d++) ;
}

/* ------------------------------------------------------------------
 * Generic box helpers - same as bship.c/ssnake.c.
 * ------------------------------------------------------------------ */
static void draw_box(int c1, int r1, int c2, int r2)
{
    int i;
    gfx_on();
    gotoxy(c1, r1); putchar(G_TL);
    for (i = c1 + 1; i < c2; i++) putchar(G_H);
    gotoxy(c2, r1); putchar(G_TR);
    gotoxy(c1, r2); putchar(G_BL);
    for (i = c1 + 1; i < c2; i++) putchar(G_H);
    gotoxy(c2, r2); putchar(G_BR);
    for (i = r1 + 1; i < r2; i++) {
        gotoxy(c1, i); putchar(G_V);
        gotoxy(c2, i); putchar(G_V);
    }
    gfx_off();
}

/* ==================================================================
 * quad_transition() - welcome->game transition (V1.4).
 *
 * Replaces the earlier box_transition() (a shrinking tunnel of nested
 * boxes, ported from SSNAKE.C) with RomaX ManiaX's own design: the
 * 80x24 screen split into four 40x12 quadrants, each filled row by row
 * in one direction, one quadrant at a time -
 *
 *   1. top-left     : top -> down,   reverse-video spaces
 *   2. bottom-right : bottom -> up,  reverse-video spaces
 *   3. top-right    : top -> down,   graphics checkerboard (G_SH)
 *   4. bottom-left  : bottom -> up,  graphics checkerboard (G_SH)
 *
 * - then the exact same four steps again, same quadrants, same
 * directions, same order, but with plain spaces instead, erasing
 * everything back to a blank screen. quad_fill() below does one
 * quadrant's sweep; QF_REV/QF_GFX/QF_PLAIN pick what it writes.
 *
 * Each row is drawn with a single gotoxy() and then QW back-to-back
 * putchar()s (cursor auto-advances) rather than one gotoxy() per
 * character, and there's no artificial delay anywhere - both make
 * this as fast as the H19 can take the output, same "no delay, let
 * the baud rate pace it" approach as the box_transition() it replaces
 * and as tri_transition()'s own fill/erase passes.
 * ================================================================== */
#define QW 40   /* quadrant width  (80 / 2) */
#define QH 12   /* quadrant height (24 / 2) */

#define QF_PLAIN 0
#define QF_REV   1
#define QF_GFX   2

/* col1,row1: quadrant's top-left corner. top_down: 1 = sweep from its
 * first row downward, 0 = from its last row upward. mode: what each
 * row is filled with (see QF_* above). */
static void quad_fill(int col1, int row1, int top_down, int mode)
{
    int i, row, k;

    for (i = 0; i < QH; i++) {
        row = top_down ? row1 + i : row1 + QH - 1 - i;
        gotoxy(col1, row);
        if (mode == QF_REV) rev_on();
        else if (mode == QF_GFX) gfx_on();
        for (k = 0; k < QW; k++) putchar(mode == QF_GFX ? G_SH : ' ');
        if (mode == QF_REV) rev_off();
        else if (mode == QF_GFX) gfx_off();
    }
}

static void quad_transition(void)
{
    /* Fill. */
    quad_fill(1,      1, 1, QF_REV);   /* top-left,     top -> down   */
    quad_fill(QW + 1, QH + 1, 0, QF_REV);   /* bottom-right, bottom -> up   */
    quad_fill(QW + 1, 1, 1, QF_GFX);   /* top-right,    top -> down   */
    quad_fill(1,      QH + 1, 0, QF_GFX);   /* bottom-left,  bottom -> up   */

    /* Erase, same quadrants/order/directions, back to a blank screen. */
    quad_fill(1,      1, 1, QF_PLAIN);
    quad_fill(QW + 1, QH + 1, 0, QF_PLAIN);
    quad_fill(QW + 1, 1, 1, QF_PLAIN);
    quad_fill(1,      QH + 1, 0, QF_PLAIN);
}

/* ------------------------------------------------------------------
 * Title bar (row 1) - same style as bship.c's draw_title().
 * ------------------------------------------------------------------ */
static void draw_title(void)
{
    int i = 0;
    const char *t =
        "     [[ CONNECT 4 V1.5 ]]          Zenith Z-89 / Heathkit H-89  |  CP/M 2.2";
    gotoxy(1, ROW_TITLE);
    fputs(t, stdout);
    while (t[i]) i++;
    for (; i < COLS; i++) putchar(' ');
}

/* ------------------------------------------------------------------
 * Status bar (row 24) - left = " Turn : <label>", right = quit hint,
 * optional centered message - same layout/trick as bship.c's own
 * draw_status() (last column written separately, anti-scroll habit).
 * ------------------------------------------------------------------ */
static void draw_status(const char *turn_label, const char *center_msg)
{
    char lft[24], rgt[16];
    int i, p, ll, rl, rp, cl, cp;

    p = 0;
    { const char *s = " Turn : "; while (*s) lft[p++] = *s++; }
    { const char *s = turn_label; while (*s) lft[p++] = *s++; }
    lft[p] = '\0'; ll = p;

    p = 0;
    { const char *s = "[ESC] : Quit"; while (*s) rgt[p++] = *s++; }
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

/* Y/N quit-confirmation prompt in the status bar - same pattern as
 * bship.c's confirm_quit(). */
static int confirm_quit(const char *turn_label)
{
    int ans;
    draw_status(turn_label, "Quit the game? (Y/N)");
    for (;;) {
        ans = get_key();
        if (ans == 'y' || ans == 'Y') return 1;
        if (ans == 'n' || ans == 'N') return 0;
    }
}

/* ------------------------------------------------------------------
 * Welcome screen - full-screen box (same idea as bship.c's own),
 * plain-text figlet banner ported verbatim from CONNECT4_VAX.C's
 * draw_logo_connect4() (it's just literal text, no terminal-specific
 * codes, so it needs no adaptation at all), then instructions and a
 * "press Space" wait. No name entry (see file header) - the wait
 * loop still perturbs rseed on every poll tick and on every stray
 * keypress, same technique as SPENDU.C's ecran_bienvenue().
 *
 * Content block (logo through "Press Space to start") is centered as
 * a whole in the box's interior (rows 2-23): 4 blank rows above and
 * below it.
 *
 * Horizontal centering (this pass): WELCOME_W used to be a separate,
 * hand-maintained "78" that had to be kept in sync with WELCOME_C1/C2
 * by hand - easy to let drift after an edit even though it happened to
 * still be correct here. It's now derived (WELCOME_IW), and both
 * bv_cbox() and draw_logo_connect4() go through the same wc_center_col()
 * so there's exactly one centering formula in the file instead of two
 * copies of it that could quietly disagree.
 * ------------------------------------------------------------------ */
#define WELCOME_C1   1
#define WELCOME_R1   1
#define WELCOME_C2  80
#define WELCOME_R2  24
#define WELCOME_IW (WELCOME_C2 - WELCOME_C1 - 1)   /* 78 - interior width */

/* How many passes through welcome_screen()'s key-polling loop between
 * blink toggles of "Press Space to start" - same busy-wait-by-loop-count
 * idea as BLINK_HALF_LOOPS, just counted in polling passes instead of an
 * inner delay loop, since this blink has to share the loop with the
 * (non-blocking) keyboard read instead of owning a loop of its own.
 * Measured against the real Z-89 and retimed twice (6000 -> 2000 -> the
 * current 1000) - see the version history in the file header. */
#define WELCOME_BLINK_LOOPS 1000u

/* Column to start a string of length len at so it lands centered in
 * the welcome box's interior (columns WELCOME_C1+1 .. WELCOME_C2-1). */
static int wc_center_col(int len)
{
    return WELCOME_C1 + 1 + (WELCOME_IW - len) / 2;
}

static void bv_cbox(int row, const char *txt)
{
    int len = 0;
    const char *p = txt; while (*p++) len++;
    if (len > 0) { gotoxy(wc_center_col(len), row); fputs(txt, stdout); }
}

static void draw_logo_connect4(void)
{
    static const char *line[5] = {
        "  ____                            _     _  _   ",
        " / ___|___  _ __  _ __   ___  ___| |_  | || |  ",
        "| |   / _ \\| '_ \\| '_ \\ / _ \\/ __| __| | || |_ ",
        "| |__| (_) | | | | | | |  __/ (__| |_  |__   _|",
        " \\____\\___/|_| |_|_| |_|\\___|\\___|\\__|    |_|  "
    };
    int i, maxlen, l, col;
    const char *p;

    /* All 5 lines are the same length (padded with trailing spaces),
     * so any of them would give the same maxlen - computed from all 5
     * anyway rather than assumed, so the banner still centers itself
     * correctly if the art is ever edited to ragged widths. Drawn at
     * one shared column (not re-centered per line) so the block stays
     * a rigid unit instead of jittering left/right line to line. */
    maxlen = 0;
    for (i = 0; i < 5; i++) {
        l = 0; p = line[i]; while (*p++) l++;
        if (l > maxlen) maxlen = l;
    }
    col = wc_center_col(maxlen);
    for (i = 0; i < 5; i++) {
        gotoxy(col, WELCOME_R1 + 5 + i);
        fputs(line[i], stdout);
    }
}

static void welcome_screen(void)
{
    int ch, i;
    int psc_col = wc_center_col(20) - 1;   /* "Press Space to start" col */
    unsigned tick = 0;
    int shown = 1;

    clrscr();
    cursor_off();
    draw_box(WELCOME_C1, WELCOME_R1, WELCOME_C2, WELCOME_R2);

    draw_logo_connect4();                                        /* rows 6-10 */
    bv_cbox(WELCOME_R1 + 11, "By Claude A.I. & RomaX ManiaX");
    bv_cbox(WELCOME_R1 + 14, "Drop your token into a column - line up 4 to win.");
    bv_cbox(WELCOME_R1 + 15, "4 / 6 = choose column    Space = drop token");

    /* "Press Space to start" - the formula-centered column landed one
     * column too far right on the real H19 (RomaX ManiaX's report after
     * the hardware test); nudged one column left rather than reworking
     * wc_center_col() itself, since every other bv_cbox() line measured
     * correctly on the same screen. */
    gotoxy(psc_col, WELCOME_R1 + 18);
    fputs("Press Space to start", stdout);

    /* No cursor_on() here: the hardware cursor used to land right after
     * the text and stay there, visible, for the whole wait - not wanted.
     * cursor_off() was already set above and never gets turned back on
     * until the player presses Space, so there's nothing left on screen
     * but the (now blinking) text itself. */
    for (;;) {
        rseed++;
        ch = bdos(6, 0xFF);
        if (ch == ' ') break;
        if (ch != 0) { rseed += (unsigned)ch + 1u; }

        /* Blink "Press Space to start" in place, same plain alternating-
         * with-blank technique as blink_pause() (no reverse video) - just
         * paced by polling-loop passes instead of an inner delay loop,
         * since this one has to share the loop with get_key()'s cousin
         * above instead of blocking on its own. */
        if (++tick >= WELCOME_BLINK_LOOPS) {
            tick = 0;
            shown = !shown;
            gotoxy(psc_col, WELCOME_R1 + 18);
            if (shown) fputs("Press Space to start", stdout);
            else for (i = 0; i < 20; i++) putchar(' ');
        }
    }
    cursor_off();
}

/* ==================================================================
 * tri_transition() - end-of-match transition.
 *
 * Used only by play_end_sequence(), between the status-bar blink and
 * end_screen()'s goodbye box (a real win/lose/draw). Replaces the old
 * tetris_fill() (a precomputed tetromino tiling of the 40x12 grid) -
 * see the design notes above for why - with a triangular sibling of
 * quad_transition(): instead of four 40x12 rectangles, the 80x24
 * screen is split by an X - the two full corner-to-corner diagonals,
 * (1,1)-(80,24) and (80,1)-(1,24) - into four triangles, all meeting
 * at dead centre: North (base = top edge), South (base = bottom
 * edge), West (base = left edge), East (base = right edge).
 *
 *   1. North : top -> down,       graphics checkerboard (G_SH)
 *   2. South : bottom -> up,      graphics checkerboard (G_SH)
 *   3. West  : left -> right,     reverse-video spaces
 *   4. East  : right -> left,     reverse-video spaces
 *
 * - then the same four triangles again, same order, same directions,
 * but with plain spaces, erasing everything back to a blank screen.
 *
 * tri_col_band()/tri_row_band() work out, for a given row or column,
 * where the two diagonals are - the North/South triangles are swept
 * row by row (tri_fill_ns(), one gotoxy() then back-to-back putchar()s
 * per row, same trick as quad_fill()); the West/East triangles are
 * swept column by column (tri_fill_we()) - a column can't be drawn
 * with back-to-back putchar()s the way a row can, so that one gotoxy()
 * per cell instead, same as blank_cell()/draw_token() do elsewhere in
 * this file. No artificial delay anywhere here either.
 * ================================================================== */

/* Column span [lo,hi] of the North/South triangles at row r (1..24).
 * Both triangles sit against the SAME two diagonals - (1,1)-(80,24)
 * and (80,1)-(1,24) - but North (is_north=1) is bounded by where each
 * diagonal is ABOVE row r's crossing, South by where it's BELOW, so
 * the two halves round differently (one needs the ceiling of the
 * diagonal's real column at that row, the other the floor) - using
 * the same rounding for both, as an earlier draft of this function
 * did, silently overlapped a handful of cells with tri_row_band()'s
 * West/East bands along the seam nearest the centre; this pairing is
 * the one that was checked cell-by-cell (all 1920 of them) to tile
 * the screen exactly, no gaps, no overlaps. */
static void tri_col_band(int r, int is_north, int *lo, int *hi)
{
    int n = (r - 1) * 79;
    if (is_north) {
        *lo = 1 + (n + 22) / 23;   /* ceil(n/23) */
        *hi = 79 - n / 23;         /* floor(n/23) */
    } else {
        *lo = 80 - n / 23;
        *hi = (n + 22) / 23;
    }
}

/* Row span [lo,hi] of the West/East triangles at column c (1..80) -
 * same two diagonals and the same reasoning as tri_col_band() above,
 * just transposed (row/column swapped), and checked the same way. */
static void tri_row_band(int c, int is_west, int *lo, int *hi)
{
    int p = (c - 1) * 23;
    int q = (80 - c) * 23;
    if (is_west) {
        *lo = 2 + p / 79;
        *hi = (q + 78) / 79;      /* ceil(q/79) */
    } else {
        *lo = 1 + (q + 78) / 79;
        *hi = 1 + p / 79;
    }
}

/* North/South sweep: r1..r2 is the triangle's own row range (1..12 for
 * North, 24..13 for South - r1 may be above or below r2, the step
 * below goes either way), each row filled lo..hi per tri_col_band().
 * Near dead centre a row's span can be empty (lo>hi, nothing to draw
 * that row) - expected, that row's cells there belong to West/East
 * instead. */
static void tri_fill_ns(int r1, int r2, int is_north, int mode)
{
    int step = (r2 >= r1) ? 1 : -1;
    int r, lo, hi, k;

    for (r = r1; ; r += step) {
        tri_col_band(r, is_north, &lo, &hi);
        if (lo <= hi) {
            gotoxy(lo, r);
            if (mode == QF_REV) rev_on();
            else if (mode == QF_GFX) gfx_on();
            for (k = lo; k <= hi; k++) putchar(mode == QF_GFX ? G_SH : ' ');
            if (mode == QF_REV) rev_off();
            else if (mode == QF_GFX) gfx_off();
        }
        if (r == r2) break;
    }
}

/* West/East sweep: c1..c2 is the triangle's own column range (1..40
 * for West, 80..41 for East), each column filled lo..hi per
 * tri_row_band() - also possibly empty near dead centre, same as
 * above. */
static void tri_fill_we(int c1, int c2, int is_west, int mode)
{
    int step = (c2 >= c1) ? 1 : -1;
    int c, lo, hi, k;

    for (c = c1; ; c += step) {
        tri_row_band(c, is_west, &lo, &hi);
        if (lo <= hi) {
            if (mode == QF_REV) rev_on();
            else if (mode == QF_GFX) gfx_on();
            for (k = lo; k <= hi; k++) {
                gotoxy(c, k);
                putchar(mode == QF_GFX ? G_SH : ' ');
            }
            if (mode == QF_REV) rev_off();
            else if (mode == QF_GFX) gfx_off();
        }
        if (c == c2) break;
    }
}

static void tri_transition(void)
{
    /* Fill. */
    tri_fill_ns(1, 12, 1, QF_GFX);    /* North : top -> down,   checkerboard  */
    tri_fill_ns(24, 13, 0, QF_GFX);   /* South : bottom -> up,  checkerboard  */
    tri_fill_we(1, 40, 1, QF_REV);    /* West  : left -> right, reverse-video */
    tri_fill_we(80, 41, 0, QF_REV);   /* East  : right -> left, reverse-video */

    /* Erase, same triangles/order/directions, back to a blank screen. */
    tri_fill_ns(1, 12, 1, QF_PLAIN);
    tri_fill_ns(24, 13, 0, QF_PLAIN);
    tri_fill_we(1, 40, 1, QF_PLAIN);
    tri_fill_we(80, 41, 0, QF_PLAIN);
}

/* ------------------------------------------------------------------
 * Board frame drawing.
 * ------------------------------------------------------------------ */
static int col_x(int c) { return GRID_LEFT + c * (CELL_W + 1); }
static int row_y(int r) { return GRID_TOP  + r * (CELL_H + 1); }

/* One full-width horizontal boundary row (top border / bottom border
 * / an internal row separator). At internal column-boundary spots on
 * the TOP border and on internal row separators there is no proven
 * top-tee/cross glyph on this hardware (see file header), so the
 * line just runs straight through (G_H) there; every other junction
 * uses a glyph already confirmed elsewhere in this port family. */
static void hline_row(int row, int is_top, int is_bottom)
{
    int c, x, k;

    gfx_on();
    for (c = 0; c <= BOARD_COLS; c++) {
        x = col_x(c);
        gotoxy(x, row);
        if (c == 0) {
            putchar(is_top ? G_TL : (is_bottom ? G_BL : G_LT));
        } else if (c == BOARD_COLS) {
            putchar(is_top ? G_TR : (is_bottom ? G_BR : G_RT));
        } else if (is_bottom) {
            putchar(G_BT);
        } else {
            putchar(G_H);
        }
        if (c < BOARD_COLS) {
            for (k = 1; k <= CELL_W; k++) putchar(G_H);
        }
    }
    gfx_off();
}

/* One interior content row: vertical separators at every column
 * boundary (all proven G_V), blank cell interiors in between -
 * tokens are drawn separately by draw_token(). */
static void vline_row(int row)
{
    int c, x;

    gfx_on();
    for (c = 0; c <= BOARD_COLS; c++) {
        x = col_x(c);
        gotoxy(x, row);
        putchar(G_V);
    }
    gfx_off();
}

static void draw_board_frame(void)
{
    int r, k;

    for (r = 0; r <= BOARD_ROWS; r++) {
        hline_row(row_y(r), r == 0, r == BOARD_ROWS);
        if (r < BOARD_ROWS) {
            for (k = 1; k <= CELL_H; k++) vline_row(row_y(r) + k);
        }
    }
}

/* board_row: 0 = bottom row of the board, BOARD_ROWS-1 = top row.
 * player: 1 = reverse-video block, 2 = graphics checkerboard (normal
 * video) - same convention as bship.c's put_ship_cell()/put_hit(). */
static void draw_token(int col, int board_row, int player)
{
    int visual_row = BOARD_ROWS - 1 - board_row;
    int top  = row_y(visual_row) + 1;
    int left = col_x(col) + 1;
    int i, k;

    for (i = 0; i < CELL_H; i++) {
        gotoxy(left, top + i);
        if (player == 1) {
            rev_on();
            for (k = 0; k < CELL_W; k++) putchar(' ');
            rev_off();
        } else {
            gfx_on();
            for (k = 0; k < CELL_W; k++) putchar(G_SH);
            gfx_off();
        }
    }
}

/* Same cell geometry as draw_token(), but blanks it instead of drawing
 * a token - used to blink a winning line's cells in play_end_sequence(). */
static void blank_cell(int col, int board_row)
{
    int visual_row = BOARD_ROWS - 1 - board_row;
    int top  = row_y(visual_row) + 1;
    int left = col_x(col) + 1;
    int i, k;

    for (i = 0; i < CELL_H; i++) {
        gotoxy(left, top + i);
        for (k = 0; k < CELL_W; k++) putchar(' ');
    }
}

/* 3-char marker on ROW_CURSOR, centered over column c, styled like
 * the current player's own token - so the cursor itself shows whose
 * turn it is. Clears the whole row first. */
static void draw_cursor(int c, int player)
{
    int i, x;

    gotoxy(GRID_LEFT, ROW_CURSOR);
    for (i = 0; i < GRID_W; i++) putchar(' ');

    x = col_x(c) + 1 + (CELL_W - 3) / 2;
    gotoxy(x, ROW_CURSOR);
    if (player == 1) {
        rev_on();
        fputs("   ", stdout);
        rev_off();
    } else {
        gfx_on();
        putchar(G_SH); putchar(G_SH); putchar(G_SH);
        gfx_off();
    }
}

/* ------------------------------------------------------------------
 * Board state + win detection + AI - ported from CONNECT4_VAX.C
 * essentially unchanged (pure logic, no terminal dependency). Only
 * change: rand() -> mrand().
 *
 * board[col][row]: 0 = empty, 1 = human, 2 = AI. row 0 = bottom row
 * (matches draw_token()'s board_row convention).
 * ------------------------------------------------------------------ */
static int board[BOARD_COLS][BOARD_ROWS];
static int col_height[BOARD_COLS];

/* The 4 (col, board_row) cells of the most recent winning line found by
 * check_win() - set only when it returns 1, read by play_end_sequence()
 * to blink those tokens in the status-bar pause. ai_choose_column()
 * calls check_win() speculatively too (win-now / block / fork checks),
 * which also writes this array on a speculative hit, but never as the
 * LAST check_win() call before a real win: game_screen() breaks out of
 * its loop immediately on a true result, so the one real, final
 * check_win() call for that drop is always the last one to run before
 * play_end_sequence() reads win_cells - any earlier speculative
 * overwrite from inside ai_choose_column() is harmless. */
static int win_cells[4][2];

static void board_reset(void)
{
    int c, r;
    for (c = 0; c < BOARD_COLS; c++) {
        col_height[c] = 0;
        for (r = 0; r < BOARD_ROWS; r++) board[c][r] = 0;
    }
}

static int count_dir(int c, int r, int dc, int dr, int player)
{
    int n = 0;
    c += dc; r += dr;
    while (c >= 0 && c < BOARD_COLS && r >= 0 && r < BOARD_ROWS &&
           board[c][r] == player) {
        n++;
        c += dc; r += dr;
    }
    return n;
}

static int check_win(int c, int r, int player)
{
    static const int dirs[4][2] = { {1,0}, {0,1}, {1,1}, {1,-1} };
    int i;

    for (i = 0; i < 4; i++) {
        int dc = dirs[i][0], dr = dirs[i][1];
        int fwd  = count_dir(c, r, dc, dr, player);
        int back = count_dir(c, r, -dc, -dr, player);
        int total = 1 + fwd + back;
        if (total >= 4) {
            /* Record the 4 cells starting from the back end of the run,
             * so win_cells always holds exactly 4 consecutive cells of
             * the winning line even if more than 4 happen to line up. */
            int k, sc = c - back * dc, sr = r - back * dr;
            for (k = 0; k < 4; k++) {
                win_cells[k][0] = sc + k * dc;
                win_cells[k][1] = sr + k * dr;
            }
            return 1;
        }
    }
    return 0;
}

static int board_full(void)
{
    int c;
    for (c = 0; c < BOARD_COLS; c++)
        if (col_height[c] < BOARD_ROWS) return 0;
    return 1;
}

static int window_open(int c, int r, int dc, int dr, int start, int player)
{
    int k, cc, rr;
    for (k = 0; k < 4; k++) {
        cc = c + (start + k) * dc;
        rr = r + (start + k) * dr;
        if (cc < 0 || cc >= BOARD_COLS || rr < 0 || rr >= BOARD_ROWS) return 0;
        if (board[cc][rr] != 0 && board[cc][rr] != player) return 0;
    }
    return 1;
}

static int line_potential(int c, int r, int player)
{
    static const int dirs[4][2] = { {1,0}, {0,1}, {1,1}, {1,-1} };
    int i, s, total = 0;
    for (i = 0; i < 4; i++)
        for (s = -3; s <= 0; s++)
            total += window_open(c, r, dirs[i][0], dirs[i][1], s, player);
    return total;
}

static int ai_choose_column(int ai_player)
{
    static const int col_weight[BOARD_COLS] = { 3, 4, 5, 7, 5, 4, 3 };
    int opp = (ai_player == 1) ? 2 : 1;
    int c, r, i;
    int cand[BOARD_COLS], ncand;
    int safe[BOARD_COLS], nsafe;
    int best_c, best_score, score, tie_count;

    /* 1. Win immediately if possible. */
    for (c = 0; c < BOARD_COLS; c++) {
        if (col_height[c] >= BOARD_ROWS) continue;
        r = col_height[c];
        board[c][r] = ai_player;
        if (check_win(c, r, ai_player)) { board[c][r] = 0; return c; }
        board[c][r] = 0;
    }

    /* 2. Block the opponent's immediate win. */
    for (c = 0; c < BOARD_COLS; c++) {
        if (col_height[c] >= BOARD_ROWS) continue;
        r = col_height[c];
        board[c][r] = opp;
        if (check_win(c, r, opp)) { board[c][r] = 0; return c; }
        board[c][r] = 0;
    }

    /* 2b. Block a fork: a column that isn't a win for the opponent
           yet but would hand them two or more winning columns next
           turn (the classic "open three"). */
    for (c = 0; c < BOARD_COLS; c++) {
        int c2, r2, wins;

        if (col_height[c] >= BOARD_ROWS) continue;
        r = col_height[c];
        board[c][r] = opp;
        col_height[c]++;

        wins = 0;
        for (c2 = 0; c2 < BOARD_COLS; c2++) {
            if (col_height[c2] >= BOARD_ROWS) continue;
            r2 = col_height[c2];
            board[c2][r2] = opp;
            if (check_win(c2, r2, opp)) wins++;
            board[c2][r2] = 0;
        }

        col_height[c]--;
        board[c][r] = 0;

        if (wins >= 2) return c;
    }

    ncand = 0;
    for (c = 0; c < BOARD_COLS; c++)
        if (col_height[c] < BOARD_ROWS) cand[ncand++] = c;

    /* 3. Drop the columns that would hand the opponent an immediate
          win on top of the cell we'd just fill. */
    nsafe = 0;
    for (i = 0; i < ncand; i++) {
        c = cand[i];
        r = col_height[c];
        board[c][r] = ai_player;
        col_height[c]++;
        if (col_height[c] < BOARD_ROWS) {
            int r2 = col_height[c];
            board[c][r2] = opp;
            if (!check_win(c, r2, opp)) safe[nsafe++] = c;
            board[c][r2] = 0;
        } else {
            safe[nsafe++] = c;
        }
        col_height[c]--;
        board[c][r] = 0;
    }
    if (nsafe == 0) {
        for (i = 0; i < ncand; i++) safe[i] = cand[i];
        nsafe = ncand;
    }

    /* 4. Weighted scoring among the safe columns, center-biased,
          ties broken at random. */
    best_c = safe[0];
    best_score = -9999;
    tie_count = 0;
    for (i = 0; i < nsafe; i++) {
        c = safe[i];
        r = col_height[c];

        {
            int opp_pot = line_potential(c, r, opp);
            int ai_pot;
            board[c][r] = ai_player;
            ai_pot = line_potential(c, r, ai_player);
            board[c][r] = 0;
            score = ai_pot - opp_pot + col_weight[c];
        }

        if (score > best_score) {
            best_score = score;
            best_c = c;
            tie_count = 1;
        } else if (score == best_score) {
            tie_count++;
            if ((mrand() % tie_count) == 0) best_c = c;
        }
    }
    return best_c;
}

/* ------------------------------------------------------------------
 * End screen - same box style as bship.c's end_screen(), minus the
 * Hall of Fame table (this port has none - see file header).
 *
 * Geometry is centered on the full 24x80 screen (end_screen() clears
 * the whole screen first, so there's no title/status bar to leave
 * room for). Horizontally: GBY_BC=10, box width 62 (GBY_BW=60 plus
 * its two border columns) against COLS=80 gives a 9-column margin on
 * both sides - already exactly symmetric. Vertically: box height 9
 * (7 interior rows plus 2 border rows) against 24 screen rows leaves
 * 15 rows to split above/below; 15 is odd, so GBY_BR=8 gives the
 * closest possible split (7 rows above, 8 below) - one row off from
 * perfect only because 24-9 doesn't divide evenly, not a bug. (An
 * earlier version had a 6-interior-row box at the same GBY_BR=8,
 * which threw that split off by two rows instead of one - fixed by
 * sizing the box to its actual content instead of eyeballing it.)
 * ------------------------------------------------------------------ */
#define GBY_BC  10
#define GBY_BW  60
#define GBY_BR   8

#define RES_LOSE 0
#define RES_WIN  1
#define RES_DRAW 2
#define RES_QUIT 3

static void gcbox_line(int row, const char *txt)
{
    int l = 0, p;
    const char *q = txt; while (*q++) l++;
    p = (GBY_BW - l) / 2;
    gfx_on();
    gotoxy(GBY_BC, row); putchar(G_V);
    gotoxy(GBY_BC + GBY_BW + 1, row); putchar(G_V);
    gfx_off();
    if (l > 0) { gotoxy(GBY_BC + 1 + p, row); fputs(txt, stdout); }
}

static void end_screen(int result)
{
    const char *line1;

    clrscr();
    cursor_off();

    switch (result) {
        case RES_WIN:  line1 = "YOU WIN! Four in a row - well played.";        break;
        case RES_LOSE: line1 = "YOU LOSE! The Computer wins.";                 break;
        case RES_DRAW: line1 = "DRAW GAME - the grid is full.";                break;
        default:       line1 = "GAME ABORTED.";                                break;
    }

    /* 7 interior rows: 1 blank above the result line, 2 blank below it
     * (RomaX ManiaX asked for 2, not 1), the two closing lines, and 1
     * blank bookending the bottom - see the box-height comment above
     * for how GBY_BR+8 keeps this centered. */
    draw_box(GBY_BC, GBY_BR, GBY_BC + GBY_BW + 1, GBY_BR + 8);
    gcbox_line(GBY_BR + 1, "");
    gcbox_line(GBY_BR + 2, line1);
    gcbox_line(GBY_BR + 3, "");
    gcbox_line(GBY_BR + 4, "");
    gcbox_line(GBY_BR + 5, "Thank you for playing Connect 4.");
    gcbox_line(GBY_BR + 6, "Hope to see you again soon !");
    gcbox_line(GBY_BR + 7, "");

    /* No "press any key" prompt, no wait for one, and (as of this pass)
     * no timed hold either - the box is drawn and end_screen() returns
     * immediately, straight back to the CP/M command prompt. Exit is
     * still clean, same as CONNECT4_VAX.C's own clean_exit(): cursor
     * back on, but no clear and no cursor-home, so the goodbye box
     * stays on screen exactly as drawn instead of being wiped on the
     * way out. */
    cursor_on();
}

/* How long blink_pause() flashes the result before tri_transition()
 * runs - a first guess at a multi-second pause (BLINK_TOGGLES
 * on/off flips, BLINK_HALF_LOOPS busy-wait iterations each), same
 * "not yet confirmed on real hardware" caveat as pause_msg()/
 * ESC_WAIT_LOOPS - flag if it still runs too short or too long.
 * BLINK_HALF_LOOPS was halved from an initial 20000 after RomaX
 * ManiaX flagged the whole pause as twice too long. */
#define BLINK_TOGGLES      10u
#define BLINK_HALF_LOOPS 10000u

/* Blinks a centered result message on the status bar for a few
 * seconds - same first beat as CONNECT4_VAX.C's finish_match() (blink
 * the result, THEN tri_transition(), THEN the goodbye box - see
 * play_end_sequence() near main()). Plain text, no reverse video -
 * this hardware has no confirmed native "blink" attribute (VAX's own
 * draw_status_blink() uses VT100 ESC[5m, not available here), so the
 * blink itself is just the message alternating against a blank bar,
 * both drawn with the ordinary draw_status(). Leaves the message
 * showing once the toggling is done.
 *
 * have_cells/player: for a real win (WIN or LOSE, not DRAW),
 * play_end_sequence() also passes the winning line (win_cells[], set by
 * check_win()) and which player's token style to draw it with, so the
 * 4 winning tokens blink on the board in ALTERNATION with the status
 * message - hidden while the message shows, shown while the message is
 * blank - rather than in the same phase. DRAW has no winning line, so
 * it just passes have_cells=0 and blink_pause() leaves the board alone,
 * same as before this feature existed. */
static void blink_pause(const char *turn_label, const char *center_msg,
                         int have_cells, int player)
{
    unsigned i;
    volatile unsigned d;
    int k;

    for (i = 0; i < BLINK_TOGGLES; i++) {
        int show = !(i & 1);
        draw_status(turn_label, show ? center_msg : "");
        if (have_cells) {
            for (k = 0; k < 4; k++) {
                if (show) blank_cell(win_cells[k][0], win_cells[k][1]);
                else      draw_token(win_cells[k][0], win_cells[k][1], player);
            }
        }
        for (d = 0; d < BLINK_HALF_LOOPS; d++) ;
    }
    draw_status(turn_label, center_msg);
    if (have_cells) {
        for (k = 0; k < 4; k++) draw_token(win_cells[k][0], win_cells[k][1], player);
    }
}

/* Runs the pre-goodbye-box beat for a genuine match result (win/lose/
 * draw), reproducing CONNECT4_VAX.C's own finish_match() sequence:
 * blink the result in the status bar for a few seconds, THEN
 * tri_transition(), THEN end_screen()'s goodbye box. A voluntary ESC
 * quit skips straight to end_screen() instead (see game_screen()) -
 * it isn't a match result and doesn't get the theatrics. */
static void play_end_sequence(int result)
{
    const char *turn_label = 0;
    const char *msg = 0;

    switch (result) {
        case RES_WIN:  turn_label = "Player 1"; msg = "YOU WIN!";     break;
        case RES_LOSE: turn_label = "Computer"; msg = "YOU LOSE!";    break;
        case RES_DRAW: turn_label = "Player 1"; msg = "DRAW GAME!";   break;
        default: break;
    }

    if (msg) {
        /* Winning line blinks along with the message for a real win/
         * lose (win_cells[] was set by the check_win() call that ended
         * the match); a draw has no winning line, so the board is left
         * alone. */
        int have_cells = (result == RES_WIN || result == RES_LOSE);
        int player = (result == RES_WIN) ? 1 : 2;
        blink_pause(turn_label, msg, have_cells, player);
        tri_transition();
    }

    end_screen(result);
}

/* ------------------------------------------------------------------
 * Game loop - solo, human always first. Human uses 4/6 to move the
 * column cursor and Space to drop; the AI answers right after, with
 * a short pause_msg() so its move reads as a "decision" rather than
 * an instant snap (same idea as bship.c's own turn pacing).
 * ------------------------------------------------------------------ */
static void game_screen(void)
{
    int cur_col = BOARD_COLS / 2;
    int key, r, result;

    board_reset();
    result = RES_QUIT;

    clrscr();
    draw_title();
    draw_board_frame();
    draw_cursor(cur_col, 1);
    draw_status("Player 1", "You vs Computer - line up 4 to win");

    for (;;) {
        key = get_key();

        if (key == '4') {
            if (cur_col > 0) cur_col--;
            draw_cursor(cur_col, 1);
        } else if (key == '6') {
            if (cur_col < BOARD_COLS - 1) cur_col++;
            draw_cursor(cur_col, 1);
        } else if (key == ' ') {
            if (col_height[cur_col] >= BOARD_ROWS) {
                continue;
            }

            r = col_height[cur_col];
            board[cur_col][r] = 1;
            col_height[cur_col]++;
            draw_token(cur_col, r, 1);

            if (check_win(cur_col, r, 1)) { result = RES_WIN;  break; }
            if (board_full())             { result = RES_DRAW; break; }

            /* Single pause here, right after the cursor lands on the
             * chosen column - same as CONNECT4_VAX.C's own game_screen()
             * (one get_key_timed(1), not two). There used to be a second
             * pause_msg() right after this status line too, before even
             * calling ai_choose_column() - doubling the wait before
             * anything visibly happened for no real benefit, since
             * choosing a column is cheap. Dropped. */
            draw_status("Computer", "The computer is thinking...");
            cur_col = ai_choose_column(2);
            draw_cursor(cur_col, 2);
            pause_msg();

            r = col_height[cur_col];
            board[cur_col][r] = 2;
            col_height[cur_col]++;
            draw_token(cur_col, r, 2);

            if (check_win(cur_col, r, 2)) { result = RES_LOSE; break; }
            if (board_full())             { result = RES_DRAW; break; }

            draw_status("Player 1", "You vs Computer - line up 4 to win");
            draw_cursor(cur_col, 1);
        } else if (key == 27) {
            if (confirm_quit("Player 1")) { result = RES_QUIT; break; }
            draw_status("Player 1", "You vs Computer - line up 4 to win");
        }
    }

    play_end_sequence(result);
}

int main(void)
{
    clrscr();
    cursor_off();

    welcome_screen();
    quad_transition();

    game_screen();

    return 0;
}
