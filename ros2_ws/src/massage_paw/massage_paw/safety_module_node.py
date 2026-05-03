"""
SafetyModuleNode — independent watchdog and force limiter
(SysMLv2: Parts::SafetyModule, Requirements REQ-002, REQ-005).

Subscribes to /robot_hand/status and /teleop/command.
Republishes a gated /teleop/command_safe with force_scale clamped.
Triggers /robot_hand/set_mode → EMERGENCY_STOP when limits are violated.
"""

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy

from massage_paw.msg import CommandPacket, StatusPacket
from massage_paw.srv import SetMode

MAX_FORCE_N       = 5.0    # REQ-002
WATCHDOG_MS       = 100.0  # REQ-005
MAX_FORCE_SCALE   = 1.0


class SafetyModuleNode(Node):

    def __init__(self):
        super().__init__("safety_module_node")

        qos = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            history=HistoryPolicy.KEEP_LAST,
            depth=10,
        )

        self._last_status_time = self.get_clock().now()
        self._robot_mode       = 0  # IDLE

        # Subscribe to raw command and robot status
        self._raw_cmd_sub = self.create_subscription(
            CommandPacket, "/teleop/command", self._on_raw_command, qos
        )
        self._status_sub = self.create_subscription(
            StatusPacket, "/robot_hand/status", self._on_status, qos
        )

        # Publish gated safe command
        self._safe_cmd_pub = self.create_publisher(
            CommandPacket, "/teleop/command_safe", qos
        )

        # Service client to command mode changes
        self._mode_client = self.create_client(SetMode, "/robot_hand/set_mode")

        # Watchdog timer — checks at 2× watchdog period
        self.create_timer(WATCHDOG_MS / 2000.0, self._watchdog_tick)

        self.get_logger().info("SafetyModuleNode active — monitoring force and watchdog")

    def _on_raw_command(self, msg: CommandPacket):
        # Clamp force_scale so resultant grip force stays within REQ-002
        if msg.pose.grip_force_n * msg.force_scale > MAX_FORCE_N:
            safe_scale = MAX_FORCE_N / max(msg.pose.grip_force_n, 0.001)
            self.get_logger().warn(
                f"Force clamped: {msg.pose.grip_force_n * msg.force_scale:.2f} N → {MAX_FORCE_N} N"
            )
            msg.force_scale = min(safe_scale, MAX_FORCE_SCALE)

        self._safe_cmd_pub.publish(msg)

    def _on_status(self, msg: StatusPacket):
        self._last_status_time = self.get_clock().now()
        self._robot_mode       = msg.mode

    def _watchdog_tick(self):
        if self._robot_mode not in (2,):  # only watch in TELEOP_ACTIVE
            return
        elapsed_ms = (
            (self.get_clock().now() - self._last_status_time).nanoseconds / 1e6
        )
        if elapsed_ms > WATCHDOG_MS:
            self.get_logger().error(
                f"[SafetyModule] No status for {elapsed_ms:.0f} ms — requesting EMERGENCY_STOP"
            )
            self._request_estop()

    def _request_estop(self):
        if not self._mode_client.service_is_ready():
            self.get_logger().error("set_mode service unavailable — cannot send ESTOP")
            return
        req = SetMode.Request()
        req.target_mode = 4  # EMERGENCY_STOP
        self._mode_client.call_async(req)


def main(args=None):
    rclpy.init(args=args)
    node = SafetyModuleNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()
