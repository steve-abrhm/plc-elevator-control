# PLC Elevator Control System

A 4-floor elevator controller built on a Siemens S7-1500 (CPU 1512C-1 PN) using Structured Text (IEC 61131-3) in TIA Portal V18. Developed as part of the Automation Lab at THWS.

## How It Works

The scan logic runs every PLC cycle: latched request arrays (cabin calls, up-calls, down-calls) are checked against the current floor and travel direction, and the controller decides whether to keep moving, stop, or reverse. Requests are only cleared after the floor is actually serviced.

Door sequencing uses edge-trigger logic -- a rising-edge trigger (R_TRIG) fires when a stop is needed, a 5-second TON timer holds the doors open, and a falling-edge trigger (F_TRIG) on Q4 clears the request and re-enables the motor. The motor stays locked out until the B6 sensor confirms the door is fully closed.

Floor detection uses active-low light barrier sensors; travel between floors is simulated at 2 seconds per floor.

## Logic Breakdown

| Section | Description |
|---|---|
| 1. Load Requests | Latches cabin, up, and down calls into request arrays |
| 2. Floor Detection | Scans active-low FloorSensor[] array to find current floor |
| 3. Scan Above/Below | Checks for pending requests above and below current floor |
| 4. Stop Conditions | Determines if elevator should stop based on direction and priority |
| 5. Door Sequencing | R_TRIG -> 5s TON timer -> F_TRIG clears request and unlocks motor |
| 6. Motor Logic | Drives MotorUp/MotorDown only when door closed and no stop active |
| 7. Movement Simulation | 2s TON timer per floor, updates CurrentFloor on expiry |

## Hardware & Tools

- **PLC:** Siemens S7-1500 (CPU 1512C-1 PN)
- **IDE:** TIA Portal V18
- **Language:** IEC 61131-3 Structured Text
- **Floor detection:** Active-low light barrier sensors
- **GRAFCET:** Designed in GRAFCET-Studio v2.0

## Repository Structure

```
plc-elevator-control/
├── src/
│   └── PLC_PRG.st        # Main Structured Text program
├── grafcet/
│   └── elevator.grafcet  # GRAFCET-Studio project file (open with GRAFCET-Studio v2.0+)
└── README.md
```