import cocotb
from cocotb.log import SimLog

from bitfields import bitfield, bitfieldManip
from tcp_slow_test_structs import PayloadBufStruct
from circ_buf_helpers import payloadPtrBitfield
from cocotb.binary import BinaryValue

from cocotb.triggers import Event, RisingEdge, Combine, with_timeout
from cocotb.result import SimTimeoutError

class BufCopier():
    def __init__(self, hdr_op, commit_wr_op, commit_rd_req_op,
            commit_rd_resp_op, done_event, rx_circ_bufs, tmp_buf):
        self.hdr_op = hdr_op
        self.commit_wr_op = commit_wr_op
        self.commit_rd_req_op = commit_rd_req_op
        self.commit_rd_resp_op = commit_rd_resp_op
        self.ptr_w = self.commit_wr_op._bus.data.value.n_bits
        self.trunc_ptr = bitfield("commit_ptr", self.ptr_w, trunc_value = True)
        self.done_event = done_event
        self.rx_circ_bufs = rx_circ_bufs
        self.tmp_buf = tmp_buf

    async def req_loop(self):
        while not self.done_event.is_set():
            copy_req = None
            # try to wait for a response
            try:
                resp_coro = cocotb.start_soon(self.hdr_op.recv_resp())
                copy_req = await with_timeout(resp_coro,
                        2000, timeout_unit="ns")
            # if we don't get a response, continue, so we check done_event
            except SimTimeoutError:
                continue
            payload_entry = PayloadBufStruct(init_bitstring=copy_req["payload"])
            payload_size = payload_entry.getField("size")
            if payload_size != 0:
                if copy_req["accept_payload"]:

                    # figure out what the commit pointer is
                    await self.commit_rd_req_op.send_req(
                            {"addr": copy_req["flowid"]})
                    commit_ptr_dict = await self.commit_rd_resp_op.recv_resp()
                    commit_ptr_binval = commit_ptr_dict["data"]
                    commit_ptr = payloadPtrBitfield("commit_ptr",
                            size=commit_ptr_binval.n_bits,
                            value=commit_ptr_binval.integer)

                    # get the data from the tmp buf and write the data in
                    data = self.tmp_buf.read_slab(payload_entry.getField("addr"))
                    self.rx_circ_bufs[copy_req["flowid"]].write_from(commit_ptr.to_addr(), data)
                    #cocotb.log.info(f"Writing to addr {commit_ptr.to_addr()}: {data}")

                    new_ptr = commit_ptr.value + payload_entry.getField("size")

                    # truncate the new_ptr to the correct width
                    self.trunc_ptr.set_value(new_ptr)
                    ptr_bitstr = self.trunc_ptr.bitfield_format()
                    await self.commit_wr_op.send_req(
                            {"addr": copy_req["flowid"],
                             "data": BinaryValue(n_bits = self.ptr_w, value=ptr_bitstr)})

                    # free the buffer
                    self.tmp_buf.free_slab(payload_entry.getField("addr"))

        cocotb.log.info("Copier loop exiting")
