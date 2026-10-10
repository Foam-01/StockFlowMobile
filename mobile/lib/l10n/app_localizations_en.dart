// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'StockFlow';

  @override
  String get retry => 'Retry';

  @override
  String get tryAgain => 'Try again';

  @override
  String get back => 'Back';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get add => 'Add';

  @override
  String get newLabel => 'New';

  @override
  String get all => 'All';

  @override
  String get remove => 'Remove';

  @override
  String get scan => 'Scan';

  @override
  String get required => 'Required';

  @override
  String get note => 'Note';

  @override
  String get couldNotLoad => 'Could not load data';

  @override
  String get somethingWrong => 'Something went wrong';

  @override
  String get cannotReach => 'Cannot reach the server. Check your connection.';

  @override
  String requestFailed(String code) {
    return 'Request failed ($code)';
  }

  @override
  String get noResponse => 'no response';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String moreCount(String name, int count) {
    return '$name +$count more';
  }

  @override
  String qtyUnit(int qty, String unit) {
    return '$qty $unit';
  }

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navProducts => 'Products';

  @override
  String get navOperations => 'Operations';

  @override
  String get navJobs => 'Jobs';

  @override
  String get navProfile => 'Profile';

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleStaff => 'Warehouse';

  @override
  String get roleTechnician => 'Technician';

  @override
  String get roleSupervisor => 'Supervisor';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get signOut => 'Sign out';

  @override
  String get loginTagline =>
      'Receive, issue and count stock\nfrom the warehouse floor.';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get email => 'Email';

  @override
  String get enterEmail => 'Please enter your email';

  @override
  String get validEmail => 'Please enter a valid email';

  @override
  String get password => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get enterPassword => 'Please enter your password';

  @override
  String get signIn => 'Sign in';

  @override
  String get demoAccounts => 'Demo accounts';

  @override
  String serverHost(String host) {
    return 'Server: $host';
  }

  @override
  String get server => 'Server';

  @override
  String get serverHelp =>
      'Address of the StockFlow API. On a phone, use your computer’s Wi-Fi IP.';

  @override
  String get apiUrl => 'API URL';

  @override
  String get testConnection => 'Test connection';

  @override
  String serverDefault(String host) {
    return 'Default ($host)';
  }

  @override
  String get connected => 'Connected';

  @override
  String get notStockflow => 'Not a StockFlow server';

  @override
  String notStockflowCode(String code) {
    return 'Not a StockFlow server (HTTP $code)';
  }

  @override
  String get serverUnreachable =>
      'Cannot reach the server. Same Wi-Fi? Firewall open on port 3000?';

  @override
  String get enterServer => 'Enter the server address';

  @override
  String get serverExample => 'e.g. http://192.168.1.10:3000';

  @override
  String hello(String name) {
    return 'Hello, $name';
  }

  @override
  String get unitsOnHand => 'Units on hand';

  @override
  String acrossProducts(int count) {
    return 'across $count products';
  }

  @override
  String get receive => 'Receive';

  @override
  String get issue => 'Issue';

  @override
  String get adjust => 'Adjust';

  @override
  String get lowStock => 'Low stock';

  @override
  String get outOfStock => 'Out of stock';

  @override
  String get inStock => 'In stock';

  @override
  String draftsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drafts waiting for confirmation',
      one: '1 draft waiting for confirmation',
    );
    return '$_temp0';
  }

  @override
  String get last7Days => 'Last 7 days';

  @override
  String weekFlow(int received, int issued) {
    return '$received received · $issued issued';
  }

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get allAboveMin => 'All products are above their minimum stock';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get noConfirmedOps => 'No confirmed operations yet';

  @override
  String skuMin(String sku, int min, String unit) {
    return '$sku · min $min $unit';
  }

  @override
  String get fieldJobs => 'Field jobs';

  @override
  String get filterActive => 'Active';

  @override
  String get filterToReview => 'To review';

  @override
  String get overdue => 'Overdue';

  @override
  String get filterDone => 'Done';

  @override
  String get received => 'Received';

  @override
  String get issued => 'Issued';

  @override
  String get inShort => 'In';

  @override
  String get outShort => 'Out';

  @override
  String get day => 'Day';

  @override
  String get showChart => 'Show chart';

  @override
  String get showTable => 'Show table';

  @override
  String get weekdays => 'Mon,Tue,Wed,Thu,Fri,Sat,Sun';

  @override
  String dayFlowA11y(String day, int received, int issued) {
    return '$day: received $received, issued $issued';
  }

  @override
  String get stockHistory => 'Stock history';

  @override
  String get noMovements => 'No movements yet';

  @override
  String get confirmedAppearHere => 'Confirmed operations will appear here.';

  @override
  String movementsOnHand(int count, int onHand, String unit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count movements',
      one: '1 movement',
    );
    return '$_temp0 · on hand $onHand $unit';
  }

  @override
  String balanceAfter(int qty, String unit) {
    return 'bal. $qty $unit';
  }

  @override
  String syncedCount(int count) {
    return '$count synced';
  }

  @override
  String needAttentionCount(int count) {
    return '$count need attention';
  }

  @override
  String get serverRetryLater => 'server not reachable, will retry';

  @override
  String get nothingToSync => 'Nothing to sync';

  @override
  String get couldNotSync => 'Could not sync';

  @override
  String get serverRejected => 'The server rejected this document.';

  @override
  String get retryOrDiscard => 'Retry if the problem was fixed, or discard it.';

  @override
  String get discard => 'Discard';

  @override
  String get offlineBanner =>
      'You’re offline. New documents are saved on this device.';

  @override
  String waitingToSync(int count) {
    return 'Waiting to sync ($count)';
  }

  @override
  String get syncing => 'Syncing…';

  @override
  String get syncNow => 'Sync now';

  @override
  String get rejectedByServer => 'Rejected by server';

  @override
  String get failed => 'Failed';

  @override
  String get pending => 'Pending';

  @override
  String get addOneProduct => 'Add at least one product';

  @override
  String get mustBePositive => 'Must be greater than 0';

  @override
  String onlyOnHand(int qty, String unit) {
    return 'Only $qty $unit on hand';
  }

  @override
  String get mustNotBeZero => 'Must not be 0';

  @override
  String wouldGoNegative(int qty) {
    return 'Would go below 0 (on hand $qty)';
  }

  @override
  String get takePhoto => 'Take photo';

  @override
  String get chooseGallery => 'Choose from gallery';

  @override
  String get photoAttached => 'Photo attached';

  @override
  String evidencePhotosCount(int count, int max) {
    return 'Evidence photos ($count/$max)';
  }

  @override
  String get noPhotosAttached => 'No photos attached';

  @override
  String get evidencePhoto => 'Evidence photo';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get saving => 'Saving…';

  @override
  String get deleteThisPhoto => 'Delete this photo?';

  @override
  String get removedFromTx => 'It will be removed from the transaction.';

  @override
  String get photoDeleted => 'Photo deleted';

  @override
  String get deletePhoto => 'Delete photo';

  @override
  String get scanItem => 'Scan item';

  @override
  String addedProduct(String name) {
    return 'Added $name';
  }

  @override
  String get issueDraftForWo => 'Issue draft created for the work order';

  @override
  String get savedOnDevice => 'Saved on this device. It will sync when online.';

  @override
  String get newReceive => 'New receive';

  @override
  String get newIssue => 'New issue';

  @override
  String get newAdjust => 'New adjustment';

  @override
  String forWo(String code) {
    return 'For $code';
  }

  @override
  String get hintReceive => 'Quantities are added to stock.';

  @override
  String get hintIssue => 'Quantities are removed from stock.';

  @override
  String get hintAdjust =>
      'Enter the difference: positive adds, negative removes.';

  @override
  String get referenceOptional => 'Reference no. (optional)';

  @override
  String get referenceHint => 'e.g. PO-2026-0001';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get items => 'Items';

  @override
  String get noProductsAdded => 'No products added';

  @override
  String get saveDraft => 'Save as draft';

  @override
  String lineProjection(String sku, int onHand, int next, String unit) {
    return '$sku · on hand $onHand → $next $unit';
  }

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get descReceive => 'Goods coming into stock';

  @override
  String get descIssue => 'Goods going out of stock';

  @override
  String get descAdjust => 'Correct stock after a count';

  @override
  String get stockOperations => 'Stock operations';

  @override
  String get noOperations => 'No operations yet';

  @override
  String noOperationsStatus(String status) {
    return 'No $status operations';
  }

  @override
  String get tapNewHint => 'Tap New to receive, issue or adjust stock.';

  @override
  String createdByAt(String name, String time) {
    return '$name · $time';
  }

  @override
  String get operation => 'Operation';

  @override
  String get cancelDraftQ => 'Cancel this draft?';

  @override
  String get noStockEffect => 'It will not affect stock.';

  @override
  String get cancelDraft => 'Cancel draft';

  @override
  String get draftCancelled => 'Draft cancelled';

  @override
  String confirmTypeQ(String type) {
    return 'Confirm $type?';
  }

  @override
  String confirmStockMsg(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Stock will be updated for $count products. This cannot be undone.',
      one: 'Stock will be updated for 1 product. This cannot be undone.',
    );
    return '$_temp0';
  }

  @override
  String get stockUpdated => 'Stock updated';

  @override
  String get waitingAdmin => 'Waiting for an admin to confirm';

  @override
  String get createdBy => 'Created by';

  @override
  String get createdAt => 'Created at';

  @override
  String get confirmedBy => 'Confirmed by';

  @override
  String get confirmedAt => 'Confirmed at';

  @override
  String itemsWithCount(int count) {
    return 'Items ($count)';
  }

  @override
  String get searchProduct => 'Search product';

  @override
  String get noProductsFound => 'No products found';

  @override
  String get txDraft => 'Draft';

  @override
  String get txConfirmed => 'Confirmed';

  @override
  String get txCancelled => 'Cancelled';

  @override
  String get searchProducts => 'Search name, SKU or barcode';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get noMatchingProducts => 'No matching products';

  @override
  String get tryDifferentSearch =>
      'Try a different search or clear the filters.';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get noProductsYet => 'No products yet';

  @override
  String get productsByAdmin => 'Products added by an admin will appear here.';

  @override
  String productsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
    );
    return '$_temp0';
  }

  @override
  String get product => 'Product';

  @override
  String get uncategorized => 'Uncategorized';

  @override
  String get barcode => 'Barcode';

  @override
  String get unit => 'Unit';

  @override
  String get onHand => 'On hand';

  @override
  String get minimumStock => 'Minimum stock';

  @override
  String get recentMovements => 'Recent movements';

  @override
  String viewAll(int count) {
    return 'View all ($count)';
  }

  @override
  String get noConfirmedMovements => 'No confirmed movements yet';

  @override
  String get couldNotLoadMovements => 'Could not load movements';

  @override
  String noProductBarcode(String code) {
    return 'No product with barcode $code';
  }

  @override
  String get flashlight => 'Flashlight';

  @override
  String get pointCamera => 'Point the camera at a product barcode';

  @override
  String get typeBarcode => 'Type barcode';

  @override
  String get cameraPermission =>
      'Camera permission is needed to scan.\nAllow it in system settings, or type the barcode.';

  @override
  String get cameraUnavailable => 'Camera is not available on this device.';

  @override
  String get enterBarcode => 'Enter barcode';

  @override
  String get find => 'Find';

  @override
  String get woOpen => 'Open';

  @override
  String get woInProgress => 'In progress';

  @override
  String get woSubmitted => 'Submitted';

  @override
  String get woNeedsRevision => 'Needs revision';

  @override
  String get woApproved => 'Approved';

  @override
  String get woCancelled => 'Cancelled';

  @override
  String get prLow => 'Low';

  @override
  String get prNormal => 'Normal';

  @override
  String get prHigh => 'High';

  @override
  String get prUrgent => 'Urgent';

  @override
  String get evBefore => 'Before work';

  @override
  String get evAfter => 'After work';

  @override
  String get evOther => 'Other';

  @override
  String get evtCreated => 'Created';

  @override
  String get evtAssigned => 'Assignment';

  @override
  String get evtStarted => 'Work started';

  @override
  String get evtChecklist => 'Checklist';

  @override
  String get evtPhotoAdded => 'Photo added';

  @override
  String get evtPhotoRemoved => 'Photo removed';

  @override
  String get evtSubmitted => 'Submitted for review';

  @override
  String get evtChangesRequested => 'Changes requested';

  @override
  String get evtMaterials => 'Materials';

  @override
  String get myJobs => 'My jobs';

  @override
  String get reviewsJobs => 'Reviews & jobs';

  @override
  String get workOrders => 'Work orders';

  @override
  String get searchWo => 'Search code, title or site';

  @override
  String get noMatchingWo => 'No matching work orders';

  @override
  String get nothingToReview => 'Nothing waiting for review';

  @override
  String get noActiveJobs => 'No active jobs';

  @override
  String get noWoYet => 'No work orders yet';

  @override
  String get unassigned => 'Unassigned';

  @override
  String woCreated(String code) {
    return '$code created';
  }

  @override
  String get newWorkOrder => 'New work order';

  @override
  String get title => 'Title';

  @override
  String get titleHint => 'e.g. Install split AC – meeting room';

  @override
  String get site => 'Site';

  @override
  String get addressOptional => 'Address (optional)';

  @override
  String get instructionsOptional => 'Instructions (optional)';

  @override
  String get priority => 'Priority';

  @override
  String get noDueDate => 'No due date';

  @override
  String dueAt(String date) {
    return 'Due $date';
  }

  @override
  String overdueAt(String date) {
    return 'Overdue · $date';
  }

  @override
  String get set => 'Set';

  @override
  String get clearDueDate => 'Clear due date';

  @override
  String get checklist => 'Checklist';

  @override
  String get noChecklist => 'No checklist';

  @override
  String get technician => 'Technician';

  @override
  String get assignLater => 'Assign later';

  @override
  String get reviewer => 'Reviewer';

  @override
  String get anySupervisor => 'Any supervisor';

  @override
  String get requiredPhotos => 'Required photos';

  @override
  String get materials => 'Materials';

  @override
  String get noMaterialsOk => 'None: work without parts is fine';

  @override
  String skuOnHand(String sku, int qty, String unit) {
    return '$sku · on hand $qty $unit';
  }

  @override
  String get createWorkOrder => 'Create work order';

  @override
  String get submitForReviewQ => 'Submit for review?';

  @override
  String get submitExplain =>
      'A supervisor will check the checklist and photos. You can’t change them after submitting unless changes are requested.';

  @override
  String get submit => 'Submit';

  @override
  String get submittedForReview => 'Submitted for review';

  @override
  String get approveWork => 'Approve work';

  @override
  String get commentOptional => 'Comment (optional)';

  @override
  String get approve => 'Approve';

  @override
  String get approved => 'Approved';

  @override
  String get requestChanges => 'Request changes';

  @override
  String get whatToChange => 'What needs to change?';

  @override
  String get sendBack => 'Send back';

  @override
  String get sentBack => 'Sent back to the technician';

  @override
  String get cancelWorkOrder => 'Cancel work order';

  @override
  String get reason => 'Reason';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get assignmentUpdated => 'Assignment updated';

  @override
  String get photoAdded => 'Photo added';

  @override
  String get deletePhotoQ => 'Delete photo?';

  @override
  String get removedFromWo => 'It will be removed from the work order.';

  @override
  String get workOrder => 'Work order';

  @override
  String get activity => 'Activity';

  @override
  String codeActivity(String code) {
    return '$code activity';
  }

  @override
  String get noActivity => 'No activity yet';

  @override
  String get system => 'System';

  @override
  String get assignMenu => 'Assign…';

  @override
  String get cancelWoMenu => 'Cancel work order…';

  @override
  String get backInProgress => 'Back in progress';

  @override
  String get workStarted => 'Work started';

  @override
  String get resumeWork => 'Resume work';

  @override
  String get startWork => 'Start work';

  @override
  String get submitForReview => 'Submit for review';

  @override
  String technicianIs(String name) {
    return 'Technician: $name';
  }

  @override
  String reviewerIs(String name) {
    return 'Reviewer: $name';
  }

  @override
  String get unassignedLower => 'unassigned';

  @override
  String get anySupervisorLower => 'any supervisor';

  @override
  String checklistDone(int done, int total) {
    return '$done/$total done';
  }

  @override
  String get noChecklistJob => 'No checklist for this job';

  @override
  String get photos => 'Photos';

  @override
  String requiredList(String list) {
    return 'Required: $list';
  }

  @override
  String get noMaterialsPlanned => 'No materials planned';

  @override
  String get stockDocuments => 'Stock documents';

  @override
  String changesRequestedBy(String name, String note) {
    return 'Changes requested by $name: $note';
  }

  @override
  String changesRequested(String note) {
    return 'Changes requested: $note';
  }

  @override
  String approvedBy(String name) {
    return 'Approved by $name';
  }

  @override
  String cancelledReason(String reason) {
    return 'Cancelled: $reason';
  }

  @override
  String get waitingReview => 'Waiting for review';

  @override
  String submittedAt(String time) {
    return 'submitted $time';
  }

  @override
  String get beforeSubmit => 'Before you can submit:';

  @override
  String get optional => 'Optional';

  @override
  String noteIs(String note) {
    return 'Note: $note';
  }

  @override
  String get addNote => 'Add note';

  @override
  String materialLine(String sku, int planned, int issued, String unit) {
    return '$sku · planned $planned · issued $issued $unit';
  }

  @override
  String shortBy(int short, int onHand) {
    return 'Short by $short (on hand $onHand)';
  }

  @override
  String toIssue(int count) {
    return '$count to issue';
  }

  @override
  String get noPhotosYet => 'No photos yet';

  @override
  String get addReason => 'Please add a reason';

  @override
  String get moreWords => 'A few more words, please';

  @override
  String get assign => 'Assign';

  @override
  String uploadFailed(String detail) {
    return 'Upload failed: $detail';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String notificationsUnread(int count) {
    return 'Notifications, $count unread';
  }

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get noNotificationsHint =>
      'Assignments and review results appear here. Pull down to check for new ones.';

  @override
  String ntfAssigned(String actor, String code) {
    return '$actor assigned $code to you';
  }

  @override
  String ntfSubmitted(String actor, String code) {
    return '$actor submitted $code for review';
  }

  @override
  String ntfChangesRequested(String actor, String code) {
    return '$actor asked for changes on $code';
  }

  @override
  String ntfApproved(String actor, String code) {
    return '$actor approved $code';
  }

  @override
  String ntfCancelled(String actor, String code) {
    return '$actor cancelled $code';
  }
}
