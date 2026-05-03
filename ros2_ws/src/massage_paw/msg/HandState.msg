# Maps to SysMLv2: DataStructures::HandState
std_msgs/Header            header
massage_paw/FingerJointState[] joints       # 19 entries (4×thumb + 3×4 fingers)
float64[]                  palm_pressure   # 16 taxels (4×4 array), kPa
