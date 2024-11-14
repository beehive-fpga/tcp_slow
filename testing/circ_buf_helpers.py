from bitfields import bitfield, bitfieldManip

class payloadPtrBitfield(bitfield):
    def __init__(self, name, size=None, value=0, init_bitfield=None):
        init_size = size
        init_name = name
        init_value = value

        if init_bitfield is not None:
            init_size = init_bitfield.size
            init_name = init_bitfield.name
            init_value = init_bitfield.value

        self.num_ptr_w = init_size - 1
        super().__init__(init_name, init_size, value=init_value,
                trunc_value=True)

    """
    Subtraction that mimics the Verilog semantics w.r.t.
    wrapping/overflow
    """
    def sub(self, other):
        #print(f"other.value {other.value}, self.value {self.value}")
        if other.value > self.value:
            max_val = 1 << self.num_ptr_w
            diff = other.to_addr() - self.to_addr()
            return max_val - diff
        else:
            return self.value - other.value

    def to_addr(self):
        formatted = self.bitfield_format()
        num_val = formatted[-self.num_ptr_w:]
        return int(num_val, 2)


class circBuf():
    def __init__(self, size_bytes):
        self.size_bytes = size_bytes
        self.data = bytearray([0] * self.size_bytes)

    def write_from(self, addr, buf):
        if addr >= self.size_bytes:
            raise ValueError("Start address outside possible range")
        if len(buf) > self.size_bytes:
            raise ValueError("data larger than possible size of the buffer")
        for i in range(0, len(buf)):
            self.data[(addr + i) % self.size_bytes] = buf[i]

    def read_from(self, addr, length):
        if addr >= self.size_bytes:
            raise ValueError("Start address outside possible range")
        if length > self.size_bytes:
            raise ValueError("requested data larger than possible size of the buffer")
        ret_buf = bytearray([0] * length)

        for i in range(0, length):
            ret_buf[i] = self.data[(addr + i) % self.size_bytes]

        return ret_buf


