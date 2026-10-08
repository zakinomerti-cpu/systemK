module display;
import ram;
import std::io;

struct Font {
	char[64] data;
}

struct Color {
	char r;
	char g;
	char b;
	char a;
}

struct Vector2 {
	float x;
	float y;
}

struct Vector3 {
	float x;
	float y;
	float z;
}

struct Display {
	char mode;
}


char  color_mode	= 0;
char* cur_mem_ptr	= null;
char* tmode_mptr	= null;
char* gmode_mptr	= null;
const int TMOD_RESX	= 960;
const int TMOD_RESY = 725;
const int GMOD_RESX = 960;
const int GMOD_RESY = 720;

alias Draw_func = fn void();
Draw_func g_draw_func;

const Color[*] VGA_PALETTE = {
	// ---- 0..15: классические 16 цветов CGA/EGA ----
	{0,		0,		0, 		255}, //	0 чёрный
	{0,		0, 		170, 	255}, //	1 синий
	{0, 	170,	0, 		255}, //	2 зелёный
	{0, 	170, 	170, 	255}, //	3 голубой
	{170,	0,		0, 		255}, //	4 красный
	{170,	0, 		170, 	255}, //	5 пурпурный
	{170,	85,		0, 		255}, //	6 коричневый
	{170, 	170, 	170, 	255}, //	7 светло-серый
	{ 85,	85,		85, 	255}, //	8 тёмно-серый
	{ 85,	85,		255, 	255}, //	9 ярко-синий
	{ 85, 	255,	85, 	255}, // 10 ярко-зелёный
	{ 85, 	255, 	255, 	255}, // 11 ярко-голубой
	{255,	85,		85, 	255}, // 12 ярко-красный
	{255,	85, 	255, 	255}, // 13 ярко-пурпурный
	{255, 	255,	85, 	255}, // 14 жёлтый
	{255, 	255, 	255, 	255}, // 15 белый

	// ---- 16..31: серый градиент (16 оттенков) ----
	{	0,	0,	0, 255}, { 20,	20,	20, 255}, { 32,	32,	32, 255}, { 44,	44,	44, 255},
	{ 56,	56,	56, 255}, { 68,	68,	68, 255}, { 80,	80,	80, 255}, { 96,	96,	96, 255},
	{112, 112, 112, 255}, {128, 128, 128, 255}, {144, 144, 144, 255}, {160, 160, 160, 255},
	{176, 176, 176, 255}, {192, 192, 192, 255}, {208, 208, 208, 255}, {224, 224, 224, 255},
};

extern fn void initWindow(int, int, char*)			@cname("InitWindow");
extern fn void setWindowSize(int, int)				@cname("SetWindowSize");
extern fn bool windowShouldClose()					@cname("WindowShouldClose");
extern fn void beginDrawing()						@cname("BeginDrawing");
extern fn void clearBackground(Color)				@cname("ClearBackground");
extern fn void drawText(char*, int, int, int, Color)	@cname("DrawText");
extern fn void drawTextEx
(
	Font,
	char*,
	Vector2,
	float,
	float,
	Color
)	@cname("DrawTextEx");
extern fn void endDrawing()							@cname("EndDrawing");
extern fn void closeWindow()						@cname("CloseWindow");
extern fn Font loadFontEx(char*, int, int*, int)	@cname("LoadFontEx");

extern fn void drawRectangleV
(Vector2, Vector2, Color)
@cname("DrawRectangleV");

extern fn void drawRectangle
(int, int, int, int, Color) 
@cname("DrawRectangle");

Font ibmVga;

fn Color byte_to_color(char b) {
	Color c;
	c.r = (char)(((b >> 5) & 0x07) * 255 / 7);
	c.g = (char)(((b >> 2) & 0x07) * 255 / 7);
	c.b = (char)(( b & 0x03) * 255 / 3);
	c.a = 255;
	return c;
}

fn void gfxDraw() {
	int scale  = 3;
	int offset = 3;

	beginDrawing();
	clearBackground((Color){64, 64, 64, 255});

	for (int y = 0; y < 240; y++) {
		for (int x = 0; x < 320; x++) {
			Color c = byte_to_color(cur_mem_ptr[y * 320 + x]);
			drawRectangle(
				offset + x * scale,
				offset + y * scale,
				scale,
				scale,
				c
			);
		}
	}

	endDrawing();
}

fn void tDraw() {
	beginDrawing();
	clearBackground((Color){64, 64, 64, 255});

	for (int y = 0; y < 25; y++) {
		for (int x = 0; x < 80; x++) {

			int i = (y * 80 + x) * 2;
			char s = cur_mem_ptr[i + 0];
			char c = cur_mem_ptr[i + 1];

			char[2] text = {
				s, 0
			};

			drawRectangle(
				12*x,
				29*y,
				12,
				29,
				(Color){(char)x*4+50, (char)y*4+50, 0, 255}
			);

			Color cl = byte_to_color(c);
			//drawText(&text, 12*x, 29*y, 18, cl);
			drawTextEx
			(
				ibmVga, 
				&text, 
				(Vector2)
				{ 12*(float)x, 29*(float)y },
				20,
				0,
				(Color){255, 255, 255, 255}
			);
		}
	}

	endDrawing();
}

fn void Display.init
(
	Display* this,
	char* t,
	char* g
)
{
	tmode_mptr = t;
	gmode_mptr = g;
	
	cur_mem_ptr	
	= gmode_mptr;
	this.mode = 'g';
	g_draw_func = &gfxDraw;

	ibmVga = loadFontEx
	(
		"Mx437_ACM_VGA_8x16.ttf",
		29,
		null,
		0
	);
}

fn void Display.start
(Display* this)
{
	initWindow
	(
		GMOD_RESX,
		GMOD_RESY,
		"DISP"
	);
}

fn void Display.switchMode
(Display* this, char mode) 
{
	if
	(
		mode != 'g'
			&& 
		mode != 't'
	)
	{
		return;
	}

	if(mode == 'g')
	{
		cur_mem_ptr
		= gmode_mptr;
		
		setWindowSize
		(
			GMOD_RESX,
			GMOD_RESY
		);
		g_draw_func = &gfxDraw;
		return;
	}

	cur_mem_ptr
	= tmode_mptr;
	
	setWindowSize
	(
		TMOD_RESX,
		TMOD_RESY
	);
	g_draw_func = &tDraw;
	return;

}

fn void Display.draw
(Display* this)
{
	g_draw_func();
}

fn bool Display.shouldClose
(Display* this)
{
	return windowShouldClose();
}

fn void Display.end
(Display* this)
{
	closeWindow();
}

