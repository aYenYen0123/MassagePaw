/**
 * SysMLv2 Bridge Extension — MassagePaw ↔ ROS2
 *
 * Formalises the mapping between SysMLv2 model elements and their
 * ROS2 runtime counterparts (topics, nodes, services, parameters).
 *
 * This file extends MassagePaw (RobotHandMassage.sysml) with
 * ROS2Binding stereotypes so the model can drive code generation
 * and simulation verification.
 */

package MassagePaw_ROS2_Bridge {

    import MassagePaw::*;

    // ── Stereotype definitions ────────────────────────────────────────────────

    /** Marks a SysMLv2 part as realised by a ROS2 node. */
    metadata def ROS2Node {
        attribute packageName  : String;
        attribute executable   : String;
        attribute nodeName     : String;
        attribute namespace    : String;
    }

    /** Binds a SysMLv2 interface flow to a ROS2 topic. */
    metadata def ROS2Topic {
        attribute topicName    : String;
        attribute msgType      : String;
        attribute qosProfile   : String;  // "reliable" | "best_effort" | "sensor_data"
        attribute publishHz    : Real;
    }

    /** Binds a SysMLv2 interface flow to a ROS2 service. */
    metadata def ROS2Service {
        attribute serviceName  : String;
        attribute srvType      : String;
    }

    /** Binds a SysMLv2 requirement attribute to a ROS2 parameter. */
    metadata def ROS2Param {
        attribute paramPath    : String;   // e.g. "robot_hand.max_contact_force_n"
        attribute defaultValue : String;
    }

    // ── Part → Node mappings ──────────────────────────────────────────────────

    @ROS2Node {
        packageName = "massage_paw";
        executable  = "robot_hand_node";
        nodeName    = "robot_hand";
        namespace   = "/";
    }
    part def ROS2_RobotHand :> Parts::RobotHand {}

    @ROS2Node {
        packageName = "massage_paw";
        executable  = "operator_station_node";
        nodeName    = "operator_station";
        namespace   = "/";
    }
    part def ROS2_OperatorStation :> Parts::OperatorStation {}

    @ROS2Node {
        packageName = "massage_paw";
        executable  = "safety_module_node";
        nodeName    = "safety_module";
        namespace   = "/";
    }
    part def ROS2_SafetyModule :> Parts::SafetyModule {}

    // ── Interface → Topic / Service mappings ─────────────────────────────────

    /**
     * Operator command stream:
     *   SysMLv2: TeleOpCommandIF.poseCommand  →  /teleop/command (raw)
     *                                          →  /teleop/command_safe (after safety gate)
     */
    @ROS2Topic {
        topicName  = "/teleop/command";
        msgType    = "massage_paw/msg/CommandPacket";
        qosProfile = "reliable";
        publishHz  = 200.0;   // satisfies REQ-001 latency budget
    }
    interface def TeleOpCommand_Binding :> Interfaces::TeleOpCommandIF {}

    @ROS2Topic {
        topicName  = "/teleop/command_safe";
        msgType    = "massage_paw/msg/CommandPacket";
        qosProfile = "reliable";
        publishHz  = 200.0;
    }
    interface def TeleOpCommandSafe_Binding :> Interfaces::TeleOpCommandIF {}

    /**
     * Robot hand status:
     *   SysMLv2: TeleOpCommandIF.systemStatus  →  /robot_hand/status
     */
    @ROS2Topic {
        topicName  = "/robot_hand/status";
        msgType    = "massage_paw/msg/StatusPacket";
        qosProfile = "reliable";
        publishHz  = 100.0;
    }
    interface def HandStatus_Binding :> Interfaces::TeleOpCommandIF {}

    /**
     * Haptic feedback return:
     *   SysMLv2: HapticFeedbackIF.forceReading  →  embedded in StatusPacket.hand_state.palm_pressure
     */
    @ROS2Topic {
        topicName  = "/robot_hand/status";    // reuses StatusPacket (palm_pressure field)
        msgType    = "massage_paw/msg/StatusPacket";
        qosProfile = "reliable";
        publishHz  = 100.0;
    }
    interface def HapticReturn_Binding :> Interfaces::HapticFeedbackIF {}

    /**
     * Joint states for RViz / Gazebo:
     *   SysMLv2: MechanicalJointIF.actualAngle → /robot_hand/joint_states
     */
    @ROS2Topic {
        topicName  = "/robot_hand/joint_states";
        msgType    = "sensor_msgs/msg/JointState";
        qosProfile = "sensor_data";
        publishHz  = 200.0;
    }
    interface def JointState_Binding :> Interfaces::MechanicalJointIF {}

    /**
     * Mode transition:
     *   SysMLv2: RobotHandFSM trigger  →  /robot_hand/set_mode service
     */
    @ROS2Service {
        serviceName = "/robot_hand/set_mode";
        srvType     = "massage_paw/srv/SetMode";
    }
    interface def ModeTransition_Binding :> Interfaces::SafetyIF {}

    // ── Requirement → Parameter mappings ─────────────────────────────────────

    @ROS2Param { paramPath = "robot_hand.max_contact_force_n"; defaultValue = "5.0"; }
    requirement def REQ002_Param :> Requirements::MaxContactForce {}

    @ROS2Param { paramPath = "robot_hand.watchdog_timeout_ms";  defaultValue = "100.0"; }
    requirement def REQ005_Param :> Requirements::WatchdogTimeout {}

    @ROS2Param { paramPath = "robot_hand.control_loop_hz";      defaultValue = "1000"; }
    requirement def REQ003_Param :> Requirements::PositionResolution {}

    @ROS2Param { paramPath = "operator_station.command_rate_hz"; defaultValue = "200"; }
    requirement def REQ001_Param :> Requirements::TeleOpLatency {}

    // ── Full system binding ───────────────────────────────────────────────────

    part massagePawSim : System::HeadMassageTeleOpSystem {
        part :>> robotHand  : ROS2_RobotHand;
        part :>> opStation  : ROS2_OperatorStation;
    }

    // ── ROS2 topic graph (documented as analysis) ─────────────────────────────

    analysis def ROS2TopicGraph {
        doc /*
            Node graph for the MassagePaw teleoperation stack:

            ┌─────────────────────┐         ┌──────────────────────┐
            │  operator_station   │──────── ▶│    safety_module      │
            │  /teleop/command    │  200 Hz  │  /teleop/command_safe │
            └─────────────────────┘         └──────────┬───────────┘
                                                        │ 200 Hz
                                                        ▼
                                            ┌──────────────────────┐
                                            │    robot_hand         │
                                            │  /teleop/command_safe │
                                            │                       │
                                            │  publishes:           │
                                            │  /robot_hand/status   │──▶ operator_station
                                            │  /robot_hand/joint_states ─▶ robot_state_pub
                                            └──────────────────────┘
                                                        │
                                                        ▼ /robot_hand/set_mode (srv)
                                            ┌──────────────────────┐
                                            │   safety_module       │
                                            │   (watchdog/ESTOP)    │
                                            └──────────────────────┘

            External (sim only):
              robot_state_publisher  → /tf, /tf_static  (from joint_states + URDF)
              rviz2                  ← /tf, /robot_hand/joint_states
              gazebo                 ↔ gz_ros2_control bridge
        */
    }

}
