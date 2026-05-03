# Maps to SysMLv2: DataStructures::StatusPacket
std_msgs/Header        header
int32                  sequence_num
massage_paw/HandState  hand_state
int32                  mode            # see OperationMode enum constants below
float64                battery_pct
string[]               alerts

# OperationMode enum (mirrors SysMLv2 Enumerations::OperationMode)
int32 IDLE           = 0
int32 CALIBRATING    = 1
int32 TELEOP_ACTIVE  = 2
int32 SAFETY_HOLD    = 3
int32 EMERGENCY_STOP = 4
