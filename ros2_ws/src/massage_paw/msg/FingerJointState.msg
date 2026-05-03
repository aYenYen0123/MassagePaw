# Maps to SysMLv2: DataStructures::FingerJointState
std_msgs/Header header
int32   finger_id       # 0=thumb 1=index 2=middle 3=ring 4=pinky
int32   joint_index     # 0=MCP/CMC 1=PIP/MCP 2=DIP/IP 3=abduct(thumb)
float64 angle_deg
float64 velocity_deg_s
float64 torque_nm
