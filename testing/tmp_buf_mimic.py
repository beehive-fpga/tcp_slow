from collections import deque

class TmpBufMimic():
    def __init__(self, size):
        self.max_size = size
        self.data = [None] * self.max_size
        self.free_slabs = deque()
        self.free_index = 0
        self.use_queue = False

    def get_slab(self):
        if self.use_queue:
            if len(self.free_slabs) != 0:
                return (True, self.free_slabs.popleft())
            else:
                return (False, -1)
        else:
            index = self.free_index
            self.free_index += 1
            if self.free_index == self.max_size:
                self.use_queue = True
            return (True, index)

    def free_slab(self, index):
        self.free_slabs.append(index)

    def write_slab(self, index, data_buf):
        self.data[index] = data_buf

    def read_slab(self, index):
        return self.data[index]
