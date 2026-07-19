# RACM: Runtime-Adaptive Clock-Enable and Sleep Controller

## What it does

RACM observes two workload signals:

- `core_valid`: useful work completed in the current sample
- `core_stall`: the core is unable to make progress

Every 64 active system-clock cycles, RACM classifies workload into four levels:

| Activity | Productive samples | Selected rate |
|---|---:|---:|
| High | at least 75% | /1 |
| Medium | at least 50% | /2 |
| Low | at least 25% | /4 |
| Idle | below 25% | /8 |

Three consecutive matching classification windows are required before the selected rate changes. This hysteresis prevents rapid oscillation.

The design uses one physical clock domain. `/1`, `/2`, `/4`, and `/8` are implemented as synchronous clock-enable pulses, not internally generated clocks. This avoids clock-domain-crossing and runt-pulse risks.

After eight idle windows, `sleep_request` is asserted and the demonstration counter stops. A pulse on `wake_request` starts a four-cycle wake delay; `wake_ack` then pulses for one clock.

## Important limitation

`sleep_request` is a digital power-management request. In the standard Tiny Tapeout digital flow it does not physically disconnect the power supply. Actual header switches, isolation cells, retention cells and a separate voltage domain require a custom low-power physical-design flow.

## Pin mapping

### Inputs

| Pin | Function |
|---|---|
| `ui_in[0]` | core_stall |
| `ui_in[1]` | core_valid |
| `ui_in[2]` | wake_request |

### Outputs

| Pin | Function |
|---|---|
| `uo_out[1:0]` | activity level |
| `uo_out[3:2]` | divider selection |
| `uo_out[4]` | sleep request |
| `uo_out[5]` | wake acknowledgement |
| `uo_out[6]` | selected debug-rate waveform |
| `uo_out[7]` | MSB of rate-controlled demo counter |

## How to test on silicon

1. Enable the project and reset it.
2. Drive `core_valid=1`, `core_stall=0`; expect activity `11` and divider `00`.
3. Provide alternating productive/nonproductive samples; expect activity `10` and divider `01` after hysteresis.
4. Provide one productive sample per four cycles; expect activity `01` and divider `10`.
5. Drive `core_stall=1`, `core_valid=0`; expect activity `00`, divider `11`, then `sleep_request=1`.
6. Pulse `wake_request`; expect `sleep_request=0` followed by a one-cycle `wake_ack`.

Use an oscilloscope or logic analyzer on `uo_out[6]` to observe the selected rate.
