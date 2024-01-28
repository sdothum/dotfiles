///---User configurable stuff---///
///---Modifiers---///
#define MOD             XCB_MOD_MASK_4       /* Super/Windows key  or check xmodmap(1) with -pm  defined in /usr/include/xcb/xproto.h */
///--Speed---///
/* Move this many pixels when moving or resizing with keyboard unless the window has hints saying otherwise.
 *0)move step slow   1)move step fast
 *2)mouse slow       3)mouse fast     */
static const uint16_t movements[] = {20,40,15,400};
/* resize by line like in mcwm -- jmbi */
static const bool     resize_by_line           = true;
/* the ratio used when resizing and keeping the aspect */
static const float    resize_keep_aspect_ratio = 1.03;
 ///---Offsets---///
/*0)offsetx          1)offsety
 *2)maxwidth         3)maxheight */
// static const uint8_t offsets[] = {0,0,0,0};
static const uint8_t offsets[] = {40,30,80,60};
///---Colors---///
/*0)focuscol         1)unfocuscol
 *2)fixedcol         3)unkilcol
 *4)fixedunkilcol    5)outerbordercol
 *6)emptycol         */
// static const char *colors[] = {"#35586c","#333333","#7a8c5c","#ff6666","#cc9933","#0d131a","#000000"};
static const char *colors[] = {"#ff0000","#546e7a","#008b8b","#fa8c69","#a1462a","#505050","#000000"};
// static const char *colors[] = {"#ff0000","#939393","#008b8b","#fa8c69","#a1462a","#575757","#000000"};
/* if this is set to true the inner border and outer borders colors will be swapped */
static const bool inverted_colors = true;
///---Cursor---///
/* default position of the cursor:
 * correct values are:
 * TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT, MIDDLE
 * All these are relative to the current window. */
#define CURSOR_POSITION MIDDLE
///---Borders---///
/*0) Outer border size. If you put this negative it will be a square.
 *1) Full borderwidth    2) Magnet border size
 *3) Resize border size  */
// static const uint8_t borders[] = {3,5,5,4};
static const uint8_t borders[] = {1,11,11,10};
// static const uint8_t borders[] = {0,0,0,0};
/* Windows that won't have a border.
 * It uses substring comparison with what is found in the WM_NAME
 * attribute of the window. You can test this using `xprop WM_NAME`
 */
