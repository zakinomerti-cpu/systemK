module ram;
import std::io;
import std::core::mem;

struct Ram {
	uint size;
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

fn void Ram.set(Ram* this, uint addr, char v) {
	if(addr >= this.capacity) return;
	this.ptr[addr] = v;
}


fn void Ram.add_byte
(Ram* this, char input_byte)
{
	if(this.size < this.capacity) {
		this.ptr[this.size] 
		= input_byte;
		this.size += 1;
	}
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