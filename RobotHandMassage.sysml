/**
 * SysMLv2 Model: Dexterous Robot Hand for Teleoperated Head Massage
 *
 * Use Case: A human operator remotely controls a dexterous robotic hand
 * to perform therapeutic head massage on a recipient. The system supports
 * low-latency teleoperation with haptic feedback and force-limited safety.
 */

// ─────────────────────────────────────────────────────────────────────────────
// PACKAGE STRUCTURE
// ─────────────────────────────────────────────────────────────────────────────

package MassagePaw {

    // ── Value Types ──────────────────────────────────────────────────────────

    package Values {

        attribute def Force       { attribute value : Real; attribute unit = "N"; }
        attribute def Torque      { attribute value : Real; attribute unit = "Nm"; }
        attribute def Angle       { attribute value : Real; attribute unit = "deg"; }
        attribute def AngularVel  { attribute value : Real; attribute unit = "deg/s"; }
        attribute def Pressure    { attribute value : Real; attribute unit = "kPa"; }
        attribute def Latency     { attribute value : Real; attribute unit = "ms"; }
        attribute def Frequency   { attribute value : Real; attribute unit = "Hz"; }
        attribute def Mass        { attribute value : Real; attribute unit = "kg"; }
        attribute def Temperature { attribute value : Real; attribute unit = "degC"; }
        attribute def Voltage     { attribute value : Real; attribute unit = "V"; }

    }

    // ── Enumerations ─────────────────────────────────────────────────────────

    package Enumerations {

        enum def OperationMode {
            enum IDLE;
            enum CALIBRATING;
            enum TELEOP_ACTIVE;
            enum SAFETY_HOLD;
            enum EMERGENCY_STOP;
        }

        enum def MassageTechnique {
            enum EFFLEURAGE;      // long gliding strokes
            enum PETRISSAGE;      // kneading
            enum TAPOTEMENT;      // rhythmic tapping
            enum FRICTION;        // deep circular pressure
            enum VIBRATION;       // fine oscillatory movement
            enum SCALP_PRESS;     // static point pressure
        }

        enum def FeedbackType {
            enum FORCE_HAPTIC;
            enum VIBROTACTILE;
            enum VISUAL;
            enum AUDIO_CUE;
        }

        enum def NetworkState {
            enum CONNECTED;
            enum DEGRADED;
            enum DISCONNECTED;
        }

    }

    // ── Interfaces ───────────────────────────────────────────────────────────

    package Interfaces {

        interface def MechanicalJointIF {
            in  flow commandAngle  : Values::Angle;
            out flow actualAngle   : Values::Angle;
            out flow jointTorque   : Values::Torque;
        }

        interface def HapticFeedbackIF {
            out flow forceReading  : Values::Force;
            out flow pressureMap   : Values::Pressure;
        }

        interface def TeleOpCommandIF {
            in  flow poseCommand   : OperatorPose;
            out flow systemStatus  : SystemStatus;
            out flow hapticReturn  : Values::Force;
        }

        interface def NetworkIF {
            attribute maxLatency    : Values::Latency { :>> value = 20.0; }
            attribute minBandwidth  : Values::Frequency { :>> value = 1000.0; }
            in  flow txData : CommandPacket;
            out flow rxData : StatusPacket;
        }

        interface def SafetyIF {
            out flow forceLimit    : Values::Force;
            out flow emergencyStop : Boolean;
        }

    }

    // ── Data Structures ──────────────────────────────────────────────────────

    package DataStructures {

        item def FingerJointState {
            attribute fingerID     : Integer;
            attribute jointIndex   : Integer;
            attribute angle        : Values::Angle;
            attribute velocity     : Values::AngularVel;
            attribute torque       : Values::Torque;
        }

        item def HandState {
            attribute timestamp    : Real;
            attribute joints       : FingerJointState[15];  // 5 fingers × 3 joints
            attribute thumbJoints  : FingerJointState[4];   // thumb has extra CMC joint
            attribute palmPressure : Values::Pressure[16];  // 4×4 tactile array
        }

        item def OperatorPose {
            attribute handPosition : Real[3];    // x, y, z in mm
            attribute handOrient   : Real[4];    // quaternion w, x, y, z
            attribute fingerAngles : Values::Angle[19];
            attribute gripForce    : Values::Force;
        }

        item def CommandPacket {
            attribute sequenceNum  : Integer;
            attribute timestamp    : Real;
            attribute pose         : OperatorPose;
            attribute technique    : Enumerations::MassageTechnique;
            attribute forceScale   : Real;        // 0.0–1.0 safety scale factor
        }

        item def StatusPacket {
            attribute sequenceNum  : Integer;
            attribute timestamp    : Real;
            attribute handState    : HandState;
            attribute mode         : Enumerations::OperationMode;
            attribute alerts       : String[*];
        }

        item def SystemStatus {
            attribute mode         : Enumerations::OperationMode;
            attribute networkState : Enumerations::NetworkState;
            attribute batteryLevel : Real;        // 0–100 %
            attribute alerts       : String[*];
        }

    }

    // ─────────────────────────────────────────────────────────────────────────
    // PART DEFINITIONS
    // ─────────────────────────────────────────────────────────────────────────

    package Parts {

        // ── Finger Assembly ──────────────────────────────────────────────────

        part def JointActuator {
            attribute peakTorque   : Values::Torque   { :>> value = 1.2; }
            attribute maxAngle     : Values::Angle     { :>> value = 90.0; }
            attribute posResolution: Values::Angle     { :>> value = 0.05; }

            port mechanicalOut     : ~Interfaces::MechanicalJointIF;
        }

        part def TactileSensor {
            attribute resolution   : Integer = 8;      // taxels per cm²
            attribute maxPressure  : Values::Pressure { :>> value = 100.0; }
            attribute sampleRate   : Values::Frequency { :>> value = 500.0; }

            port feedbackOut       : ~Interfaces::HapticFeedbackIF;
        }

        part def Fingertip {
            attribute material     : String = "silicone_gel_shore_20A";
            attribute radius       : Real   = 8.0;     // mm, mimics adult fingertip

            part sensor            : TactileSensor;
        }

        part def FingerLink {
            attribute length       : Real;             // mm
            attribute mass         : Values::Mass;
        }

        part def Finger {
            attribute fingerID     : Integer;
            attribute dofCount     : Integer = 3;

            part proxLink          : FingerLink { :>> length = 45.0; :>> mass.value = 0.018; }
            part midLink           : FingerLink { :>> length = 30.0; :>> mass.value = 0.012; }
            part distLink          : FingerLink { :>> length = 22.0; :>> mass.value = 0.008; }
            part tip               : Fingertip;

            part mcpJoint          : JointActuator;   // metacarpophalangeal
            part pipJoint          : JointActuator;   // proximal interphalangeal
            part dipJoint          : JointActuator;   // distal interphalangeal
        }

        part def Thumb {
            attribute dofCount     : Integer = 4;

            part proxLink          : FingerLink { :>> length = 38.0; :>> mass.value = 0.022; }
            part distLink          : FingerLink { :>> length = 28.0; :>> mass.value = 0.014; }
            part tip               : Fingertip;

            part cmcJoint          : JointActuator;   // carpometacarpal
            part mcpJoint          : JointActuator;
            part ipJoint           : JointActuator;
            part abductJoint       : JointActuator;
        }

        // ── Palm & Wrist ─────────────────────────────────────────────────────

        part def Palm {
            attribute length       : Real = 95.0;     // mm
            attribute width        : Real = 85.0;     // mm
            attribute mass         : Values::Mass { :>> value = 0.12; }

            part tactileArray      : TactileSensor[4]; // 2×2 palm zones
        }

        part def WristAssembly {
            attribute flexionRange : Values::Angle { :>> value = 80.0; }
            attribute pronationRange : Values::Angle { :>> value = 180.0; }

            part flexJoint         : JointActuator;
            part rotJoint          : JointActuator;
        }

        // ── Electronics ──────────────────────────────────────────────────────

        part def MotorController {
            attribute channels     : Integer = 20;    // 19 DoF + 1 wrist
            attribute supplyVolt   : Values::Voltage { :>> value = 24.0; }
            attribute loopRate     : Values::Frequency { :>> value = 1000.0; }
        }

        part def OnboardComputer {
            attribute cpuCores     : Integer = 8;
            attribute ram          : Real    = 8.0;   // GB
            attribute osRealtime   : Boolean = true;

            port safetyPort        : Interfaces::SafetyIF;
        }

        part def NetworkAdapter {
            attribute protocol     : String = "UDP_over_5G_or_WiFi6";
            attribute maxLatency   : Values::Latency { :>> value = 5.0; }

            port netPort           : ~Interfaces::NetworkIF;
        }

        part def ForceTorqueSensor {
            attribute dof          : Integer = 6;
            attribute maxForce     : Values::Force { :>> value = 50.0; }
            attribute maxTorque    : Values::Torque { :>> value = 5.0; }
        }

        part def SafetyModule {
            attribute maxContactForce : Values::Force { :>> value = 5.0; }  // N, scalp safety
            attribute watchdogPeriod  : Values::Latency { :>> value = 100.0; }

            port safetyOut         : Interfaces::SafetyIF;
        }

        // ── Robot Hand (Physical Assembly) ───────────────────────────────────

        part def RobotHand {
            // Kinematic structure
            part wrist             : WristAssembly;
            part palm              : Palm;
            part thumb             : Thumb;
            part indexFinger       : Finger { :>> fingerID = 1; }
            part middleFinger      : Finger { :>> fingerID = 2; }
            part ringFinger        : Finger { :>> fingerID = 3; }
            part pinkyFinger       : Finger { :>> fingerID = 4; }

            // Electronics
            part motorCtrl         : MotorController;
            part computer          : OnboardComputer;
            part netAdapter        : NetworkAdapter;
            part wristFTS          : ForceTorqueSensor;
            part safety            : SafetyModule;

            // Aggregate properties
            attribute totalDOF     : Integer = 20;    // 4 × (3 fingers) + 4 (thumb) + 2 (wrist) + 2 (abduction)
            attribute totalMass    : Values::Mass { :>> value = 0.85; }

            // Internal connections
            connect motorCtrl to computer;
            connect safety.safetyOut to computer.safetyPort;
        }

        // ── Operator Glove (Input Device) ────────────────────────────────────

        part def IMUSensor {
            attribute dof      : Integer = 9;  // accel + gyro + mag
            attribute sampleRate : Values::Frequency { :>> value = 200.0; }
        }

        part def HapticActuator {
            attribute type       : String = "LRA_vibrotactile";
            attribute frequency  : Values::Frequency { :>> value = 200.0; }
            attribute maxForce   : Values::Force { :>> value = 2.0; }
        }

        part def OperatorGlove {
            attribute fingerSensors  : IMUSensor[5];
            attribute palmIMU        : IMUSensor;
            attribute hapticArray    : HapticActuator[10];  // 2 per finger
            attribute wristIMU       : IMUSensor;

            port commandOut          : Interfaces::TeleOpCommandIF;
        }

        // ── Operator Workstation ─────────────────────────────────────────────

        part def Display {
            attribute type         : String = "stereo_3D_or_VR_headset";
            attribute refreshRate  : Values::Frequency { :>> value = 90.0; }
        }

        part def AudioFeedback {
            attribute channels     : Integer = 2;
        }

        part def OperatorStation {
            part glove             : OperatorGlove;
            part display           : Display;
            part audio             : AudioFeedback;
            part netAdapter        : NetworkAdapter;

            port commandOut        : Interfaces::TeleOpCommandIF;
            port netOut            : Interfaces::NetworkIF;
        }

        // ── Communication Link ───────────────────────────────────────────────

        part def TeleOpLink {
            attribute protocol     : String   = "UDP_with_RTP_timestamp";
            attribute encryption   : String   = "AES_256";
            attribute maxLatency   : Values::Latency { :>> value = 20.0; }
            attribute minLatency   : Values::Latency { :>> value = 1.0; }
        }

    }

    // ─────────────────────────────────────────────────────────────────────────
    // TOP-LEVEL SYSTEM
    // ─────────────────────────────────────────────────────────────────────────

    package System {

        part def HeadMassageTeleOpSystem {

            part robotHand   : Parts::RobotHand;
            part opStation   : Parts::OperatorStation;
            part commsLink   : Parts::TeleOpLink;

            // Command flow: operator → network → hand
            connect opStation.commandOut to robotHand.computer.safetyPort;

            // Network connections
            connect opStation.netOut to robotHand.netAdapter.netPort;

        }

    }

    // ─────────────────────────────────────────────────────────────────────────
    // USE CASES
    // ─────────────────────────────────────────────────────────────────────────

    package UseCases {

        use case def CalibrateSystem {
            subject sys : System::HeadMassageTeleOpSystem;
            actor operator : Person;
            objective : "Establish joint zero positions and verify haptic feedback loop before contact.";
        }

        use case def PerformHeadMassage {
            subject sys : System::HeadMassageTeleOpSystem;
            actor operator : Person;
            actor recipient : Person;
            objective : "Operator wears glove and guides the robot hand through massage strokes on recipient's scalp.";

            include use case CalibrateSystem;
        }

        use case def EmergencyStop {
            subject sys : System::HeadMassageTeleOpSystem;
            actor operator : Person;
            objective : "Operator or watchdog triggers immediate halt and hand retraction from contact.";
        }

        use case def ForceLimitViolation {
            subject sys : System::HeadMassageTeleOpSystem;
            objective : "Safety module detects contact force exceeding threshold and overrides command input.";

            include use case EmergencyStop;
        }

    }

    // ─────────────────────────────────────────────────────────────────────────
    // REQUIREMENTS
    // ─────────────────────────────────────────────────────────────────────────

    package Requirements {

        requirement def <'REQ-001'> TeleOpLatency {
            doc /* End-to-end command latency from glove to robot joint shall be ≤ 20 ms
                   under normal network conditions to maintain perceptual transparency. */
            subject link : Parts::TeleOpLink;
            require constraint { link.maxLatency.value <= 20.0 }
        }

        requirement def <'REQ-002'> MaxContactForce {
            doc /* Maximum allowable normal force at any fingertip contact with scalp
                   shall not exceed 5 N to prevent discomfort or injury. */
            subject safety : Parts::SafetyModule;
            require constraint { safety.maxContactForce.value <= 5.0 }
        }

        requirement def <'REQ-003'> PositionResolution {
            doc /* Each finger joint actuator shall achieve angular position resolution
                   of ≤ 0.1° to enable fine massage stroke control. */
            subject joint : Parts::JointActuator;
            require constraint { joint.posResolution.value <= 0.1 }
        }

        requirement def <'REQ-004'> TactileSampleRate {
            doc /* Tactile sensors shall sample at ≥ 200 Hz to provide real-time
                   pressure feedback to the operator's haptic glove. */
            subject sensor : Parts::TactileSensor;
            require constraint { sensor.sampleRate.value >= 200.0 }
        }

        requirement def <'REQ-005'> WatchdogTimeout {
            doc /* Safety watchdog shall trigger an emergency stop if no valid
                   command packet is received within 100 ms. */
            subject safety : Parts::SafetyModule;
            require constraint { safety.watchdogPeriod.value <= 100.0 }
        }

        requirement def <'REQ-006'> TotalHandMass {
            doc /* Total robot hand assembly mass shall not exceed 1.0 kg
                   to minimise inertia during contact transitions. */
            subject hand : Parts::RobotHand;
            require constraint { hand.totalMass.value <= 1.0 }
        }

        requirement def <'REQ-007'> DOFCount {
            doc /* The robot hand shall provide at least 19 independently
                   actuated degrees of freedom to replicate human hand dexterity. */
            subject hand : Parts::RobotHand;
            require constraint { hand.totalDOF >= 19 }
        }

        requirement def <'REQ-008'> EncryptedComms {
            doc /* All teleoperation data shall be encrypted in transit using
                   AES-256 or stronger to protect operator and recipient privacy. */
            subject link : Parts::TeleOpLink;
            require constraint { link.encryption == "AES_256" }
        }

    }

    // ─────────────────────────────────────────────────────────────────────────
    // STATE MACHINE — Robot Hand Operation
    // ─────────────────────────────────────────────────────────────────────────

    package StateMachines {

        state def RobotHandFSM {

            entry action powerOn   { /* initialise actuators, zero encoders */ }

            state idle : Enumerations::OperationMode::IDLE {
                entry action holdPosition { /* maintain last commanded pose */ }
                transition to calibrating on received(CalibrateCmd);
            }

            state calibrating : Enumerations::OperationMode::CALIBRATING {
                entry action runCalibration { /* drive joints to hard stops, record offsets */ }
                transition to teleopActive  on CalibrationComplete;
                transition to idle          on CalibrationFailed;
            }

            state teleopActive : Enumerations::OperationMode::TELEOP_ACTIVE {
                entry action enableControl { /* open control loop, arm watchdog */ }
                do    action executeCommand {
                    /* 1. Receive CommandPacket from network adapter
                       2. Apply safety scale factor
                       3. IK solve → joint angle targets
                       4. PID position control at 1 kHz
                       5. Stream HandState back to operator */
                }
                transition to safetyHold on ForceThresholdExceeded;
                transition to emergencyStop on WatchdogTimeout or EStopSignal;
                transition to idle on DisconnectCmd;
            }

            state safetyHold : Enumerations::OperationMode::SAFETY_HOLD {
                entry action freezeMotion { /* hold position, alert operator */ }
                transition to teleopActive on OperatorAcknowledge;
                transition to emergencyStop on EStopSignal;
            }

            state emergencyStop : Enumerations::OperationMode::EMERGENCY_STOP {
                entry action retractHand { /* move to safe park pose, cut motor torque */ }
                transition to idle on SystemReset;
            }

        }

    }

    // ─────────────────────────────────────────────────────────────────────────
    // ANALYSIS — Safety & Performance Constraints
    // ─────────────────────────────────────────────────────────────────────────

    package Analysis {

        analysis def LatencyBudget {
            doc /* Round-trip latency budget (ms):
                   Glove IMU → host USB:         2
                   Pose computation:             1
                   Network (5G / WiFi6, LAN):   10
                   Network jitter buffer:         3
                   Robot IK solve:               1
                   Motor command dispatch:        1
                   Tactile → haptic return:       5
                   ─────────────────────────────
                   Total budget:                23 ms   (target ≤ 20 ms via LAN path)
            */
        }

        analysis def ForceSafetyMargin {
            doc /* Scalp tissue tolerance: ~8–12 N sustained, ~20 N peak.
                   System force limit: 5 N (REQ-002).
                   Safety margin: ×1.6–2.4 — adequate for therapeutic massage.
                   Force sensor resolution: 0.05 N — sufficient for closed-loop control.
            */
        }

        analysis def KinematicWorkspace {
            doc /* Robot finger workspace is sized to match adult-hand anthropometry
                   (ISO 15743 hand measurement standards).
                   Fingertip radius 8 mm mimics median adult fingertip.
                   Wrist ±80° flexion/extension and ±90° pronation/supination
                   cover all scalp surface approaches from a single mount point.
            */
        }

    }

}
