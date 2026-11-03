class AppStrings {
  // English / Hindi bilingual dictionary
  static bool isHindi = false;

  // General Actions
  static String get save => isHindi ? 'सुरक्षित करें' : 'Save';
  static String get cancel => isHindi ? 'रद्द करें' : 'Cancel';
  static String get close => isHindi ? 'बंद करें' : 'Close';
  static String get retry => isHindi ? 'पुनः प्रयास करें' : 'Retry';
  static String get continueLabel => isHindi ? 'आगे बढ़ें' : 'Continue';

  // Pillar A: Add Shop
  static String get addShopTitle => isHindi ? 'नई दुकान जोड़ें' : 'Add New Shop';
  static String get quickAddSubtitle => isHindi ? 'तुरंत दुकान जोड़ें (20 सेकंड)' : 'Quick-Add Shop (under 20s)';
  static String get shopNameLabel => isHindi ? 'दुकान का नाम' : 'Shop Name';
  static String get shopNameHint => isHindi ? 'उदा. महालक्ष्मी किराना' : 'e.g. Mahalaxmi Kirana';
  static String get ownerNameLabel => isHindi ? 'मालिक का नाम' : 'Owner Name';
  static String get ownerNameHint => isHindi ? 'उदा. सुरेश कुमार' : 'e.g. Suresh Kumar';
  static String get mobileLabel => isHindi ? 'मोबाइल नंबर (10 अंक)' : 'Mobile Number (10 digits)';
  static String get mobileHint => isHindi ? '98290XXXXX' : '98290XXXXX';
  static String get routeLabel => isHindi ? 'बीट / रूट' : 'Beat / Route';
  static String get captureGpsButton => isHindi ? '📍 जीपीएस लोकेशन लें' : '📍 Capture Current Location';
  static String get locationNotCaptured => isHindi ? 'लोकेशन दर्ज नहीं की गई' : 'Location not captured';
  static String locationAccuracy(double m) => isHindi ? 'सटीकता: ±${m.toStringAsFixed(0)} मीटर' : 'Location accuracy: ±${m.toStringAsFixed(0)} m';
  
  // Optional Shop Details
  static String get moreDetails => isHindi ? '+ अन्य विवरण (वैकल्पिक)' : '+ Add More Details (Optional)';
  static String get addressLabel => isHindi ? 'दुकान का पता' : 'Shop Address';
  static String get landmarkLabel => isHindi ? 'लैंडमार्क / पहचान' : 'Landmark';
  static String get pincodeLabel => isHindi ? 'पिन कोड' : 'PIN Code';
  static String get gstinLabel => isHindi ? 'जीएसटी नंबर (GSTIN)' : 'GSTIN';
  static String get saveShopButton => isHindi ? 'दुकान सुरक्षित करें' : 'Save Shop';
  
  // Classification
  static String get classNew => isHindi ? 'नई दुकान' : 'New';
  static String get classA => isHindi ? 'श्रेणी A' : 'Class A';
  static String get classB => isHindi ? 'श्रेणी B' : 'Class B';
  static String get classC => isHindi ? 'श्रेणी C' : 'Class C';
  static String get classD => isHindi ? 'श्रेणी D (नकद)' : 'Class D (Cash Only)';
  static String get cashOnlyWarning => isHindi ? 'यह दुकान केवल नकद/सीओडी पर है।' : 'This shop is cash/COD only.';

  // Duplicate Detection
  static String get duplicateWarningTitle => isHindi ? 'क्या यह वही दुकान है?' : 'Is this the same shop?';
  static String get openExistingShop => isHindi ? 'हाँ, यही दुकान खोलें' : 'Yes, open that shop';
  static String get differentShopConfirm => isHindi ? 'नहीं, यह अलग दुकान है' : 'No, this is a different shop';

  // Sync & Storage Honesty
  static String get savedOnPhone => isHindi ? 'फोन पर सुरक्षित (लोकल)' : 'Saved on this phone';
  static String get waitingToSync => isHindi ? 'सिंक की प्रतीक्षा में' : 'Waiting to sync';
  static String get localOnlyMode => isHindi ? 'लोकल आउटबॉक्स मोड' : 'Local Outbox Mode';
  static String get syncStatusTitle => isHindi ? 'सिंक स्थिति' : 'Sync Status';
  static String get savedOnPhoneOutbox => isHindi ? 'फोन पर सुरक्षित (ऑफलाइन आउटबॉक्स)' : 'Saved on this phone (Offline Outbox)';
  static String get uploadingToCloud => isHindi ? 'क्लाउड पर अपलोड हो रहा है...' : 'Uploading to Cloud...';
  static String get syncedToCloud => isHindi ? 'क्लाउड पर सिंक हो गया' : 'Synced to Cloud';
  static String get syncWorkerNote => isHindi ? 'सिंक वर्कर अभी निष्क्रिय है — सभी ऑर्डर और बदलाव फोन पर पूरी तरह सुरक्षित हैं।' : 'Sync worker inactive — mutations remain safe on phone.';
  static String pendingMutationsCount(int count) => isHindi ? '$count बदलाव कतार में सुरक्षित' : '$count pending mutation(s) safely queued';
  static String get bookedOnDevice => isHindi ? 'डिवाइस पर बुक हुआ' : 'Booked on Device';
  static String get savedInLocalOutbox => isHindi ? 'लोकल आउटबॉक्स में सुरक्षित' : 'Saved in Local Outbox';
  static String get cloudSync => isHindi ? 'क्लाउड सिंक' : 'Cloud Sync';
  static String get pendingUploadCloudflare => isHindi ? 'ऑफिस सर्वर पर अपलोड लंबित' : 'Pending upload to Office Cloud';
  static String get auditTimeline => isHindi ? 'ऑर्डर ऑडिट टाइमलाइन' : 'Order Audit Timeline';

  // Pillar C: Inventory & GRN
  static String get receiveStock => isHindi ? 'स्टॉक आवक (GRN)' : 'Receive Stock (GRN)';
  static String get godownCartons => isHindi ? 'गोदाम पेटियां' : 'Godown Cartons';
  static String get loosePieces => isHindi ? 'खुले पीस' : 'Loose Pieces';
  static String get damagedStock => isHindi ? 'खराब / क्षतिग्रस्त' : 'Damaged / Quarantine';
  static String get invoiceNumber => isHindi ? 'चालान / बिल नंबर' : 'Invoice / GRN No.';
  static String get supplierName => isHindi ? 'सप्लायर / कंपनी' : 'Supplier Name';

  // Pillar B & Units: Sales & Packaging
  static String get salesOrder => isHindi ? 'बिक्री ऑर्डर' : 'Sales Order';
  static String get unitPiece => isHindi ? 'पीस' : 'Piece';
  static String get unitStrip => isHindi ? 'स्ट्रिप / पत्ता' : 'Strip';
  static String get unitBox => isHindi ? 'पेटी / बॉक्स' : 'Box';
  static String get cartDraftSaved => isHindi ? 'कार्ट सुरक्षित (ड्राफ्ट)' : 'Cart draft auto-saved';
  static String get noOrderRecorded => isHindi ? 'बिना ऑर्डर विज़िट दर्ज' : 'No-order visit recorded';
  static String get creditLimitExceeded => isHindi ? 'उधार सीमा समाप्त' : 'Credit limit exceeded';

  // Validation Errors
  static String get shopNameRequired => isHindi ? 'कृपया दुकान का नाम लिखें' : 'Shop name is required';
  static String get ownerNameRequired => isHindi ? 'कृपया मालिक का नाम लिखें' : 'Owner name is required';
  static String get validMobileRequired => isHindi ? 'कृपया 10 अंकों का मान्य मोबाइल नंबर दर्ज करें' : 'Please enter a valid 10-digit mobile number';
}
