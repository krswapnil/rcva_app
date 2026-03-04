import '../models/issue_model.dart';

/// MASTER ISSUE SEED (ENGINEERING + ENFORCEMENT)
/// - Titles are in report/table style for easy search
/// - Recommendations are max 2–3 concise actions (1 code-ref + practical actions)
final List<IssueModel> issuesSeed = [

  // =====================================================
  // ENGINEERING ISSUES – MASTER TABLE
  // =====================================================

  // -------------------------
  // Crash Barrier
  // -------------------------

  IssueModel(
    id: '',
    title: 'Absent crash barrier',
    recommendation:
        'Installation of crash barrier as per IRC:119-2015 and IRC:SP:84-2019. '
        'Prioritise high-speed sections, steep slopes and run-off-road risk locations.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Damaged crash barrier',
    recommendation:
        'Repair or replacement of crash barrier as per IRC:119-2015. '
        'Replace bent posts/rails and restore anchorage to ensure continuity and strength.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Gap in crash barrier',
    recommendation:
        'Provision of continuous crash barrier without gaps as per IRC:119-2015. '
        'Close all discontinuities near hazards, structures and embankments.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Improper termination of crash barrier',
    recommendation:
        'Provision of proper crash barrier terminals as per IRC:119-2015. '
        'Avoid blunt ends facing traffic; use approved end treatments.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Improper height of crash barrier',
    recommendation:
        'Correction of crash barrier height as per IRC:119-2015. '
        'Reset posts/rails to standard height to ensure effective vehicle redirection.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Improper placement of crash barrier',
    recommendation:
        'Reinstallation of crash barrier at correct offset and location as per IRC:119-2015. '
        'Ensure barrier placement shields the hazard and maintains required working width.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Improper length of crash barrier',
    recommendation:
        'Extension of crash barrier length as per IRC:119-2015. '
        'Ensure adequate length-of-need to fully protect the hazard zone.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Improper transition of crash barrier',
    recommendation:
        'Provision of smooth transition of crash barrier as per IRC:119-2015. '
        'Provide proper transition between barrier types/near structures to avoid snagging.',
    category: 'ENGINEERING',
  ),

  // -------------------------
  // Roadside Objects, Vegetation & Visibility
  // -------------------------

  IssueModel(
    id: '',
    title: 'Large tree within clear zone',
    recommendation:
        'Removal or relocation of roadside trees from clear zone as per IRC:SP:84-2019. '
        'Where removal is not feasible, provide shielding using crash barrier and hazard markers.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Vegetation obstructing visibility',
    recommendation:
        'Trimming/removal of vegetation to restore sight distance as per IRC:SP:84-2019. '
        'Implement periodic vegetation maintenance to prevent re-obstruction.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Vision obstruction at curve or access',
    recommendation:
        'Removal of visual obstructions to ensure adequate sight distance as per IRC:SP:84-2019. '
        'Maintain clear sight triangles at curves, intersections and access points.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Hoardings obstructing visibility',
    recommendation:
        'Removal or relocation of hoardings from sight triangle as per IRC:SP:84-2019. '
        'Restrict new hoardings within visibility zones through local authority coordination.',
    category: 'ENGINEERING',
  ),

  // -------------------------
  // Traffic Signage
  // -------------------------

  IssueModel(
    id: '',
    title: 'Absent traffic signage',
    recommendation:
        'Installation of appropriate traffic signage as per IRC:67-2022. '
        'Ensure correct placement, visibility and retro-reflectivity at approach locations.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Damaged traffic signage',
    recommendation:
        'Replacement of damaged traffic signage as per IRC:67-2022. '
        'Remove broken/bent signs immediately and restore correct mounting height and angle.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Incorrect traffic signage',
    recommendation:
        'Correction and relocation of traffic signage as per IRC:67-2022. '
        'Audit sign type, size and placement so it matches road geometry and speed environment.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Traffic signage covered by vegetation',
    recommendation:
        'Clearing vegetation and restoring visibility of signage as per IRC:67-2022. '
        'Implement periodic trimming and add maintenance responsibility tagging.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent curve warning signage',
    recommendation:
        'Installation of curve warning signage and chevron boards as per IRC:67-2022. '
        'Provide additional guidance with delineators/road studs on sharp curves.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent speed limit signage',
    recommendation:
        'Installation of speed limit signage as per IRC:67-2022. '
        'Repeat speed limit signs after major junctions and at regular intervals in built-up zones.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent pedestrian crossing signage',
    recommendation:
        'Installation of pedestrian crossing signage as per IRC:67-2022. '
        'Place signs in advance of crossings and ensure night visibility through reflectivity/lighting.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent bus stop signage',
    recommendation:
        'Installation of bus stop signage as per IRC:67-2022. '
        'Mark bus stop area clearly and avoid stopping in live carriageway.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent intersection signage',
    recommendation:
        'Installation of advance intersection warning signage as per IRC:67-2022. '
        'Supplement with lane direction signs/markings where turning volumes are high.',
    category: 'ENGINEERING',
  ),

  // -------------------------
  // Road Markings & Delineation
  // -------------------------

  IssueModel(
    id: '',
    title: 'Absent lane marking',
    recommendation:
        'Provision of thermoplastic lane markings as per IRC:35-2015. '
        'Prioritise approaches to junctions, crossings, curves and built-up sections.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Faded lane/edge line marking',
    recommendation:
        'Repainting of lane and edge line markings as per IRC:35-2015. '
        'Use durable, reflective marking materials for night-time guidance.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent dashed line at entry/exit',
    recommendation:
        'Provision of dashed lane markings at entry/exit as per IRC:35-2015. '
        'Ensure proper taper and guidance to reduce sudden weaving.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Speed hump not highlighted',
    recommendation:
        'Provision of speed hump markings and warning signage as per IRC:99-2018 and IRC:67-2022. '
        'Ensure adequate advance visibility and night retro-reflectivity.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent road delineation',
    recommendation:
        'Provision of road studs and delineators as per IRC:79-2019. '
        'Install along curves, median edges and at conflict locations for night guidance.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Faded road delineation',
    recommendation:
        'Replacement of retro-reflective delineators as per IRC:79-2019. '
        'Conduct periodic night inspections and replace missing/damaged units.',
    category: 'ENGINEERING',
  ),

  // -------------------------
  // Traffic Calming
  // -------------------------

  IssueModel(
    id: '',
    title: 'Absent rumble strips',
    recommendation:
        'Provision of rumble strips with advance warning signage as per IRC:99-2018. '
        'Use rumble strips at built-up entry, crossings and junction approaches.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Faded rumble strips',
    recommendation:
        'Repainting and refurbishment of rumble strips as per IRC:99-2018. '
        'Restore visibility and maintain effective spacing/height.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent traffic calming measures',
    recommendation:
        'Provision of traffic calming measures as per IRC:99-2018. '
        'Combine with signage and markings to ensure driver compliance.',
    category: 'ENGINEERING',
  ),

  // -------------------------
  // Pavement, Shoulder & Drainage
  // -------------------------

  IssueModel(
    id: '',
    title: 'Potholes on carriageway',
    recommendation:
        'Repair of potholes and pavement distress as per IRC:SP:83-2018. '
        'Implement routine inspection and preventive maintenance to avoid recurrence.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Cracked or deteriorated pavement',
    recommendation:
        'Resurfacing and pavement strengthening as per IRC:SP:83-2018. '
        'Address underlying drainage/subgrade issues where distress repeats.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Edge drop at shoulder',
    recommendation:
        'Correction of shoulder edge drop as per IRC:SP:84-2019. '
        'Provide sealed shoulders and safe recovery area for errant vehicles.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Water pooling due to poor drainage',
    recommendation:
        'Improvement of roadside drainage as per IRC:SP:50. '
        'Clean and restore drain slopes/outlets to prevent repeated waterlogging.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Sand/debris on roadway',
    recommendation:
        'Removal of sand/debris and regular maintenance as per IRC:SP:84-2019. '
        'Improve housekeeping and prevent material spill/shoulder erosion.',
    category: 'ENGINEERING',
  ),

  // -------------------------
  // Intersections, Median & Access
  // -------------------------

  IssueModel(
    id: '',
    title: 'Untreated intersection',
    recommendation:
        'Provision of channelisation, signage and markings as per IRC:SP:84-2019. '
        'Improve conflict management using proper islands, stop control and lighting where needed.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Broken or damaged median',
    recommendation:
        'Repair and restoration of median as per IRC:SP:84-2019. '
        'Ensure median continuity and protect openings with delineation/markings.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Unsafe median opening',
    recommendation:
        'Closure or proper treatment of median opening as per IRC:SP:84-2019. '
        'Provide approach markings, warning signs and speed management on both approaches.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Improper access to highway',
    recommendation:
        'Provision of controlled access and deceleration lanes as per IRC:SP:84-2019. '
        'Restrict unsafe direct accesses and provide proper entry/exit geometry and signage.',
    category: 'ENGINEERING',
  ),

  // -------------------------
  // Pedestrian & Bus Stop Infrastructure
  // -------------------------

  IssueModel(
    id: '',
    title: 'Absent pedestrian infrastructure',
    recommendation:
        'Provision of footpaths, crossings and guardrails as per IRC:103-2022. '
        'Ensure pedestrian continuity near bus stops, junctions and built-up areas.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent pedestrian crossing',
    recommendation:
        'Provision of zebra crossing as per IRC:35-2015. '
        'Locate crossings at desire lines and add signs/lighting where pedestrian volumes are high.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent pedestrian guardrails',
    recommendation:
        'Installation of pedestrian guardrails as per IRC:103-2022. '
        'Use guardrails to channelise pedestrians to safe crossings and prevent sudden entry.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent bus stop',
    recommendation:
        'Provision of designated bus stop bays as per IRC:80-2022. '
        'Provide signage and pedestrian access so buses do not stop on the live carriageway.',
    category: 'ENGINEERING',
  ),


  // =====================================================
  // ENFORCEMENT ISSUES – RESTORED + IMPROVED (11)
  // =====================================================

  IssueModel(
    id: '',
    title: 'Helmet / seatbelt non-compliance',
    recommendation:
        'Strengthen enforcement against non-helmeted two-wheeler riders as per Section 194D of the Motor Vehicles Act, 1988. '
        'Strengthen enforcement against non-usage of seat belts by drivers and passengers as per Section 194B of the Motor Vehicles Act, 1988.',
    category: 'ENFORCEMENT',
  ),

  IssueModel(
    id: '',
    title: 'Wrong side driving',
    recommendation:
        'Strengthen enforcement against wrong-side driving as per Section 184 of the Motor Vehicles Act, 1988. '
        'Conduct targeted enforcement drives at identified wrong-side hotspots and junction approaches.',
    category: 'ENFORCEMENT',
  ),

  IssueModel(
    id: '',
    title: 'Overspeeding',
    recommendation:
        'Strengthen enforcement against overspeeding as per Section 183 of the Motor Vehicles Act, 1988. '
        'Deploy speed guns/interceptors and speed cameras at crash-prone and built-up sections.',
    category: 'ENFORCEMENT',
  ),

  IssueModel(
    id: '',
    title: 'Unauthorised roadside parking',
    recommendation:
        'Strengthen enforcement against obstruction and unsafe parking as per Section 122 r/w Section 177 of the Motor Vehicles Act, 1988. '
        'Tow/relocate parked vehicles from carriageway/shoulders at critical locations and apply penalties.',
    category: 'ENFORCEMENT',
  ),

  IssueModel(
    id: '',
    title: 'Unauthorised boarding/alighting',
    recommendation:
        'Strengthen enforcement against unauthorised stopping for boarding/alighting as per Section 201 of the Motor Vehicles Act, 1988. '
        'Conduct targeted enforcement near bus stops, markets and high pedestrian activity locations.',
    category: 'ENFORCEMENT',
  ),

  IssueModel(
    id: '',
    title: 'Roadside encroachment / vendor activity',
    recommendation:
        'Penalise encroachers for obstruction of traffic flow under Section 201 of the Motor Vehicles Act, 1988. '
        'Coordinate with local authorities for removal/relocation of vendors outside the clear zone and sustained control.',
    category: 'ENFORCEMENT',
  ),

  IssueModel(
    id: '',
    title: 'Absent/Inadequate retro-reflective tape on goods/commercial vehicles',
    recommendation:
        'Strengthen enforcement against goods/commercial vehicles without proper retro-reflective tapes under Section 190(2) of the Motor Vehicles Act, 1988. '
        'Conduct night-time checks at tolls, check posts and high-risk corridors.',
    category: 'ENFORCEMENT',
  ),

  IssueModel(
    id: '',
    title: 'Drunk driving',
    recommendation:
        'Strengthen enforcement through breath analyser checks and penal action as per Section 185 of the Motor Vehicles Act, 1988. '
        'Conduct targeted night enforcement at identified high-risk corridors and around entertainment zones.',
    category: 'ENFORCEMENT',
  ),

  IssueModel(
    id: '',
    title: 'Rash / dangerous driving & lane indiscipline',
    recommendation:
        'Strengthen enforcement against dangerous/rash driving as per Section 184 of the Motor Vehicles Act, 1988. '
        'Carry out visible policing and targeted enforcement drives at crash-prone locations.',
    category: 'ENFORCEMENT',
  ),

  IssueModel(
    id: '',
    title: 'Overloading of goods vehicles',
    recommendation:
        'Strengthen enforcement against overloading as per Section 194A of the Motor Vehicles Act, 1988. '
        'Conduct axle-load / overload checks at toll plazas and designated enforcement points.',
    category: 'ENFORCEMENT',
  ),

  IssueModel(
    id: '',
    title: 'Use of mobile phone while driving',
    recommendation:
        'Strengthen enforcement against distracted driving under Section 184 of the Motor Vehicles Act, 1988. '
        'Use camera-based evidence collection and targeted enforcement drives in high-risk corridors.',
    category: 'ENFORCEMENT',
  ),
];
