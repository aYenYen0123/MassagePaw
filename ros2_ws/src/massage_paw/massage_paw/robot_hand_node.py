"""
RobotHandNode — simulates the physical robot hand (SysMLv2: Parts::RobotHand).

Topics published:
  /robot_hand/status          StatusPacket
  /robot_hand/joint_states    sensor_msgs/JointState   (for RViz / Gazebo)

Topics subscribed:
  /teleop/command             CommandPacket

Services:
  /robot_hand/set_mode        SetMode

The node implements the SysMLv2 RobotHandFSM state machine and enforces
REQ-002 (force ≤ 5 N) and REQ-005 (watchdog ≤ 100 ms).
"""

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
from sensor_msgs.msg import JointState
from std_msgs.msg import Header
import time
import math

from massage_paw.msg import CommandPacket, StatusPacket, HandState, FingerJointState
from massage_paw.srv import SetMode

# ── constants matching SysMLv2 StatusPacket enum ──────────────────────────────
MODE_IDLE          = 0
MODE_CALIBRATING   = 1
MODE_TELEOP_ACTIVE = 2
MODE_SAFETY_HOLD   = 3
MODE_EMERGENCY_STOP = 4

MAX_CONTACT_FORCE_N   = 5.0    # REQ-002
WATCHDOG_TIMEOUT_MS   = 100.0  # REQ-005
CONTROL_LOOP_HZ       = 1000   # REQ-003 (actuator loop rate)
STATUS_PUBLISH_HZ     = 100

# Joint names mirror the URDF (see massage_paw_sim/urdf/robot_hand.urdf.xacro)
JOINT_NAMES = [
    "thumb_cmc", "thumb_mcp", "thumb_ip", "thumb_abduct",
    "index_mcp", "index_pip", "index_dip",
    "middle_mcp", "middle_pip", "middle_dip",
    "ring_mcp",   "ring_pip",   "ring_dip",
    "pinky_mcp",  "pinky_pip",  "pinky_dip",
    "wrist_flex", "wrist_rot",
]


