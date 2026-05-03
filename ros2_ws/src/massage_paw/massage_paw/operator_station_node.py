"""
OperatorStationNode — simulates the operator glove workstation
(SysMLv2: Parts::OperatorStation).

Topics published:
  /teleop/command          CommandPacket

Topics subscribed:
  /robot_hand/status       StatusPacket   → drives haptic feedback display

The node reads operator pose from /operator/pose (geometry_msgs/PoseStamped)
published by a glove driver or a keyboard/joystick demo publisher.
"""

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
from geometry_msgs.msg import PoseStamped
import math

from massage_paw.msg import CommandPacket, OperatorPose, StatusPacket

COMMAND_RATE_HZ = 200   # REQ-001: 200 Hz command stream keeps latency budget


class OperatorStationNode(Node):

    def __init__(self):
        super().__init__("operator_station_node")

        qos = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            history=HistoryPolicy.KEEP_LAST,
            depth=10,
        )

        # Parameters — can be overridden via ros2 param set
        self.declare_parameter("force_scale",  0.6)
        self.declare_parameter("technique",    0)   # EFFLEURAGE default
        self.declare_parameter("grip_force_n", 1.5)

        self._seq = 0

        # Operator pose (from glove driver or keyboard demo)
        self._latest_pose: PoseStamped | None = None
        self._pose_sub = self.create_subscription(
            PoseStamped, "/operator/pose", self._on_pose, qos
        )

        # Status feedback from robot
        self._status_sub = self.create_subscription(
            StatusPacket, "/robot_hand/status", self._on_status, qos
        )

        self._cmd_pub = self.create_publisher(CommandPacket, "/teleop/command", qos)

        self.create_timer(1.0 / COMMAND_RATE_HZ, self._publish_command)

        self.get_logger().info("OperatorStationNode started — publishing at 200 Hz")

    def _on_pose(self, msg: PoseStamped):
        self._latest_pose = msg

    def _on_status(self, msg: StatusPacket):
        if msg.alerts:
            for alert in msg.alerts:
                self.get_logger().warn(f"[Robot alert] {alert}")
        if msg.mode == 3:  # SAFETY_HOLD
            self.get_logger().warn("Robot entered SAFETY_HOLD — reduce force and acknowledge")
        if msg.mode == 4:  # EMERGENCY_STOP
            self.get_logger().error("Robot EMERGENCY_STOP — cease teleoperation")

    def _publish_command(self):
        self._seq += 1
        force_scale  = self.get_parameter("force_scale").value
        technique    = self.get_parameter("technique").value
        grip_force   = self.get_parameter("grip_force_n").value

        pose = OperatorPose()
        if self._latest_pose is not None:
            p = self._latest_pose.pose.position
            q = self._latest_pose.pose.orientation
            pose.hand_position_mm.x = p.x * 1000.0  # m → mm
            pose.hand_position_mm.y = p.y * 1000.0
            pose.hand_position_mm.z = p.z * 1000.0
            pose.hand_orientation   = q
        else:
            # Neutral/rest pose — straight fingers, relaxed
            pass

        # Simulate gentle sinusoidal finger curl for demo (effleurage stroke)
        t = self.get_clock().now().nanoseconds * 1e-9
        curl = 15.0 * math.sin(2 * math.pi * 0.5 * t)   # ±15° at 0.5 Hz
        pose.finger_angles_deg = [curl] * 19
        pose.grip_force_n      = grip_force

        cmd = CommandPacket()
        cmd.header.stamp = self.get_clock().now().to_msg()
        cmd.sequence_num = self._seq
        cmd.pose         = pose
        cmd.technique    = technique
        cmd.force_scale  = force_scale
        self._cmd_pub.publish(cmd)


def main(args=None):
    rclpy.init(args=args)
    node = OperatorStationNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()
