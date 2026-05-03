/**
 * MassagePaw_ROS2_Bridge — SysMLv2 ↔ ROS2 Binding
 *
 * Formalises the mapping between SysMLv2 model elements and their
 * ROS2 runtime counterparts (topics, nodes, services, parameters).
 *
 * Notation: OMG SysMLv2 beta-2 textual syntax.
 * metadata def + @ annotations are the SysMLv2 v2 stereotype mechanism.
 */

package MassagePaw_ROS2_Bridge {

    import MassagePaw::*;
    import MassagePaw::Parts::*;
    import MassagePaw::Ports::*;
    import MassagePaw::Requirements::*;
    import MassagePaw::System::*;
    import ScalarValues::*;

    // ═══════════════════════════════════════════════════════════════════════
    // 1. METADATA DEFINITIONS  (metadata def)
    //    SysMLv2 v2 stereotype mechanism: metadata def + @ application.
    // ═══════════════════════════════════════════════════════════════════════

    /** Marks a part def as realised by a ROS2 node at runtime. */
    metadata def ROS2Node {
        attribute packageName : String;
        attribute executable  : String;
        attribute nodeName    : String;
        attribute namespace   : String;
    }

    /** Binds a port def flow to a ROS2 topic. */
    metadata def ROS2Topic {
        attribute topicName  : String;
        attribute msgType    : String;
        attribute qosProfile : String;   // "reliable" | "best_effort" | "sensor_data"
        attribute publishHz  : Real;
    }

    /** Binds a port def (request/reply) to a ROS2 service. */
    metadata def ROS2Service {
        attribute serviceName : String;
        attribute srvType     : String;
    }

    /** Binds a requirement attribute to a ROS2 parameter path. */
    metadata def ROS2Param {
        attribute paramPath    : String;
        attribute defaultValue : String;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 2. PART → NODE BINDINGS
    // ═══════════════════════════════════════════════════════════════════════

    @ROS2Node {
        packageName = "massage_paw";
        executable  = "robot_hand_node";
        nodeName    = "robot_hand";
        namespace   = "/";
    }
    part def ROS2_RobotHand :> RobotHand {}

    @ROS2Node {
        packageName = "massage_paw";
        executable  = "operator_station_node";
        nodeName    = "operator_station";
        namespace   = "/";
    }
    part def ROS2_OperatorStation :> OperatorStation {}

    @ROS2Node {
        packageName = "massage_paw";
        executable  = "safety_module_node";
        nodeName    = "safety_module";
        namespace   = "/";
    }
    part def ROS2_SafetyModule :> SafetyModule {}

    // ═══════════════════════════════════════════════════════════════════════
    // 3. PORT → TOPIC BINDINGS
    //    Each annotation targets the port def whose flows map to a topic.
    // ═══════════════════════════════════════════════════════════════════════

    /** TeleOpCommandPort.poseCommand  →  /teleop/command (raw from operator) */
    @ROS2Topic {
        topicName  = "/teleop/command";
        msgType    = "massage_paw/msg/CommandPacket";
        qosProfile = "reliable";
        publishHz  = 200.0;        // 200 Hz satisfies REQ-001 latency budget
    }
    port def ROS2_TeleOpCommandPort :> TeleOpCommandPort {}

    /** Safety-gated command after force clamping  →  /teleop/command_safe */
    @ROS2Topic {
        topicName  = "/teleop/command_safe";
        msgType    = "massage_paw/msg/CommandPacket";
        qosProfile = "reliable";
        publishHz  = 200.0;
    }
    port def ROS2_TeleOpCommandSafePort :> TeleOpCommandPort {}

    /** TeleOpCommandPort.systemStatus  →  /robot_hand/status */
    @ROS2Topic {
        topicName  = "/robot_hand/status";
        msgType    = "massage_paw/msg/StatusPacket";
        qosProfile = "reliable";
        publishHz  = 100.0;
    }
    port def ROS2_HandStatusPort :> TeleOpCommandPort {}

    /** HapticFeedbackPort.forceReading — embedded in StatusPacket.palm_pressure */
    @ROS2Topic {
        topicName  = "/robot_hand/status";
        msgType    = "massage_paw/msg/StatusPacket";
        qosProfile = "reliable";
        publishHz  = 100.0;
    }
    port def ROS2_HapticReturnPort :> HapticFeedbackPort {}

    /** MechanicalJointPort.actualAngle  →  /robot_hand/joint_states (for RViz/Gazebo) */
    @ROS2Topic {
        topicName  = "/robot_hand/joint_states";
        msgType    = "sensor_msgs/msg/JointState";
        qosProfile = "sensor_data";
        publishHz  = 200.0;
    }
    port def ROS2_JointStatePort :> MechanicalJointPort {}

    // ═══════════════════════════════════════════════════════════════════════
    // 4. PORT → SERVICE BINDING
    //    SafetyPort drives FSM mode transitions via ROS2 service.
    // ═══════════════════════════════════════════════════════════════════════

    /** SafetyPort.emergencyStop  →  /robot_hand/set_mode service */
    @ROS2Service {
        serviceName = "/robot_hand/set_mode";
        srvType     = "massage_paw/srv/SetMode";
    }
    port def ROS2_ModeTransitionPort :> SafetyPort {}

    // ═══════════════════════════════════════════════════════════════════════
    // 5. REQUIREMENT → PARAMETER BINDINGS
    // ═══════════════════════════════════════════════════════════════════════

    @ROS2Param { paramPath = "robot_hand.max_contact_force_n";  defaultValue = "5.0"; }
    requirement def ROS2_REQ002 :> MaxContactForce {}

    @ROS2Param { paramPath = "robot_hand.watchdog_timeout_ms";  defaultValue = "100.0"; }
    requirement def ROS2_REQ005 :> WatchdogTimeout {}

    @ROS2Param { paramPath = "robot_hand.control_loop_hz";      defaultValue = "1000"; }
    requirement def ROS2_REQ003 :> PositionResolution {}

    @ROS2Param { paramPath = "operator_station.command_rate_hz"; defaultValue = "200"; }
    requirement def ROS2_REQ001 :> TeleOpLatency {}

    @ROS2Param { paramPath = "robot_hand.tactile_sample_rate_hz"; defaultValue = "500"; }
    requirement def ROS2_REQ004 :> TactileSampleRate {}

    // ═══════════════════════════════════════════════════════════════════════
    // 6. SYSTEM BINDING  — redefine sub-parts to their ROS2-annotated types
    // ═══════════════════════════════════════════════════════════════════════

    part massagePawSim : HeadMassageTeleOpSystem {
        part :>> robotHand : ROS2_RobotHand;
        part :>> opStation : ROS2_OperatorStation;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 7. ROS2 TOPIC GRAPH — documented as analysis def
    // ═══════════════════════════════════════════════════════════════════════

    analysis def ROS2TopicGraph {
        subject sim : massagePawSim;
        doc /*
            ROS2 node / topic graph for the MassagePaw stack:

            [operator_station_node]
              publishes  /teleop/command            (CommandPacket, 200 Hz)
              subscribes /robot_hand/status          (StatusPacket, 100 Hz)
              calls      /robot_hand/set_mode        (SetMode srv)

            [safety_module_node]
              subscribes /teleop/command             (raw)
              publishes  /teleop/command_safe        (force-clamped, 200 Hz)
              subscribes /robot_hand/status
              calls      /robot_hand/set_mode        (ESTOP)

            [robot_hand_node]
              subscribes /teleop/command_safe
              publishes  /robot_hand/status          (100 Hz)
              publishes  /robot_hand/joint_states    (JointState, 200 Hz)
              serves     /robot_hand/set_mode

            [robot_state_publisher]  (standard ROS2)
              subscribes /robot_hand/joint_states
              publishes  /tf  /tf_static

            [rviz2]
              subscribes /tf  /robot_hand/joint_states

            [gazebo / gz_ros2_control]
              bridges    /robot_hand/joint_states ↔ physics sim
        */
    }

}
