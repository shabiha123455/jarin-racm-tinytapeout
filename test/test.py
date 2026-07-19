import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


def outputs(dut):
    value = int(dut.uo_out.value)
    return {
        "activity": value & 0b11,
        "div_sel": (value >> 2) & 0b11,
        "sleep_req": (value >> 4) & 1,
        "wake_ack": (value >> 5) & 1,
        "debug_rate": (value >> 6) & 1,
        "demo_msb": (value >> 7) & 1,
    }


async def reset_dut(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 3)


async def drive_windows(dut, stall, valid, windows):
    dut.ui_in.value = (valid << 1) | stall
    await ClockCycles(dut.clk, 64 * windows + 2)


@cocotb.test()
async def test_reset_disable_and_pin_safety(dut):
    cocotb.start_soon(Clock(dut.clk, 100, unit="ns").start())
    await reset_dut(dut)

    assert int(dut.uio_oe.value) == 0
    assert int(dut.uio_out.value) == 0

    dut.ena.value = 0
    await ClockCycles(dut.clk, 2)
    assert int(dut.uo_out.value) == 0

    dut.ena.value = 1
    await ClockCycles(dut.clk, 3)
    out = outputs(dut)
    assert out["activity"] == 0b11
    assert out["div_sel"] == 0b00
    assert out["sleep_req"] == 0


@cocotb.test()
async def test_all_activity_levels_and_hysteresis(dut):
    cocotb.start_soon(Clock(dut.clk, 100, unit="ns").start())
    await reset_dut(dut)

    # High: 100% productive samples.
    await drive_windows(dut, stall=0, valid=1, windows=4)
    out = outputs(dut)
    assert out["activity"] == 0b11
    assert out["div_sel"] == 0b00

    # Medium: valid without stall on alternating cycles.
    for _ in range(4):
        for i in range(64):
            dut.ui_in.value = 0b10 if i % 2 == 0 else 0
            await RisingEdge(dut.clk)
    await ClockCycles(dut.clk, 3)
    out = outputs(dut)
    assert out["activity"] == 0b10
    assert out["div_sel"] == 0b01

    # Low: exactly 16 active samples out of 64 = 25%.
    for _ in range(4):
        for i in range(64):
            dut.ui_in.value = 0b10 if i % 4 == 0 else 0
            await RisingEdge(dut.clk)
    await ClockCycles(dut.clk, 3)
    out = outputs(dut)
    assert out["activity"] == 0b01
    assert out["div_sel"] == 0b10

    # One high window must not immediately defeat hysteresis.
    await drive_windows(dut, stall=0, valid=1, windows=1)
    assert outputs(dut)["div_sel"] == 0b10

    # Sustained high restores /1.
    await drive_windows(dut, stall=0, valid=1, windows=4)
    out = outputs(dut)
    assert out["activity"] == 0b11
    assert out["div_sel"] == 0b00


@cocotb.test()
async def test_idle_sleep_and_wake(dut):
    cocotb.start_soon(Clock(dut.clk, 100, unit="ns").start())
    await reset_dut(dut)

    dut.ui_in.value = 0b01
    sleep_seen = False
    for _ in range(64 * 13):
        await RisingEdge(dut.clk)
        if outputs(dut)["sleep_req"]:
            sleep_seen = True
            break
    assert sleep_seen, "sleep_req did not assert"

    # One-cycle wake pulse.
    dut.ui_in.value = 0b101
    await RisingEdge(dut.clk)
    dut.ui_in.value = 0b001

    wake_seen = False
    for _ in range(16):
        await RisingEdge(dut.clk)
        if outputs(dut)["wake_ack"]:
            wake_seen = True
            break
    assert wake_seen, "wake_ack did not pulse"
    assert outputs(dut)["sleep_req"] == 0


@cocotb.test()
async def test_rate_scaling_affects_demo_counter(dut):
    cocotb.start_soon(Clock(dut.clk, 100, unit="ns").start())
    await reset_dut(dut)

    # At /1, bit 7 should toggle after 128 increments.
    dut.ui_in.value = 0b10
    await ClockCycles(dut.clk, 130)
    assert outputs(dut)["demo_msb"] == 1

    # Reset and enter idle; controller should eventually request /8 and sleep.
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst_n.value = 1
    dut.ui_in.value = 0b01
    await ClockCycles(dut.clk, 64 * 5)
    assert outputs(dut)["div_sel"] == 0b11
