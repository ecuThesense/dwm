#include <X11/XF86keysym.h>
/* appearance */
static const unsigned int borderpx  = 5;        /* border pixel of windows */
static const int gappx = 0;
static const float colwidths[] = { 1.0/3, 0.5, 2.0/3, };

static const unsigned int snap      = 32;       /* snap pixel */
static const int showbar            = 1;        /* 0 means no bar */
static const int topbar             = 1;        /* 0 means bottom bar */
static const char *fonts[]          = { "AdwaitaMono Nerd Font:size=14" };
static const char dmenufont[]       = "AdwaitaMono Nerd Font:size=14";
static const char col_gray1[]       = "#222222";
static const char col_gray2[]       = "#505050";
static const char col_gray3[]       = "#bbbbbb";
static const char col_gray4[]       = "#15161e";
static const char col_cyan[]        = "#7aa2f7";
static const char *colors[][3]      = {
	/*               fg         bg         border   */
	[SchemeNorm] = { col_gray3, col_gray1, col_gray2 },
	[SchemeSel]  = { col_gray4, col_cyan,  col_cyan },
};

/* tagging */
static const char *tags[] = { "1", "2", "3", "4", "5" };

static const Rule rules[] = {
	/* xprop(1):
	 *	WM_CLASS(STRING) = instance, class
	 *	WM_NAME(STRING) = title
	 */
	/* class          instance    title       tags mask     isfloating   monitor   cw  */
	{ "Gimp",         NULL,       NULL,       0,            0,           -1,       1.0  },
	{ "firefox-esr",  NULL,       NULL,       0,            0,           -1,       1.0  },
};

/* layout(s) */
static const float mfact     = 0.5;  /* factor of master area size [0.05..0.95] */
static const int nmaster     = 1;    /* number of clients in master area */
static const int resizehints = 0;    /* 1 means respect size hints in tiled resizals */
static const int lockfullscreen = 1; /* 1 will force focus on the fullscreen window */
static const int refreshrate = 120;  /* refresh rate (per second) for client move/resize */

static const Layout layouts[] = {
 	/* symbol     arrange function */
  {  "",        scroll },
 	{  "",        NULL },    /* no layout function means floating behavior */
  // { "|||",    scroll },
 	/* { "",      tile },*/    /* first entry is default */
 	/* { "",      monocle }, */
 };

