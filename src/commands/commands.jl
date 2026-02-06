# ═══════════════════════════════════════════════════════════════════
# commands/commands.jl — Hub file that defines all command types
#                        and their encoding/decoding methods
#
# Each command type is a zero-size singleton struct inheriting from
# SetReadCommand, SetOnlyCommand, or ReadOnlyCommand. This encodes
# the command's capabilities in the type system.
#
# Following kd-boss/CAT: each command maps to the 2-letter code
# from the Yaesu CAT manual. The Set/Read/Answer column pattern
# (O=available, X=not) determines which abstract parent to use.
# ═══════════════════════════════════════════════════════════════════

# ── Frequency ───────────────────────────────────────────────────

"""
    FrequencyVFO{V <: AbstractVFO} <: SetReadCommand

VFO frequency command. Parametric on VFO tag for compile-time dispatch.
CAT codes: `FA` (VFO-A), `FB` (VFO-B). Capabilities: Set/Read/Answer.

```julia
set!(radio, FrequencyVFO{A}(), Hz(14_250_000))
freq = read(radio, FrequencyVFO{A}())  # → Hz(14250000)
```
"""
struct FrequencyVFO{V <: AbstractVFO} <: SetReadCommand end

_vfo_prefix(::FrequencyVFO{A}) = "FA"
_vfo_prefix(::FrequencyVFO{B}) = "FB"

function encode_set(cmd::FrequencyVFO, freq::Hz)
    terminate(_vfo_prefix(cmd) * pad_int(freq.value, 9))
end

function encode_read(cmd::FrequencyVFO)
    terminate(_vfo_prefix(cmd))
end

function decode_answer(cmd::FrequencyVFO, raw::AbstractString)
    Hz(parse(Int, raw[3:11]))
end

# ── Mode ────────────────────────────────────────────────────────

"""
    Mode <: SetReadCommand

Operating mode command. CAT code: `MD`. Capabilities: Set/Read/Answer.
P1 is fixed to `0` for the FT-891 (main VFO).

```julia
set!(radio, Mode(), CW())
mode = read(radio, Mode())  # → CW()
```
"""
struct Mode <: SetReadCommand end

encode_set(::Mode, m::AbstractMode) = terminate("MD0" * mode_code(m))
encode_read(::Mode) = terminate("MD0")

function decode_answer(::Mode, raw::AbstractString)
    # Response format: MD0X
    decode_mode(raw[4:4])
end

# ── AF Gain ─────────────────────────────────────────────────────

"""
    AFGain <: SetReadCommand

AF (audio) gain. CAT code: `AG`. P1=0 (main), P2 = 000–255.
"""
struct AFGain <: SetReadCommand end

encode_set(::AFGain, v::Level) = terminate("AG0" * pad_int(v.value, 3))
encode_read(::AFGain) = terminate("AG0")
decode_answer(::AFGain, raw::AbstractString) = Level(parse(Int, raw[4:6]))

# ── Mic Gain ────────────────────────────────────────────────────

"""
    MicGain <: SetReadCommand

Microphone gain. CAT code: `MG`. Range: 0–100.
"""
struct MicGain <: SetReadCommand end

encode_set(::MicGain, v::Level) = terminate("MG" * pad_int(v.value, 3))
encode_read(::MicGain) = terminate("MG")
decode_answer(::MicGain, raw::AbstractString) = Level(parse(Int, raw[3:5]))

# ── Monitor Level ───────────────────────────────────────────────

"""
    MonitorLevel <: SetReadCommand

Monitor level. CAT code: `ML`. Range: 0–100.
"""
struct MonitorLevel <: SetReadCommand end

encode_set(::MonitorLevel, v::Level) = terminate("ML" * pad_int(v.value, 3))
encode_read(::MonitorLevel) = terminate("ML")
decode_answer(::MonitorLevel, raw::AbstractString) = Level(parse(Int, raw[3:5]))

# ── TX State ────────────────────────────────────────────────────

"""
    TXState <: SetReadCommand

Transmit state control. CAT code: `TX`.
Values: `0` = all off, `1` = CAT TX on, `2` = radio TX on.

```julia
set!(radio, TXState(), On())   # key up via CAT (TX1)
set!(radio, TXState(), Off())  # unkey (TX0)
```
"""
struct TXState <: SetReadCommand end

encode_set(::TXState, ::On)  = terminate("TX1")
encode_set(::TXState, ::Off) = terminate("TX0")
encode_read(::TXState) = terminate("TX")

function decode_answer(::TXState, raw::AbstractString)
    raw[end] == '0' ? Off() : On()
end

# ── Key Speed ───────────────────────────────────────────────────

