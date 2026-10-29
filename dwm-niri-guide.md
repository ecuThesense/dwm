# dwm → niri-style scrolling columns

```

All edits below are in `dwm.c` and `config.h`.

---

## Data model (`dwm.c`)

In `struct Client` add:

```c
	float cw;          /* column width, fraction of screen */
```

In `struct Monitor` add:

```c
	int viewx;         /* scroll offset of the strip */
```

In `manage()`, right after `c->oldbw = wa->border_width;`:

```c
	c->cw = 0.5;
```

Add to the function declarations near the top (next to `static void tile(Monitor *);`):

```c
static void scroll(Monitor *m);
static void focuscol(const Arg *arg);
static void movecol(const Arg *arg);
static void cyclecolw(const Arg *arg);
```

---

## New windows open right of the focused one

Replace `attach()`:

```c
void
attach(Client *c)
{
	Client *s = c->mon->sel;

	if (s && s != c) {
		c->next = s->next;
		s->next = c;
	} else {
		c->next = c->mon->clients;
		c->mon->clients = c;
	}
}
```

The order of `m->clients` is now the left-to-right column order.

---

## The layout

Add anywhere after `nexttiled()` is declared (for example where `tile()` is):

```c
void
scroll(Monitor *m)
{
	Client *c, *sel = m->sel;
	int x = gappx, w, sx, selx = 0, selw = 0, total;
	int y = m->wy + gappx, h = m->wh - 2 * gappx;

	/* pass 1: column positions in strip coordinates, find focused column */
	for (c = nexttiled(m->clients); c; c = nexttiled(c->next)) {
		w = (int)(c->cw * (m->ww - gappx)) - gappx;   /* outer width */
		if (c == sel) {
			selx = x;
			selw = w;
		}
		x += w + gappx;
	}
	total = x;

	/* scroll the minimum amount needed to show the focused column */
	if (sel && !sel->isfloating && ISVISIBLE(sel)) {
		if (selx - gappx < m->viewx)
			m->viewx = selx - gappx;
		else if (selx + selw + gappx > m->viewx + m->ww)
			m->viewx = selx + selw + gappx - m->ww;
	}
	if (m->viewx > total - m->ww)
		m->viewx = total - m->ww;
	if (m->viewx < 0)
		m->viewx = 0;

	/* pass 2: place the windows */
	x = gappx;
	for (c = nexttiled(m->clients); c; c = nexttiled(c->next)) {
		w = (int)(c->cw * (m->ww - gappx)) - gappx;
		sx = m->wx + x - m->viewx;
		if (sx + w <= m->wx || sx >= m->wx + m->ww)
			/* fully off-screen: resize() would clamp it back on-screen */
			resizeclient(c, sx, y, w - 2 * c->bw, h - 2 * c->bw);
		else
			resize(c, sx, y, w - 2 * c->bw, h - 2 * c->bw, 0);
		x += w + gappx;
	}
}
```

The width formula `cw * (ww - gap) - gap` gives equal gaps for 1/3, 1/2, 2/3 and 1.0 columns.

---

## Commands

```c
void
focuscol(const Arg *arg)
{
	focusstack(arg);
	arrange(selmon);        /* re-run the layout so the view follows focus */
}

static void
pushright(Client *c)        /* move c one tiled slot to the right */
{
	Client *n = nexttiled(c->next);

	if (!n)
		return;
	detach(c);
	c->next = n->next;
	n->next = c;
}

void
movecol(const Arg *arg)
{
	Client *c = selmon->sel, *p, *q;

	if (!c || c->isfloating)
		return;
	if (arg->i > 0)
		pushright(c);
	else {
		for (p = NULL, q = nexttiled(selmon->clients); q && q != c; q = nexttiled(q->next))
			p = q;
		if (!p || !q)
			return;
		pushright(p);       /* moving the left neighbour past us = moving us left */
	}
	arrange(selmon);
}

void
cyclecolw(const Arg *arg)
{
	Client *c = selmon->sel;
	size_t i;

	if (!c || c->isfloating)
		return;
	for (i = 0; i < LENGTH(colwidths); i++)
		if (colwidths[i] > c->cw + 0.01)
			break;
	c->cw = colwidths[i % LENGTH(colwidths)];
	arrange(selmon);
}
```

Disable focus-follows-mouse: in the `handler[]` array comment out `[EnterNotify] = enternotify,`. Otherwise, when the strip scrolls under a stationary pointer, focus jumps to whatever slid underneath and you get a scroll loop. Niri defaults to keyboard and click focus anyway.

---

## `config.h`

```c
#define MODKEY Mod4Mask                       /* Super, like niri */

static const int gappx = 10;
static const float colwidths[] = { 1.0/3, 0.5, 2.0/3, 1.0 };

static const char *termcmd[] = { "xterm", NULL };   /* foot is Wayland-only */

static const Layout layouts[] = {
	{ "|||", scroll },
	{ "><>", NULL },                          /* floating */
};
```

In `keys[]`:

- Delete the line binding `XK_m` to `setlayout` (`layouts[2]` no longer exists).
- Replace the `focusstack`, `incnmaster` and `setmfact` lines with:

```c
	{ MODKEY,             XK_Right, focuscol,  {.i = +1} },
	{ MODKEY,             XK_Left,  focuscol,  {.i = -1} },
	{ MODKEY|ControlMask, XK_Right, movecol,   {.i = +1} },
	{ MODKEY|ControlMask, XK_Left,  movecol,   {.i = -1} },
	{ MODKEY,             XK_r,     cyclecolw, {0} },
```

You'll get "defined but not used" warnings for `tile`, `monocle` and `enternotify`. Delete them or ignore the warnings.

---

## Build and test safely

```sh
make
Xephyr -br -ac -noreset -screen 1280x720 :1 &
DISPLAY=:1 ./dwm &
DISPLAY=:1 xterm &
```

Open a few terminals with Super+Shift+Return. Check:

1. New windows appear to the right and the view scrolls to them.
2. Super+←/→ scrolls the strip.
3. Super+Ctrl+←/→ reorders columns.
4. Super+r cycles the column width through 1/3, 1/2, 2/3 and full.

When it works: `doas make clean install`, then start it from `~/.xinitrc` (`exec dwm`).

---
