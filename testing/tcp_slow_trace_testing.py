import logging
import random
import collections
from pathlib import Path

import cocotb
from cocotb.queue import Queue as CocoQueue
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ReadOnly, Combine, First, Event
from cocotb.triggers import ClockCycles, with_timeout, Join
from cocotb.result import SimTimeoutError
from cocotb.log import SimLog
from cocotb.utils import get_sim_time
import scapy

from scapy.layers.l2 import Ether, ARP
from scapy.layers.inet import IP, UDP, TCP
from scapy.packet import Raw

import sys
import os
sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/cocotb_testing/common/")

from tcp_driver import TCPFourTuple
from generic_val_rdy import GenericValRdyBus, GenericValRdySource, GenericValRdySink
from tcp_slow_test_utils import TCPSlowTB, PayloadBufStruct
from tcp_slow_test_utils import payloadPtrBitfield, reset

@cocotb.test()
async def tcp_trace_test(dut):
    tb = TCPSlowTB(dut)

    cocotb.start_soon(Clock(dut.clk, 4, units='ns').start())

    await reset(dut)
    # start up all the hw mimic tasks
    app_flow_notif = cocotb.start_soon(tb.app_mimic.flow_notif())
    app_loop = cocotb.start_soon(tb.app_mimic.app_loop())
    buf_copy = cocotb.start_soon(tb.buf_cpy_obj.req_loop())