"""
    KeySpeed <: SetReadCommand

CW keyer speed. CAT code: `KS`. Range: 4–60 WPM.

```julia
set!(radio, KeySpeed(), WPM(17))
wpm = read(radio, KeySpeed())  # → WPM(17)
```
"""
struct KeySpeed <: SetReadCommand end

function encode_set(::KeySpeed, w::WPM)
    4 <= w.value <= 60 || throw(ArgumentError("WPM must be 4–60, got $(w.value)"))
    terminate("KS" * pad_int(w.value, 3))
end

encode_read(::KeySpeed) = terminate("KS")
decode_answer(::KeySpeed, raw::AbstractString) = WPM(parse(Int, raw[3:5]))

# ── Keyer On/Off ────────────────────────────────────────────────

"""
    Keyer <: SetReadCommand

Internal electronic keyer enable/disable. CAT code: `KR`.
"""
struct Keyer <: SetReadCommand end

encode_set(::Keyer, s::AbstractSwitch) = terminate("KR" * switch_code(s))
encode_read(::Keyer) = terminate("KR")
decode_answer(::Keyer, raw::AbstractString) = raw[end] == '1' ? On() : Off()

# ── Key Pitch ───────────────────────────────────────────────────

"""
    KeyPitch <: SetReadCommand

CW sidetone pitch. CAT code: `KP`. Range: 300–1050 Hz, 10 Hz steps.
Parameter: `(hz - 300) ÷ 10`, formatted as 2 digits.
"""
struct KeyPitch <: SetReadCommand end

function encode_set(::KeyPitch, p::Pitch)
    300 <= p.value <= 1050 || throw(ArgumentError("Pitch must be 300–1050 Hz"))
    p.value % 10 == 0 || throw(ArgumentError("Pitch must be a multiple of 10 Hz"))
    terminate("KP" * pad_int((p.value - 300) ÷ 10, 2))
end

encode_read(::KeyPitch) = terminate("KP")
decode_answer(::KeyPitch, raw::AbstractString) = Pitch(parse(Int, raw[3:4]) * 10 + 300)

# ── CW Keying (playback trigger) ───────────────────────────────

"""
    CWKeying <: SetOnlyCommand

CW keyer memory / message playback trigger. CAT code: `KY`.
**Set only** — the FT-891 does not support reading the keying state.

This command triggers playback of a *pre-stored* message. It does NOT
accept arbitrary text. Use [`KeyerMemory`](@ref) to store messages first,
or use [`RTSKeyer`](@ref) for arbitrary CW text.

```julia
set!(radio, CWKeying(), KeyerSlot(1))   # play keyer memory 1
set!(radio, CWKeying(), MessageSlot(3)) # play message keyer 3
```

!!! note "kd-boss/CAT reference"
    In the C++ library, `CWKeying::Set()` maps the same way — it only
    triggers playback of stored messages. There is no `Read()` or
    `Answer()` for this command (column pattern O/X/X/X).
"""
struct CWKeying <: SetOnlyCommand end

function encode_set(::CWKeying, slot::KeyerSlot)
    terminate("KY" * string(slot.slot))
end

function encode_set(::CWKeying, slot::MessageSlot)
    codes = ('6', '7', '8', '9', 'A')
    terminate("KY" * string(codes[slot.slot]))
end

# ── Keyer Memory (store message) ────────────────────────────────

"""
    KeyerMemory <: SetReadCommand

CW keyer memory storage. CAT code: `KM`. Slots 1–5, up to 50 characters each.
Set stores a message; Read retrieves the stored text.

```julia
set!(radio, KeyerMemory(1), "CQ CQ DE SA0KAM K")
msg = read(radio, KeyerMemory(1))  # → "CQ CQ DE SA0KAM K"
```
"""
struct KeyerMemory <: SetReadCommand
    slot::Int
    function KeyerMemory(slot::Int)
        1 <= slot <= 5 || throw(ArgumentError("Keyer memory slot must be 1–5"))
        new(slot)
    end
end

function encode_set(cmd::KeyerMemory, message::AbstractString)
    msg = uppercase(strip(String(message)))
    length(msg) <= 50 || throw(ArgumentError("Keyer message max 50 chars, got $(length(msg))"))
    terminate("KM" * string(cmd.slot) * msg)
end

encode_read(cmd::KeyerMemory) = terminate("KM" * string(cmd.slot))

function decode_answer(cmd::KeyerMemory, raw::AbstractString)
    # Response: KM<slot><message>
    rstrip(raw[4:end])
end

# ── Break-In ────────────────────────────────────────────────────

"""
    BreakIn <: SetReadCommand

CW break-in mode. CAT code: `BI`.
"""
struct BreakIn <: SetReadCommand end

