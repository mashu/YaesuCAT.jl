# API Reference

## Radio Types

```@docs
FT891
```

## Connection

```@docs
connect!
disconnect!
```

## High-Level API

```@docs
set!
Base.read
```

## Low-Level API

```@docs
send_cmd!
read_response
query
```

## Commands — Frequency & Mode

```@docs
FrequencyVFO
Mode
```

## Commands — CW Keyer

```@docs
KeySpeed
Keyer
KeyPitch
CWKeying
KeyerMemory
BreakIn
CWSpot
```

## Commands — TX Control

```@docs
TXState
Power
AntennaControl
```

## Commands — Audio & Filters

```@docs
AFGain
MicGain
MonitorLevel
AutoNotch
ManualNotch
Contour
IFShift
AGCFunction
```

## Commands — Navigation

```@docs
BandSelect
BandUp
BandDown
FastStep
```

## Commands — Info & Misc

```@docs
Identification
Information
MeterSwitch
ReadMeter
Lock
Dimmer
VoxStatus
VoxGain
VoxDelay
MenuAccess
```

## Value Types

```@docs
Hz
WPM
MilliSeconds
Pitch
Level
KeyerSlot
MessageSlot
```

## CW Keying

```@docs
RTSKeyer
DTRKeyer
send_morse!
text_to_morse
```

## Protocol (Internal)

```@docs
encode_set
encode_read
decode_answer
```

## Transport (Internal)

```@docs
SerialTransport
NullTransport
```

## Type Hierarchy

```@docs
AbstractRadio
AbstractYaesuRadio
AbstractCommand
SetReadCommand
SetOnlyCommand
ReadOnlyCommand
AbstractVFO
AbstractValue
AbstractMode
AbstractBreakInMode
AbstractAGCMode
AbstractMeterType
AbstractSwitch
AbstractBand
AbstractTransport
AbstractCWKeyer
```
