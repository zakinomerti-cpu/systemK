module cpu;
import ram;
import std::io;
import std::core::mem;
import std::core::mem::alloc;

const int CPUMEM		= 128;
const int REG_COUNT		= 16;
const int STACK_SIZE	= 2048;

fn void memdump(void* memry, usz len) {
	if(!memry) return;
	char* p = (char*)memry;
	for(usz i = 0; i < len; i++) {
		if(i != 0 && i % 16 == 0) {
			io::printn("");
		}
		io::printf("%x\t", p[i]);
	}
	io::printn("\n");
}

constset ExitCode : ichar {
	NONE = 0,
	HALT = 1,
	BREAKPOINT = 2,
	STEP_LIMIT = 3,
	INVALID_OPCODE = -1,
	INVALID_OPERAND = -2,
	BAD_REGISTER = -3,
	MEMORY_READ = -4,
	MEMORY_WRITE = -5,
	MEMORY_EXEC = -6,
	DIVIDE_BY_ZERO = -7,
	ILLEGAL_JUMP = -8,
	INTERNAL_ERROR = -9
}

enum ArgType : char {
	NONE,
	R,
	RR,
	B,
	RB,
	DWORD,
	R_DWORD,
	DWORD_R,
}

enum OpcodeId : char {
	HALT,
	NOP,
	INT,
	SYSCALL,
	MOV,
	MOVI,
	PUSH,
	POP,
	PUSHI,
	DUP,
	SWAP,
	ADD,
	SUB,
	MUL,
	DIV,
	MOD,
	ADDI,
	SUBI,
	MULI,
	DIVI,
	INC,
	DEC,
	NEG,
	AND,
	OR,
	XOR,
	NOT,
	SHL,
	SHR,
	CMP,
	CMPI,
	JMP,
	JP,
	JZ,
	JN,
	//JNE,
	//JL,
	//JLE,
	//JG,
	//JGE,
	CALL,
	RET,
	LOAD,
	STORE,
	LOADB,
	STOREB,
	IN,
	OUT,
	VGET,
	VSET,
	VHAS,
	RAND,
}

