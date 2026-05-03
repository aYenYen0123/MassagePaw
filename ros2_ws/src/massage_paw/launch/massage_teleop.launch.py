"""
Launch file: full teleoperation stack + Gazebo simulation.

Nodes started:
  robot_hand_node         — simulates robot hand FSM and joint control
  operator_station_node   — simulates operator glove command stream
  safety_module_node      — independent force/watchdog safety gate
  robot_state_publisher   — publishes TF from URDF joint states
  rviz2                   — visualisation (optional, set viz:=false to skip)
  gazebo_sim              — Gazebo Ignition world (optional, set sim:=false to skip)
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription, GroupAction
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():

    pkg_massage   = FindPackageShare("massage_paw")
    pkg_sim       = FindPackageShare("massage_paw_sim")

    # ── Arguments ─────────────────────────────────────────────────────────────
    viz_arg = DeclareLaunchArgument("viz", default_value="true",
                                    description="Launch RViz2 visualiser")
    sim_arg = DeclareLaunchArgument("sim", default_value="true",
                                    description="Launch Gazebo Ignition simulator")
    params_arg = DeclareLaunchArgument(
        "params_file",
        default_value=PathJoinSubstitution([pkg_massage, "config", "hand_params.yaml"]),
        description="Path to parameter YAML file",
    )

    viz    = LaunchConfiguration("viz")
    sim    = LaunchConfiguration("sim")
    params = LaunchConfiguration("params_file")

    # ── Core nodes ────────────────────────────────────────────────────────────
    robot_hand_node = Node(
        package="massage_paw",
        executable="robot_hand_node",
        name="robot_hand",
        parameters=[params],
        output="screen",
        emulate_tty=True,
    )

    operator_node = Node(
        package="massage_paw",
        executable="operator_station_node",
        name="operator_station",
        parameters=[params],
        output="screen",
        emulate_tty=True,
    )

    safety_node = Node(
        package="massage_paw",
        executable="safety_module_node",
        name="safety_module",
        parameters=[params],
        output="screen",
        emulate_tty=True,
    )

    # ── Robot state publisher (TF from URDF) ──────────────────────────────────
    robot_state_publisher = Node(
        package="robot_state_publisher",
        executable="robot_state_publisher",
        name="robot_state_publisher",
        parameters=[{
            "robot_description": PathJoinSubstitution(
                [pkg_sim, "urdf", "robot_hand.urdf.xacro"]
            ),
        }],
        remappings=[("joint_states", "/robot_hand/joint_states")],
    )

    # ── RViz2 (optional) ──────────────────────────────────────────────────────
    rviz_node = Node(
        package="rviz2",
        executable="rviz2",
        name="rviz2",
        arguments=["-d", PathJoinSubstitution([pkg_massage, "config", "massage_paw.rviz"])],
        condition=IfCondition(viz),
    )

    # ── Gazebo Ignition (optional) ────────────────────────────────────────────
    gazebo_launch = IncludeLaunchDescription(
        PathJoinSubstitution([pkg_sim, "launch", "gazebo.launch.py"]),
        condition=IfCondition(sim),
    )

    return LaunchDescription([
        viz_arg,
        sim_arg,
        params_arg,
        robot_state_publisher,
        robot_hand_node,
        operator_node,
        safety_node,
        rviz_node,
        gazebo_launch,
    ])
