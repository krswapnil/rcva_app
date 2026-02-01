import '../models/issue_model.dart';

/// Master issue seed:
/// - category: ENGINEERING / ENFORCEMENT
/// You can add/edit/disable issues from the app later.
final List<IssueModel> issuesSeed = [
  // =========================
  // ENGINEERING
  // =========================
  IssueModel(
    id: '',
    title: 'Absent Crash Barrier',
    recommendation: 'Provide crash barriers at critical sections as per IRC 119:2018.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent Delineation',
    recommendation:
        'Provide retro-reflective road studs for at least 100 m on either side of critical locations (intersection/zebra/median opening) as per IRC 79:2019.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent Illumination',
    recommendation:
        'Provide street lighting at built-up areas/intersections/critical locations as per IRC SP 73:2018 and IS 1944:2003.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent Pavement Marking',
    recommendation: 'Provide road markings (centre line, edge line, stop line, zebra, arrows etc.) as per IRC 35:2015.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Absent Pedestrian Infrastructure',
    recommendation: 'Provide pedestrian infrastructure such as footpaths, guardrails, and safe crossings as per IRC 103:2012.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Damaged Pavement Surface',
    recommendation: 'Repair damaged pavement surface through patchwork/maintenance as per relevant specifications.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Improper Median Opening',
    recommendation: 'Close unauthorized median opening and provide standard median opening with proper channelization as per IRC guidelines.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Inadequate Signage',
    recommendation: 'Install adequate regulatory/warning/informatory signage as per IRC 67:2012 and IRC 79:2019.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Roadside Encroachment',
    recommendation: 'Relocate vendors/encroachments outside the clear zone and ensure the road is kept obstruction-free.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Unauthorized Parking',
    recommendation: 'Restrict parking at critical locations, provide designated parking spaces, and implement measures to prevent roadside parking.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Unauthorized Boarding And Deboarding',
    recommendation: 'Designate safe bus stops/boarding areas away from the carriageway and provide guardrails/signage as needed.',
    category: 'ENGINEERING',
  ),
  IssueModel(
    id: '',
    title: 'Untreated Intersection',
    recommendation: 'Provide proper intersection treatment with channelization, markings, signs, studs and illumination as per IRC guidelines.',
    category: 'ENGINEERING',
  ),

  // =========================
  // ENFORCEMENT (from your uploaded CSV)
  // =========================
  IssueModel(
    id: '',
    title: 'Poor helmet and seatbelt compliance',
    recommendation:
        '• Strengthen enforcement against non-helmeted two-wheeler riders as per Section 194D of the MVA, 1988.\n'
        '• Strengthen enforcement against non-usage of seat belts by drivers and passengers in cars and commercial vehicles under Section 194B of the MVA, 1988.',
    category: 'ENFORCEMENT',
  ),
  IssueModel(
    id: '',
    title: 'Wrong side driving',
    recommendation:
        '• Strengthen enforcement measures against drivers involved in wrong side driving as per Section 184 of the MVA, 1988.\n'
        '• Issue challan to offenders.\n'
        '• Impound driving licence under Section 206.\n'
        '• Forward cases for prosecution.\n'
        '• Create a special prosecution cell for dangerous driving offences.\n'
        '• Implement electronic evidence collection system.',
    category: 'ENFORCEMENT',
  ),
  IssueModel(
    id: '',
    title: 'Overspeeding',
    recommendation:
        '• Strengthen enforcement measures against overspeeding as per Section 183 of the MVA, 1988.\n'
        '• Use interceptors or speed cameras at crash-prone zones.',
    category: 'ENFORCEMENT',
  ),
  IssueModel(
    id: '',
    title: 'Unauthorised roadside parking',
    recommendation:
        '• Strengthen enforcement measures against drivers parking vehicles on highways in a way that blocks or slows traffic as per Section 177A r/w Section 122 of the MVA, 1988.\n'
        '• Issue challans to violators.\n'
        '• Create special prosecution cell for dangerous driving offences.\n'
        '• Implement electronic evidence collection system.',
    category: 'ENFORCEMENT',
  ),
  IssueModel(
    id: '',
    title: 'Unauthorised boarding/deboarding of passengers',
    recommendation:
        '• Strengthen enforcement by issuing challans to drivers involved in unauthorised stopping and parking as per Section 201 of the MVA, 1988.',
    category: 'ENFORCEMENT',
  ),
  IssueModel(
    id: '',
    title: 'Roadside encroachment causing vision obstruction',
    recommendation:
        '• Relocate vendors to a safe place outside the clear zone of the road.\n'
        '• Penalise encroachers for obstructing traffic flow under Section 201 of the MVA, 1988.\n'
        '• Formulate rules under Section 138(1A) of the MVA for pedestrian safety and encroachment removal.',
    category: 'ENFORCEMENT',
  ),
  IssueModel(
    id: '',
    title: 'Absent/Inadequate retro-reflective tape on goods/commercial vehicles',
    recommendation:
        '• Strengthen enforcement against commercial and goods vehicles without proper retro-reflective tapes under Section 190(2) of the MVA, 1988.',
    category: 'ENFORCEMENT',
  ),
  IssueModel(
    id: '',
    title: 'Drunk and driving',
    recommendation:
        '• Strengthen enforcement under Section 185 of the MVA, 1988.\n'
        '• Impose a penalty of ₹10,000 or 6 months imprisonment for the first offence.\n'
        '• Impose a penalty of ₹15,000 or 2 years imprisonment for subsequent offences if blood alcohol level exceeds 30 mg/100 ml.',
    category: 'ENFORCEMENT',
  ),
];
