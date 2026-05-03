# Maps to SysMLv2: DataStructures::OperatorPose
std_msgs/Header header
geometry_msgs/Point    hand_position_mm    # x,y,z in millimetres
geometry_msgs/Quaternion hand_orientation  # w,x,y,z
float64[19]            finger_angles_deg
float64                grip_force_n
