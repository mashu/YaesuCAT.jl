# CW Keying

The FT-891 supports two methods for sending CW from a computer.
Understanding the distinction is important for choosing the right approach.

## Approach 1: Keyer Memory Playback (KY/KM Commands)

The FT-891's `KY` CAT command **only triggers playback of pre-stored messages**.
It does NOT accept arbitrary text for direct CW transmission.

!!! warning "Common misconception"
    Unlike the FT-991 which supports sending arbitrary text via `KY`, the FT-891's
    `KY` command only has a Set operation (no Read/Answer) and only accepts slot
    numbers. This matches the kd-boss/CAT C++ library where `CWKeying` only
    has `Set()` with a slot parameter.

### Usage

```julia
# Store messages in keyer memory slots 1-5 (max 50 chars each)
set!(radio, KeyerMemory(1), "CQ CQ DE SA0KAM SA0KAM K")
set!(radio, KeyerMemory(2), "5NN TU")
set!(radio, KeyerMemory(3), "SA0KAM")

# Trigger playback — radio's internal keyer sends at current KS speed
set!(radio, CWKeying(), KeyerSlot(1))

# Or trigger message keyer slots (6-A in the CAT manual)
set!(radio, CWKeying(), MessageSlot(1))
```

### When to use this
- Contest exchanges with fixed messages
- CQ calls, callsign, RST reports
- Any message ≤ 50 characters that you can pre-store

## Approach 2: RTS/DTR Line Keying (PC KEYING)

For **arbitrary CW text**, the FT-891 supports "PC KEYING" via menu `07-12`.
The computer toggles the RTS (or DTR) serial control line to key the transmitter
directly — functioning as a software straight key.

This package implements the full timing logic following the PARIS standard.

### Setup

1. Set menu `07-12 PC KEYING` to `RTS` (or `DTR`)
2. Set menu `04-01 KEYER TYPE` to `OFF` (straight key emulation)
3. Use the **Standard COM port** (lower-numbered `/dev/ttyUSB`)

### Usage

```julia
# CAT commands on Enhanced port
radio = FT891("/dev/ttyUSB0")
connect!(radio)
set!(radio, Mode(), CW())

# CW keying on Standard port (separate connection)
keyer = RTSKeyer("/dev/ttyUSB1")

# Send arbitrary text at 17 WPM
send_morse!(keyer, "CQ CQ DE SA0KAM SA0KAM K", WPM(17))

# Wait for response, then send again
send_morse!(keyer, "UR RST 599 599 BK", WPM(17))

close(keyer)
disconnect!(radio)
```

### Pre-computing Morse

For repeated messages, pre-compute the element sequence:

```julia
cq_elements = text_to_morse("CQ CQ DE SA0KAM K")

# Send multiple times without re-encoding
send_morse!(keyer, cq_elements, WPM(17))
send_morse!(keyer, cq_elements, WPM(17))
```

### Timing Details

The PARIS standard defines timing in "units" where 1 unit = 1200/WPM milliseconds:

| Element | Duration | At 17 WPM |
|:--------|:---------|:----------|
| Dit (key down) | 1 unit | 70.6 ms |
| Dah (key down) | 3 units | 211.8 ms |
| Element gap | 1 unit | 70.6 ms |
| Character gap | 3 units | 211.8 ms |
| Word gap | 7 units | 494.1 ms |

## Comparison

| Feature | Keyer Memory | RTS/DTR Keying |
|:--------|:-------------|:---------------|
| Arbitrary text | No (50 char limit, pre-stored) | Yes |
| Timing accuracy | Excellent (radio's internal keyer) | Good (limited by OS scheduling) |
| Speed control | Uses radio's KS setting | Explicit `WPM()` parameter |
| COM port | Enhanced (CAT) | Standard (lower number) |
| Break-in support | Yes (radio handles TX/RX) | Manual (or set break-in via CAT) |
| Setup complexity | Simple (just CAT commands) | Requires menu 07-12 configuration |

## Extending with New Keyer Types

The keyer system is extensible via Julia's type hierarchy:

```julia
# All keyers inherit from AbstractCWKeyer
# To add a new keyer, define the type and implement _key_down/_key_up:

struct GPIOKeyer <: AbstractCWKeyer
    pin::Int
end

YaesuCAT._key_down(k::GPIOKeyer) = # set GPIO pin high
YaesuCAT._key_up(k::GPIOKeyer)   = # set GPIO pin low

# send_morse! works automatically via dispatch!
send_morse!(GPIOKeyer(17), "CQ", WPM(20))
```