/* key definitions */
#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask,           KEY,      toggleview,     {.ui = 1 << TAG} }, \
	{ MODKEY|ShiftMask,             KEY,      tag,            {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask|ShiftMask, KEY,      toggletag,      {.ui = 1 << TAG} },

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* System */
static char dmenumon[2] = "0"; /* component of dmenucmd, manipulated in spawn() */
static const char *dmenucmd[] = { "dmenu_run", "-m", dmenumon, "-fn", dmenufont, "-nb", col_gray1, "-nf", col_gray3, "-sb", col_cyan, "-sf", col_gray4, NULL };
/* Apps */
static const char *termcmd[]  = { "st", "-f", "AdwaitaMono Nerd Font:size=16", NULL };
/* static const char *filemanager[]  = { "st", "-f", "AdwaitaMono Nerd Font:size=16", "-e", "nnn", NULL }; */
static const char *filemanager[]  = { "pcmanfm", NULL };
static const char *texteditor[]  = { "st", "-f", "AdwaitaMono Nerd Font:size=16", "-e", "nvim", NULL };
/* static const char *browser[]  = {"firefox", NULL}; */
/*
static const char *browser[]  = {
    "sh", "-c",
    "query=$(printf '' | dmenu -fn monospace:size=14 -p 'Search: ') && "
    "surf \"https://www.startpage.com/do/dsearch?query=$(printf '%s' \"$query\" | sed 's/ /+/g')\"",
    NULL
};
*/
/* static const char *browser[]  = {"./dwm/dwm/scripts/surf-launch.sh", NULL}; */
static const char *browser[]  = {"./dwm/dwm/scripts/dwm-browser-launch.sh", NULL};
static const char *locker[]  = { "slock", NULL };
/* Audio & Brightness
static const char *audiomute[]  = { "wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle", "&&", "~/dwm/dwm/scripts/statusbar.sh", "--once", NULL };
static const char *audiolower[]  = { "wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "0.1-", "&&", "~/dwm/dwm/scripts/statusbar.sh", "--once", NULL };
static const char *audioraise[]  = { "wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "0.1+", "-l", "1.0", "&&", "~/dwm/dwm/scripts/statusbar.sh", "--once", NULL };
static const char *micmute[]  = { "wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle", NULL };
static const char *audioplay[]  = { "playerctl", "play-pause", NULL };
static const char *audiostop[]  = { "playerctl", "stop", NULL };
static const char *audioprev[]  = { "playerctl", "previous", NULL };
static const char *audionext[]  = { "playerctl", "next", NULL };

static const char *brightnessup[]  = { "brightnessctl", "--class=backlight", "set", "+10%", NULL };
static const char *brightnessdown[]  = { "brightnessctl", "--class=backlight", "set", "10%-", NULL };
*/

/*Move Stack Function*/
void
movestack(const Arg *arg) {
	Client *c = NULL, *p = NULL, *pc = NULL, *i;

	if (arg->i > 0) {
		/* find the client after selmon->sel */
		for (c = selmon->sel->next; c && (!ISVISIBLE(c) || c->isfloating); c = c->next);
		if (!c)
			for (c = selmon->clients; c && (!ISVISIBLE(c) || c->isfloating); c = c->next);
	} else {
		/* find the client before selmon->sel */
		for (i = selmon->clients; i != selmon->sel; i = i->next)
			if (ISVISIBLE(i) && !i->isfloating)
				c = i;
		if (!c)
			for (; i; i = i->next)
				if (ISVISIBLE(i) && !i->isfloating)
					c = i;
	}
	/* find the client before selmon->sel and c */
	for (i = selmon->clients; i && (!p || !pc); i = i->next) {
		if (i->next == selmon->sel)
			p = i;
		if (i->next == c)
			pc = i;
	}

	/* swap c and selmon->sel in the clients list */
	if (c && c != selmon->sel) {
		Client *temp = selmon->sel->next == c ? selmon->sel : selmon->sel->next;
		selmon->sel->next = c->next == selmon->sel ? c : c->next;
		c->next = temp;

		if (p && p != c)
			p->next = c;
		if (pc && pc != selmon->sel)
			pc->next = selmon->sel;

		if (selmon->sel == selmon->clients)
			selmon->clients = c;
		else if (c == selmon->clients)
			selmon->clients = selmon->sel;

		arrange(selmon);
	}
}

static const Key keys[] = {
	/* modifier                     key                 function        argument */
	{ MODKEY,                       XK_f,               spawn,          {.v = dmenucmd } },
	{ MODKEY,                       XK_t,               spawn,          {.v = termcmd } },
	{ MODKEY|ShiftMask,             XK_b,               togglebar,      {0} },
	{ MODKEY,                       XK_e,               spawn,          {.v = filemanager } },
	/*{ MODKEY|ShiftMask,             XK_e,               spawn,          SHCMD("st -f AdwaitaMono Nerd Font:size=16 -e ./SourceApps/dwm/dwm/search.sh")},*/
	{ MODKEY|ShiftMask,             XK_e,               spawn,          SHCMD("st -f 'AdwaitaMono Nerd Font:size=16' -e ./dwm/dwm/scripts/file-picker.sh")},
	{ MODKEY,                       XK_i,               spawn,          SHCMD("./dwm/dmenuman/dmenuman.sh")},
	{ MODKEY,                       XK_m,               spawn,          {.v = texteditor } },
	{ MODKEY,                       XK_b,               spawn,          {.v = browser } },

	{ MODKEY,                       XK_l,               focuscol,       {.i = +1} },
	{ MODKEY,                       XK_h,               focuscol,       {.i = -1} },
	{ MODKEY|ShiftMask,             XK_l,               movecol,        {.i = -1} },
	{ MODKEY|ShiftMask,             XK_h,               movecol,        {.i = +1} },
	{ MODKEY,                       XK_r,               cyclecolw,      {.i = +1} },
	{ MODKEY,                       XK_minus,           setcolw,        {.f = -0.10} },
	{ MODKEY,                       XK_plus,            setcolw,        {.f = +0.10} },
	{ MODKEY|ShiftMask,             XK_f,               maxcol,         {0} },
	// { MODKEY,                       XK_l,               focusstack,     {.i = +1 } },
	// { MODKEY,                       XK_h,               focusstack,     {.i = -1 } },
	// { MODKEY,                       XK_k,               incnmaster,     {.i = +1 } },
	// { MODKEY,                       XK_j,               incnmaster,     {.i = -1 } },
	// { MODKEY|ShiftMask,             XK_j,               setmfact,       {.f = -0.05} },
	// { MODKEY|ShiftMask,             XK_k,               setmfact,       {.f = +0.05} },

  { MODKEY|ShiftMask,             XK_h,               movestack,      {.i = -1 } },
  { MODKEY|ShiftMask,             XK_l,               movestack,      {.i = +1 } },
	{ MODKEY,                       XK_z,               zoom,           {0} },
	{ MODKEY,                       XK_Tab,             view,           {0} },
	{ MODKEY,                       XK_w,               killclient,     {0} },
	// { MODKEY|ShiftMask,             XK_t,               setlayout,      {.v = &layouts[0]} },
/*{ MODKEY|ShiftMask,             XK_f,               setlayout,      {.v = &layouts[1]} },*/
	{ MODKEY|ControlMask|ShiftMask, XK_f,               togglefloating, {0} },
	// { MODKEY|ShiftMask,             XK_m,               setlayout,      {.v = &layouts[2]} },
/*{ MODKEY|ShiftMask,             XK_space,           setlayout,      {0} },*/
	{ MODKEY,                       XK_0,               view,           {.ui = ~0 } },
	{ MODKEY|ShiftMask,             XK_0,               tag,            {.ui = ~0 } },
	{ MODKEY,                       XK_comma,           focusmon,       {.i = -1 } },
	{ MODKEY,                       XK_period,          focusmon,       {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_comma,           tagmon,         {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_period,          tagmon,         {.i = +1 } },
	TAGKEYS(                        XK_1,                               0)
	TAGKEYS(                        XK_2,                               1)
	TAGKEYS(                        XK_3,                               2)
	TAGKEYS(                        XK_4,                               3)
	TAGKEYS(                        XK_5,                               4)
	TAGKEYS(                        XK_6,                               5)
	TAGKEYS(                        XK_7,                               6)
	TAGKEYS(                        XK_8,                               7)
	TAGKEYS(                        XK_9,                               8)
	{ MODKEY|ShiftMask,             XK_u,               quit,           {0} },
	{ MODKEY,                       XK_u,               spawn,          {.v = locker } },
	{ 0,                     XF86XK_AudioMute,          spawn,          SHCMD("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")},
	{ 0,                     XF86XK_AudioLowerVolume,   spawn,          SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-")},
	{ 0,                     XF86XK_AudioRaiseVolume,   spawn,          SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+ -l 1.0")},
	{ 0,                     XF86XK_AudioMicMute,       spawn,          SHCMD("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")},
	{ 0,                     XF86XK_AudioPlay,          spawn,          SHCMD("playerctl play-pause")},
	{ 0,                     XF86XK_AudioStop,          spawn,          SHCMD("playerctl stop")},
	{ 0,                     XF86XK_AudioPrev,          spawn,          SHCMD("playerctl previous")},
	{ 0,                     XF86XK_AudioNext,          spawn,          SHCMD("playerctl next")},
	{ 0,                     XF86XK_MonBrightnessUp,    spawn,          SHCMD("brightnessctl --class=backlight set +10%")},
	{ 0,                     XF86XK_MonBrightnessDown,  spawn,          SHCMD("brightnessctl --class=backlight set 10%-")},
	{ 0,                     XK_Print,                  spawn,          SHCMD("maim -s ~/Pictures/Screenshots/$(date +%s).png | xclip -selection clipboard -t image/png")},
};

/* button definitions */
/* click can be ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static const Button buttons[] = {
	/* click                event mask      button          function        argument */
	// { ClkLtSymbol,          0,              Button1,        setlayout,      {0} },
	// { ClkLtSymbol,          0,              Button3,        setlayout,      {.v = &layouts[2]} },
	{ ClkWinTitle,          0,              Button2,        zoom,           {0} },
	{ ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } },
	{ ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
	// { ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} },
	{ ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
	{ ClkTagBar,            0,              Button1,        view,           {0} },
	{ ClkTagBar,            0,              Button3,        toggleview,     {0} },
	{ ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
	{ ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
};