#define LOOK_INTO "WM_NAME"
static const char *ignore_names[]  = {"bar", "xclock"};
///--Menus and Programs---///
static const char *build2bwm[]     = {"term", "2bwm", "2make"     , NULL};
static const char *kill2bwm[]      = {"pkill", "-KILL", "2bwm"    , NULL};
static const char *quit2bwm[]      = {"quit2bwm"                  , NULL};
// desktop control
static const char *background[]    = {"toggle", "background"      , NULL};  // root background color
static const char *wallpaper[]     = {"toggle", "wallpaper"       , NULL};  // root wallpaper
static const char *panel[]         = {"toggle", "panel"           , NULL};
static const char *invertpanel[]   = {"invert_panel"              , NULL};  // panel contrast
static const char *notifypush[]    = {"dunstctl", "close"         , NULL};  // dunstctl clear
static const char *notifyclr[]     = {"dunstctl", "close-all"     , NULL};  // dunstctl clear all
static const char *notifypop[]     = {"dunstctl", "history-pop"   , NULL};  // dunstctl history
static const char *wallclock[]     = {"conky", "clock"            , NULL};  // toggle (current) display
static const char *unclock[]       = {"conky", "clock", "toggle"  , NULL};  // toggle mode
// window actions
static const char *hidewindow[]    = {"window", "hide"            , NULL};  // adds focusnext
static const char *unhide[]        = {"menu", "unhide"            , NULL};
static const char *east[]          = {"closest.sh", "east"        , NULL};  // wmutils focus direction
static const char *west[]          = {"closest.sh", "west"        , NULL};
static const char *north[]         = {"closest.sh", "north"       , NULL};
static const char *south[]         = {"closest.sh", "south"       , NULL};
static const char *snapnear[]      = {"window", "snap"            , NULL};
static const char *snapleft[]      = {"window", "snap", "left"    , NULL};
static const char *snapright[]     = {"window", "snap", "right"   , NULL};
static const char *snaptop[]       = {"window", "snap", "top"     , NULL};
static const char *snapbottom[]    = {"window", "snap", "bottom"  , NULL};
static const char *snaplevel[]     = {"window", "snap", "all"     , NULL};  // all windows
static const char *snaprestore[]   = {"window", "snap", "restore" , NULL};  // all windows
static const char *windowstretch[] = {"menu", "windowstretch"     , NULL};
static const char *windowsize[]    = {"menu", "windowsize"        , NULL};
static const char *windowsize0[]   = {"menu", "windowsize", "0"   , NULL};  // Super keybind shortcut
static const char *windowsize1[]   = {"menu", "windowsize", "1"   , NULL};
static const char *windowsize2[]   = {"menu", "windowsize", "2"   , NULL};
static const char *windowsize3[]   = {"menu", "windowsize", "3"   , NULL};
static const char *windowsize4[]   = {"menu", "windowsize", "4"   , NULL};
static const char *windowsize5[]   = {"menu", "windowsize", "5"   , NULL};
static const char *windowsize6[]   = {"menu", "windowsize", "6"   , NULL};
static const char *windowsize7[]   = {"menu", "windowsize", "7"   , NULL};
static const char *windowsize8[]   = {"menu", "windowsize", "8"   , NULL};
static const char *windowsize9[]   = {"menu", "windowsize", "9"   , NULL};
// terminals
static const char *terminal[]      = {"term"                      , NULL};
static const char *scratchy[]      = {"scratchpad", "scratchy"    , NULL};
static const char *itchy[]         = {"scratchpad", "itchy"       , NULL};
// menus
static const char *menucmd[]       = {"menu"                      , NULL};
static const char *address[]       = {"menu", "abook"             , NULL};
static const char *inspector[]     = {"menu", "system"            , NULL};
static const char *media[]         = {"menu", "media"             , NULL};
static const char *notes[]         = {"menu", "notes"             , NULL};
static const char *passwords[]     = {"menu", "passwords"         , NULL};
static const char *projects[]      = {"menu", "projects"          , NULL};
static const char *scripts[]       = {"menu", "scripts"           , NULL};
static const char *wikis[]         = {"menu", "wikis"             , NULL};
static const char *quit[]          = {"menu", "halt"              , NULL};
// apps
static const char *browser[]       = {"qutebrowser"               , NULL};
static const char *browserclr[]    = {"qutebrowser", "closeall"   , NULL};
static const char *btop[]          = {"btop"                      , NULL};
static const char *mail[]          = {"mail"                      , NULL};
static const char *filecli[]       = {"filecli"                   , NULL};
static const char *filegui[]       = {"filegui"                   , NULL};
static const char *fileroot[]      = {"fileroot"                  , NULL};  // superuser
///--Custom foo---///
static void halfandcentered(const Arg *arg)
{
	Arg arg2 = {.i=TWOBWM_MAXHALF_VERTICAL_LEFT};
	maxhalf(&arg2);
	Arg arg3 = {.i=TWOBWM_TELEPORT_CENTER};
	teleport(&arg3);
}
///---Sloppy focus behavior---///
/*
 * Command to execute when switching from sloppy focus to click to focus
 * The strings "Sloppy" and "Click" will be passed as the last argument
 * If NULL this is ignored
 */
