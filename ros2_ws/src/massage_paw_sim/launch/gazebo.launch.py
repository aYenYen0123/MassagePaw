"""
Gazebo Ignition launch for MassagePaw simulation.
Spawns the head_massage world and the robot hand.
"""

from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription, ExecuteProcess
from launch.substitutions import PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    pkg_sim = FindPackageShare("massage_paw_sim")

    gz_sim = ExecuteProcess(
        cmd=[
            "ign", "gazebo", "--render-engine", "ogre2",
            PathJoinSubstitution([pkg_sim, "worlds", "head_massage.world"]),
        ],
        output="screen",
    )

    return LaunchDescription([gz_sim])
