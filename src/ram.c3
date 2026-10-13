module ram;
import std::io;
import std::core::mem;




/* ---------------------------------------------- */
// Test memory allocator 
/* ---------------------------------------------- */
fn char* mymalloc(usz size) {
	char* s = std::core::mem::calloc((sz)size);
	return s;
}




/* ---------------------------------------------- */
//    Window( memory window, part of memory map)
//    Object declaration
/* ---------------------------------------------- */
struct Window {
	char* base;
	uint size;
}

fn char Window.get
(&this, sz i)
@operator([])
{
	if(i >= (sz)this.size) {
		return 0;
	} 
	return this.base[i];
}

fn char Window.set
(&this, sz i, char b)
@operator([]=)
{
	if(i >= (sz)this.size) {
		return 0;
	}
	return this.base[i] = b;
}

fn sz Window.len
(&this)
@operator(len)
{
	return (sz)this.size;
}

fn void Window.init
(&this, char* base, uint size)
{
	this.base = base;
	this.size = size;
}




<*
@require $vaarg.len >= 2
@require $vaarg.len % 2 == 0
*>
macro @memory_mapping(#newf, #arrsize, ...)
{
	var $ram_struct =
		@sprintf("%s\n\t%s\n\t%s\n",
			"struct Ram {",
			"char* ptr;",
			"uint capacity;"
		);

	
	var $gInitFunc	= `fn void Ram.init(Ram* this) {`;
	$gInitFunc = @sprintf("%s\n\tthis.ptr = %s(%s);\n",
		$gInitFunc, $stringify(#newf), $stringify(#arrsize)
	);
	$gInitFunc = @sprintf("%s\tthis.capacity = %s;\n",
		$gInitFunc, $stringify(#arrsize)
	);
	$gInitFunc = @sprintf("%s\tuint offset = 0;\n",
		$gInitFunc
	);


	$for var $i = 0; $i < $vaarg.len; $i += 2:
		$ram_struct = @sprintf(
			"%s\tWindow %s;\n",
				$ram_struct,
				$stringify($vaarg[$i]),
		);
		
		$gInitFunc = @sprintf(
			"%s\tthis.%s.init(this.ptr+offset, %s); offset+=%s;\n",
				$gInitFunc,
				$stringify($vaarg[$i]),
				$stringify($vaarg[$i+1]),
				$stringify($vaarg[$i+1])
		);
	$endfor

	$ram_struct	= $ram_struct	+++ "}";
	$gInitFunc	= $gInitFunc	+++ "}";

	return $ram_struct +++ "\n" +++ $gInitFunc +++ "\n";
}

const String MMAP_MSTR = @memory_mapping(
	mymalloc,
	81920,
	bootldr,	760,
	mousew,		8,
	keyb,		256,
	rermw,		4096,
	vgaw,		76_800,
);
$expand(MMAP_MSTR);




/* ---------------------------------------------- */
// Ram object tools
/* ---------------------------------------------- */
fn void Ram.set
(Ram* this, uint addr, char v) {
	if(addr >= this.capacity) return;
	this.ptr[addr] = v;
}

fn void Ram.dump(Ram* this, int len, uint bg=0) {
	if (bg >= this.capacity) { return; }
	if (len < 0) {
		len = (int)(this.capacity - bg);
	}
	if (bg + (uint)len > this.capacity) { return; }

	char* p = this.ptr + bg;
	for (usz i = 0; i < (usz)len; i++) {
		if (i != 0 && i % 16 == 0) {
			io::printn("");
		}
		io::printf("%x\t", p[i]);
	}
	io::printn("\n");
}