// static const char *sloppy_switch_cmd[] = {};
//static const char *sloppy_switch_cmd[] = { "notify-send", "toggle sloppy", NULL };
static const char *sloppy_switch_cmd[] = { "notify-send", "Toggle sloppy focus", NULL };
static void toggle_sloppy(const Arg *arg)
{
	is_sloppy = !is_sloppy;
	if (arg->com != NULL && LENGTH(arg->com) > 0) {
		start(arg);
	}
}
///---Shortcuts---///
/* Check /usr/include/X11/keysymdef.h for the list of all keys
 * 0x000000 is for no modkey
 * If you are having trouble finding the right keycode use the `xev` to get it
 * For example:
 * KeyRelease event, serial 40, synthetic NO, window 0x1e00001,
 *  root 0x98, subw 0x0, time 211120530, (128,73), root:(855,214),
 *  state 0x10, keycode 171 (keysym 0x1008ff17, XF86AudioNext), same_screen YES,
 *  XLookupString gives 0 bytes: 
 *  XFilterEvent returns: False
 *
 *  The keycode here is keysym 0x1008ff17, so use  0x1008ff17
 *
 *
 * For AZERTY keyboards XK_1...0 should be replaced by :
 *      DESKTOPCHANGE(     XK_ampersand,                     0)
 *      DESKTOPCHANGE(     XK_eacute,                        1)
 *      DESKTOPCHANGE(     XK_quotedbl,                      2)
 *      DESKTOPCHANGE(     XK_apostrophe,                    3)
 *      DESKTOPCHANGE(     XK_parenleft,                     4)
 *      DESKTOPCHANGE(     XK_minus,                         5)
 *      DESKTOPCHANGE(     XK_egrave,                        6)
 *      DESKTOPCHANGE(     XK_underscore,                    7)
 *      DESKTOPCHANGE(     XK_ccedilla,                      8)
 *      DESKTOPCHANGE(     XK_agrave,                        9)*
 */
#define DESKTOPCHANGE(K,N) \
	{  MOD |SHIFT,            K,          changeworkspace,     {.i=N}}, \
	{  MOD |CONTROL,          K,          sendtoworkspace,     {.i=N}},
