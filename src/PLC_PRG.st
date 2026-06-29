PROGRAM PLC_PRG
VAR
    CabinCall : ARRAY[0..3] OF BOOL;
    UpCall    : ARRAY[0..3] OF BOOL;
    DownCall  : ARRAY[0..3] OF BOOL;

    ReqCabin  : ARRAY[0..3] OF BOOL;
    ReqUp     : ARRAY[0..3] OF BOOL;
    ReqDown   : ARRAY[0..3] OF BOOL;

    FloorSensor : ARRAY[0..3] OF BOOL;

    CurrentFloor : INT;

    ReqAbove : BOOL;
    ReqBelow : BOOL;
    uptrig : R_TRIG;   // rising-edge
    fall   : F_TRIG;   // falling-edge
    dortime : TON;     // timer

    MotorUp : BOOL;
    MotorDown : BOOL;
    DirUp : BOOL := TRUE;

    StopActive : BOOL;
    reset    : bool;
    DoorOpen : BOOL;
    DoorTimer : TON;
    DoorTimerRunning : BOOL := FALSE;
    i,k : INT;
    MoveTimer : TON;
    Q1,Q2,Q3,Q4,B5,B6, mem,mem1 : BOOL;

END_VAR


// 1. Load requests
// =========================================================
FOR i := 0 TO 3 DO
    IF CabinCall[i] THEN ReqCabin[i] := TRUE; END_IF;
    IF UpCall[i]    THEN ReqUp[i]    := TRUE; END_IF;
    IF DownCall[i]  THEN ReqDown[i]  := TRUE; END_IF;
END_FOR;


// =========================================================
// 2. Detect current floor
// =========================================================
FOR k := 0 TO 3 DO
    IF NOT FloorSensor[k] THEN       // Sensor FALSE means elevator is here
        CurrentFloor := k;
        EXIT;                        // Stop scanning once found
    END_IF;
END_FOR;

// Safety fallback
IF CurrentFloor = -1 THEN
    FloorSensor[0] := FALSE;
END_IF;

// =========================================================
// 3. Scan requests above & below
// =========================================================
ReqAbove := FALSE;
FOR i := CurrentFloor+1 TO 3 DO
    IF ReqCabin[i] OR ReqUp[i] OR ReqDown[i] THEN
        ReqAbove := TRUE;
        EXIT;
    END_IF;
END_FOR;

ReqBelow := FALSE;
FOR i := 0 TO CurrentFloor-1 DO
    IF ReqCabin[i] OR ReqUp[i] OR ReqDown[i] THEN
        ReqBelow := TRUE;
        EXIT;
    END_IF;
END_FOR;


// =========================================================
// 4. STOP Conditions (no movement during stop)
// =========================================================
StopActive := FALSE;

IF ReqCabin[CurrentFloor] THEN StopActive := TRUE; END_IF;

IF DirUp THEN
    IF ReqUp[CurrentFloor] OR (ReqDown[CurrentFloor] AND (NOT ReqAbove OR CurrentFloor = 3)) THEN
        StopActive := TRUE;
    END_IF;
ELSE
    IF ReqDown[CurrentFloor] OR (ReqUp[CurrentFloor] AND (NOT ReqBelow OR CurrentFloor = 0)) THEN
        StopActive := TRUE;
    END_IF;
END_IF;


// =========================================================
// 5. DOOR OPEN + WAIT 5 SECONDS + CLOSE
// =========================================================
IF StopActive THEN
    MotorUp := FALSE;
    MotorDown := FALSE;
END_IF;


// =========================================================
// 6. MOTOR LOGIC - ONLY WHEN DOOR CLOSED
// =========================================================
IF (NOT DoorOpen) AND (NOT StopActive) THEN

    IF DirUp THEN
        IF ReqAbove THEN
            MotorUp := TRUE;
            MotorDown := FALSE;
        ELSIF ReqBelow THEN
            DirUp := FALSE;
            MotorUp := FALSE;
            MotorDown := TRUE;
        ELSE
            MotorUp := FALSE;
            MotorDown := FALSE;
        END_IF;
    ELSE
        IF ReqBelow THEN
            MotorUp := FALSE;
            MotorDown := TRUE;
        ELSIF ReqAbove THEN
            DirUp := TRUE;
            MotorUp := TRUE;
            MotorDown := FALSE;
        ELSE
            MotorUp := FALSE;
            MotorDown := FALSE;
        END_IF;
    END_IF;

ELSE
    MotorUp := FALSE;
    MotorDown := FALSE;
END_IF;


// =========================================================
// 7. MOVEMENT SIMULATION
// =========================================================

// Moving UP
IF MotorUp AND NOT MotorDown THEN
    MoveTimer(IN := TRUE, PT := T#2S);
    IF MoveTimer.Q THEN
        FloorSensor[CurrentFloor] := TRUE;
        IF CurrentFloor < 3 THEN CurrentFloor := CurrentFloor + 1; END_IF;
        FloorSensor[CurrentFloor] := FALSE;
        MoveTimer(IN := FALSE);
    END_IF;
END_IF;

// Moving DOWN
IF MotorDown AND NOT MotorUp THEN
    MoveTimer(IN := TRUE, PT := T#2S);
    IF MoveTimer.Q THEN
        FloorSensor[CurrentFloor] := TRUE;
        IF CurrentFloor > 0 THEN CurrentFloor := CurrentFloor - 1; END_IF;
        FloorSensor[CurrentFloor] := FALSE;
        MoveTimer(IN := FALSE);
    END_IF;
END_IF;

// Not moving
IF NOT MotorUp AND NOT MotorDown THEN
    MoveTimer(IN := FALSE);
END_IF;

uptrig(CLK := StopActive);
IF uptrig.Q THEN
    mem := TRUE;
END_IF;

(* --- Rung 2 : StopActive AND NOT B5 resets mem and sets mem1 --- *)
IF StopActive AND NOT B5 THEN
    mem := FALSE;
    mem1 := TRUE;
END_IF;

(* --- Rung 3 : mem drives Q3 --- *)
Q3 := mem;

(* --- Rung 4 : StopActive AND mem1 start TON, NC B6 enables Q4 --- *)
dortime(
    IN := StopActive AND mem1,
    PT := T#5S
);

(* B6 is normally-closed in the ladder -> use NOT B6 *)
Q4 := dortime.Q AND (NOT B6);

(* --- Rung 5 : Falling edge of Q4 resets StopActive and mem1 --- *)
fall(CLK := Q4);
IF fall.Q THEN
    StopActive := FALSE;
    mem1 := FALSE;
    ReqUp[CurrentFloor]    := FALSE;
    UpCall[CurrentFloor]   := FALSE;
    ReqDown[CurrentFloor]  := FALSE;
    DownCall[CurrentFloor] := FALSE;
    ReqCabin[CurrentFloor] := FALSE;
    CabinCall[CurrentFloor]:= FALSE;
END_IF;

IF reset THEN
    ReqUp[CurrentFloor]    := FALSE;
    UpCall[CurrentFloor]   := FALSE;
    ReqDown[CurrentFloor]  := FALSE;
    DownCall[CurrentFloor] := FALSE;
    ReqCabin[CurrentFloor] := FALSE;
    CabinCall[CurrentFloor]:= FALSE;
END_IF