const Opcode[*] OPCODE_ARRAY = {
	[OpcodeId.HALT]    = {"HALT",    ArgType.NONE},
	[OpcodeId.NOP]     = {"NOP",     ArgType.NONE},
	[OpcodeId.INT]     = {"INT",     ArgType.B},
	[OpcodeId.SYSCALL] = {"SYSCALL", ArgType.DWORD},

	[OpcodeId.MOV]     = {"MOV",     ArgType.RR},
	[OpcodeId.MOVI]    = {"MOVI",    ArgType.R_DWORD},
	[OpcodeId.PUSH]    = {"PUSH",    ArgType.R},
	[OpcodeId.POP]     = {"POP",     ArgType.R},
	[OpcodeId.PUSHI]   = {"PUSHI",   ArgType.DWORD},
	[OpcodeId.DUP]     = {"DUP",     ArgType.NONE},
	[OpcodeId.SWAP]    = {"SWAP",    ArgType.NONE},

	[OpcodeId.ADD]     = {"ADD",     ArgType.RR},
	[OpcodeId.SUB]     = {"SUB",     ArgType.RR},
	[OpcodeId.MUL]     = {"MUL",     ArgType.RR},
	[OpcodeId.DIV]     = {"DIV",     ArgType.RR},
	[OpcodeId.MOD]     = {"MOD",     ArgType.RR},
	[OpcodeId.ADDI]    = {"ADDI",    ArgType.R_DWORD},
	[OpcodeId.SUBI]    = {"SUBI",    ArgType.R_DWORD},
	[OpcodeId.MULI]    = {"MULI",    ArgType.R_DWORD},
	[OpcodeId.DIVI]    = {"DIVI",    ArgType.R_DWORD},
	[OpcodeId.INC]     = {"INC",     ArgType.R},
	[OpcodeId.DEC]     = {"DEC",     ArgType.R},
	[OpcodeId.NEG]     = {"NEG",     ArgType.R},

	[OpcodeId.AND]     = {"AND",     ArgType.RR},
	[OpcodeId.OR]      = {"OR",      ArgType.RR},
	[OpcodeId.XOR]     = {"XOR",     ArgType.RR},
	[OpcodeId.NOT]     = {"NOT",     ArgType.R},
	[OpcodeId.SHL]     = {"SHL",     ArgType.RR},
	[OpcodeId.SHR]     = {"SHR",     ArgType.RR},

	[OpcodeId.CMP]     = {"CMP",     ArgType.RR},
	[OpcodeId.CMPI]    = {"CMPI",    ArgType.R_DWORD},

	[OpcodeId.JMP]     = {"JMP",     ArgType.DWORD},
	[OpcodeId.JP]      = {"JP",      ArgType.DWORD},
	[OpcodeId.JZ]      = {"JZ",      ArgType.DWORD},
	[OpcodeId.JN]      = {"JN",      ArgType.DWORD},
	//[OpcodeId.JNE]     = {"JNE",     ArgType.DWORD},
	//[OpcodeId.JL]      = {"JL",      ArgType.DWORD},
	//[OpcodeId.JLE]     = {"JLE",     ArgType.DWORD},
	//[OpcodeId.JG]      = {"JG",      ArgType.DWORD},
	//[OpcodeId.JGE]     = {"JGE",     ArgType.DWORD},
	[OpcodeId.CALL]    = {"CALL",    ArgType.DWORD},
	[OpcodeId.RET]     = {"RET",     ArgType.NONE},

	[OpcodeId.LOAD]    = {"LOAD",    ArgType.R_DWORD},
	[OpcodeId.STORE]   = {"STORE",   ArgType.DWORD_R},
	[OpcodeId.LOADB]   = {"LOADB",   ArgType.R_DWORD},
	[OpcodeId.STOREB]  = {"STOREB",  ArgType.DWORD_R},

	[OpcodeId.IN]      = {"IN",      ArgType.R},
	[OpcodeId.OUT]     = {"OUT",     ArgType.R},

	[OpcodeId.VGET]    = {"VGET",    ArgType.R_DWORD},
	[OpcodeId.VSET]    = {"VSET",    ArgType.DWORD_R},
	[OpcodeId.VHAS]    = {"VHAS",    ArgType.R_DWORD},

	[OpcodeId.RAND]    = {"RAND",    ArgType.R},
};


struct Opcode {
	char* op_mnemonic;
	ArgType type;
}

struct RegisterBlock {
	uint count;
	uint offset;
	uptr ptr;
}

struct Stack {
	uint size;
	uint capacity;
	uint offset;
	uptr ptr;
}

struct CpuMemory {
	uint size;
	uint capacity;
	uint offset;
	uptr ptr;
}


fn void CpuMemory.add_byte
(CpuMemory* this, char input_byte)
{
	if(this.size < this.capacity-1) {
		char* ptr = (char*)this.ptr;
		ptr[this.size] = input_byte;
		this.size += 1;
	}
}

fn void CpuMemory.add_opcode
(CpuMemory* this, Opcode* op)
{
	return;
}

fn void CpuMemory.dump
(
	CpuMemory* this,
	char* arr,
	usz len,
	usz* written
)
{
	
}




struct Processor { //32bit processor
	uint ip;
	uint sp;
	char hlt;
	ExitCode code;
	ichar cmp_result;
	
	RegisterBlock regs;
	Stack stack;
	Ram* memory;
}

fn void Processor.chmode
(Processor* this, char mode)
{

}

fn uint Processor.io_in
(Processor* this, uint addr)
{
	return 0;
}

fn uint Processor.io_out
(Processor* this, uint addr)
{
	return 0;
}

fn uint Processor.vget
(Processor* this, uint name)
{
	return 0;
}

fn uint Processor.vset
(
	Processor* this,
	uint name, 
	uint value
)
{
	return 0;
}

