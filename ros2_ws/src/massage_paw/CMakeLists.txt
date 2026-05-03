cmake_minimum_required(VERSION 3.8)
project(massage_paw)

find_package(ament_cmake REQUIRED)
find_package(rosidl_default_generators REQUIRED)
find_package(std_msgs REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(sensor_msgs REQUIRED)

# ── Generate ROS2 message and service types ────────────────────────────────
rosidl_generate_interfaces(${PROJECT_NAME}
  "msg/FingerJointState.msg"
  "msg/HandState.msg"
  "msg/OperatorPose.msg"
  "msg/CommandPacket.msg"
  "msg/StatusPacket.msg"
  "srv/SetMode.srv"
  DEPENDENCIES std_msgs geometry_msgs sensor_msgs
)

# ── Install Python nodes ───────────────────────────────────────────────────
find_package(ament_cmake_python REQUIRED)
ament_python_install_package(${PROJECT_NAME})

install(PROGRAMS
  massage_paw/robot_hand_node.py
  massage_paw/operator_station_node.py
  massage_paw/safety_module_node.py
  DESTINATION lib/${PROJECT_NAME}
)

install(DIRECTORY launch config
  DESTINATION share/${PROJECT_NAME}
)

ament_export_dependencies(rosidl_default_runtime)
ament_package()
