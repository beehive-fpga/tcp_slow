import logging
import random

import cocotb
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly

PTR_W = 11
WIN_SIZE_W = 16
MAX_SEG_SIZE = 1024
CLOCK_CYCLE_TIME = 4

@cocotb.test()
async def win_size_testing(dut):
    cocotb.start_soon(Clock(dut.clk, CLOCK_CYCLE_TIME, units='ns').start())
    dut.trail_ptr.setimmediatevalue(0)
    dut.lead_ptr.setimmediatevalue(0)
    dut.next_send_ptr.setimmediatevalue(0)
    dut.curr_win.setimmediatevalue(0)

    await RisingEdge(dut.clk)
    # try a basic test: empty buffer
    await run_test(dut, 0, 0, 0, 1200, 0)

    await RisingEdge(dut.clk)

    # try a basic test: buffer with less data than window, seg size
    await run_test(dut, 16, 24, 16, 1200, 24-16)
    await RisingEdge(dut.clk)

    # try a basic test: buffer with more data than seg size, window larger
    # than seg size
    await run_test(dut, 0, 1200, 0, 1200, MAX_SEG_SIZE)
    await RisingEdge(dut.clk)

    # try a basic test: buffer with more data than seg size, window smaller
    # than seg size
    await run_test(dut, 0, 1200, 0, 500, 500)
    await RisingEdge(dut.clk)

    # try a test where the window is full, but of unacked data
    await run_test(dut, 16, 512, 256, 256-16, 0)
    await RisingEdge(dut.clk)

    # try a test where we have a smaller window than unacked data
    await run_test(dut, 100, 500, 100, 200, 200)
    await RisingEdge(dut.clk)

    # try a test where the window is partially full with unacked data
    await run_test(dut, 0, 256, 256-16, 256, 16)
    await RisingEdge(dut.clk)

    # try a test where the pointers wrap, but the lead pointer is still
    # arithmetically larger than the trail pointer
    lead_ptr = (1 << PTR_W) + 16
    trail_ptr = (1 << PTR_W) - 16
    next_send_ptr = 1 << PTR_W

    await run_test(dut, trail_ptr, lead_ptr, trail_ptr, 1200, 32)
    await RisingEdge(dut.clk)

    # try a test where the pointers wrap, but the lead pointer is
    # arithmetically smaller than the trail pointer
    lead_ptr = 10
    trail_ptr = (1 << PTR_W) + ((1 << PTR_W) - 16)
    await run_test(dut, trail_ptr, lead_ptr, trail_ptr, 1200, 10 + 16)
    await RisingEdge(dut.clk)

    # try a wrapped test, but also limit by window size
    lead_ptr = 50
    await run_test(dut, trail_ptr, lead_ptr, trail_ptr, 32, 32)
    await RisingEdge(dut.clk)


async def run_test(dut, trail, lead, next_send, curr_win, ref_value):
    dut.trail_ptr.value = BinaryValue(trail, n_bits=PTR_W+1, bigEndian=False)
    dut.lead_ptr.value = BinaryValue(lead, n_bits=PTR_W+1,bigEndian=False)
    dut.next_send_ptr.value = BinaryValue(next_send, n_bits=PTR_W+1, bigEndian=False)
    dut.curr_win.value = BinaryValue(curr_win, n_bits=WIN_SIZE_W, bigEndian=False)

    await ReadOnly()
    if (dut.seg_size.value != ref_value):
        await RisingEdge(dut.clk)
        raise RuntimeError()

