import cpu;
import ram;
import display;
import std::io;
import std::core::mem;
import std::thread;
import std::time;

/*
0x0000–0x02F7	760		Bootloader	ROM, после старта может переиспользоваться
0x02F8–0x02FF	8		Мышь	X (2 Б), Y (2 Б), статус (4 Б)
0x0300–0x03FF	256 	Клавиатура	Матрица/буфер
0x0400–0x13FF	4096	Терминал	4000 Б видеопамять + 96 Б регистры
0x1400–0x13FFF	76_800 	Дисплей	320×240×1 байт (индекс палитры)
0x14000–...		RAM		Основная память


Итого: 760 + 8 + 256 + 4096 + 76800 = 81920 байт = 80 кбайт
*/

fn int main(String[] args)
{
	Ram ram;
	ram.init();

	Display dsp;
	dsp.init(ram.ptr+0x0400, ram.ptr+0x1400);

	Processor*? pr;
	pr = cpu::processor_new();

	Processor* p = pr!!;
	p.memory = &ram;
	char[*] program = {
		OpcodeId.MOVI.ordinal,   0,    'c', 0x00, 0x00, 0x00,   // r0 = 0x1400
		OpcodeId.STOREB.ordinal, 0x00, 0x04, 0x00, 0x00, 0,
	};
	for(int i = 0; i < program.len; i+=1) {
		p.memory.set((uint)i, program[i]);
	}

	dsp.switchMode('t');

	dsp.start();
	while(1) {
		//break;
		for(int i = 0; i < 5680; i+=1) {
			ExitCode code = p.step();
			if(code != ExitCode.NONE && code != ExitCode.HALT) {
				break;
			}
			char[*] msg = "hallo, world!";
			for(uint j = 0; j < msg.len; j+=1) {
				uint q = j * 2;
				ram.set(0x0400+q,   msg[j]);
				ram.set(0x0400+q+1, 2*(char)j);
			}
		}
		dsp.draw();
		if(dsp.shouldClose()) {
			break;
		}
		thread::sleep((Duration)16_000);
	}
	dsp.end();


	io::printf("%p\n", p);
	p.regs_dump(-1);

	io::printn(ram::MMAP_MSTR);
	return 0;
} 
