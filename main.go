package main

import (
	"bufio"
	"encoding/binary"
	"os"
	"github.com/OMGasm/glua/assert"
)

func main() {
	file, err := os.Open("./mem.luac.dbg")
	assert.Some(file, err)
	var dump Dump
	dump.Read_header(bufio.NewReader(file))
}

type Dump struct {
	magic [3]byte
	version uint8
	flags uint64
	debug_name *string
	proto []Proto
}

func(self *Dump) Read_header(r *bufio.Reader) {
	self.Read_magic(r)
	self.Read_version(r)
	self.Read_flags(r)
	if (self.flags & COMPAT_STRIP) == 0 {
		self.Read_debug(r)
	}
	self.Read_prototypes(r)
}

func(self *Dump) Read_magic(r *bufio.Reader) {
	r.Read(self.magic[:])
	assert.SliceEq(self.magic[:], []byte{'\x1B', 'L', 'J'}, "Invalid magic header")
}

func(self *Dump) Read_version(r *bufio.Reader) {
	err := binary.Read(r, binary.LittleEndian, &self.version)
	assert.No(err)
}

func(self *Dump) Read_flags(r *bufio.Reader) {
	flags, err := binary.ReadUvarint(r)
	assert.Some(flags, err)
	self.flags = flags
}

func(self *Dump) Read_debug(r *bufio.Reader) {
	len, err := binary.ReadUvarint(r)
	assert.Some(len, err)
	chars := make([]byte, len)
	r.Read(chars)
	str := string(chars)
	self.debug_name = &str
}

func(self *Dump) Read_prototypes(r *bufio.Reader) {
	var proto Proto
	proto.parent_dump = self
	proto.Read_header(r)
	if (proto.flags & COMPAT_STRIP) == 0 {
		proto.debug = new(ProtoDebug)
		proto.debug.Read_proto_debug(r)
	}
	proto.Read_instructions(r)
	proto.Read_upvalues(r)
	proto.Read_objects(r)
	proto.Read_nums(r)
	proto.Read_debug(r)
}

type Proto struct {
	parent_dump *Dump
	flags uint64
	instructions []uint32
	upvalues []uint16
	gc_objects []GCObject
	gc_nums []GCNum
	debug *ProtoDebug
}

func(self *Proto) Read_header(r *bufio.Reader) {
	flags, err := binary.ReadUvarint(r)
	self.flags = flags
	assert.Some(flags, err)

	var num_params, frame_size, num_upvals uint8
	err = binary.Read(r, binary.LittleEndian, &num_params)
	assert.No(err)

	err = binary.Read(r, binary.LittleEndian, &frame_size)
	assert.No(err)

	err = binary.Read(r, binary.LittleEndian, &num_upvals)
	assert.No(err)

	num_objects, err := binary.ReadUvarint(r)
	assert.No(err)
	num_nums, err := binary.ReadUvarint(r)
	assert.No(err)
	num_instructions, err := binary.ReadUvarint(r)
	assert.No(err)

	self.gc_objects = make([]GCObject, num_objects)
	self.gc_nums = make([]GCNum, num_nums)
	self.instructions = make([]uint32, num_instructions)
}

func(self *Proto) Read_instructions(r *bufio.Reader) {
	err := binary.Read(r, binary.LittleEndian, self.instructions)
	assert.No(err)
}

func(self *Proto) Read_upvalues(r *bufio.Reader) {
	err := binary.Read(r, binary.LittleEndian, self.upvalues)
	assert.No(err)
}

func(self *Proto) Read_objects(r *bufio.Reader) {

}

func(self *Proto) Read_nums(r *bufio.Reader) {
	err := binary.Read(r, binary.LittleEndian, self.gc_nums)
	assert.No(err)
}

func(self *Proto) Read_debug(r *bufio.Reader) {
	chars := make([]byte, self.debug.len)
	r.Read(chars)
}

type GCObject struct { }

type GCNum struct { }

type ProtoDebug struct {
	len uint64
	first_line uint64
	num_lines uint64
	info string
}

func(self *ProtoDebug) Read_proto_debug(r *bufio.Reader) {
	debug_len, err := binary.ReadUvarint(r)
	assert.Some(debug_len, err)
	self.len = debug_len

	if debug_len > 0 {
		first_line, err := binary.ReadUvarint(r)
		assert.Some(first_line, err)

		num_lines, err := binary.ReadUvarint(r)
		assert.Some(num_lines, err)

		self.first_line = first_line
		self.num_lines = num_lines
	}
}