encode_set(::BreakIn, m::AbstractBreakInMode) = terminate("BI" * breakin_code(m))
encode_read(::BreakIn) = terminate("BI")

# ── CW Spot ─────────────────────────────────────────────────────

"""
    CWSpot <: SetReadCommand

CW spot tone enable/disable. CAT code: `CS`.
"""
struct CWSpot <: SetReadCommand end

encode_set(::CWSpot, s::AbstractSwitch) = terminate("CS" * switch_code(s))
encode_read(::CWSpot) = terminate("CS")
decode_answer(::CWSpot, raw::AbstractString) = raw[end] == '1' ? On() : Off()

# ── Auto Notch ──────────────────────────────────────────────────

"""
    AutoNotch <: SetReadCommand

Auto notch filter. CAT code: `BC`.
"""
struct AutoNotch <: SetReadCommand end

encode_set(::AutoNotch, s::AbstractSwitch) = terminate("BC0" * switch_code(s))
encode_read(::AutoNotch) = terminate("BC0")

# ── Manual Notch ────────────────────────────────────────────────

"""
    ManualNotch <: SetReadCommand

Manual notch filter level. CAT code: `BP`. Range: 0–320 (×10 Hz).
"""
struct ManualNotch <: SetReadCommand end

encode_set(::ManualNotch, v::Level) = terminate("BP" * pad_int(v.value, 3))
encode_read(::ManualNotch) = terminate("BP")
decode_answer(::ManualNotch, raw::AbstractString) = Level(parse(Int, raw[3:5]))

# ── Contour ─────────────────────────────────────────────────────

"""
    Contour <: SetReadCommand

Contour filter. CAT code: `CO`.
"""
struct Contour <: SetReadCommand end

encode_set(::Contour, s::AbstractSwitch) = terminate("CO00" * switch_code(s))
encode_read(::Contour) = terminate("CO00")

# ── IF Shift ────────────────────────────────────────────────────

"""
    IFShift <: SetReadCommand

IF shift. CAT code: `IS`. P1=0 (fixed), P2=on/off, P3=signed Hz (0–1200, 20 Hz steps).
"""
struct IFShift <: SetReadCommand end

function encode_set(::IFShift, ::Off)
    terminate("IS00-0000")
end

function encode_set(::IFShift, p::Pitch)
    sign = p.value >= 0 ? "+" : "-"
    terminate("IS01" * sign * pad_int(abs(p.value), 4))
end

encode_read(::IFShift) = terminate("IS")

# ── AGC Function ────────────────────────────────────────────────

"""
    AGCFunction <: SetReadCommand

AGC mode. CAT code: `GT`. P1=0 (main).
"""
struct AGCFunction <: SetReadCommand end

encode_set(::AGCFunction, m::AbstractAGCMode) = terminate("GT0" * agc_code(m))
encode_read(::AGCFunction) = terminate("GT0")

# ── Identification ──────────────────────────────────────────────

"""
    Identification <: ReadOnlyCommand

Radio identification. CAT code: `ID`. FT-891 returns `"0670"`.
Read-only — used to verify the connected radio model.
"""
struct Identification <: ReadOnlyCommand end

encode_read(::Identification) = terminate("ID")
decode_answer(::Identification, raw::AbstractString) = String(raw[3:end])

# ── Information ─────────────────────────────────────────────────

"""
    Information <: ReadOnlyCommand

Information query. CAT code: `IF`. Returns a packed string with
frequency, mode, clarifier, VFO status, CTCSS, and shift information.
Read-only.
"""
struct Information <: ReadOnlyCommand end

encode_read(::Information) = terminate("IF")
decode_answer(::Information, raw::AbstractString) = String(raw)

# ── Meter Switch ────────────────────────────────────────────────

"""
    MeterSwitch <: SetReadCommand

Select which meter to display during TX. CAT code: `MS`.
"""
struct MeterSwitch <: SetReadCommand end

encode_set(::MeterSwitch, m::AbstractMeterType) = terminate("MS" * meter_code(m))
encode_read(::MeterSwitch) = terminate("MS")

# ── Read Meter ──────────────────────────────────────────────────

"""
    ReadMeter <: ReadOnlyCommand

Read current meter value. CAT code: `RM`. Returns raw level string.
"""
struct ReadMeter <: ReadOnlyCommand end

encode_read(::ReadMeter) = terminate("RM")
decode_answer(::ReadMeter, raw::AbstractString) = String(raw)

# ── Power ───────────────────────────────────────────────────────

"""
    Power <: SetReadCommand

TX output power. CAT code: `PC`. Range: 5–100 watts.
"""
struct Power <: SetReadCommand end

function encode_set(::Power, v::Level)
    5 <= v.value <= 100 || throw(ArgumentError("Power must be 5–100 W, got $(v.value)"))
    terminate("PC" * pad_int(v.value, 3))