fn uint Processor.vhas
(Processor* this, uint name)
{
	return 0;
}

fn uint Processor.rand
(Processor* this)
{
	return 0;
}



//debug
fn void Processor.regs_dump
(Processor* this, ichar reg)
{
	if(reg > REG_COUNT) {
		return;
	}
	if(reg < 0) { 
		memdump
		(
			(void*)this.regs.ptr, 
			REG_COUNT*uint::size
		);
		return;
	}
	memdump
	(
		(void*)this.regs.ptr
		+reg*uint::size,
		uint::size
	);

}
fn void Processor.stack_dump
(Processor* this)
{
	memdump
	(
		(void*)this.stack.ptr,
		STACK_SIZE
	); 
}
fn void Processor.mem_dump
(Processor* this)
{
	memdump
	(
		(void*)this.memory.ptr,
		CPUMEM
	); 
}
fn void Processor.cpumem_dump
(Processor* this)
{

}



fn ExitCode Processor.step
(Processor* this)
{
	uint ip = this.ip;
	ExitCode code = ExitCode.NONE;
	uint* rgs = (uint*)this.regs.ptr;
	char* mem = (char*)this.memory.ptr;
	uint* s = (uint*)this.stack.ptr;

	switch((OpcodeId)mem[ip]) {
		case OpcodeId.HALT:
			code = ExitCode.HALT;
			break;

		case OpcodeId.NOP:
			this.ip++;
			break;

		case OpcodeId.INT: {
			char b = mem[ip+1];
			this.chmode(b);
			this.ip += 2;
			break;
		}

		case OpcodeId.SYSCALL:
			this.ip += 2;
			break;

		case OpcodeId.MOV: {
			char r1i = mem[ip+1];
			char r2i = mem[ip+2];
			if(r1i >= 16 || r2i >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[r1i] = rgs[r2i];
			this.ip += 3;
			break;
		}

		case OpcodeId.MOVI: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint im;
			mem::copy(&im, &mem[ip+2], 4);
			rgs[ri] = im;
			this.ip += 6;
			break;
		}

		case OpcodeId.PUSH: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			if
			(
				this.stack.size
				>= this.stack.capacity
			)
			{
				code = ExitCode.INTERNAL_ERROR;
				break;
			}
			s[this.stack.size++] = rgs[ri];
			this.ip += 2;
			break;
		}

		case OpcodeId.POP: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			if(this.stack.size == 0) {
				code = ExitCode.INTERNAL_ERROR;
				break;
			}
			
			rgs[ri] = s[--this.stack.size];
			this.ip += 2;
			break;
		}

		case OpcodeId.PUSHI: {
			if
			(
				this.stack.size 
				>= this.stack.capacity
			)
			{
				code = ExitCode.INTERNAL_ERROR;
				break;
			}
			uint im;
			mem::copy(&im, &mem[ip+1], 4);
			
			s[this.stack.size++] = im;
			this.ip += 5;
			break;
		}

		case OpcodeId.DUP: {
			if(this.stack.size == 0) {
				code = ExitCode.INTERNAL_ERROR;
				break;
			}
			if
			(
				this.stack.size
				>= this.stack.capacity
			)
			{
				code = ExitCode.INTERNAL_ERROR;
				break;
			}
			
			s[this.stack.size]
			= s[this.stack.size - 1];
			this.stack.size++;
			this.ip++;
			break;
		}

		case OpcodeId.SWAP: {
			if(this.stack.size < 2) {
				code = ExitCode.INTERNAL_ERROR;
				break;
			}
			
			uint t = s[this.stack.size - 1];
			s[this.stack.size - 1]
			= s[this.stack.size - 2];
			s[this.stack.size - 2] = t;
			this.ip++;
			break;
		}

		case OpcodeId.ADD: {
			char r1i = mem[ip+1];
			char r2i = mem[ip+2];
			if(r1i >= 16 || r2i >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[r1i] += rgs[r2i];
			this.ip += 3;
			break;
		}

		case OpcodeId.SUB: {
			char r1i = mem[ip+1];
			char r2i = mem[ip+2];
			if(r1i >= 16 || r2i >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[r1i] -= rgs[r2i];
			this.ip += 3;
			break;
		}

		case OpcodeId.MUL: {
			char r1i = mem[ip+1];
			char r2i = mem[ip+2];
			if(r1i >= 16 || r2i >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[r1i] *= rgs[r2i];
			this.ip += 3;
			break;
		}

		case OpcodeId.DIV: {
			char r1i = mem[ip+1];
			char r2i = mem[ip+2];
			if(r1i >= 16 || r2i >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			if(rgs[r2i] == 0) {
				code = ExitCode.DIVIDE_BY_ZERO;
				break;
			}
			rgs[r1i] /= rgs[r2i];
			this.ip += 3;
			break;
		}

		case OpcodeId.MOD: {
			char r1i = mem[ip+1];
			char r2i = mem[ip+2];
			if(r1i >= 16 || r2i >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			if(rgs[r2i] == 0) {
				code = ExitCode.DIVIDE_BY_ZERO;
				break;
			}
			rgs[r1i] %= rgs[r2i];
			this.ip += 3;
			break;
		}

		case OpcodeId.ADDI: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint im;
			mem::copy(&im, &mem[ip+2], 4);
			rgs[ri] += im;
			this.ip += 6;
			break;
		}

		case OpcodeId.SUBI: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint im;
			mem::copy(&im, &mem[ip+2], 4);
			rgs[ri] -= im;
			this.ip += 6;
			break;
		}

		case OpcodeId.MULI: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint im;
			mem::copy(&im, &mem[ip+2], 4);
			rgs[ri] *= im;
			this.ip += 6;
			break;
		}

		case OpcodeId.DIVI: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint im;
			mem::copy(&im, &mem[ip+2], 4);
			if(im == 0) {
				code = ExitCode.DIVIDE_BY_ZERO;
				break;
			}
			rgs[ri] /= im;
			this.ip += 6;
			break;
		}

		case OpcodeId.INC: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[ri]++;
			this.ip += 2;
			break;
		}

		case OpcodeId.DEC: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[ri]--;
			this.ip += 2;
			break;
		}

		case OpcodeId.NEG: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[ri] = (uint)(-(int)rgs[ri]);
			this.ip += 2;
			break;
		}

		case OpcodeId.AND: {
			char r1i = mem[ip+1];
			char r2i = mem[ip+2];
			if(r1i >= 16 || r2i >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[r1i] &= rgs[r2i];
			this.ip += 3;
			break;
		}

		case OpcodeId.OR: {
			char r1i = mem[ip+1];
			char r2i = mem[ip+2];
			if(r1i >= 16 || r2i >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[r1i] |= rgs[r2i];
			this.ip += 3;
			break;
		}

		case OpcodeId.XOR: {
			char r1i = mem[ip+1];
			char r2i = mem[ip+2];
			if(r1i >= 16 || r2i >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[r1i] ^= rgs[r2i];
			this.ip += 3;
			break;
		}

		case OpcodeId.NOT: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[ri] = ~rgs[ri];
			this.ip += 2;
			break;
		}

		case OpcodeId.SHL: {
			char r1i = mem[ip+1];
			char r2i = mem[ip+2];
			if(r1i >= 16 || r2i >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[r1i] <<= (rgs[r2i] & 31);
			this.ip += 3;
			break;
		}

		case OpcodeId.SHR: {
			char r1i = mem[ip+1];
			char r2i = mem[ip+2];
			if(r1i >= 16 || r2i >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[r1i] >>= (rgs[r2i] & 31);
			this.ip += 3;
			break;
		}

		case OpcodeId.CMP: {
			char r1i = mem[ip+1];
			char r2i = mem[ip+2];
			if(r1i >= 16 || r2i >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint a = rgs[r1i];
			uint b = rgs[r2i];
			if(a < b) {
				this.cmp_result = -1;
			} else if(a > b) {
				this.cmp_result = 1;
			} else {
				this.cmp_result = 0;
			}
			this.ip += 3;
			break;
		}

		case OpcodeId.CMPI: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint im;
			mem::copy(&im, &mem[ip+2], 4);
			uint a = rgs[ri];
			uint b = im;
			if(a < b) {
				this.cmp_result = -1;
			} else if(a > b) {
				this.cmp_result = 1;
			} else {
				this.cmp_result = 0;
			}
			this.ip += 6;
			break;
		}

		case OpcodeId.JMP: {
			uint addr;
			mem::copy(&addr, &mem[ip+1], 4);
			if(addr >= this.memory.capacity) {
				code = ExitCode.ILLEGAL_JUMP;
				break;
			}
			this.ip = addr;
			break;
		}

		case OpcodeId.JP: {
			uint addr;
			if(this.cmp_result > 0) { 
				mem::copy(&addr, &mem[ip+1], 4);
				if(addr >= this.memory.capacity) {
					code = ExitCode.ILLEGAL_JUMP;
					break;
				}

				this.ip = addr;
				break;
			}
			this.ip+=5;
			break;
		}

		case OpcodeId.JZ: {
			uint addr;
			if(this.cmp_result == 0) { 
				mem::copy(&addr, &mem[ip+1], 4);
				if(addr >= this.memory.capacity) {
					code = ExitCode.ILLEGAL_JUMP;
					break;
				}

				this.ip = addr;
				break;
			}
			this.ip+=5;
			break;
		}

		case OpcodeId.JN: {
			uint addr;
			if(this.cmp_result < 0) { 
				mem::copy(&addr, &mem[ip+1], 4);
				if(addr >= this.memory.capacity) {
					code = ExitCode.ILLEGAL_JUMP;
					break;
				}

				this.ip = addr;
				break;
			}
			this.ip+=5;
			break;
		}
		/*
		case OpcodeId.JNE: {
			uint addr;
			mem::copy(&addr, &mem[ip+1], 4);
			if(addr >= this.memory.capacity) {
				code = ExitCode.ILLEGAL_JUMP;
				break;
			}
			if(this.cmp_result != 0) {
				this.ip = addr;
			} else {
				this.ip += 5;
			}
			break;
		}

		case OpcodeId.JL: {
			uint addr;
			mem::copy(&addr, &mem[ip+1], 4);
			if(addr >= this.memory.capacity) {
				code = ExitCode.ILLEGAL_JUMP;
				break;
			}
			if(this.cmp_result < 0) {
				this.ip = addr;
			} else {
				this.ip += 5;
			}
			break;
		}

		case OpcodeId.JLE: {
			uint addr;
			mem::copy(&addr, &mem[ip+1], 4);
			if(addr >= this.memory.capacity) {
				code = ExitCode.ILLEGAL_JUMP;
				break;
			}
			if(this.cmp_result <= 0) {
				this.ip = addr;
			} else {
				this.ip += 5;
			}
			break;
		}

		case OpcodeId.JG: {
			uint addr;
			mem::copy(&addr, &mem[ip+1], 4);
			if(addr >= this.memory.capacity) {
				code = ExitCode.ILLEGAL_JUMP;
				break;
			}
			if(this.cmp_result > 0) {
				this.ip = addr;
			} else {
				this.ip += 5;
			}
			break;
		}

		case OpcodeId.JGE: {
			uint addr;
			mem::copy(&addr, &mem[ip+1], 4);
			if(addr >= this.memory.capacity) {
				code = ExitCode.ILLEGAL_JUMP;
				break;
			}
			if(this.cmp_result >= 0) {
				this.ip = addr;
			} else {
				this.ip += 5;
			}
			break;
		}
		*/
		case OpcodeId.CALL: {
			uint addr;
			mem::copy(&addr, &mem[ip+1], 4);
			if(addr >= this.memory.capacity) {
				code = ExitCode.ILLEGAL_JUMP;
				break;
			}
			if
			(
				this.stack.size
				>= this.stack.capacity
			)
			{
				code = ExitCode.INTERNAL_ERROR;
				break;
			}
			
			s[this.stack.size++] = ip + 5;
			this.ip = addr;
			break;
		}

		case OpcodeId.RET: {
			if(this.stack.size == 0) {
				code = ExitCode.ILLEGAL_JUMP;
				break;
			}
			
			this.ip = s[--this.stack.size];
			break;
		}

		case OpcodeId.LOAD: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint addr;
			mem::copy(&addr, &mem[ip+2], 4);
			if(addr + 4 > this.memory.capacity) {
				code = ExitCode.MEMORY_READ;
				break;
			}
			uint v;
			mem::copy(&v, &mem[addr], 4);
			rgs[ri] = v;
			this.ip += 6;
			break;
		}

		case OpcodeId.STORE: {
			char ri = mem[ip+5];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint addr;
			mem::copy(&addr, &mem[ip+1], 4);
			if(addr + 4 > this.memory.capacity) {
				code = ExitCode.MEMORY_WRITE;
				break;
			}
			mem::copy(&mem[addr], &rgs[ri], 4);
			this.ip += 6;
			break;
		}

		case OpcodeId.LOADB: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint addr;
			mem::copy(&addr, &mem[ip+2], 4);
			if(addr >= this.memory.capacity) {
				code = ExitCode.MEMORY_READ;
				break;
			}
			rgs[ri] = (char)mem[addr];
			this.ip += 6;
			break;
		}

		case OpcodeId.STOREB: {
			char ri = mem[ip+5];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint addr;
			mem::copy(&addr, &mem[ip+1], 4);
			if(addr >= this.memory.capacity) {
				code = ExitCode.MEMORY_WRITE;
				break;
			}
			mem[addr] = (char)rgs[ri];
			this.ip += 6;
			break;
		}

		case OpcodeId.IN: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[ri] = this.io_in(rgs[ri]);
			this.ip += 2;
			break;
		}

		case OpcodeId.OUT: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			this.io_out(rgs[ri]);
			this.ip += 2;
			break;
		}

		case OpcodeId.VGET: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint name;
			mem::copy(&name, &mem[ip+2], 4);
			rgs[ri] = this.vget(name);
			this.ip += 6;
			break;
		}

		case OpcodeId.VSET: {
			char ri = mem[ip+5];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint name;
			mem::copy(&name, &mem[ip+1], 4);
			this.vset(name, rgs[ri]);
			this.ip += 6;
			break;
		}

		case OpcodeId.VHAS: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			uint name;
			mem::copy(&name, &mem[ip+2], 4);
			if(this.vhas(name)) {
				rgs[ri] = 1;
			} else {
				rgs[ri] = 0;
			}
			this.ip += 6;
			break;
		}

		case OpcodeId.RAND: {
			char ri = mem[ip+1];
			if(ri >= 16) {
				code = ExitCode.BAD_REGISTER;
				break;
			}
			rgs[ri] = this.rand();
			this.ip += 2;
			break;
		}

		default:
			code = ExitCode.INVALID_OPCODE;
			break;
	}

	return code;
}

fn Processor*? processor_new() 
{

	uint prMemSize = 0;
	prMemSize += Processor::size;
	prMemSize += REG_COUNT*4;
	prMemSize += STACK_SIZE;
	prMemSize += CPUMEM;
	Processor*? p_opt = alloc::calloc_try
	(mem, prMemSize);

	if(catch err = p_opt) {
		return err~;
	}
	
	/* unboxing opt */
	Processor* p = p_opt;



	/* fill up regs field */
	p.regs.count = REG_COUNT;
	p.regs.offset = Processor::size;
	p.regs.ptr = (uptr)p
	+ p.regs.offset;



	/* fill up stack field */
	p.stack.capacity = STACK_SIZE;
	p.stack.offset = p.regs.offset
	+ p.regs.count*4;
	p.stack.ptr = (uptr)p
	+ p.stack.offset;

	return p;

}
