/**
 * MassagePaw — SysMLv2 Model
 * Dexterous Robot Hand for Teleoperated Head Massage
 *
 * Notation: OMG SysMLv2 beta-2 textual syntax (2023).
 * Tooling target: SysMLv2 Pilot Implementation / Jupyter kernel.
 */

package MassagePaw {

    private import ScalarValues::*;

    // ═══════════════════════════════════════════════════════════════════════
    // 1. VALUE TYPES  (attribute def)
    // ═══════════════════════════════════════════════════════════════════════

    package Values {
        attribute def Force       { attribute value : Real; attribute unit : String = "N"; }
        attribute def Torque      { attribute value : Real; attribute unit : String = "Nm"; }
        attribute def Angle       { attribute value : Real; attribute unit : String = "deg"; }
        attribute def AngularVel  { attribute value : Real; attribute unit : String = "deg/s"; }
        attribute def Pressure    { attribute value : Real; attribute unit : String = "kPa"; }
        attribute def Latency     { attribute value : Real; attribute unit : String = "ms"; }
        attribute def Frequency   { attribute value : Real; attribute unit : String = "Hz"; }
        attribute def Mass        { attribute value : Real; attribute unit : String = "kg"; }
        attribute def Voltage     { attribute value : Real; attribute unit : String = "V"; }
        attribute def Length      { attribute value : Real; attribute unit : String = "mm"; }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 2. ENUMERATIONS  (enum def)
    // ═══════════════════════════════════════════════════════════════════════

    package Enumerations {

        enum def OperationMode {
            enum IDLE;
            enum CALIBRATING;
            enum TELEOP_ACTIVE;
            enum SAFETY_HOLD;
            enum EMERGENCY_STOP;
        }

        enum def MassageTechnique {
            enum EFFLEURAGE;    // long gliding strokes
            enum PETRISSAGE;    // kneading
            enum TAPOTEMENT;    // rhythmic tapping
            enum FRICTION;      // deep circular pressure
            enum VIBRATION;     // fine oscillatory movement
            enum SCALP_PRESS;   // static point pressure
        }

        enum def NetworkState {
            enum CONNECTED;
            enum DEGRADED;
            enum DISCONNECTED;
        }

        enum def FeedbackType {
            enum FORCE_HAPTIC;
            enum VIBROTACTILE;
            enum VISUAL;
            enum AUDIO_CUE;
        }

    }

    // ═══════════════════════════════════════════════════════════════════════
    // 3. PORT DEFINITIONS  (port def)
    //    SysMLv2: port def replaces SysMLv1 interface/flow-port definitions.
    //    ~PortDef denotes the conjugate (provider side).
    // ═══════════════════════════════════════════════════════════════════════

    package Ports {

        port def MechanicalJointPort {
            in  flow commandAngle : Values::Angle;
            out flow actualAngle  : Values::Angle;
            out flow jointTorque  : Values::Torque;
        }

        port def HapticFeedbackPort {
            out flow forceReading : Values::Force;
            out flow pressureMap  : Values::Pressure;
        }

        port def TeleOpCommandPort {
            in  flow poseCommand  : Items::OperatorPose;
            out flow systemStatus : Items::SystemStatus;
            out flow hapticReturn : Values::Force;
        }

        port def NetworkPort {
            attribute maxLatency   : Values::Latency  { :>> value = 20.0; }
            attribute minBandwidth : Values::Frequency { :>> value = 1000.0; }
            in  flow txData : Items::CommandPacket;
            out flow rxData : Items::StatusPacket;
        }

        port def SafetyPort {
            out flow forceLimit    : Values::Force;
            out flow emergencyStop : Boolean;
        }

    }

    // ═══════════════════════════════════════════════════════════════════════
    // 4. ITEM DEFINITIONS  (item def)
    //    Items represent data / matter flowing through the system.
    // ═══════════════════════════════════════════════════════════════════════

    package Items {

        item def FingerJointState {
            attribute fingerID   : Integer;
            attribute jointIndex : Integer;
            attribute angle      : Values::Angle;
            attribute velocity   : Values::AngularVel;
            attribute torque     : Values::Torque;
        }

        item def HandState {
            attribute timestamp   : Real;
            item joints           : FingerJointState[19];   // 4×thumb + 3×4 fingers
            attribute palmPressure : Values::Pressure[16];  // 4×4 tactile array
        }

        item def OperatorPose {
            attribute posX         : Values::Length;    // hand position
            attribute posY         : Values::Length;
            attribute posZ         : Values::Length;
            attribute orientW      : Real;              // quaternion
            attribute orientX      : Real;
            attribute orientY      : Real;
            attribute orientZ      : Real;
            attribute fingerAngles : Values::Angle[19];
            attribute gripForce    : Values::Force;
        }

        item def CommandPacket {
            attribute sequenceNum : Integer;
            attribute timestamp   : Real;
            item      pose        : OperatorPose;
            attribute technique   : Enumerations::MassageTechnique;
            attribute forceScale  : Real;               // 0.0–1.0 safety multiplier
        }

        item def StatusPacket {
            attribute sequenceNum : Integer;
            attribute timestamp   : Real;
            item      handState   : HandState;
            attribute mode        : Enumerations::OperationMode;
            attribute batteryPct  : Real;
            attribute alerts      : String[0..*];
        }

        item def SystemStatus {
            attribute mode         : Enumerations::OperationMode;
            attribute networkState : Enumerations::NetworkState;
            attribute batteryPct   : Real;
            attribute alerts       : String[0..*];
        }

    }

    // ═══════════════════════════════════════════════════════════════════════
    // 5. PART DEFINITIONS  (part def)
    // ═══════════════════════════════════════════════════════════════════════

    package Parts {

        // ── Actuation & Sensing ───────────────────────────────────────────────

        part def JointActuator {
            attribute peakTorque    : Values::Torque   { :>> value = 1.2; }
            attribute maxAngle      : Values::Angle    { :>> value = 90.0; }
            attribute posResolution : Values::Angle    { :>> value = 0.05; }

            port mechanicalOut : ~Ports::MechanicalJointPort;
        }

        part def TactileSensor {
            attribute resolution  : Integer = 8;        // taxels per cm²
            attribute maxPressure : Values::Pressure  { :>> value = 100.0; }
            attribute sampleRate  : Values::Frequency { :>> value = 500.0; }

            port feedbackOut : Ports::HapticFeedbackPort;
        }

        part def Fingertip {
            attribute material : String = "silicone_gel_shore_20A";
            attribute radius   : Values::Length { :>> value = 8.0; }

            part sensor : TactileSensor;
        }

        part def FingerLink {
            attribute length : Values::Length;
            attribute mass   : Values::Mass;
        }

        // ── Finger (3 DoF) ────────────────────────────────────────────────────

        part def Finger {
            attribute fingerID : Integer;

            part proxLink : FingerLink { :>> length.value = 45.0; :>> mass.value = 0.018; }
            part midLink  : FingerLink { :>> length.value = 30.0; :>> mass.value = 0.012; }
            part distLink : FingerLink { :>> length.value = 22.0; :>> mass.value = 0.008; }
            part tip      : Fingertip;

            part mcpJoint : JointActuator;   // metacarpophalangeal
            part pipJoint : JointActuator;   // proximal interphalangeal
            part dipJoint : JointActuator;   // distal interphalangeal
        }

        // ── Thumb (4 DoF) ─────────────────────────────────────────────────────

        part def Thumb {
            part proxLink    : FingerLink { :>> length.value = 38.0; :>> mass.value = 0.022; }
            part distLink    : FingerLink { :>> length.value = 28.0; :>> mass.value = 0.014; }
            part tip         : Fingertip;

            part cmcJoint    : JointActuator;   // carpometacarpal
            part mcpJoint    : JointActuator;
            part ipJoint     : JointActuator;
            part abductJoint : JointActuator;
        }

        // ── Palm & Wrist ──────────────────────────────────────────────────────

        part def Palm {
            attribute length : Values::Length { :>> value = 95.0; }
            attribute width  : Values::Length { :>> value = 85.0; }
            attribute mass   : Values::Mass   { :>> value = 0.12; }

            part tactileArray : TactileSensor[4];
        }

        part def WristAssembly {
            attribute flexionRange   : Values::Angle { :>> value = 80.0; }
            attribute pronationRange : Values::Angle { :>> value = 180.0; }

            part flexJoint : JointActuator;
            part rotJoint  : JointActuator;
        }

        // ── Electronics ───────────────────────────────────────────────────────

        part def MotorController {
            attribute channels   : Integer = 20;
            attribute supplyVolt : Values::Voltage   { :>> value = 24.0; }
            attribute loopRate   : Values::Frequency { :>> value = 1000.0; }
        }

        part def OnboardComputer {
            attribute cpuCores   : Integer = 8;
            attribute ram        : Real    = 8.0;    // GB
            attribute osRealtime : Boolean = true;

            port safetyIn : ~Ports::SafetyPort;
            port netIn    : ~Ports::NetworkPort;
        }

        part def NetworkAdapter {
            attribute protocol   : String = "UDP_over_5G_or_WiFi6";
            attribute maxLatency : Values::Latency { :>> value = 5.0; }

            port netOut : Ports::NetworkPort;
        }

        part def ForceTorqueSensor {
            attribute dof       : Integer = 6;
            attribute maxForce  : Values::Force  { :>> value = 50.0; }
            attribute maxTorque : Values::Torque { :>> value = 5.0; }
        }

        part def SafetyModule {
            attribute maxContactForce : Values::Force   { :>> value = 5.0; }
            attribute watchdogPeriod  : Values::Latency { :>> value = 100.0; }

            port safetyOut : Ports::SafetyPort;
        }

        // ── Robot Hand (physical assembly) ────────────────────────────────────

        part def RobotHand {
            attribute totalDOF  : Integer    = 20;
            attribute totalMass : Values::Mass { :>> value = 0.85; }

            part wrist        : WristAssembly;
            part palm         : Palm;
            part thumb        : Thumb;
            part indexFinger  : Finger { :>> fingerID = 1; }
            part middleFinger : Finger { :>> fingerID = 2; }
            part ringFinger   : Finger { :>> fingerID = 3; }
            part pinkyFinger  : Finger { :>> fingerID = 4; }

            part motorCtrl  : MotorController;
            part computer   : OnboardComputer;
            part netAdapter : NetworkAdapter;
            part wristFTS   : ForceTorqueSensor;
            part safety     : SafetyModule;

            // Bind ports: safety module → computer safety input
            bind safety.safetyOut = computer.safetyIn;
            // Bind ports: network adapter → computer network input
            bind netAdapter.netOut = computer.netIn;
        }

        // ── Operator Side ─────────────────────────────────────────────────────

        part def IMUSensor {
            attribute dof        : Integer = 9;   // accel + gyro + mag
            attribute sampleRate : Values::Frequency { :>> value = 200.0; }
        }

        part def HapticActuator {
            attribute actuatorType : String = "LRA_vibrotactile";
            attribute frequency    : Values::Frequency { :>> value = 200.0; }
            attribute maxForce     : Values::Force     { :>> value = 2.0; }
        }

        part def OperatorGlove {
            part fingerIMU   : IMUSensor[5];
            part palmIMU     : IMUSensor;
            part wristIMU    : IMUSensor;
            part hapticArray : HapticActuator[10];

            port commandOut : Ports::TeleOpCommandPort;
        }

        part def Display {
            attribute displayType : String = "stereo_3D_or_VR_headset";
            attribute refreshRate : Values::Frequency { :>> value = 90.0; }
        }

        part def AudioFeedback {
            attribute channels : Integer = 2;
        }

        part def OperatorStation {
            part glove      : OperatorGlove;
            part display    : Display;
            part audio      : AudioFeedback;
            part netAdapter : NetworkAdapter;

            port commandOut : Ports::TeleOpCommandPort;
            port netOut     : Ports::NetworkPort;
        }

        // ── Communication Link ────────────────────────────────────────────────

        part def TeleOpLink {
            attribute protocol   : String = "UDP_with_RTP_timestamp";
            attribute encryption : String = "AES_256";
            attribute maxLatency : Values::Latency { :>> value = 20.0; }
            attribute minLatency : Values::Latency { :>> value = 1.0; }
        }

    }

    // ═══════════════════════════════════════════════════════════════════════
    // 6. CONNECTION DEFINITIONS  (connection def)
    // ═══════════════════════════════════════════════════════════════════════

    package Connections {

        connection def TeleOpConnection {
            end operator : Parts::OperatorStation[1];
            end robot    : Parts::RobotHand[1];
        }

        connection def NetworkLink {
            end side1 : Parts::NetworkAdapter[1];
            end side2 : Parts::NetworkAdapter[1];
        }

    }

    // ═══════════════════════════════════════════════════════════════════════
    // 7. TOP-LEVEL SYSTEM
    // ═══════════════════════════════════════════════════════════════════════

    package System {

        part def HeadMassageTeleOpSystem {

            part robotHand : Parts::RobotHand;
            part opStation : Parts::OperatorStation;
            part commsLink : Parts::TeleOpLink;

            // Operator → robot command path
            connection teleOpConn : Connections::TeleOpConnection {
                :>> end operator = opStation;
                :>> end robot    = robotHand;
            }

            // Network adapters paired through the comms link
            connection netConn : Connections::NetworkLink {
                :>> end side1 = opStation.netAdapter;
                :>> end side2 = robotHand.netAdapter;
            }

        }

    }

    // ═══════════════════════════════════════════════════════════════════════
    // 8. USE CASES  (use case def)
    // ═══════════════════════════════════════════════════════════════════════

    package UseCases {

        use case def CalibrateSystem {
            subject sys    : System::HeadMassageTeleOpSystem;
            actor operator : Person;
            objective doc /* Establish joint zero positions and verify
                             haptic feedback loop before contact. */
        }

        use case def PerformHeadMassage {
            subject sys      : System::HeadMassageTeleOpSystem;
            actor operator   : Person;
            actor recipient  : Person;
            objective doc /* Operator wears glove and guides the robot hand
                             through massage strokes on recipient's scalp. */

            include use case calibrate : CalibrateSystem;
        }

        use case def EmergencyStop {
            subject sys    : System::HeadMassageTeleOpSystem;
            actor operator : Person;
            objective doc /* Operator or watchdog triggers immediate halt
                             and hand retraction from contact. */
        }

        use case def ForceLimitViolation {
            subject sys : System::HeadMassageTeleOpSystem;
            objective doc /* Safety module detects contact force exceeding
                             threshold and overrides command input. */

            include use case estop : EmergencyStop;
        }

    }

    // ═══════════════════════════════════════════════════════════════════════
    // 9. REQUIREMENTS  (requirement def)
    // ═══════════════════════════════════════════════════════════════════════

    package Requirements {

        requirement def <'REQ-001'> TeleOpLatency {
            doc /* End-to-end command latency from glove to robot joint shall be
                   ≤ 20 ms under normal network conditions. */
            subject link : Parts::TeleOpLink;
            require constraint latencyOk { link.maxLatency.value <= 20.0 }
        }

        requirement def <'REQ-002'> MaxContactForce {
            doc /* Maximum allowable normal force at any fingertip contact with
                   scalp shall not exceed 5 N to prevent discomfort or injury. */
            subject safety : Parts::SafetyModule;
            require constraint forceOk { safety.maxContactForce.value <= 5.0 }
        }

        requirement def <'REQ-003'> PositionResolution {
            doc /* Each finger joint actuator shall achieve angular position
                   resolution of ≤ 0.1° to enable fine massage stroke control. */
            subject joint : Parts::JointActuator;
            require constraint resolutionOk { joint.posResolution.value <= 0.1 }
        }

        requirement def <'REQ-004'> TactileSampleRate {
            doc /* Tactile sensors shall sample at ≥ 200 Hz to provide real-time
                   pressure feedback to the operator's haptic glove. */
            subject sensor : Parts::TactileSensor;
            require constraint sampleOk { sensor.sampleRate.value >= 200.0 }
        }

        requirement def <'REQ-005'> WatchdogTimeout {
            doc /* Safety watchdog shall trigger an emergency stop if no valid
                   command packet is received within 100 ms. */
            subject safety : Parts::SafetyModule;
            require constraint watchdogOk { safety.watchdogPeriod.value <= 100.0 }
        }

        requirement def <'REQ-006'> TotalHandMass {
            doc /* Total robot hand assembly mass shall not exceed 1.0 kg to
                   minimise inertia during contact transitions. */
            subject hand : Parts::RobotHand;
            require constraint massOk { hand.totalMass.value <= 1.0 }
        }

        requirement def <'REQ-007'> DOFCount {
            doc /* The robot hand shall provide at least 19 independently
                   actuated degrees of freedom. */
            subject hand : Parts::RobotHand;
            require constraint dofOk { hand.totalDOF >= 19 }
        }

        requirement def <'REQ-008'> EncryptedComms {
            doc /* All teleoperation data shall be encrypted in transit using
                   AES-256 or stronger to protect operator and recipient privacy. */
            subject link : Parts::TeleOpLink;
            require constraint encryptionOk { link.encryption == "AES_256" }
        }

    }

    // ═══════════════════════════════════════════════════════════════════════
    // 10. VERIFICATION  — satisfy relationships
    // ═══════════════════════════════════════════════════════════════════════

    package Verification {
        satisfy Requirements::TeleOpLatency      by Parts::TeleOpLink::maxLatency;
        satisfy Requirements::MaxContactForce    by Parts::SafetyModule::maxContactForce;
        satisfy Requirements::PositionResolution by Parts::JointActuator::posResolution;
        satisfy Requirements::TactileSampleRate  by Parts::TactileSensor::sampleRate;
        satisfy Requirements::WatchdogTimeout    by Parts::SafetyModule::watchdogPeriod;
        satisfy Requirements::TotalHandMass      by Parts::RobotHand::totalMass;
        satisfy Requirements::DOFCount           by Parts::RobotHand::totalDOF;
        satisfy Requirements::EncryptedComms     by Parts::TeleOpLink::encryption;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 11. ACTION DEFINITIONS  (action def)
    // ═══════════════════════════════════════════════════════════════════════

    package Actions {

        action def HoldPosition {
            in  item currentState   : Items::HandState;
            out item commandedState : Items::HandState;
        }

        action def RunCalibration {
            out attribute success : Boolean;
        }

        action def ExecuteTeleOpCommand {
            in  item command   : Items::CommandPacket;
            out item handState : Items::HandState;

            // Decomposed sub-actions
            action applyForceScale {
                in  attribute rawScale  : Real;
                in  attribute gripForce : Values::Force;
                out attribute safeScale : Real;
            }

            action solveIK {
                in  item pose          : Items::OperatorPose;
                out attribute targets  : Values::Angle[19];
            }

            action runPIDControl {
                in  attribute targets  : Values::Angle[19];
                out attribute actuals  : Values::Angle[19];
                out attribute torques  : Values::Torque[19];
            }

            // Action data flows
            flow from command to applyForceScale.rawScale;
            flow from applyForceScale.safeScale to solveIK.pose;
            flow from solveIK.targets to runPIDControl.targets;
        }

        action def FreezeMotion {
            in  item currentState : Items::HandState;
            out item heldState    : Items::HandState;
        }

        action def RetractHand {
            out item parkState : Items::HandState;
        }

    }

    // ═══════════════════════════════════════════════════════════════════════
    // 12. STATE MACHINE  (state def)
    //     SysMLv2: transitions use  accept <Event> then <targetState>
    //     Initial transition:       entry; then <initialState>
    //     Events are occurrence def
    // ═══════════════════════════════════════════════════════════════════════

    package States {

        // ── Event (occurrence) definitions ────────────────────────────────────
        occurrence def CalibrateCmd;
        occurrence def CalibrationComplete;
        occurrence def CalibrationFailed;
        occurrence def ForceThresholdExceeded;
        occurrence def WatchdogTimeout;
        occurrence def EStopSignal;
        occurrence def DisconnectCmd;
        occurrence def OperatorAcknowledge;
        occurrence def SystemReset;

        // ── Robot Hand FSM ────────────────────────────────────────────────────
        state def RobotHandFSM {

            entry; then idle;

            state idle {
                entry action holdPosition : Actions::HoldPosition;
                accept CalibrateCmd then calibrating;
            }

            state calibrating {
                entry action runCalibration : Actions::RunCalibration;
                accept CalibrationComplete then teleopActive;
                accept CalibrationFailed   then idle;
            }

            state teleopActive {
                entry action enableControl;
                do    action executeCommand : Actions::ExecuteTeleOpCommand;
                accept ForceThresholdExceeded then safetyHold;
                accept WatchdogTimeout        then emergencyStop;
                accept EStopSignal            then emergencyStop;
                accept DisconnectCmd          then idle;
            }

            state safetyHold {
                entry action freezeMotion : Actions::FreezeMotion;
                accept OperatorAcknowledge then teleopActive;
                accept EStopSignal         then emergencyStop;
            }

            state emergencyStop {
                entry action retractHand : Actions::RetractHand;
                accept SystemReset then idle;
            }

        }

    }

    // ═══════════════════════════════════════════════════════════════════════
    // 13. ANALYSIS  (analysis def)
    //     analysis def is a specialisation of action def in SysMLv2.
    // ═══════════════════════════════════════════════════════════════════════

    package Analysis {

        analysis def LatencyBudget {
            subject sys : System::HeadMassageTeleOpSystem;
            return attribute totalMs : Values::Latency;
            doc /* Round-trip latency budget (ms):
                   Glove IMU → host USB ............  2
                   Pose computation ................  1
                   Network (5G / WiFi6 / LAN) .....  10
                   Network jitter buffer ...........  3
                   Robot IK solve ..................  1
                   Motor command dispatch ..........  1
                   Tactile → haptic return .........  5
                   ─────────────────────────────────
                   Total ..........................  23 ms
                   Target (LAN path) ≤ 20 ms  →  REQ-001 satisfied on LAN.
            */
        }

        analysis def ForceSafetyMargin {
            subject safety : Parts::SafetyModule;
            return attribute margin : Real;
            doc /* Scalp tissue tolerance: ~8–12 N sustained, ~20 N peak.
                   System force limit: 5 N (REQ-002).
                   Safety margin: ×1.6–2.4 — adequate for therapeutic massage.
            */
        }

        analysis def KinematicWorkspace {
            subject hand : Parts::RobotHand;
            doc /* Robot finger workspace sized to ISO 15743 adult-hand anthropometry.
                   Fingertip radius 8 mm. Wrist ±80° flex/ext, ±90° pron/supination.
                   Covers full scalp surface approach from a fixed mount point.
            */
        }

    }

}