end

encode_read(::Power) = terminate("PC")
decode_answer(::Power, raw::AbstractString) = Level(parse(Int, raw[3:5]))

# ── Band Select ─────────────────────────────────────────────────

"""
    BandSelect <: SetOnlyCommand

Direct band selection. CAT code: `BS`. Set only.
"""
struct BandSelect <: SetOnlyCommand end

encode_set(::BandSelect, b::AbstractBand) = terminate("BS" * band_code(b))

# ── Band Up / Band Down ────────────────────────────────────────

"""
    BandUp <: SetOnlyCommand

Step band up. CAT code: `BU`.
"""
struct BandUp <: SetOnlyCommand end

encode_set(::BandUp) = terminate("BU")

"""
    BandDown <: SetOnlyCommand

Step band down. CAT code: `BD`.
"""
struct BandDown <: SetOnlyCommand end

encode_set(::BandDown) = terminate("BD")

# ── Lock ────────────────────────────────────────────────────────

"""
    Lock <: SetReadCommand

Dial lock. CAT code: `LK`.
"""
struct Lock <: SetReadCommand end

encode_set(::Lock, s::AbstractSwitch) = terminate("LK" * switch_code(s))
encode_read(::Lock) = terminate("LK")

# ── Antenna Tuner Control ──────────────────────────────────────

"""
    AntennaControl <: SetReadCommand

Antenna tuner. CAT code: `AC`. `set!(radio, AntennaControl(), On())` starts tuning.
"""
struct AntennaControl <: SetReadCommand end

encode_set(::AntennaControl, ::On)  = terminate("AC002")  # start tune
encode_set(::AntennaControl, ::Off) = terminate("AC000")  # tuner off
encode_read(::AntennaControl) = terminate("AC")

# ── Fast Step ───────────────────────────────────────────────────

"""
    FastStep <: SetReadCommand

Fast tuning step enable/disable. CAT code: `FS`.
"""
struct FastStep <: SetReadCommand end

encode_set(::FastStep, s::AbstractSwitch) = terminate("FS" * switch_code(s))
encode_read(::FastStep) = terminate("FS")

# ── Clarifier ───────────────────────────────────────────────────

"""
    Clarifier <: SetReadCommand

Clarifier (RIT/XIT). CAT code: `CF`.
"""
struct Clarifier <: SetReadCommand end

encode_set(::Clarifier, ::Off) = terminate("CF000")
encode_read(::Clarifier) = terminate("CF")

# ── VOX ─────────────────────────────────────────────────────────

"""
    VoxStatus <: SetReadCommand

VOX enable/disable. CAT code: `VX`.
"""
struct VoxStatus <: SetReadCommand end

encode_set(::VoxStatus, s::AbstractSwitch) = terminate("VX" * switch_code(s))
encode_read(::VoxStatus) = terminate("VX")

"""
    VoxGain <: SetReadCommand

VOX gain level. CAT code: `VG`. Range: 0–100.
"""
struct VoxGain <: SetReadCommand end

encode_set(::VoxGain, v::Level) = terminate("VG" * pad_int(v.value, 3))
encode_read(::VoxGain) = terminate("VG")
decode_answer(::VoxGain, raw::AbstractString) = Level(parse(Int, raw[3:5]))

"""
    VoxDelay <: SetReadCommand

VOX delay time. CAT code: `VD`. Range: 30–3000 ms, 10 ms steps.
"""
struct VoxDelay <: SetReadCommand end

function encode_set(::VoxDelay, v::MilliSeconds)
    terminate("VD" * pad_int(v.value, 4))
end

encode_read(::VoxDelay) = terminate("VD")
decode_answer(::VoxDelay, raw::AbstractString) = MilliSeconds(parse(Int, raw[3:6]))

# ── Dimmer ──────────────────────────────────────────────────────

"""
    Dimmer <: SetReadCommand

Display dimmer. CAT code: `DA`.
"""
struct Dimmer <: SetReadCommand end

encode_set(::Dimmer, v::Level) = terminate("DA" * pad_int(v.value, 2))
encode_read(::Dimmer) = terminate("DA")

# ── Menu Access ─────────────────────────────────────────────────

"""
    MenuAccess <: SetReadCommand

Direct menu parameter access. CAT code: `EX`.
Use with raw strings for the menu number + value.

```julia
# Set CAT baud rate (menu 05-06) to 9600
set!(radio, MenuAccess(), "05069600")
```
"""
struct MenuAccess <: SetReadCommand end

encode_set(::MenuAccess, params::AbstractString) = terminate("EX" * params)
encode_read(::MenuAccess, params::AbstractString) = terminate("EX" * params)