class RobotHandNode(Node):

    def __init__(self):
        super().__init__("robot_hand_node")

        qos = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            history=HistoryPolicy.KEEP_LAST,
            depth=10,
        )

        # State
        self._mode            = MODE_IDLE
        self._joint_angles    = [0.0] * len(JOINT_NAMES)   # degrees
        self._joint_torques   = [0.0] * len(JOINT_NAMES)
        self._palm_pressure   = [0.0] * 16
        self._last_cmd_time   = self.get_clock().now()
        self._seq             = 0

        # Publishers
        self._status_pub = self.create_publisher(StatusPacket, "/robot_hand/status", qos)
        self._js_pub     = self.create_publisher(JointState,   "/robot_hand/joint_states", qos)

        # Subscriber
        self._cmd_sub = self.create_subscription(
            CommandPacket, "/teleop/command", self._on_command, qos
        )

        # Service
        self._mode_srv = self.create_service(SetMode, "/robot_hand/set_mode", self._on_set_mode)

        # Timers
        self.create_timer(1.0 / STATUS_PUBLISH_HZ, self._publish_status)
        self.create_timer(1.0 / 10,                self._watchdog_check)

        self.get_logger().info("RobotHandNode started — mode: IDLE")

    # ── Command handler ───────────────────────────────────────────────────────

    def _on_command(self, msg: CommandPacket):
        if self._mode != MODE_TELEOP_ACTIVE:
            return

        self._last_cmd_time = self.get_clock().now()
        scale = max(0.0, min(1.0, msg.force_scale))

        # Map operator finger angles → joint targets (direct mapping in sim)
        for i, angle in enumerate(msg.pose.finger_angles_deg):
            if i < len(self._joint_angles):
                self._joint_angles[i] = angle

        # Simulate contact force = grip_force * scale
        sim_contact_force = msg.pose.grip_force_n * scale
        if sim_contact_force > MAX_CONTACT_FORCE_N:
            self.get_logger().warn(
                f"Force limit exceeded ({sim_contact_force:.2f} N > {MAX_CONTACT_FORCE_N} N) — SAFETY_HOLD"
            )
            self._mode = MODE_SAFETY_HOLD

        # Simulate palm pressure distribution
        base_p = sim_contact_force * 2.0  # kPa rough approximation
        self._palm_pressure = [base_p + math.sin(i * 0.4) * 0.5 for i in range(16)]

        self._publish_joint_states()

    # ── Watchdog ──────────────────────────────────────────────────────────────

    def _watchdog_check(self):
        if self._mode != MODE_TELEOP_ACTIVE:
            return
        elapsed_ms = (
            (self.get_clock().now() - self._last_cmd_time).nanoseconds / 1e6
        )
        if elapsed_ms > WATCHDOG_TIMEOUT_MS:
            self.get_logger().error(
                f"Watchdog timeout ({elapsed_ms:.0f} ms) — EMERGENCY_STOP"
            )
            self._mode = MODE_EMERGENCY_STOP
            self._joint_angles = [0.0] * len(JOINT_NAMES)  # park pose

    # ── Mode service ──────────────────────────────────────────────────────────

    def _on_set_mode(self, req: SetMode.Request, resp: SetMode.Response):
        target = req.target_mode
        allowed = self._valid_transitions().get(self._mode, [])
        if target in allowed:
            self._mode = target
            resp.success = True
            resp.message = f"Transitioned to mode {target}"
            if target == MODE_CALIBRATING:
                self._run_calibration()
            elif target == MODE_TELEOP_ACTIVE:
                self._last_cmd_time = self.get_clock().now()
        else:
            resp.success = False
            resp.message = f"Transition {self._mode}→{target} not permitted"
        resp.current_mode = self._mode
        return resp

    def _valid_transitions(self):
        # Mirrors SysMLv2 RobotHandFSM
        return {
            MODE_IDLE:           [MODE_CALIBRATING],
            MODE_CALIBRATING:    [MODE_TELEOP_ACTIVE, MODE_IDLE],
            MODE_TELEOP_ACTIVE:  [MODE_SAFETY_HOLD, MODE_EMERGENCY_STOP, MODE_IDLE],
            MODE_SAFETY_HOLD:    [MODE_TELEOP_ACTIVE, MODE_EMERGENCY_STOP],
            MODE_EMERGENCY_STOP: [MODE_IDLE],
        }

    def _run_calibration(self):
        self.get_logger().info("Calibrating — zeroing joint encoders...")
        self._joint_angles = [0.0] * len(JOINT_NAMES)
        # In hardware: drive to hard stops and record offsets; here just complete
        self._mode = MODE_IDLE  # will need explicit activate after calibration

    # ── Publishers ────────────────────────────────────────────────────────────

    def _publish_status(self):
        self._seq += 1
        now = self.get_clock().now().to_msg()

        finger_joints = []
        for i, (name, angle, torque) in enumerate(
            zip(JOINT_NAMES, self._joint_angles, self._joint_torques)
        ):
            fjs = FingerJointState()
            fjs.header.stamp = now
            fjs.finger_id    = i // 4 if i < 4 else 1 + (i - 4) // 3
            fjs.joint_index  = i % 4 if i < 4 else (i - 4) % 3
            fjs.angle_deg    = float(angle)
            fjs.velocity_deg_s = 0.0
            fjs.torque_nm    = float(torque)
            finger_joints.append(fjs)

        hs = HandState()
        hs.header.stamp   = now
        hs.joints         = finger_joints
        hs.palm_pressure  = self._palm_pressure

        sp = StatusPacket()
        sp.header.stamp  = now
        sp.sequence_num  = self._seq
        sp.hand_state    = hs
        sp.mode          = self._mode
        sp.battery_pct   = 95.0
        sp.alerts        = []
        self._status_pub.publish(sp)

    def _publish_joint_states(self):
        js = JointState()
        js.header.stamp = self.get_clock().now().to_msg()
        js.name         = JOINT_NAMES
        js.position     = [math.radians(a) for a in self._joint_angles]
        js.velocity     = [0.0] * len(JOINT_NAMES)
        js.effort       = self._joint_torques
        self._js_pub.publish(js)


def main(args=None):
    rclpy.init(args=args)
    node = RobotHandNode()
    rclpy.spin(node)
    node.destroy_node()
    rclpy.shutdown()


if __name__ == "__main__":
    main()
