module ram;
import std::io;
import std::core::mem;

fn char* mymalloc(usz size) {
	char* s = std::core::mem::calloc((sz)size);
	return s;
}



/*
macro(newf, $vaarg{name, size})


что должен делать макрос - составлять карту памяти устройства.
	нечетным аргументом будет передаваться размер окна, четным его имя.
	имя окна будет преобразовано в имя массива байт.
5j	массив байт будет выделен на стеке.
	Соответственно макрос создает набор указателей на память и связывает их
	с модулем Ram. Важно: в программе может быть лишь одна карта памяти

нужно не n количество указателей а смещения от базового адреса
тоесть обьект memory содержит указатель на плоскую память но и по

char* name; $globals
name = newf(size); $gInitFunc
fn finit_name() {

*/


<*
@require $vaarg.len >= 2
@require $vaarg.len % 2 == 0
*>
macro @memory_mapping(#newf, #arrsize, ...)
{
	var $ram_struct = `
struct Ram {
	char* ptr;
	uint capacity;
`;
	
	var $gInitFunc	= `fn void Ram.init(Ram* this) {`;
	$gInitFunc = @sprintf("%s\n\tthis.ptr = %s(%s);\n",
		$gInitFunc, $stringify(#newf), $stringify(#arrsize)
	);
	$gInitFunc = @sprintf("%s\tthis.capacity = %s;\n",
		$gInitFunc, $stringify(#arrsize)
	);


	$for var $i = 0; $i < $vaarg.len; $i += 2:
		$ram_struct = @sprintf(
			"%s\tchar* %s;",
				$ram_struct,
				$stringify($vaarg[$i]),
		);
		
		$gInitFunc = @sprintf(
			"%s\tthis.%s = this.ptr + %s;",
				$gInitFunc,
				$stringify($vaarg[$i]),
				$stringify($vaarg[$i+1]),
		);
	$endfor

	$ram_struct	= $ram_struct	+++ "}";
	$gInitFunc	= $gInitFunc	+++ "}";

	return $ram_struct +++ "\n" +++ $gInitFunc;
}

$expand(@memory_mapping(
	mymalloc,
	81920,
	bootldr, 0
));




/*

struct Ram {
	uint capacity;
	char* ptr;
}

fn void Ram.init(Ram* this, uint capacity) {
	char*? r_opt = alloc::calloc_try
	(mem, capacity);

	if(catch err = r_opt) {
		return;
	}

	char* r = r_opt;
	this.capacity = capacity;
	this.ptr = r;
}

*/

fn void Ram.set(Ram* this, uint addr, char v) {
	if(addr >= this.capacity) return;
	this.ptr[addr] = v;
}


fn void Ram.add_byte
(Ram* this, char input_byte, uint offset)
{
		this.ptr[offset] = input_byte;
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
