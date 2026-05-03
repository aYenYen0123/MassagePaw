# Maps to SysMLv2: DataStructures::CommandPacket
std_msgs/Header          header
int32                    sequence_num
massage_paw/OperatorPose pose
int32                    technique       # see MassageTechnique enum constants below
float64                  force_scale     # 0.0–1.0 safety multiplier

# MassageTechnique enum (mirrors SysMLv2 Enumerations::MassageTechnique)
int32 EFFLEURAGE  = 0
int32 PETRISSAGE  = 1
int32 TAPOTEMENT  = 2
int32 FRICTION    = 3
int32 VIBRATION   = 4
int32 SCALP_PRESS = 5
