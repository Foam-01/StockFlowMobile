// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class L10nTh extends L10n {
  L10nTh([String locale = 'th']) : super(locale);

  @override
  String get appTitle => 'StockFlow';

  @override
  String get retry => 'ลองใหม่';

  @override
  String get tryAgain => 'ลองอีกครั้ง';

  @override
  String get back => 'ย้อนกลับ';

  @override
  String get save => 'บันทึก';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get delete => 'ลบ';

  @override
  String get confirm => 'ยืนยัน';

  @override
  String get add => 'เพิ่ม';

  @override
  String get newLabel => 'สร้างใหม่';

  @override
  String get all => 'ทั้งหมด';

  @override
  String get remove => 'นำออก';

  @override
  String get scan => 'สแกน';

  @override
  String get required => 'จำเป็นต้องกรอก';

  @override
  String get note => 'หมายเหตุ';

  @override
  String get couldNotLoad => 'โหลดข้อมูลไม่สำเร็จ';

  @override
  String get somethingWrong => 'เกิดข้อผิดพลาด';

  @override
  String get cannotReach => 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ตรวจสอบการเชื่อมต่อ';

  @override
  String requestFailed(String code) {
    return 'คำขอล้มเหลว ($code)';
  }

  @override
  String get noResponse => 'ไม่มีการตอบกลับ';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count รายการ',
    );
    return '$_temp0';
  }

  @override
  String moreCount(String name, int count) {
    return '$name และอีก $count';
  }

  @override
  String qtyUnit(int qty, String unit) {
    return '$qty $unit';
  }

  @override
  String get navDashboard => 'ภาพรวม';

  @override
  String get navProducts => 'สินค้า';

  @override
  String get navOperations => 'เอกสารสต็อก';

  @override
  String get navJobs => 'งาน';

  @override
  String get navProfile => 'โปรไฟล์';

  @override
  String get scanBarcode => 'สแกนบาร์โค้ด';

  @override
  String get roleAdmin => 'ผู้ดูแลระบบ';

  @override
  String get roleStaff => 'พนักงานคลัง';

  @override
  String get roleTechnician => 'ช่างเทคนิค';

  @override
  String get roleSupervisor => 'หัวหน้างาน';

  @override
  String get language => 'ภาษา';

  @override
  String get languageSystem => 'ตามเครื่อง';

  @override
  String get signOut => 'ออกจากระบบ';

  @override
  String get loginTagline =>
      'รับ เบิก และตรวจนับสต็อก\nได้จากหน้างานคลังสินค้า';

  @override
  String get welcomeBack => 'ยินดีต้อนรับกลับ';

  @override
  String get email => 'อีเมล';

  @override
  String get enterEmail => 'กรุณากรอกอีเมล';

  @override
  String get validEmail => 'รูปแบบอีเมลไม่ถูกต้อง';

  @override
  String get password => 'รหัสผ่าน';

  @override
  String get showPassword => 'แสดงรหัสผ่าน';

  @override
  String get hidePassword => 'ซ่อนรหัสผ่าน';

  @override
  String get enterPassword => 'กรุณากรอกรหัสผ่าน';

  @override
  String get signIn => 'เข้าสู่ระบบ';

  @override
  String get demoAccounts => 'บัญชีทดลอง';

  @override
  String serverHost(String host) {
    return 'เซิร์ฟเวอร์: $host';
  }

  @override
  String get server => 'เซิร์ฟเวอร์';

  @override
  String get serverHelp =>
      'ที่อยู่ของ StockFlow API ถ้าใช้บนมือถือ ให้ใส่ IP Wi-Fi ของคอมพิวเตอร์';

  @override
  String get apiUrl => 'API URL';

  @override
  String get testConnection => 'ทดสอบการเชื่อมต่อ';

  @override
  String serverDefault(String host) {
    return 'ค่าเริ่มต้น ($host)';
  }

  @override
  String get connected => 'เชื่อมต่อสำเร็จ';

  @override
  String get notStockflow => 'ไม่ใช่เซิร์ฟเวอร์ StockFlow';

  @override
  String notStockflowCode(String code) {
    return 'ไม่ใช่เซิร์ฟเวอร์ StockFlow (HTTP $code)';
  }

  @override
  String get serverUnreachable =>
      'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ อยู่ Wi-Fi เดียวกันไหม? เปิดไฟร์วอลล์พอร์ต 3000 หรือยัง?';

  @override
  String get enterServer => 'กรุณากรอกที่อยู่เซิร์ฟเวอร์';

  @override
  String get serverExample => 'เช่น http://192.168.1.10:3000';

  @override
  String hello(String name) {
    return 'สวัสดี $name';
  }

  @override
  String get unitsOnHand => 'จำนวนคงเหลือรวม';

  @override
  String acrossProducts(int count) {
    return 'จากสินค้า $count รายการ';
  }

  @override
  String get receive => 'รับเข้า';

  @override
  String get issue => 'เบิกออก';

  @override
  String get adjust => 'ปรับยอด';

  @override
  String get lowStock => 'ใกล้หมด';

  @override
  String get outOfStock => 'หมดสต็อก';

  @override
  String get inStock => 'มีสินค้า';

  @override
  String draftsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ร่าง $count รายการรอยืนยัน',
    );
    return '$_temp0';
  }

  @override
  String get last7Days => '7 วันล่าสุด';

  @override
  String weekFlow(int received, int issued) {
    return 'รับเข้า $received · เบิกออก $issued';
  }

  @override
  String get needsAttention => 'ต้องดูแล';

  @override
  String get allAboveMin => 'สินค้าทุกรายการอยู่เหนือจุดสั่งซื้อขั้นต่ำ';

  @override
  String get recentActivity => 'กิจกรรมล่าสุด';

  @override
  String get noConfirmedOps => 'ยังไม่มีเอกสารที่ยืนยันแล้ว';

  @override
  String skuMin(String sku, int min, String unit) {
    return '$sku · ขั้นต่ำ $min $unit';
  }

  @override
  String get fieldJobs => 'งานภาคสนาม';

  @override
  String get filterActive => 'กำลังดำเนินการ';

  @override
  String get filterToReview => 'รอตรวจ';

  @override
  String get overdue => 'เลยกำหนด';

  @override
  String get filterDone => 'เสร็จแล้ว';

  @override
  String get received => 'รับเข้า';

  @override
  String get issued => 'เบิกออก';

  @override
  String get inShort => 'เข้า';

  @override
  String get outShort => 'ออก';

  @override
  String get day => 'วัน';

  @override
  String get showChart => 'แสดงกราฟ';

  @override
  String get showTable => 'แสดงตาราง';

  @override
  String get weekdays => 'จ.,อ.,พ.,พฤ.,ศ.,ส.,อา.';

  @override
  String dayFlowA11y(String day, int received, int issued) {
    return '$day: รับเข้า $received เบิกออก $issued';
  }

  @override
  String get stockHistory => 'ประวัติสต็อก';

  @override
  String get noMovements => 'ยังไม่มีความเคลื่อนไหว';

  @override
  String get confirmedAppearHere => 'เอกสารที่ยืนยันแล้วจะแสดงที่นี่';

  @override
  String movementsOnHand(int count, int onHand, String unit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count รายการเคลื่อนไหว',
    );
    return '$_temp0 · คงเหลือ $onHand $unit';
  }

  @override
  String balanceAfter(int qty, String unit) {
    return 'คงเหลือ $qty $unit';
  }

  @override
  String syncedCount(int count) {
    return 'ซิงก์แล้ว $count';
  }

  @override
  String needAttentionCount(int count) {
    return 'ต้องแก้ไข $count';
  }

  @override
  String get serverRetryLater => 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ จะลองใหม่ภายหลัง';

  @override
  String get nothingToSync => 'ไม่มีรายการรอซิงก์';

  @override
  String get couldNotSync => 'ซิงก์ไม่สำเร็จ';

  @override
  String get serverRejected => 'เซิร์ฟเวอร์ปฏิเสธเอกสารนี้';

  @override
  String get retryOrDiscard => 'ลองใหม่หากแก้ปัญหาแล้ว หรือทิ้งเอกสารนี้';

  @override
  String get discard => 'ทิ้ง';

  @override
  String get offlineBanner => 'ออฟไลน์อยู่ เอกสารใหม่จะถูกบันทึกไว้ในเครื่อง';

  @override
  String waitingToSync(int count) {
    return 'รอซิงก์ ($count)';
  }

  @override
  String get syncing => 'กำลังซิงก์…';

  @override
  String get syncNow => 'ซิงก์ตอนนี้';

  @override
  String get rejectedByServer => 'ถูกเซิร์ฟเวอร์ปฏิเสธ';

  @override
  String get failed => 'ล้มเหลว';

  @override
  String get pending => 'รอดำเนินการ';

  @override
  String get addOneProduct => 'เพิ่มสินค้าอย่างน้อย 1 รายการ';

  @override
  String get mustBePositive => 'ต้องมากกว่า 0';

  @override
  String onlyOnHand(int qty, String unit) {
    return 'มีคงเหลือเพียง $qty $unit';
  }

  @override
  String get mustNotBeZero => 'ต้องไม่เป็น 0';

  @override
  String wouldGoNegative(int qty) {
    return 'ยอดจะติดลบ (คงเหลือ $qty)';
  }

  @override
  String get takePhoto => 'ถ่ายรูป';

  @override
  String get chooseGallery => 'เลือกจากคลังภาพ';

  @override
  String get photoAttached => 'แนบรูปแล้ว';

  @override
  String evidencePhotosCount(int count, int max) {
    return 'รูปหลักฐาน ($count/$max)';
  }

  @override
  String get noPhotosAttached => 'ยังไม่ได้แนบรูป';

  @override
  String get evidencePhoto => 'รูปหลักฐาน';

  @override
  String get addPhoto => 'เพิ่มรูป';

  @override
  String get saving => 'กำลังบันทึก…';

  @override
  String get deleteThisPhoto => 'ลบรูปนี้?';

  @override
  String get removedFromTx => 'รูปจะถูกนำออกจากเอกสาร';

  @override
  String get photoDeleted => 'ลบรูปแล้ว';

  @override
  String get deletePhoto => 'ลบรูป';

  @override
  String get scanItem => 'สแกนสินค้า';

  @override
  String addedProduct(String name) {
    return 'เพิ่ม $name แล้ว';
  }

  @override
  String get issueDraftForWo => 'สร้างร่างใบเบิกสำหรับใบงานแล้ว';

  @override
  String get savedOnDevice => 'บันทึกไว้ในเครื่องแล้ว จะซิงก์เมื่อออนไลน์';

  @override
  String get newReceive => 'รับสินค้าเข้า';

  @override
  String get newIssue => 'เบิกสินค้าออก';

  @override
  String get newAdjust => 'ปรับยอดสต็อก';

  @override
  String forWo(String code) {
    return 'สำหรับ $code';
  }

  @override
  String get hintReceive => 'จำนวนจะถูกบวกเข้าสต็อก';

  @override
  String get hintIssue => 'จำนวนจะถูกหักออกจากสต็อก';

  @override
  String get hintAdjust => 'ใส่ผลต่าง: ค่าบวกเพิ่ม ค่าลบลด';

  @override
  String get referenceOptional => 'เลขที่อ้างอิง (ไม่บังคับ)';

  @override
  String get referenceHint => 'เช่น PO-2026-0001';

  @override
  String get noteOptional => 'หมายเหตุ (ไม่บังคับ)';

  @override
  String get items => 'รายการสินค้า';

  @override
  String get noProductsAdded => 'ยังไม่ได้เพิ่มสินค้า';

  @override
  String get saveDraft => 'บันทึกเป็นร่าง';

  @override
  String lineProjection(String sku, int onHand, int next, String unit) {
    return '$sku · คงเหลือ $onHand → $next $unit';
  }

  @override
  String get decrease => 'ลด';

  @override
  String get increase => 'เพิ่ม';

  @override
  String get descReceive => 'สินค้าเข้าคลัง';

  @override
  String get descIssue => 'สินค้าออกจากคลัง';

  @override
  String get descAdjust => 'แก้ยอดหลังตรวจนับ';

  @override
  String get stockOperations => 'เอกสารสต็อก';

  @override
  String get noOperations => 'ยังไม่มีเอกสาร';

  @override
  String noOperationsStatus(String status) {
    return 'ไม่มีเอกสารสถานะ$status';
  }

  @override
  String get tapNewHint => 'แตะ “สร้างใหม่” เพื่อรับเข้า เบิกออก หรือปรับยอด';

  @override
  String createdByAt(String name, String time) {
    return '$name · $time';
  }

  @override
  String get operation => 'เอกสาร';

  @override
  String get cancelDraftQ => 'ยกเลิกร่างนี้?';

  @override
  String get noStockEffect => 'ไม่มีผลกับสต็อก';

  @override
  String get cancelDraft => 'ยกเลิกร่าง';

  @override
  String get draftCancelled => 'ยกเลิกร่างแล้ว';

  @override
  String confirmTypeQ(String type) {
    return 'ยืนยัน$type?';
  }

  @override
  String confirmStockMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'สต็อกของสินค้า $count รายการจะถูกปรับ และย้อนกลับไม่ได้',
    );
    return '$_temp0';
  }

  @override
  String get stockUpdated => 'ปรับสต็อกแล้ว';

  @override
  String get waitingAdmin => 'รอผู้ดูแลระบบยืนยัน';

  @override
  String get createdBy => 'สร้างโดย';

  @override
  String get createdAt => 'สร้างเมื่อ';

  @override
  String get confirmedBy => 'ยืนยันโดย';

  @override
  String get confirmedAt => 'ยืนยันเมื่อ';

  @override
  String itemsWithCount(int count) {
    return 'รายการสินค้า ($count)';
  }

  @override
  String get searchProduct => 'ค้นหาสินค้า';

  @override
  String get noProductsFound => 'ไม่พบสินค้า';

  @override
  String get txDraft => 'ร่าง';

  @override
  String get txConfirmed => 'ยืนยันแล้ว';

  @override
  String get txCancelled => 'ยกเลิกแล้ว';

  @override
  String get searchProducts => 'ค้นหาชื่อ, SKU หรือบาร์โค้ด';

  @override
  String get clearSearch => 'ล้างคำค้น';

  @override
  String get noMatchingProducts => 'ไม่พบสินค้าที่ตรงกัน';

  @override
  String get tryDifferentSearch => 'ลองค้นหาด้วยคำอื่น หรือล้างตัวกรอง';

  @override
  String get clearFilters => 'ล้างตัวกรอง';

  @override
  String get noProductsYet => 'ยังไม่มีสินค้า';

  @override
  String get productsByAdmin => 'สินค้าที่ผู้ดูแลระบบเพิ่มจะแสดงที่นี่';

  @override
  String productsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'สินค้า $count รายการ',
    );
    return '$_temp0';
  }

  @override
  String get product => 'สินค้า';

  @override
  String get uncategorized => 'ไม่มีหมวดหมู่';

  @override
  String get barcode => 'บาร์โค้ด';

  @override
  String get unit => 'หน่วย';

  @override
  String get onHand => 'คงเหลือ';

  @override
  String get minimumStock => 'สต็อกขั้นต่ำ';

  @override
  String get recentMovements => 'ความเคลื่อนไหวล่าสุด';

  @override
  String viewAll(int count) {
    return 'ดูทั้งหมด ($count)';
  }

  @override
  String get noConfirmedMovements => 'ยังไม่มีความเคลื่อนไหวที่ยืนยันแล้ว';

  @override
  String get couldNotLoadMovements => 'โหลดความเคลื่อนไหวไม่สำเร็จ';

  @override
  String noProductBarcode(String code) {
    return 'ไม่พบสินค้าบาร์โค้ด $code';
  }

  @override
  String get flashlight => 'ไฟฉาย';

  @override
  String get pointCamera => 'เล็งกล้องไปที่บาร์โค้ดสินค้า';

  @override
  String get typeBarcode => 'พิมพ์บาร์โค้ด';

  @override
  String get cameraPermission =>
      'ต้องอนุญาตการใช้กล้องเพื่อสแกน\nเปิดสิทธิ์ในการตั้งค่าเครื่อง หรือพิมพ์บาร์โค้ดแทน';

  @override
  String get cameraUnavailable => 'อุปกรณ์นี้ไม่มีกล้อง';

  @override
  String get enterBarcode => 'กรอกบาร์โค้ด';

  @override
  String get find => 'ค้นหา';

  @override
  String get woOpen => 'รอเริ่มงาน';

  @override
  String get woInProgress => 'กำลังทำ';

  @override
  String get woSubmitted => 'ส่งตรวจแล้ว';

  @override
  String get woNeedsRevision => 'ต้องแก้ไข';

  @override
  String get woApproved => 'อนุมัติแล้ว';

  @override
  String get woCancelled => 'ยกเลิกแล้ว';

  @override
  String get prLow => 'ต่ำ';

  @override
  String get prNormal => 'ปกติ';

  @override
  String get prHigh => 'สูง';

  @override
  String get prUrgent => 'ด่วน';

  @override
  String get evBefore => 'ก่อนทำงาน';

  @override
  String get evAfter => 'หลังทำงาน';

  @override
  String get evOther => 'อื่น ๆ';

  @override
  String get evtCreated => 'สร้างใบงาน';

  @override
  String get evtAssigned => 'มอบหมายงาน';

  @override
  String get evtStarted => 'เริ่มงาน';

  @override
  String get evtChecklist => 'เช็กลิสต์';

  @override
  String get evtPhotoAdded => 'เพิ่มรูปแล้ว';

  @override
  String get evtPhotoRemoved => 'ลบรูปแล้ว';

  @override
  String get evtSubmitted => 'ส่งตรวจแล้ว';

  @override
  String get evtChangesRequested => 'ขอให้แก้ไข';

  @override
  String get evtMaterials => 'วัสดุ';

  @override
  String get myJobs => 'งานของฉัน';

  @override
  String get reviewsJobs => 'งานและการตรวจ';

  @override
  String get workOrders => 'ใบงาน';

  @override
  String get searchWo => 'ค้นหาเลขที่ ชื่องาน หรือสถานที่';

  @override
  String get noMatchingWo => 'ไม่พบใบงานที่ตรงกัน';

  @override
  String get nothingToReview => 'ไม่มีงานรอตรวจ';

  @override
  String get noActiveJobs => 'ไม่มีงานที่กำลังดำเนินการ';

  @override
  String get noWoYet => 'ยังไม่มีใบงาน';

  @override
  String get unassigned => 'ยังไม่มอบหมาย';

  @override
  String woCreated(String code) {
    return 'สร้าง $code แล้ว';
  }

  @override
  String get newWorkOrder => 'สร้างใบงาน';

  @override
  String get title => 'ชื่องาน';

  @override
  String get titleHint => 'เช่น ติดตั้งแอร์ – ห้องประชุม';

  @override
  String get site => 'สถานที่';

  @override
  String get addressOptional => 'ที่อยู่ (ไม่บังคับ)';

  @override
  String get instructionsOptional => 'รายละเอียดงาน (ไม่บังคับ)';

  @override
  String get priority => 'ความสำคัญ';

  @override
  String get noDueDate => 'ไม่กำหนดวันครบกำหนด';

  @override
  String dueAt(String date) {
    return 'ครบกำหนด $date';
  }

  @override
  String overdueAt(String date) {
    return 'เลยกำหนด · $date';
  }

  @override
  String get set => 'กำหนด';

  @override
  String get clearDueDate => 'ล้างวันครบกำหนด';

  @override
  String get checklist => 'เช็กลิสต์';

  @override
  String get noChecklist => 'ไม่มีเช็กลิสต์';

  @override
  String get technician => 'ช่างเทคนิค';

  @override
  String get assignLater => 'มอบหมายภายหลัง';

  @override
  String get reviewer => 'ผู้ตรวจงาน';

  @override
  String get anySupervisor => 'หัวหน้างานคนใดก็ได้';

  @override
  String get requiredPhotos => 'รูปที่ต้องถ่าย';

  @override
  String get materials => 'วัสดุ';

  @override
  String get noMaterialsOk => 'ไม่มี: งานที่ไม่ใช้อะไหล่ก็ได้';

  @override
  String skuOnHand(String sku, int qty, String unit) {
    return '$sku · คงเหลือ $qty $unit';
  }

  @override
  String get createWorkOrder => 'สร้างใบงาน';

  @override
  String get submitForReviewQ => 'ส่งตรวจงาน?';

  @override
  String get submitExplain =>
      'หัวหน้างานจะตรวจเช็กลิสต์และรูป หลังส่งแล้วจะแก้ไขไม่ได้ เว้นแต่ถูกขอให้แก้ไข';

  @override
  String get submit => 'ส่งงาน';

  @override
  String get submittedForReview => 'ส่งตรวจแล้ว';

  @override
  String get approveWork => 'อนุมัติงาน';

  @override
  String get commentOptional => 'ความเห็น (ไม่บังคับ)';

  @override
  String get approve => 'อนุมัติ';

  @override
  String get approved => 'อนุมัติแล้ว';

  @override
  String get requestChanges => 'ขอให้แก้ไข';

  @override
  String get whatToChange => 'ต้องแก้ไขอะไรบ้าง?';

  @override
  String get sendBack => 'ส่งกลับ';

  @override
  String get sentBack => 'ส่งกลับให้ช่างแล้ว';

  @override
  String get cancelWorkOrder => 'ยกเลิกใบงาน';

  @override
  String get reason => 'เหตุผล';

  @override
  String get cancelled => 'ยกเลิกแล้ว';

  @override
  String get assignmentUpdated => 'อัปเดตการมอบหมายแล้ว';

  @override
  String get photoAdded => 'เพิ่มรูปแล้ว';

  @override
  String get deletePhotoQ => 'ลบรูป?';

  @override
  String get removedFromWo => 'รูปจะถูกนำออกจากใบงาน';

  @override
  String get workOrder => 'ใบงาน';

  @override
  String get activity => 'ประวัติการทำงาน';

  @override
  String codeActivity(String code) {
    return 'ประวัติ $code';
  }

  @override
  String get noActivity => 'ยังไม่มีประวัติ';

  @override
  String get system => 'ระบบ';

  @override
  String get assignMenu => 'มอบหมาย…';

  @override
  String get cancelWoMenu => 'ยกเลิกใบงาน…';

  @override
  String get backInProgress => 'กลับมาทำงานต่อแล้ว';

  @override
  String get workStarted => 'เริ่มงานแล้ว';

  @override
  String get resumeWork => 'ทำงานต่อ';

  @override
  String get startWork => 'เริ่มงาน';

  @override
  String get submitForReview => 'ส่งตรวจงาน';

  @override
  String technicianIs(String name) {
    return 'ช่าง: $name';
  }

  @override
  String reviewerIs(String name) {
    return 'ผู้ตรวจ: $name';
  }

  @override
  String get unassignedLower => 'ยังไม่มอบหมาย';

  @override
  String get anySupervisorLower => 'หัวหน้างานคนใดก็ได้';

  @override
  String checklistDone(int done, int total) {
    return 'เสร็จ $done/$total';
  }

  @override
  String get noChecklistJob => 'งานนี้ไม่มีเช็กลิสต์';

  @override
  String get photos => 'รูปถ่าย';

  @override
  String requiredList(String list) {
    return 'ต้องมี: $list';
  }

  @override
  String get noMaterialsPlanned => 'ไม่ได้วางแผนใช้วัสดุ';

  @override
  String get stockDocuments => 'เอกสารสต็อก';

  @override
  String changesRequestedBy(String name, String note) {
    return '$name ขอให้แก้ไข: $note';
  }

  @override
  String changesRequested(String note) {
    return 'ขอให้แก้ไข: $note';
  }

  @override
  String approvedBy(String name) {
    return 'อนุมัติโดย $name';
  }

  @override
  String cancelledReason(String reason) {
    return 'ยกเลิกแล้ว: $reason';
  }

  @override
  String get waitingReview => 'รอตรวจงาน';

  @override
  String submittedAt(String time) {
    return 'ส่งเมื่อ $time';
  }

  @override
  String get beforeSubmit => 'ก่อนส่งงาน ต้องทำให้ครบ:';

  @override
  String get optional => 'ไม่บังคับ';

  @override
  String noteIs(String note) {
    return 'หมายเหตุ: $note';
  }

  @override
  String get addNote => 'เพิ่มหมายเหตุ';

  @override
  String materialLine(String sku, int planned, int issued, String unit) {
    return '$sku · แผน $planned · เบิกแล้ว $issued $unit';
  }

  @override
  String shortBy(int short, int onHand) {
    return 'ขาด $short (คงเหลือ $onHand)';
  }

  @override
  String toIssue(int count) {
    return 'ต้องเบิกอีก $count';
  }

  @override
  String get noPhotosYet => 'ยังไม่มีรูป';

  @override
  String get addReason => 'กรุณาระบุเหตุผล';

  @override
  String get moreWords => 'ขอรายละเอียดเพิ่มอีกนิด';

  @override
  String get assign => 'มอบหมาย';
}