static key keys[] = {
	/* modifier               key            function             argument */
	// Focus to next/previous window
	{  MOD ,                  XK_Tab,        focusnext,           {.i=TWOBWM_FOCUS_NEXT}},
	{  MOD |SHIFT,            XK_Tab,        focusnext,           {.i=TWOBWM_FOCUS_PREVIOUS}},
	// Kill a window
	// {  MOD ,               XK_q,          deletewin,           {}},
	{  MOD ,                  XK_w,          deletewin,           {}},
	// Resize a window
	// {  MOD |SHIFT,         XK_k,          resizestep,          {.i=TWOBWM_RESIZE_UP}},
	// {  MOD |SHIFT,         XK_j,          resizestep,          {.i=TWOBWM_RESIZE_DOWN}},
	// {  MOD |SHIFT,         XK_l,          resizestep,          {.i=TWOBWM_RESIZE_RIGHT}},
	// {  MOD |SHIFT,         XK_h,          resizestep,          {.i=TWOBWM_RESIZE_LEFT}},
	{  MOD |SHIFT,            XK_Up,         resizestep,          {.i=TWOBWM_RESIZE_UP}},
	{  MOD |SHIFT,            XK_Down,       resizestep,          {.i=TWOBWM_RESIZE_DOWN}},
	{  MOD |SHIFT,            XK_Right,      resizestep,          {.i=TWOBWM_RESIZE_RIGHT}},
	{  MOD |SHIFT,            XK_Left,       resizestep,          {.i=TWOBWM_RESIZE_LEFT}},
	// Resize a window slower
	// {  MOD |SHIFT|CONTROL, XK_k,          resizestep,          {.i=TWOBWM_RESIZE_UP_SLOW}},
	// {  MOD |SHIFT|CONTROL, XK_j,          resizestep,          {.i=TWOBWM_RESIZE_DOWN_SLOW}},
	// {  MOD |SHIFT|CONTROL, XK_l,          resizestep,          {.i=TWOBWM_RESIZE_RIGHT_SLOW}},
	// {  MOD |SHIFT|CONTROL, XK_h,          resizestep,          {.i=TWOBWM_RESIZE_LEFT_SLOW}},
	{  MOD |SHIFT|CONTROL,    XK_Up,         resizestep,          {.i=TWOBWM_RESIZE_UP_SLOW}},
	{  MOD |SHIFT|CONTROL,    XK_Down,       resizestep,          {.i=TWOBWM_RESIZE_DOWN_SLOW}},
	{  MOD |SHIFT|CONTROL,    XK_Right,      resizestep,          {.i=TWOBWM_RESIZE_RIGHT_SLOW}},
	{  MOD |SHIFT|CONTROL,    XK_Left,       resizestep,          {.i=TWOBWM_RESIZE_LEFT_SLOW}},
	// Move a window
	// {  MOD ,               XK_k,          movestep,            {.i=TWOBWM_MOVE_UP}},
	// {  MOD ,               XK_j,          movestep,            {.i=TWOBWM_MOVE_DOWN}},
	// {  MOD ,               XK_l,          movestep,            {.i=TWOBWM_MOVE_RIGHT}},
	// {  MOD ,               XK_h,          movestep,            {.i=TWOBWM_MOVE_LEFT}},
	{  MOD ,                  XK_Up,         movestep,            {.i=TWOBWM_MOVE_UP}},
	{  MOD ,                  XK_Down,       movestep,            {.i=TWOBWM_MOVE_DOWN}},
	{  MOD ,                  XK_Right,      movestep,            {.i=TWOBWM_MOVE_RIGHT}},
	{  MOD ,                  XK_Left,       movestep,            {.i=TWOBWM_MOVE_LEFT}},
	// Move a window slower
	// {  MOD |CONTROL,       XK_k,          movestep,            {.i=TWOBWM_MOVE_UP_SLOW}},
	// {  MOD |CONTROL,       XK_j,          movestep,            {.i=TWOBWM_MOVE_DOWN_SLOW}},
	// {  MOD |CONTROL,       XK_l,          movestep,            {.i=TWOBWM_MOVE_RIGHT_SLOW}},
	// {  MOD |CONTROL,       XK_h,          movestep,            {.i=TWOBWM_MOVE_LEFT_SLOW}},
	{  MOD |CONTROL,          XK_Up,         movestep,            {.i=TWOBWM_MOVE_UP_SLOW}},
	{  MOD |CONTROL,          XK_Down,       movestep,            {.i=TWOBWM_MOVE_DOWN_SLOW}},
	{  MOD |CONTROL,          XK_Right,      movestep,            {.i=TWOBWM_MOVE_RIGHT_SLOW}},
	{  MOD |CONTROL,          XK_Left,       movestep,            {.i=TWOBWM_MOVE_LEFT_SLOW}},
	// Teleport the window to an area of the screen.
	// Center:
	{  MOD ,                  XK_g,          teleport,            {.i=TWOBWM_TELEPORT_CENTER}},
	// Center y:
	{  MOD |SHIFT,            XK_g,          teleport,            {.i=TWOBWM_TELEPORT_CENTER_Y}},
	// Center x:
	{  MOD |CONTROL,          XK_g,          teleport,            {.i=TWOBWM_TELEPORT_CENTER_X}},
	// Top left:
	// {  MOD ,               XK_y,          teleport,            {.i=TWOBWM_TELEPORT_TOP_LEFT}},
	{  MOD ,                  XK_d,          teleport,            {.i=TWOBWM_TELEPORT_TOP_LEFT}},
	// Top right:
	// {  MOD ,               XK_u,          teleport,            {.i=TWOBWM_TELEPORT_TOP_RIGHT}},
	// {  MOD ,               XK_m,          teleport,            {.i=TWOBWM_TELEPORT_TOP_RIGHT}},
	{  MOD ,                  XK_n,          teleport,            {.i=TWOBWM_TELEPORT_TOP_RIGHT}},
	// Bottom left:
	// {  MOD ,               XK_b,          teleport,            {.i=TWOBWM_TELEPORT_BOTTOM_LEFT}},
	{  MOD ,                  XK_p,          teleport,            {.i=TWOBWM_TELEPORT_BOTTOM_LEFT}},
	// Bottom right:
	// {  MOD ,               XK_n,          teleport,            {.i=TWOBWM_TELEPORT_BOTTOM_RIGHT}},
	// {  MOD ,               XK_f,          teleport,            {.i=TWOBWM_TELEPORT_BOTTOM_RIGHT}},
	{  MOD ,                  XK_l,          teleport,            {.i=TWOBWM_TELEPORT_BOTTOM_RIGHT}},
	// Resize while keeping the window aspect
	// {  MOD ,               XK_Home,       resizestep_aspect,   {.i=TWOBWM_RESIZE_KEEP_ASPECT_GROW}},
	// {  MOD ,               XK_End,        resizestep_aspect,   {.i=TWOBWM_RESIZE_KEEP_ASPECT_SHRINK}},
	{  MOD ,                  XK_Home,       resizestep_aspect,   {.i=TWOBWM_RESIZE_KEEP_ASPECT_SHRINK}},
	{  MOD ,                  XK_End,        resizestep_aspect,   {.i=TWOBWM_RESIZE_KEEP_ASPECT_GROW}},
	// Maximize (ignore offset and no EWMH atom)
	// {  MOD ,               XK_x,          maximize,            {}},
	{  MOD ,                  XK_z,          maximize,            {}},
	// Full screen (disregarding offsets and adding EWMH atom)
	// {  MOD |SHIFT ,        XK_x,          fullscreen,          {}},
	{  MOD |SHIFT ,           XK_z,          fullscreen,          {}},
	// Maximize vertically
	// {  MOD ,               XK_m,          maxvert_hor,         {.i=TWOBWM_MAXIMIZE_VERTICALLY}},
	{  MOD ,                  XK_space,      maxvert_hor,         {.i=TWOBWM_MAXIMIZE_VERTICALLY}},
	// Maximize horizontally
	// {  MOD |SHIFT,         XK_m,          maxvert_hor,         {.i=TWOBWM_MAXIMIZE_HORIZONTALLY}},
	// {  MOD |CONTROL,       XK_space,      maxvert_hor,         {.i=TWOBWM_MAXIMIZE_HORIZONTALLY}},
	// Maximize and move
	// vertically left
	// {  MOD |SHIFT,         XK_y,          maxhalf,             {.i=TWOBWM_MAXHALF_VERTICAL_LEFT}},
	// {  MOD |SHIFT,         XK_d,          maxhalf,             {.i=TWOBWM_MAXHALF_VERTICAL_LEFT}},
	{  MOD |SHIFT,            XK_p,          maxhalf,             {.i=TWOBWM_MAXHALF_VERTICAL_LEFT}},
	// vertically right
	// {  MOD |SHIFT,         XK_u,          maxhalf,             {.i=TWOBWM_MAXHALF_VERTICAL_RIGHT}},
	// {  MOD |SHIFT,         XK_m,          maxhalf,             {.i=TWOBWM_MAXHALF_VERTICAL_RIGHT}},
	{  MOD |SHIFT,            XK_f,          maxhalf,             {.i=TWOBWM_MAXHALF_VERTICAL_RIGHT}},
	// horizontally left
	// {  MOD |SHIFT,         XK_b,          maxhalf,             {.i=TWOBWM_MAXHALF_HORIZONTAL_BOTTOM}},
	// {  MOD |SHIFT,         XK_p,          maxhalf,             {.i=TWOBWM_MAXHALF_HORIZONTAL_BOTTOM}},
	{  MOD |SHIFT,            XK_l,          maxhalf,             {.i=TWOBWM_MAXHALF_HORIZONTAL_BOTTOM}},
	// horizontally right
	// {  MOD |SHIFT,         XK_u,          maxhalf,             {.i=TWOBWM_MAXHALF_HORIZONTAL_TOP}},
	// {  MOD |SHIFT,         XK_f,          maxhalf,             {.i=TWOBWM_MAXHALF_HORIZONTAL_TOP}},
	{  MOD |SHIFT,            XK_n,          maxhalf,             {.i=TWOBWM_MAXHALF_HORIZONTAL_TOP}},
	//fold half vertically
	// {  MOD |SHIFT|CONTROL, XK_y,          maxhalf,             {.i=TWOBWM_MAXHALF_FOLD_VERTICAL}},
	// {  MOD |SHIFT|CONTROL, XK_d,          maxhalf,             {.i=TWOBWM_MAXHALF_FOLD_VERTICAL}},
	{  MOD |SHIFT|CONTROL,    XK_n,          maxhalf,             {.i=TWOBWM_MAXHALF_FOLD_VERTICAL}},
	//fold half horizoutally
	// {  MOD |SHIFT|CONTROL, XK_b,          maxhalf,             {.i=TWOBWM_MAXHALF_FOLD_HORIZONTAL}},
	{  MOD |SHIFT|CONTROL,    XK_p,          maxhalf,             {.i=TWOBWM_MAXHALF_FOLD_HORIZONTAL}},
	//unfold vertically
	// {  MOD |SHIFT|CONTROL, XK_u,          maxhalf,             {.i=TWOBWM_MAXHALF_UNFOLD_VERTICAL}},
	// {  MOD |SHIFT|CONTROL, XK_m,          maxhalf,             {.i=TWOBWM_MAXHALF_UNFOLD_VERTICAL}},
	{  MOD |SHIFT|CONTROL,    XK_l,          maxhalf,             {.i=TWOBWM_MAXHALF_UNFOLD_VERTICAL}},
	//unfold horizontally
	// {  MOD |SHIFT|CONTROL, XK_n,          maxhalf,             {.i=TWOBWM_MAXHALF_UNFOLD_HORIZONTAL}},
	{  MOD |SHIFT|CONTROL,    XK_f,          maxhalf,             {.i=TWOBWM_MAXHALF_UNFOLD_HORIZONTAL}},
	// Next/Previous screen
	// {  MOD ,               XK_comma,      changescreen,        {.i=TWOBWM_NEXT_SCREEN}},
	// {  MOD ,               XK_period,     changescreen,        {.i=TWOBWM_PREVIOUS_SCREEN}},
	// Raise or lower a window
	// {  MOD ,               XK_r,          raiseorlower,        {}},
	{  MOD ,                  XK_s,          raiseorlower,        {}},  // "show" :)
	// Next/Previous workspace
	// {  MOD ,               XK_v,          nextworkspace,       {}},
	// {  MOD ,               XK_c,          prevworkspace,       {}},
	{  MOD ,                  XK_period,     nextworkspace,       {}},
	{  MOD ,                  XK_comma,      prevworkspace,       {}},
	// Move to Next/Previous workspace
	// {  MOD |SHIFT ,        XK_v,          sendtonextworkspace, {}},
	// {  MOD |SHIFT ,        XK_c,          sendtoprevworkspace, {}},
	{  MOD |SHIFT ,           XK_period,     sendtonextworkspace, {}},
	{  MOD |SHIFT ,           XK_comma,      sendtoprevworkspace, {}},
	// Iconify the window
	// {  MOD ,               XK_i,          hide,                {}},
	{  MOD |SHIFT|CONTROL,    XK_i,          hide,                {}},  // see hidewindow
	// Make the window unkillable
	// {  MOD ,               XK_a,          unkillable,          {}},
	{  MOD |SHIFT ,           XK_k,          unkillable,          {}},
	// Make the window appear always on top
	// {  MOD,                XK_t,          always_on_top,       {}},
	{  MOD |SHIFT,            XK_t,          always_on_top,       {}},
	// Make the window stay on all workspaces
	// {  MOD ,               XK_f,          fix,                 {}},
	{  MOD |SHIFT ,           XK_a,          fix,                 {}},  // attach
	// Move the cursor
	// {  MOD ,               XK_Up,         cursor_move,         {.i=TWOBWM_CURSOR_UP_SLOW}},
	// {  MOD ,               XK_Down,       cursor_move,         {.i=TWOBWM_CURSOR_DOWN_SLOW}},
	// {  MOD ,               XK_Right,      cursor_move,         {.i=TWOBWM_CURSOR_RIGHT_SLOW}},
	// {  MOD ,               XK_Left,       cursor_move,         {.i=TWOBWM_CURSOR_LEFT_SLOW}},
	// Move the cursor faster
	// {  MOD |SHIFT,         XK_Up,         cursor_move,         {.i=TWOBWM_CURSOR_UP}},
	// {  MOD |SHIFT,         XK_Down,       cursor_move,         {.i=TWOBWM_CURSOR_DOWN}},
	// {  MOD |SHIFT,         XK_Right,      cursor_move,         {.i=TWOBWM_CURSOR_RIGHT}},
	// {  MOD |SHIFT,         XK_Left,       cursor_move,         {.i=TWOBWM_CURSOR_LEFT}},
	// Start programs
	// {  MOD ,               XK_w,          start,               {.com = menucmd}},
	{  MOD |SHIFT,            XK_space,      start,               {.com = menucmd}},
	{  MOD |CONTROL,          XK_space,      start,               {.com = snapnear}},
	{  MOD ,                  XK_Return,     start,               {.com = scratchy}},
	{  MOD |SHIFT,            XK_Return,     start,               {.com = itchy}},
	{  MOD |CONTROL,          XK_Return,     start,               {.com = terminal}},
	{  CONTROL ,              XK_space,      start,               {.com = notifypush}},
	{  CONTROL |SHIFT,        XK_space,      start,               {.com = notifyclr}},
	{  CONTROL ,              XK_BackSpace,  start,               {.com = notifypop}},
	{  MOD |SHIFT,            XK_apostrophe, start,               {.com = wikis}},
	{  MOD |CONTROL,          XK_apostrophe, start,               {.com = notes}},
	{  MOD ,                  XK_a,          start,               {.com = wallclock}},
	{  MOD |CONTROL,          XK_a,          start,               {.com = unclock}},
	{  MOD ,                  XK_b,          start,               {.com = browser}},
	{  MOD |CONTROL,          XK_b,          start,               {.com = browserclr}},
	{  MOD ,                  XK_c,          start,               {.com = snaptop}},
	{  MOD |SHIFT,            XK_c,          start,               {.com = snapbottom}},
	{  MOD |SHIFT,            XK_d,          start,               {.com = wallpaper}},
	{  MOD |CONTROL,          XK_d,          start,               {.com = background}},
	{  MOD |SHIFT,            XK_e,          start,               {.com = snaplevel}},
	{  MOD |CONTROL,          XK_e,          start,               {.com = snaprestore}},
	{  MOD ,                  XK_i,          start,               {.com = hidewindow}},
	{  MOD |SHIFT,            XK_i,          start,               {.com = unhide}},
	{  MOD ,                  XK_m,          start,               {.com = mail}},
	{  MOD |SHIFT,            XK_m,          start,               {.com = address}},
	{  MOD ,                  XK_o,          start,               {.com = scripts}},
	{  MOD |SHIFT,            XK_o,          start,               {.com = projects}},
	{  MOD |SHIFT,            XK_q,          start,               {.com = quit}},
	{  MOD |SHIFT|CONTROL,    XK_q,          start,               {.com = kill2bwm}},
	{  MOD ,                  XK_r,          start,               {.com = snapright}},
	{  MOD |SHIFT,            XK_r,          start,               {.com = build2bwm}},
	{  MOD |SHIFT,            XK_s,          start,               {.com = inspector}},
	{  MOD ,                  XK_t,          start,               {.com = snapleft}},
	{  MOD ,                  XK_u,          start,               {.com = btop}},
	{  MOD |SHIFT,            XK_u,          start,               {.com = passwords}},
	{  MOD ,                  XK_v,          start,               {.com = panel}},
	{  MOD |SHIFT,            XK_v,          start,               {.com = media}},
	{  MOD |CONTROL,          XK_v,          start,               {.com = invertpanel}},
	{  MOD ,                  XK_x,          start,               {.com = filecli}},
	{  MOD |SHIFT,            XK_x,          start,               {.com = filegui}},
	{  MOD |SHIFT|CONTROL,    XK_x,          start,               {.com = fileroot}},
	{  MOD ,                  XK_k,          start,               {.com = north}},
	{  MOD ,                  XK_j,          start,               {.com = south}},
	{  MOD ,                  XK_e,          start,               {.com = east}},      // beakl left hand placement
	{  MOD ,                  XK_h,          start,               {.com = west}},
	{  MOD |SHIFT,            XK_w,          start,               {.com = windowstretch}},
	{  MOD |CONTROL,          XK_w,          start,               {.com = windowsize}},
	{  MOD ,                  XK_0,          start,               {.com = windowsize0}},
	{  MOD ,                  XK_1,          start,               {.com = windowsize1}},
	{  MOD ,                  XK_2,          start,               {.com = windowsize2}},
	{  MOD ,                  XK_3,          start,               {.com = windowsize3}},
	{  MOD ,                  XK_4,          start,               {.com = windowsize4}},
	{  MOD ,                  XK_5,          start,               {.com = windowsize5}},
	{  MOD ,                  XK_6,          start,               {.com = windowsize6}},
	{  MOD ,                  XK_7,          start,               {.com = windowsize7}},
	{  MOD ,                  XK_8,          start,               {.com = windowsize8}},
	{  MOD ,                  XK_9,          start,               {.com = windowsize9}},
	// Exit or restart 2bwm
	{  MOD |CONTROL,          XK_q,          twobwm_exit,         {.i=0}},
	// {  MOD |CONTROL,       XK_q,          start,               {.com = quit2bwm}},  // avoid creating dead kak sessions
	{  MOD |CONTROL,          XK_r,          twobwm_restart,      {.i=0}},
	// {  MOD ,               XK_space,      halfandcentered,     {.i=0}},
	{  MOD |SHIFT|CONTROL,    XK_1,          halfandcentered,     {.i=0}},  // monocle
	// {  MOD ,               XK_s,          toggle_sloppy,       {.com = sloppy_switch_cmd}},
	{  MOD |CONTROL,          XK_s,          toggle_sloppy,       {.com = sloppy_switch_cmd}},
	// Change current workspace
		DESKTOPCHANGE(         XK_1,                               0)
		DESKTOPCHANGE(         XK_2,                               1)
		DESKTOPCHANGE(         XK_3,                               2)
		DESKTOPCHANGE(         XK_4,                               3)
		DESKTOPCHANGE(         XK_5,                               4)
		DESKTOPCHANGE(         XK_6,                               5)
		// DESKTOPCHANGE(      XK_7,                               6)        // don't need all 10 desktops :)
		// DESKTOPCHANGE(      XK_8,                               7)
		// DESKTOPCHANGE(      XK_9,                               8)
		// DESKTOPCHANGE(      XK_0,                               9)
};
// the last argument makes it a root window only event
static Button buttons[] = {  
	{  MOD ,        XCB_BUTTON_INDEX_1,      mousemotion,         {.i=TWOBWM_MOVE}, false},
	{  MOD ,        XCB_BUTTON_INDEX_3,      mousemotion,         {.i=TWOBWM_RESIZE}, false},
	// {  0   ,     XCB_BUTTON_INDEX_3,      start,               {.com = menucmd}, true},
	{  0   ,        XCB_BUTTON_INDEX_3,      start,               {.com = windowsize}, true},
	{  MOD|SHIFT,   XCB_BUTTON_INDEX_1,      changeworkspace,     {.i=0}, false},
	{  MOD|SHIFT,   XCB_BUTTON_INDEX_3,      changeworkspace,     {.i=1}, false},
	{  MOD|ALT,     XCB_BUTTON_INDEX_1,      changescreen,        {.i=1}, false},
	{  MOD|ALT,     XCB_BUTTON_INDEX_3,      changescreen,        {.i=0}, false}
};
