# Getting Started

## Hardware Setup

Connect your FT-891 to the computer via the USB Type-B port on the radio's rear panel.
On Linux, this creates two virtual serial ports:

| Port | Name | Purpose |
|:-----|:-----|:--------|
| `/dev/ttyUSB0` | Enhanced COM | CAT commands (frequency, mode, etc.) |
| `/dev/ttyUSB1` | Standard COM | PTT, CW keying via RTS/DTR |

!!! tip
    The port numbers may vary. Check `dmesg` or `/dev/serial/by-id/` after plugging in.

### Linux Permissions

```bash
sudo usermod -aG dialout $USER
# Log out and back in for the group change to take effect
```

## Radio Menu Settings

Configure these via the FT-891's menu system:

| Menu | Setting | Value | Purpose |
|:-----|:--------|:------|:--------|
| 05-06 | CAT RATE | 9600 | Serial baud rate (must match Julia code) |
| 05-07 | CAT TOT | 100ms | Command timeout |
| 05-08 | CAT RTS | Enable | RTS monitoring |
| 07-12 | PC KEYING | RTS | Required for CW keying via computer |

## Basic Usage

```julia
using YaesuCAT

# Create and connect
radio = FT891("/dev/ttyUSB0"; baudrate=9600)
connect!(radio)

# Verify connection
id = read(radio, Identification())  # Should return "0670"

# Set frequency and mode
set!(radio, FrequencyVFO{A}(), Hz(14_060_000))
set!(radio, Mode(), CW())

# Read back
freq = read(radio, FrequencyVFO{A}())  # → Hz(14060000)
mode = read(radio, Mode())              # → CW()

# Adjust CW settings
set!(radio, KeySpeed(), WPM(17))
set!(radio, KeyPitch(), Pitch(600))
set!(radio, Keyer(), On())
set!(radio, BreakIn(), SemiBreakIn())

# Power and band
set!(radio, Power(), Level(50))
set!(radio, BandSelect(), Band20m())

# Antenna tuner
set!(radio, AntennaControl(), On())

disconnect!(radio)
```

## Testing Without Hardware

Use `NullTransport` to test your code without a radio:

```julia
transport = NullTransport()
radio = FT891(transport)
connect!(radio)

# set! records commands
set!(radio, Mode(), CW())
@assert transport.sent[end] == "MD03;"

# Pre-load responses for read
push!(transport.responses, "FA014060000;")
freq = read(radio, FrequencyVFO{A}())
@assert freq == Hz(14_060_000)
```

## Raw Commands

For commands not yet wrapped in types, use the low-level API:

```julia
send_cmd!(radio, "AG0050")           # Set AF gain to 50
resp = query(radio, "AG0")           # Read AF gain
set!(radio, MenuAccess(), "05069600") # Set menu 05-06 to 9600
```
