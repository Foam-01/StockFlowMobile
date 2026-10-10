import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'StockFlow'**
  String get appTitle;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @newLabel.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newLabel;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get note;

  /// No description provided for @couldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load data'**
  String get couldNotLoad;

  /// No description provided for @somethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWrong;

  /// No description provided for @cannotReach.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Check your connection.'**
  String get cannotReach;

  /// No description provided for @requestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed ({code})'**
  String requestFailed(String code);

  /// No description provided for @noResponse.
  ///
  /// In en, this message translates to:
  /// **'no response'**
  String get noResponse;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemsCount(int count);

  /// No description provided for @moreCount.
  ///
  /// In en, this message translates to:
  /// **'{name} +{count} more'**
  String moreCount(String name, int count);

  /// No description provided for @qtyUnit.
  ///
  /// In en, this message translates to:
  /// **'{qty} {unit}'**
  String qtyUnit(int qty, String unit);

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get navProducts;

  /// No description provided for @navOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get navOperations;

  /// No description provided for @navJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get navJobs;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @scanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get scanBarcode;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleStaff.
  ///
  /// In en, this message translates to:
  /// **'Warehouse'**
  String get roleStaff;

  /// No description provided for @roleTechnician.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get roleTechnician;

  /// No description provided for @roleSupervisor.
  ///
  /// In en, this message translates to:
  /// **'Supervisor'**
  String get roleSupervisor;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'Receive, issue and count stock\nfrom the warehouse floor.'**
  String get loginTagline;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get enterEmail;

  /// No description provided for @validEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get validEmail;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get enterPassword;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @demoAccounts.
  ///
  /// In en, this message translates to:
  /// **'Demo accounts'**
  String get demoAccounts;

  /// No description provided for @serverHost.
  ///
  /// In en, this message translates to:
  /// **'Server: {host}'**
  String serverHost(String host);

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @serverHelp.
  ///
  /// In en, this message translates to:
  /// **'Address of the StockFlow API. On a phone, use your computer’s Wi-Fi IP.'**
  String get serverHelp;

  /// No description provided for @apiUrl.
  ///
  /// In en, this message translates to:
  /// **'API URL'**
  String get apiUrl;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @serverDefault.
  ///
  /// In en, this message translates to:
  /// **'Default ({host})'**
  String serverDefault(String host);

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @notStockflow.
  ///
  /// In en, this message translates to:
  /// **'Not a StockFlow server'**
  String get notStockflow;

  /// No description provided for @notStockflowCode.
  ///
  /// In en, this message translates to:
  /// **'Not a StockFlow server (HTTP {code})'**
  String notStockflowCode(String code);

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server. Same Wi-Fi? Firewall open on port 3000?'**
  String get serverUnreachable;

  /// No description provided for @enterServer.
  ///
  /// In en, this message translates to:
  /// **'Enter the server address'**
  String get enterServer;

  /// No description provided for @serverExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. http://192.168.1.10:3000'**
  String get serverExample;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String hello(String name);

  /// No description provided for @unitsOnHand.
  ///
  /// In en, this message translates to:
  /// **'Units on hand'**
  String get unitsOnHand;

  /// No description provided for @acrossProducts.
  ///
  /// In en, this message translates to:
  /// **'across {count} products'**
  String acrossProducts(int count);

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @issue.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get issue;

  /// No description provided for @adjust.
  ///
  /// In en, this message translates to:
  /// **'Adjust'**
  String get adjust;

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get lowStock;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get outOfStock;

  /// No description provided for @inStock.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get inStock;

  /// No description provided for @draftsWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 draft waiting for confirmation} other{{count} drafts waiting for confirmation}}'**
  String draftsWaiting(int count);

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get last7Days;

  /// No description provided for @weekFlow.
  ///
  /// In en, this message translates to:
  /// **'{received} received · {issued} issued'**
  String weekFlow(int received, int issued);

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @allAboveMin.
  ///
  /// In en, this message translates to:
  /// **'All products are above their minimum stock'**
  String get allAboveMin;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @noConfirmedOps.
  ///
  /// In en, this message translates to:
  /// **'No confirmed operations yet'**
  String get noConfirmedOps;

  /// No description provided for @skuMin.
  ///
  /// In en, this message translates to:
  /// **'{sku} · min {min} {unit}'**
  String skuMin(String sku, int min, String unit);

  /// No description provided for @fieldJobs.
  ///
  /// In en, this message translates to:
  /// **'Field jobs'**
  String get fieldJobs;

  /// No description provided for @filterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get filterActive;

  /// No description provided for @filterToReview.
  ///
  /// In en, this message translates to:
  /// **'To review'**
  String get filterToReview;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @filterDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get filterDone;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @issued.
  ///
  /// In en, this message translates to:
  /// **'Issued'**
  String get issued;

  /// No description provided for @inShort.
  ///
  /// In en, this message translates to:
  /// **'In'**
  String get inShort;

  /// No description provided for @outShort.
  ///
  /// In en, this message translates to:
  /// **'Out'**
  String get outShort;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @showChart.
  ///
  /// In en, this message translates to:
  /// **'Show chart'**
  String get showChart;

  /// No description provided for @showTable.
  ///
  /// In en, this message translates to:
  /// **'Show table'**
  String get showTable;

  /// No description provided for @weekdays.
  ///
  /// In en, this message translates to:
  /// **'Mon,Tue,Wed,Thu,Fri,Sat,Sun'**
  String get weekdays;

  /// No description provided for @dayFlowA11y.
  ///
  /// In en, this message translates to:
  /// **'{day}: received {received}, issued {issued}'**
  String dayFlowA11y(String day, int received, int issued);

  /// No description provided for @stockHistory.
  ///
  /// In en, this message translates to:
  /// **'Stock history'**
  String get stockHistory;

  /// No description provided for @noMovements.
  ///
  /// In en, this message translates to:
  /// **'No movements yet'**
  String get noMovements;

  /// No description provided for @confirmedAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Confirmed operations will appear here.'**
  String get confirmedAppearHere;

  /// No description provided for @movementsOnHand.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 movement} other{{count} movements}} · on hand {onHand} {unit}'**
  String movementsOnHand(int count, int onHand, String unit);

  /// No description provided for @balanceAfter.
  ///
  /// In en, this message translates to:
  /// **'bal. {qty} {unit}'**
  String balanceAfter(int qty, String unit);

  /// No description provided for @syncedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} synced'**
  String syncedCount(int count);

  /// No description provided for @needAttentionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} need attention'**
  String needAttentionCount(int count);

  /// No description provided for @serverRetryLater.
  ///
  /// In en, this message translates to:
  /// **'server not reachable, will retry'**
  String get serverRetryLater;

  /// No description provided for @nothingToSync.
  ///
  /// In en, this message translates to:
  /// **'Nothing to sync'**
  String get nothingToSync;

  /// No description provided for @couldNotSync.
  ///
  /// In en, this message translates to:
  /// **'Could not sync'**
  String get couldNotSync;

  /// No description provided for @serverRejected.
  ///
  /// In en, this message translates to:
  /// **'The server rejected this document.'**
  String get serverRejected;

  /// No description provided for @retryOrDiscard.
  ///
  /// In en, this message translates to:
  /// **'Retry if the problem was fixed, or discard it.'**
  String get retryOrDiscard;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You’re offline. New documents are saved on this device.'**
  String get offlineBanner;

  /// No description provided for @waitingToSync.
  ///
  /// In en, this message translates to:
  /// **'Waiting to sync ({count})'**
  String waitingToSync(int count);

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncing;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @rejectedByServer.
  ///
  /// In en, this message translates to:
  /// **'Rejected by server'**
  String get rejectedByServer;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @addOneProduct.
  ///
  /// In en, this message translates to:
  /// **'Add at least one product'**
  String get addOneProduct;

  /// No description provided for @mustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Must be greater than 0'**
  String get mustBePositive;

  /// No description provided for @onlyOnHand.
  ///
  /// In en, this message translates to:
  /// **'Only {qty} {unit} on hand'**
  String onlyOnHand(int qty, String unit);

  /// No description provided for @mustNotBeZero.
  ///
  /// In en, this message translates to:
  /// **'Must not be 0'**
  String get mustNotBeZero;

  /// No description provided for @wouldGoNegative.
  ///
  /// In en, this message translates to:
  /// **'Would go below 0 (on hand {qty})'**
  String wouldGoNegative(int qty);

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @chooseGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseGallery;

  /// No description provided for @photoAttached.
  ///
  /// In en, this message translates to:
  /// **'Photo attached'**
  String get photoAttached;

  /// No description provided for @evidencePhotosCount.
  ///
  /// In en, this message translates to:
  /// **'Evidence photos ({count}/{max})'**
  String evidencePhotosCount(int count, int max);

  /// No description provided for @noPhotosAttached.
  ///
  /// In en, this message translates to:
  /// **'No photos attached'**
  String get noPhotosAttached;

  /// No description provided for @evidencePhoto.
  ///
  /// In en, this message translates to:
  /// **'Evidence photo'**
  String get evidencePhoto;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @deleteThisPhoto.
  ///
  /// In en, this message translates to:
  /// **'Delete this photo?'**
  String get deleteThisPhoto;

  /// No description provided for @removedFromTx.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from the transaction.'**
  String get removedFromTx;

  /// No description provided for @photoDeleted.
  ///
  /// In en, this message translates to:
  /// **'Photo deleted'**
  String get photoDeleted;

  /// No description provided for @deletePhoto.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get deletePhoto;

  /// No description provided for @scanItem.
  ///
  /// In en, this message translates to:
  /// **'Scan item'**
  String get scanItem;

  /// No description provided for @addedProduct.
  ///
  /// In en, this message translates to:
  /// **'Added {name}'**
  String addedProduct(String name);

  /// No description provided for @issueDraftForWo.
  ///
  /// In en, this message translates to:
  /// **'Issue draft created for the work order'**
  String get issueDraftForWo;

  /// No description provided for @savedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved on this device. It will sync when online.'**
  String get savedOnDevice;

  /// No description provided for @newReceive.
  ///
  /// In en, this message translates to:
  /// **'New receive'**
  String get newReceive;

  /// No description provided for @newIssue.
  ///
  /// In en, this message translates to:
  /// **'New issue'**
  String get newIssue;

  /// No description provided for @newAdjust.
  ///
  /// In en, this message translates to:
  /// **'New adjustment'**
  String get newAdjust;

  /// No description provided for @forWo.
  ///
  /// In en, this message translates to:
  /// **'For {code}'**
  String forWo(String code);

  /// No description provided for @hintReceive.
  ///
  /// In en, this message translates to:
  /// **'Quantities are added to stock.'**
  String get hintReceive;

  /// No description provided for @hintIssue.
  ///
  /// In en, this message translates to:
  /// **'Quantities are removed from stock.'**
  String get hintIssue;

  /// No description provided for @hintAdjust.
  ///
  /// In en, this message translates to:
  /// **'Enter the difference: positive adds, negative removes.'**
  String get hintAdjust;

  /// No description provided for @referenceOptional.
  ///
  /// In en, this message translates to:
  /// **'Reference no. (optional)'**
  String get referenceOptional;

  /// No description provided for @referenceHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. PO-2026-0001'**
  String get referenceHint;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @noProductsAdded.
  ///
  /// In en, this message translates to:
  /// **'No products added'**
  String get noProductsAdded;

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save as draft'**
  String get saveDraft;

  /// No description provided for @lineProjection.
  ///
  /// In en, this message translates to:
  /// **'{sku} · on hand {onHand} → {next} {unit}'**
  String lineProjection(String sku, int onHand, int next, String unit);

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decrease;

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increase;

  /// No description provided for @descReceive.
  ///
  /// In en, this message translates to:
  /// **'Goods coming into stock'**
  String get descReceive;

  /// No description provided for @descIssue.
  ///
  /// In en, this message translates to:
  /// **'Goods going out of stock'**
  String get descIssue;

  /// No description provided for @descAdjust.
  ///
  /// In en, this message translates to:
  /// **'Correct stock after a count'**
  String get descAdjust;

  /// No description provided for @stockOperations.
  ///
  /// In en, this message translates to:
  /// **'Stock operations'**
  String get stockOperations;

  /// No description provided for @noOperations.
  ///
  /// In en, this message translates to:
  /// **'No operations yet'**
  String get noOperations;

  /// No description provided for @noOperationsStatus.
  ///
  /// In en, this message translates to:
  /// **'No {status} operations'**
  String noOperationsStatus(String status);

  /// No description provided for @tapNewHint.
  ///
  /// In en, this message translates to:
  /// **'Tap New to receive, issue or adjust stock.'**
  String get tapNewHint;

  /// No description provided for @createdByAt.
  ///
  /// In en, this message translates to:
  /// **'{name} · {time}'**
  String createdByAt(String name, String time);

  /// No description provided for @operation.
  ///
  /// In en, this message translates to:
  /// **'Operation'**
  String get operation;

  /// No description provided for @cancelDraftQ.
  ///
  /// In en, this message translates to:
  /// **'Cancel this draft?'**
  String get cancelDraftQ;

  /// No description provided for @noStockEffect.
  ///
  /// In en, this message translates to:
  /// **'It will not affect stock.'**
  String get noStockEffect;

  /// No description provided for @cancelDraft.
  ///
  /// In en, this message translates to:
  /// **'Cancel draft'**
  String get cancelDraft;

  /// No description provided for @draftCancelled.
  ///
  /// In en, this message translates to:
  /// **'Draft cancelled'**
  String get draftCancelled;

  /// No description provided for @confirmTypeQ.
  ///
  /// In en, this message translates to:
  /// **'Confirm {type}?'**
  String confirmTypeQ(String type);

  /// No description provided for @confirmStockMsg.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Stock will be updated for 1 product. This cannot be undone.} other{Stock will be updated for {count} products. This cannot be undone.}}'**
  String confirmStockMsg(int count);

  /// No description provided for @stockUpdated.
  ///
  /// In en, this message translates to:
  /// **'Stock updated'**
  String get stockUpdated;

  /// No description provided for @waitingAdmin.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an admin to confirm'**
  String get waitingAdmin;

  /// No description provided for @createdBy.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get createdBy;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created at'**
  String get createdAt;

  /// No description provided for @confirmedBy.
  ///
  /// In en, this message translates to:
  /// **'Confirmed by'**
  String get confirmedBy;

  /// No description provided for @confirmedAt.
  ///
  /// In en, this message translates to:
  /// **'Confirmed at'**
  String get confirmedAt;

  /// No description provided for @itemsWithCount.
  ///
  /// In en, this message translates to:
  /// **'Items ({count})'**
  String itemsWithCount(int count);

  /// No description provided for @searchProduct.
  ///
  /// In en, this message translates to:
  /// **'Search product'**
  String get searchProduct;

  /// No description provided for @noProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get noProductsFound;

  /// No description provided for @txDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get txDraft;

  /// No description provided for @txConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get txConfirmed;

  /// No description provided for @txCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get txCancelled;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search name, SKU or barcode'**
  String get searchProducts;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @noMatchingProducts.
  ///
  /// In en, this message translates to:
  /// **'No matching products'**
  String get noMatchingProducts;

  /// No description provided for @tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or clear the filters.'**
  String get tryDifferentSearch;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @noProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get noProductsYet;

  /// No description provided for @productsByAdmin.
  ///
  /// In en, this message translates to:
  /// **'Products added by an admin will appear here.'**
  String get productsByAdmin;

  /// No description provided for @productsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 product} other{{count} products}}'**
  String productsCount(int count);

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// No description provided for @uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get uncategorized;

  /// No description provided for @barcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get barcode;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @onHand.
  ///
  /// In en, this message translates to:
  /// **'On hand'**
  String get onHand;

  /// No description provided for @minimumStock.
  ///
  /// In en, this message translates to:
  /// **'Minimum stock'**
  String get minimumStock;

  /// No description provided for @recentMovements.
  ///
  /// In en, this message translates to:
  /// **'Recent movements'**
  String get recentMovements;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all ({count})'**
  String viewAll(int count);

  /// No description provided for @noConfirmedMovements.
  ///
  /// In en, this message translates to:
  /// **'No confirmed movements yet'**
  String get noConfirmedMovements;

  /// No description provided for @couldNotLoadMovements.
  ///
  /// In en, this message translates to:
  /// **'Could not load movements'**
  String get couldNotLoadMovements;

  /// No description provided for @noProductBarcode.
  ///
  /// In en, this message translates to:
  /// **'No product with barcode {code}'**
  String noProductBarcode(String code);

  /// No description provided for @flashlight.
  ///
  /// In en, this message translates to:
  /// **'Flashlight'**
  String get flashlight;

  /// No description provided for @pointCamera.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a product barcode'**
  String get pointCamera;

  /// No description provided for @typeBarcode.
  ///
  /// In en, this message translates to:
  /// **'Type barcode'**
  String get typeBarcode;

  /// No description provided for @cameraPermission.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is needed to scan.\nAllow it in system settings, or type the barcode.'**
  String get cameraPermission;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera is not available on this device.'**
  String get cameraUnavailable;

  /// No description provided for @enterBarcode.
  ///
  /// In en, this message translates to:
  /// **'Enter barcode'**
  String get enterBarcode;

  /// No description provided for @find.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get find;

  /// No description provided for @woOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get woOpen;

  /// No description provided for @woInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get woInProgress;

  /// No description provided for @woSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get woSubmitted;

  /// No description provided for @woNeedsRevision.
  ///
  /// In en, this message translates to:
  /// **'Needs revision'**
  String get woNeedsRevision;

  /// No description provided for @woApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get woApproved;

  /// No description provided for @woCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get woCancelled;

  /// No description provided for @prLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get prLow;

  /// No description provided for @prNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get prNormal;

  /// No description provided for @prHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get prHigh;

  /// No description provided for @prUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get prUrgent;

  /// No description provided for @evBefore.
  ///
  /// In en, this message translates to:
  /// **'Before work'**
  String get evBefore;

  /// No description provided for @evAfter.
  ///
  /// In en, this message translates to:
  /// **'After work'**
  String get evAfter;

  /// No description provided for @evOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get evOther;

  /// No description provided for @evtCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get evtCreated;

  /// No description provided for @evtAssigned.
  ///
  /// In en, this message translates to:
  /// **'Assignment'**
  String get evtAssigned;

  /// No description provided for @evtStarted.
  ///
  /// In en, this message translates to:
  /// **'Work started'**
  String get evtStarted;

  /// No description provided for @evtChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get evtChecklist;

  /// No description provided for @evtPhotoAdded.
  ///
  /// In en, this message translates to:
  /// **'Photo added'**
  String get evtPhotoAdded;

  /// No description provided for @evtPhotoRemoved.
  ///
  /// In en, this message translates to:
  /// **'Photo removed'**
  String get evtPhotoRemoved;

  /// No description provided for @evtSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review'**
  String get evtSubmitted;

  /// No description provided for @evtChangesRequested.
  ///
  /// In en, this message translates to:
  /// **'Changes requested'**
  String get evtChangesRequested;

  /// No description provided for @evtMaterials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get evtMaterials;

  /// No description provided for @myJobs.
  ///
  /// In en, this message translates to:
  /// **'My jobs'**
  String get myJobs;

  /// No description provided for @reviewsJobs.
  ///
  /// In en, this message translates to:
  /// **'Reviews & jobs'**
  String get reviewsJobs;

  /// No description provided for @workOrders.
  ///
  /// In en, this message translates to:
  /// **'Work orders'**
  String get workOrders;

  /// No description provided for @searchWo.
  ///
  /// In en, this message translates to:
  /// **'Search code, title or site'**
  String get searchWo;

  /// No description provided for @noMatchingWo.
  ///
  /// In en, this message translates to:
  /// **'No matching work orders'**
  String get noMatchingWo;

  /// No description provided for @nothingToReview.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting for review'**
  String get nothingToReview;

  /// No description provided for @noActiveJobs.
  ///
  /// In en, this message translates to:
  /// **'No active jobs'**
  String get noActiveJobs;

  /// No description provided for @noWoYet.
  ///
  /// In en, this message translates to:
  /// **'No work orders yet'**
  String get noWoYet;

  /// No description provided for @unassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassigned;

  /// No description provided for @woCreated.
  ///
  /// In en, this message translates to:
  /// **'{code} created'**
  String woCreated(String code);

  /// No description provided for @newWorkOrder.
  ///
  /// In en, this message translates to:
  /// **'New work order'**
  String get newWorkOrder;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @titleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Install split AC – meeting room'**
  String get titleHint;

  /// No description provided for @site.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get site;

  /// No description provided for @addressOptional.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get addressOptional;

  /// No description provided for @instructionsOptional.
  ///
  /// In en, this message translates to:
  /// **'Instructions (optional)'**
  String get instructionsOptional;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @noDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get noDueDate;

  /// No description provided for @dueAt.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String dueAt(String date);

  /// No description provided for @overdueAt.
  ///
  /// In en, this message translates to:
  /// **'Overdue · {date}'**
  String overdueAt(String date);

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @clearDueDate.
  ///
  /// In en, this message translates to:
  /// **'Clear due date'**
  String get clearDueDate;

  /// No description provided for @checklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get checklist;

  /// No description provided for @noChecklist.
  ///
  /// In en, this message translates to:
  /// **'No checklist'**
  String get noChecklist;

  /// No description provided for @technician.
  ///
  /// In en, this message translates to:
  /// **'Technician'**
  String get technician;

  /// No description provided for @assignLater.
  ///
  /// In en, this message translates to:
  /// **'Assign later'**
  String get assignLater;

  /// No description provided for @reviewer.
  ///
  /// In en, this message translates to:
  /// **'Reviewer'**
  String get reviewer;

  /// No description provided for @anySupervisor.
  ///
  /// In en, this message translates to:
  /// **'Any supervisor'**
  String get anySupervisor;

  /// No description provided for @requiredPhotos.
  ///
  /// In en, this message translates to:
  /// **'Required photos'**
  String get requiredPhotos;

  /// No description provided for @materials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materials;

  /// No description provided for @noMaterialsOk.
  ///
  /// In en, this message translates to:
  /// **'None: work without parts is fine'**
  String get noMaterialsOk;

  /// No description provided for @skuOnHand.
  ///
  /// In en, this message translates to:
  /// **'{sku} · on hand {qty} {unit}'**
  String skuOnHand(String sku, int qty, String unit);

  /// No description provided for @createWorkOrder.
  ///
  /// In en, this message translates to:
  /// **'Create work order'**
  String get createWorkOrder;

  /// No description provided for @submitForReviewQ.
  ///
  /// In en, this message translates to:
  /// **'Submit for review?'**
  String get submitForReviewQ;

  /// No description provided for @submitExplain.
  ///
  /// In en, this message translates to:
  /// **'A supervisor will check the checklist and photos. You can’t change them after submitting unless changes are requested.'**
  String get submitExplain;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @submittedForReview.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review'**
  String get submittedForReview;

  /// No description provided for @approveWork.
  ///
  /// In en, this message translates to:
  /// **'Approve work'**
  String get approveWork;

  /// No description provided for @commentOptional.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get commentOptional;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @requestChanges.
  ///
  /// In en, this message translates to:
  /// **'Request changes'**
  String get requestChanges;

  /// No description provided for @whatToChange.
  ///
  /// In en, this message translates to:
  /// **'What needs to change?'**
  String get whatToChange;

  /// No description provided for @sendBack.
  ///
  /// In en, this message translates to:
  /// **'Send back'**
  String get sendBack;

  /// No description provided for @sentBack.
  ///
  /// In en, this message translates to:
  /// **'Sent back to the technician'**
  String get sentBack;

  /// No description provided for @cancelWorkOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel work order'**
  String get cancelWorkOrder;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @assignmentUpdated.
  ///
  /// In en, this message translates to:
  /// **'Assignment updated'**
  String get assignmentUpdated;

  /// No description provided for @photoAdded.
  ///
  /// In en, this message translates to:
  /// **'Photo added'**
  String get photoAdded;

  /// No description provided for @deletePhotoQ.
  ///
  /// In en, this message translates to:
  /// **'Delete photo?'**
  String get deletePhotoQ;

  /// No description provided for @removedFromWo.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from the work order.'**
  String get removedFromWo;

  /// No description provided for @workOrder.
  ///
  /// In en, this message translates to:
  /// **'Work order'**
  String get workOrder;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @codeActivity.
  ///
  /// In en, this message translates to:
  /// **'{code} activity'**
  String codeActivity(String code);

  /// No description provided for @noActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get noActivity;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @assignMenu.
  ///
  /// In en, this message translates to:
  /// **'Assign…'**
  String get assignMenu;

  /// No description provided for @cancelWoMenu.
  ///
  /// In en, this message translates to:
  /// **'Cancel work order…'**
  String get cancelWoMenu;

  /// No description provided for @backInProgress.
  ///
  /// In en, this message translates to:
  /// **'Back in progress'**
  String get backInProgress;

  /// No description provided for @workStarted.
  ///
  /// In en, this message translates to:
  /// **'Work started'**
  String get workStarted;

  /// No description provided for @resumeWork.
  ///
  /// In en, this message translates to:
  /// **'Resume work'**
  String get resumeWork;

  /// No description provided for @startWork.
  ///
  /// In en, this message translates to:
  /// **'Start work'**
  String get startWork;

  /// No description provided for @submitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get submitForReview;

  /// No description provided for @technicianIs.
  ///
  /// In en, this message translates to:
  /// **'Technician: {name}'**
  String technicianIs(String name);

  /// No description provided for @reviewerIs.
  ///
  /// In en, this message translates to:
  /// **'Reviewer: {name}'**
  String reviewerIs(String name);

  /// No description provided for @unassignedLower.
  ///
  /// In en, this message translates to:
  /// **'unassigned'**
  String get unassignedLower;

  /// No description provided for @anySupervisorLower.
  ///
  /// In en, this message translates to:
  /// **'any supervisor'**
  String get anySupervisorLower;

  /// No description provided for @checklistDone.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} done'**
  String checklistDone(int done, int total);

  /// No description provided for @noChecklistJob.
  ///
  /// In en, this message translates to:
  /// **'No checklist for this job'**
  String get noChecklistJob;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @requiredList.
  ///
  /// In en, this message translates to:
  /// **'Required: {list}'**
  String requiredList(String list);

  /// No description provided for @noMaterialsPlanned.
  ///
  /// In en, this message translates to:
  /// **'No materials planned'**
  String get noMaterialsPlanned;

  /// No description provided for @stockDocuments.
  ///
  /// In en, this message translates to:
  /// **'Stock documents'**
  String get stockDocuments;

  /// No description provided for @changesRequestedBy.
  ///
  /// In en, this message translates to:
  /// **'Changes requested by {name}: {note}'**
  String changesRequestedBy(String name, String note);

  /// No description provided for @changesRequested.
  ///
  /// In en, this message translates to:
  /// **'Changes requested: {note}'**
  String changesRequested(String note);

  /// No description provided for @approvedBy.
  ///
  /// In en, this message translates to:
  /// **'Approved by {name}'**
  String approvedBy(String name);

  /// No description provided for @cancelledReason.
  ///
  /// In en, this message translates to:
  /// **'Cancelled: {reason}'**
  String cancelledReason(String reason);

  /// No description provided for @waitingReview.
  ///
  /// In en, this message translates to:
  /// **'Waiting for review'**
  String get waitingReview;

  /// No description provided for @submittedAt.
  ///
  /// In en, this message translates to:
  /// **'submitted {time}'**
  String submittedAt(String time);

  /// No description provided for @beforeSubmit.
  ///
  /// In en, this message translates to:
  /// **'Before you can submit:'**
  String get beforeSubmit;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @noteIs.
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String noteIs(String note);

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @materialLine.
  ///
  /// In en, this message translates to:
  /// **'{sku} · planned {planned} · issued {issued} {unit}'**
  String materialLine(String sku, int planned, int issued, String unit);

  /// No description provided for @shortBy.
  ///
  /// In en, this message translates to:
  /// **'Short by {short} (on hand {onHand})'**
  String shortBy(int short, int onHand);

  /// No description provided for @toIssue.
  ///
  /// In en, this message translates to:
  /// **'{count} to issue'**
  String toIssue(int count);

  /// No description provided for @noPhotosYet.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get noPhotosYet;

  /// No description provided for @addReason.
  ///
  /// In en, this message translates to:
  /// **'Please add a reason'**
  String get addReason;

  /// No description provided for @moreWords.
  ///
  /// In en, this message translates to:
  /// **'A few more words, please'**
  String get moreWords;

  /// No description provided for @assign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get assign;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {detail}'**
  String uploadFailed(String detail);

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'Notifications, {count} unread'**
  String notificationsUnread(int count);

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get noNotifications;

  /// No description provided for @noNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Assignments and review results appear here. Pull down to check for new ones.'**
  String get noNotificationsHint;

  /// No description provided for @ntfAssigned.
  ///
  /// In en, this message translates to:
  /// **'{actor} assigned {code} to you'**
  String ntfAssigned(String actor, String code);

  /// No description provided for @ntfSubmitted.
  ///
  /// In en, this message translates to:
  /// **'{actor} submitted {code} for review'**
  String ntfSubmitted(String actor, String code);

  /// No description provided for @ntfChangesRequested.
  ///
  /// In en, this message translates to:
  /// **'{actor} asked for changes on {code}'**
  String ntfChangesRequested(String actor, String code);

  /// No description provided for @ntfApproved.
  ///
  /// In en, this message translates to:
  /// **'{actor} approved {code}'**
  String ntfApproved(String actor, String code);

  /// No description provided for @ntfCancelled.
  ///
  /// In en, this message translates to:
  /// **'{actor} cancelled {code}'**
  String ntfCancelled(String actor, String code);
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return L10nEn();
    case 'th':
      return L10nTh();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
