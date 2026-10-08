module bus;
import ram;
import device;
import std::core::mem;
import std::collections::map;

struct Bus {
	uint base;
	HashMap
	{
		char*,
		Device
	}
	devices;
	Ram* ram;
}

fn void Bus.init
(
	Bus* this,
	Ram* ram,
	uint base
)
{
	this.base = base;
	this.ram = ram;
	this.devices.tinit();
}

fn void Bus.write
(
	Bus* this
)
{

}