import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class AppStrings {
  final Locale locale;
  final Map<String, String> _localizedValues;

  AppStrings(this.locale, this._localizedValues);

  static AppStrings? of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings);
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  String get playlistManager => _localizedValues['playlistManager']!;
  String get playlistList => _localizedValues['playlistList']!;
  String get goToHomeToAdd => _localizedValues['goToHomeToAdd']!;
  String get addNewPlaylist => _localizedValues['addNewPlaylist']!;
  String get playlistName => _localizedValues['playlistName']!;
  String get playlistUrl => _localizedValues['playlistUrl']!;
  String get addFromUrl => _localizedValues['addFromUrl']!;
  String get fromFile => _localizedValues['fromFile']!;
  String get importing => _localizedValues['importing']!;
  String get noPlaylists => _localizedValues['noPlaylists']!;
  String get addFirstPlaylist => _localizedValues['addFirstPlaylist']!;
  String get deletePlaylist => _localizedValues['deletePlaylist']!;
  String get deleteConfirmation => _localizedValues['deleteConfirmation']!;
  String get cancel => _localizedValues['cancel']!;
  String get delete => _localizedValues['delete']!;
  String get actions => _localizedValues['actions']!;
  String get settings => _localizedValues['settings']!;
  String get language => _localizedValues['language']!;
  String get general => _localizedValues['general']!;
  String get followSystem => _localizedValues['followSystem']!;
  String get languageFollowSystem => _localizedValues['languageFollowSystem']!;
  String get theme => _localizedValues['theme']!;
  String get themeDark => _localizedValues['themeDark']!;
  String get themeLight => _localizedValues['themeLight']!;
  String get themeSystem => _localizedValues['themeSystem']!;
  String get themeChanged => _localizedValues['themeChanged']!;
  String get fontFamily => _localizedValues['fontFamily']!;
  String get fontFamilyDesc => _localizedValues['fontFamilyDesc']!;
  String get fontChanged => _localizedValues['fontChanged']!;
  String get unknown => _localizedValues['unknown']!;
  String get save => _localizedValues['save']!;
  String get error => _localizedValues['error']!;
  String get success => _localizedValues['success']!;
  String get active => _localizedValues['active']!;
  String get refresh => _localizedValues['refresh']!;
  String get updated => _localizedValues['updated']!;
  String get version => _localizedValues['version']!;
  String get categories => _localizedValues['categories']!;
  String get allChannels => _localizedValues['allChannels']!;
  String get channels => _localizedValues['channels']!;
  String get noChannelsFound => _localizedValues['noChannelsFound']!;
  String get removeFavorites => _localizedValues['removeFavorites']!;
  String get addFavorites => _localizedValues['addFavorites']!;
  String get channelInfo => _localizedValues['channelInfo']!;
  String get playback => _localizedValues['playback']!;
  String get autoPlay => _localizedValues['autoPlay']!;
  String get autoPlaySubtitle => _localizedValues['autoPlaySubtitle']!;
  String get hardwareDecoding => _localizedValues['hardwareDecoding']!;
  String get hardwareDecodingSubtitle =>
      _localizedValues['hardwareDecodingSubtitle']!;
  String get bufferSize => _localizedValues['bufferSize']!;
  String get seconds => _localizedValues['seconds']!;
  String get playlists => _localizedValues['playlists']!;
  String get autoRefresh => _localizedValues['autoRefresh']!;
  String get autoRefreshSubtitle => _localizedValues['autoRefreshSubtitle']!;
  String get refreshInterval => _localizedValues['refreshInterval']!;
  String get hours => _localizedValues['hours']!;
  String get days => _localizedValues['days']!;
  String get day => _localizedValues['day']!;
  String get rememberLastChannel => _localizedValues['rememberLastChannel']!;
  String get rememberLastChannelSubtitle =>
      _localizedValues['rememberLastChannelSubtitle']!;
  String get epg => _localizedValues['epg']!;
  String get enableEpg => _localizedValues['enableEpg']!;
  String get enableEpgSubtitle => _localizedValues['enableEpgSubtitle']!;
  String get epgUrl => _localizedValues['epgUrl']!;
  String get notConfigured => _localizedValues['notConfigured']!;
  String get parentalControl => _localizedValues['parentalControl']!;
  String get enableParentalControl =>
      _localizedValues['enableParentalControl']!;
  String get enableParentalControlSubtitle =>
      _localizedValues['enableParentalControlSubtitle']!;
  String get changePin => _localizedValues['changePin']!;
  String get changePinSubtitle => _localizedValues['changePinSubtitle']!;
  String get about => _localizedValues['about']!;
  String get platform => _localizedValues['platform']!;
  String get resetAllSettings => _localizedValues['resetAllSettings']!;
  String get resetSettingsSubtitle =>
      _localizedValues['resetSettingsSubtitle']!;
  String get enterEpgUrl => _localizedValues['enterEpgUrl']!;
  String get setPin => _localizedValues['setPin']!;
  String get enterPin => _localizedValues['enterPin']!;
  String get resetSettings => _localizedValues['resetSettings']!;
  String get resetConfirm => _localizedValues['resetConfirm']!;
  String get reset => _localizedValues['reset']!;
  String get pleaseEnterPlaylistName =>
      _localizedValues['pleaseEnterPlaylistName']!;
  String get pleaseEnterPlaylistUrl =>
      _localizedValues['pleaseEnterPlaylistUrl']!;
  String get playlistAdded => _localizedValues['playlistAdded']!;
  String get playlistRefreshed => _localizedValues['playlistRefreshed']!;
  String get playlistRefreshFailed =>
      _localizedValues['playlistRefreshFailed']!;
  String get playlistDeleted => _localizedValues['playlistDeleted']!;
  String get playlistImported => _localizedValues['playlistImported']!;
  String get urlCopied => _localizedValues['urlCopied']!;
  String get errorPickingFile => _localizedValues['errorPickingFile']!;
  String get minutesAgo => _localizedValues['minutesAgo']!;
  String get hoursAgo => _localizedValues['hoursAgo']!;
  String get daysAgo => _localizedValues['daysAgo']!;
  String get live => _localizedValues['live']!;
  String get buffering => _localizedValues['buffering']!;
  String get paused => _localizedValues['paused']!;
  String get loading => _localizedValues['loading']!;
  String get playbackError => _localizedValues['playbackError']!;
  String get retry => _localizedValues['retry']!;
  String get goBack => _localizedValues['goBack']!;
  String get playbackSettings => _localizedValues['playbackSettings']!;
  String get playbackSpeed => _localizedValues['playbackSpeed']!;
  String get shortcutsHint => _localizedValues['shortcutsHint']!;
  String get lotusIptv => _localizedValues['lotusIptv']!;
  String get professionalIptvPlayer =>
      _localizedValues['professionalIptvPlayer']!;
  String get searchChannels => _localizedValues['searchChannels']!;
  String get searchHint => _localizedValues['searchHint']!;
  String get typeToSearch => _localizedValues['typeToSearch']!;
  String get popularCategories => _localizedValues['popularCategories']!;
  String get sports => _localizedValues['sports']!;
  String get movies => _localizedValues['movies']!;
  String get news => _localizedValues['news']!;
  String get music => _localizedValues['music']!;
  String get kids => _localizedValues['kids']!;
  String get noResultsFound => _localizedValues['noResultsFound']!;
  String get noChannelsMatch => _localizedValues['noChannelsMatch']!;
  String get resultsFor => _localizedValues['resultsFor']!;
  String get favorites => _localizedValues['favorites']!;
  String get clearAll => _localizedValues['clearAll']!;
  String get noFavoritesYet => _localizedValues['noFavoritesYet']!;
  String get favoritesHint => _localizedValues['favoritesHint']!;
  String get noProgramInfo => _localizedValues['noProgramInfo']!;
  String get browseChannels => _localizedValues['browseChannels']!;
  String get removedFromFavorites => _localizedValues['removedFromFavorites']!;
  String get undo => _localizedValues['undo']!;
  String get clearAllFavorites => _localizedValues['clearAllFavorites']!;
  String get clearFavoritesConfirm =>
      _localizedValues['clearFavoritesConfirm']!;
  String get allFavoritesCleared => _localizedValues['allFavoritesCleared']!;
  String get home => _localizedValues['home']!;
  String get managePlaylists => _localizedValues['managePlaylists']!;
  String get noPlaylistsYet => _localizedValues['noPlaylistsYet']!;
  String get addFirstPlaylistHint => _localizedValues['addFirstPlaylistHint']!;
  String get addPlaylist => _localizedValues['addPlaylist']!;
  String get totalChannels => _localizedValues['totalChannels']!;

  // New translations
  String get volumeNormalization => _localizedValues['volumeNormalization']!;
  String get volumeNormalizationSubtitle =>
      _localizedValues['volumeNormalizationSubtitle']!;
  String get volumeBoost => _localizedValues['volumeBoost']!;
  String get noBoost => _localizedValues['noBoost']!;
  String get checkUpdate => _localizedValues['checkUpdate']!;
  String get checkUpdateSubtitle => _localizedValues['checkUpdateSubtitle']!;
  String get decodingMode => _localizedValues['decodingMode']!;
  String get decodingModeAuto => _localizedValues['decodingModeAuto']!;
  String get decodingModeHardware => _localizedValues['decodingModeHardware']!;
  String get decodingModeSoftware => _localizedValues['decodingModeSoftware']!;
  String get decodingModeAutoDesc => _localizedValues['decodingModeAutoDesc']!;
  String get decodingModeHardwareDesc =>
      _localizedValues['decodingModeHardwareDesc']!;
  String get decodingModeSoftwareDesc =>
      _localizedValues['decodingModeSoftwareDesc']!;
  String get channelMergeRule => _localizedValues['channelMergeRule']!;
  String get channelMergeRuleSubtitle => _localizedValues['channelMergeRuleSubtitle']!;
  String get channelMergeRuleSet => _localizedValues['channelMergeRuleSet']!;
  String get mergeByName => _localizedValues['mergeByName']!;
  String get mergeByNameDesc => _localizedValues['mergeByNameDesc']!;
  String get mergeByNameGroup => _localizedValues['mergeByNameGroup']!;
  String get mergeByNameGroupDesc => _localizedValues['mergeByNameGroupDesc']!;
  String get volumeBoostLow => _localizedValues['volumeBoostLow']!;
  String get volumeBoostSlightLow => _localizedValues['volumeBoostSlightLow']!;
  String get volumeBoostNormal => _localizedValues['volumeBoostNormal']!;
  String get volumeBoostSlightHigh =>
      _localizedValues['volumeBoostSlightHigh']!;
  String get volumeBoostHigh => _localizedValues['volumeBoostHigh']!;
  String get chinese => _localizedValues['chinese']!;
  String get english => _localizedValues['english']!;
  String get scanToImport => _localizedValues['scanToImport']!;
  String get importingPlaylist => _localizedValues['importingPlaylist']!;
  String get importSuccess => _localizedValues['importSuccess']!;
  String get importFailed => _localizedValues['importFailed']!;
  String get serverStartFailed => _localizedValues['serverStartFailed']!;
  String get processing => _localizedValues['processing']!;
  String get testChannel => _localizedValues['testChannel']!;
  String get unavailable => _localizedValues['unavailable']!;
  String get localFile => _localizedValues['localFile']!;

  // Backup and Restore
  String get backupAndRestore => _localizedValues['backupAndRestore']!;
  String get localBackup => _localizedValues['localBackup']!;
  String get webdavBackup => _localizedValues['webdavBackup']!;
  String get createBackup => _localizedValues['createBackup']!;
  String get restoreBackup => _localizedValues['restoreBackup']!;
  String get backupList => _localizedValues['backupList']!;
  String get noBackupsYet => _localizedValues['noBackupsYet']!;
  String get backupCreated => _localizedValues['backupCreated']!;
  String get backupFailed => _localizedValues['backupFailed']!;
  String get restoreSuccess => _localizedValues['restoreSuccess']!;
  String get restoreFailed => _localizedValues['restoreFailed']!;
  String get restoreWarning => _localizedValues['restoreWarning']!;
  String get restoreWarningMessage => _localizedValues['restoreWarningMessage']!;
  String get restoreConfirm => _localizedValues['restoreConfirm']!;
  String get backupInfo => _localizedValues['backupInfo']!;
  String get webdavConfig => _localizedValues['webdavConfig']!;
  String get serverUrl => _localizedValues['serverUrl']!;
  String get username => _localizedValues['username']!;
  String get password => _localizedValues['password']!;
  String get remotePath => _localizedValues['remotePath']!;
  String get testConnection => _localizedValues['testConnection']!;
  String get connectionSuccess => _localizedValues['connectionSuccess']!;
  String get connectionFailed => _localizedValues['connectionFailed']!;
  String get uploadToWebdav => _localizedValues['uploadToWebdav']!;
  String get downloadFromWebdav => _localizedValues['downloadFromWebdav']!;
  String get backupSize => _localizedValues['backupSize']!;
  String get backupDate => _localizedValues['backupDate']!;
  String get deleteBackup => _localizedValues['deleteBackup']!;
  String get deleteBackupConfirm => _localizedValues['deleteBackupConfirm']!;
  String get backupDeleted => _localizedValues['backupDeleted']!;
  String get creating => _localizedValues['creating']!;
  String get restoring => _localizedValues['restoring']!;
  String get uploading => _localizedValues['uploading']!;
  String get downloading => _localizedValues['downloading']!;
  String get versionIncompatible => _localizedValues['versionIncompatible']!;
  String get versionIncompatibleMessage => _localizedValues['versionIncompatibleMessage']!;
  String get willAutoMigrate => _localizedValues['willAutoMigrate']!;
  String get remoteConfig => _localizedValues['remoteConfig']!;
  String get scanToConfig => _localizedValues['scanToConfig']!;
  String get configTimeout => _localizedValues['configTimeout']!;
  String get configReceived => _localizedValues['configReceived']!;
  String get appVersion => _localizedValues['appVersion']!;
  String get backupTime => _localizedValues['backupTime']!;
  String get browse => _localizedValues['browse']!;
  String get webdavConfigTitle => _localizedValues['webdavConfigTitle']!;
  String get webdavConfigStep1 => _localizedValues['webdavConfigStep1']!;
  String get webdavConfigStep2 => _localizedValues['webdavConfigStep2']!;
  String get webdavConfigStep3 => _localizedValues['webdavConfigStep3']!;
  String get preparingConfig => _localizedValues['preparingConfig']!;
  String get configReady => _localizedValues['configReady']!;
  String get backupAndRestoreSubtitle => _localizedValues['backupAndRestoreSubtitle']!;
  // Home screen
  String get recommendedChannels => _localizedValues['recommendedChannels']!;
  String get watchHistory => _localizedValues['watchHistory']!;
  String get myFavorites => _localizedValues['myFavorites']!;
  String get continueWatching => _localizedValues['continueWatching']!;
  String get channelStats => _localizedValues['channelStats']!;
  String get noPlaylistYet => _localizedValues['noPlaylistYet']!;
  String get addM3uToStart => _localizedValues['addM3uToStart']!;
  String get search => _localizedValues['search']!;

  // Player hints
  String get playerHintTV => _localizedValues['playerHintTV']!;
  String get playerHintDesktop => _localizedValues['playerHintDesktop']!;

  // More UI strings
  String get more => _localizedValues['more']!;
  String get close => _localizedValues['close']!;
  String get startingServer => _localizedValues['startingServer']!;
  String get selectM3uFile => _localizedValues['selectM3uFile']!;
  String get noFileSelected => _localizedValues['noFileSelected']!;
  String get epgAutoApplied => _localizedValues['epgAutoApplied']!;
  String get addFirstPlaylistTV => _localizedValues['addFirstPlaylistTV']!;
  String get addPlaylistSubtitle => _localizedValues['addPlaylistSubtitle']!;
  String get importFromUsb => _localizedValues['importFromUsb']!;
  String get scanQrToImport => _localizedValues['scanQrToImport']!;
  String get playlistUrlHint => _localizedValues['playlistUrlHint']!;
  String get qrStep1 => _localizedValues['qrStep1']!;
  String get qrStep2 => _localizedValues['qrStep2']!;
  String get qrStep3 => _localizedValues['qrStep3']!;
  String get qrSearchStep1 => _localizedValues['qrSearchStep1']!;
  String get qrSearchStep2 => _localizedValues['qrSearchStep2']!;
  String get qrSearchStep3 => _localizedValues['qrSearchStep3']!;
  String get scanToSearch => _localizedValues['scanToSearch']!;

  // Player gestures and EPG
  String get nextChannel => _localizedValues['nextChannel']!;
  String get previousChannel => _localizedValues['previousChannel']!;
  String get source => _localizedValues['source']!;
  String get nowPlaying => _localizedValues['nowPlaying']!;
  String get endsInMinutes => _localizedValues['endsInMinutes']!;
  String get upNext => _localizedValues['upNext']!;

  // Update dialog
  String get newVersionAvailable => _localizedValues['newVersionAvailable']!;
  String get whatsNew => _localizedValues['whatsNew']!;
  String get updateLater => _localizedValues['updateLater']!;
  String get updateNow => _localizedValues['updateNow']!;
  String get noReleaseNotes => _localizedValues['noReleaseNotes']!;

  // Settings messages
  String get autoPlayEnabled => _localizedValues['autoPlayEnabled']!;
  String get autoPlayDisabled => _localizedValues['autoPlayDisabled']!;
  String get bufferStrength => _localizedValues['bufferStrength']!;
  String get showFps => _localizedValues['showFps']!;
  String get showFpsSubtitle => _localizedValues['showFpsSubtitle']!;
  String get fpsEnabled => _localizedValues['fpsEnabled']!;
  String get fpsDisabled => _localizedValues['fpsDisabled']!;
  String get showClock => _localizedValues['showClock']!;
  String get showClockSubtitle => _localizedValues['showClockSubtitle']!;
  String get clockEnabled => _localizedValues['clockEnabled']!;
  String get clockDisabled => _localizedValues['clockDisabled']!;
  String get showNetworkSpeed => _localizedValues['showNetworkSpeed']!;
  String get showNetworkSpeedSubtitle =>
      _localizedValues['showNetworkSpeedSubtitle']!;
  String get networkSpeedEnabled => _localizedValues['networkSpeedEnabled']!;
  String get networkSpeedDisabled => _localizedValues['networkSpeedDisabled']!;
  String get showVideoInfo => _localizedValues['showVideoInfo']!;
  String get showVideoInfoSubtitle =>
      _localizedValues['showVideoInfoSubtitle']!;
  String get videoInfoEnabled => _localizedValues['videoInfoEnabled']!;
  String get videoInfoDisabled => _localizedValues['videoInfoDisabled']!;
  String get enableMultiScreen => _localizedValues['enableMultiScreen']!;
  String get enableMultiScreenSubtitle =>
      _localizedValues['enableMultiScreenSubtitle']!;
  String get multiScreenEnabled => _localizedValues['multiScreenEnabled']!;
  String get multiScreenDisabled => _localizedValues['multiScreenDisabled']!;
  String get showMultiScreenChannelName =>
      _localizedValues['showMultiScreenChannelName']!;
  String get showMultiScreenChannelNameSubtitle =>
      _localizedValues['showMultiScreenChannelNameSubtitle']!;
  String get multiScreenChannelNameEnabled =>
      _localizedValues['multiScreenChannelNameEnabled']!;
  String get multiScreenChannelNameDisabled =>
      _localizedValues['multiScreenChannelNameDisabled']!;
  String get defaultScreenPosition =>
      _localizedValues['defaultScreenPosition']!;
  String get screenPosition1 => _localizedValues['screenPosition1']!;
  String get screenPosition2 => _localizedValues['screenPosition2']!;
  String get screenPosition3 => _localizedValues['screenPosition3']!;
  String get screenPosition4 => _localizedValues['screenPosition4']!;
  String get screenPositionDesc => _localizedValues['screenPositionDesc']!;
  String get screenPositionSet => _localizedValues['screenPositionSet']!;
  String get multiScreenMode => _localizedValues['multiScreenMode']!;
  String get notImplemented => _localizedValues['notImplemented']!;
  String get volumeNormalizationNotImplemented =>
      _localizedValues['volumeNormalizationNotImplemented']!;
  String get autoRefreshNotImplemented =>
      _localizedValues['autoRefreshNotImplemented']!;
  String get rememberLastChannelEnabled =>
      _localizedValues['rememberLastChannelEnabled']!;
  String get rememberLastChannelDisabled =>
      _localizedValues['rememberLastChannelDisabled']!;
  String get epgEnabledAndLoaded => _localizedValues['epgEnabledAndLoaded']!;
  String get epgEnabledButFailed => _localizedValues['epgEnabledButFailed']!;
  String get epgEnabledPleaseConfigure =>
      _localizedValues['epgEnabledPleaseConfigure']!;
  String get epgDisabled => _localizedValues['epgDisabled']!;
  String get weak => _localizedValues['weak']!;
  String get medium => _localizedValues['medium']!;
  String get strong => _localizedValues['strong']!;

  // Errors
  String get errorTimeout => _localizedValues['errorTimeout']!;
  String get errorNetwork => _localizedValues['errorNetwork']!;
  String get usingCachedSource => _localizedValues['usingCachedSource']!;

  // Multi-screen player strings
  String get backToPlayer => _localizedValues['backToPlayer']!;
  String get miniMode => _localizedValues['miniMode']!;
  String get exitMultiScreen => _localizedValues['exitMultiScreen']!;
  String get screenNumber => _localizedValues['screenNumber']!;
  String get clickToAddChannel => _localizedValues['clickToAddChannel']!;
  String get selectChannel => _localizedValues['selectChannel']!;

  // Channel test and update strings
  String get collapse => _localizedValues['collapse']!;
  String get channelCountLabel => _localizedValues['channelCountLabel']!;
  String get showOnlyFailed => _localizedValues['showOnlyFailed']!;
  String get moveToUnavailable => _localizedValues['moveToUnavailable']!;
  String get stopTest => _localizedValues['stopTest']!;
  String get startTest => _localizedValues['startTest']!;
  String get complete => _localizedValues['complete']!;
  String get runInBackground => _localizedValues['runInBackground']!;
  String get movedToUnavailable => _localizedValues['movedToUnavailable']!;
  String get checkingUpdate => _localizedValues['checkingUpdate']!;
  String get alreadyLatestVersion => _localizedValues['alreadyLatestVersion']!;
  String get checkUpdateFailed => _localizedValues['checkUpdateFailed']!;
  String get updateFailed => _localizedValues['updateFailed']!;
  String get downloadUpdate => _localizedValues['downloadUpdate']!;
  String get downloadFailed => _localizedValues['downloadFailed']!;
  String get downloadComplete => _localizedValues['downloadComplete']!;
  String get runInstallerNow => _localizedValues['runInstallerNow']!;
  String get later => _localizedValues['later']!;
  String get installNow => _localizedValues['installNow']!;
  String get deletedChannels => _localizedValues['deletedChannels']!;
  String get testing => _localizedValues['testing']!;
  String get channelAvailableRestored =>
      _localizedValues['channelAvailableRestored']!;
  String get testingInBackground => _localizedValues['testingInBackground']!;
  String get restoredToCategory => _localizedValues['restoredToCategory']!;
  String get dlnaCast => _localizedValues['dlnaCast']!;

  // More settings messages
  String get dlnaCasting => _localizedValues['dlnaCasting']!;
  String get enableDlnaService => _localizedValues['enableDlnaService']!;
  String get dlnaServiceStarted => _localizedValues['dlnaServiceStarted']!;
  String get allowOtherDevicesToCast =>
      _localizedValues['allowOtherDevicesToCast']!;
  String get dlnaServiceStartedMsg =>
      _localizedValues['dlnaServiceStartedMsg']!;
  String get dlnaServiceStoppedMsg =>
      _localizedValues['dlnaServiceStoppedMsg']!;
  String get dlnaServiceStartFailed =>
      _localizedValues['dlnaServiceStartFailed']!;
  String get parentalControlNotImplemented =>
      _localizedValues['parentalControlNotImplemented']!;
  String get changePinNotImplemented =>
      _localizedValues['changePinNotImplemented']!;
  String get decodingModeSet => _localizedValues['decodingModeSet']!;
  String get videoOutput => _localizedValues['videoOutput']!;
  String get videoOutputAuto => _localizedValues['videoOutputAuto']!;
  String get videoOutputLibmpv => _localizedValues['videoOutputLibmpv']!;
  String get videoOutputGpu => _localizedValues['videoOutputGpu']!;
  String get videoOutputAutoDesc => _localizedValues['videoOutputAutoDesc']!;
  String get videoOutputLibmpvDesc => _localizedValues['videoOutputLibmpvDesc']!;
  String get videoOutputGpuDesc => _localizedValues['videoOutputGpuDesc']!;
  String get videoOutputSet => _localizedValues['videoOutputSet']!;
  String get windowsHwdecMode => _localizedValues['windowsHwdecMode']!;
  String get windowsHwdecModeSet => _localizedValues['windowsHwdecModeSet']!;
  String get windowsHwdecAutoSafe => _localizedValues['windowsHwdecAutoSafe']!;
  String get windowsHwdecAutoCopy => _localizedValues['windowsHwdecAutoCopy']!;
  String get windowsHwdecD3d11va => _localizedValues['windowsHwdecD3d11va']!;
  String get windowsHwdecDxva2 => _localizedValues['windowsHwdecDxva2']!;
  String get windowsHwdecAutoSafeDesc =>
      _localizedValues['windowsHwdecAutoSafeDesc']!;
  String get windowsHwdecAutoCopyDesc =>
      _localizedValues['windowsHwdecAutoCopyDesc']!;
  String get windowsHwdecD3d11vaDesc =>
      _localizedValues['windowsHwdecD3d11vaDesc']!;
  String get windowsHwdecDxva2Desc =>
      _localizedValues['windowsHwdecDxva2Desc']!;
  String get allowSoftwareFallback =>
      _localizedValues['allowSoftwareFallback']!;
  String get allowSoftwareFallbackDesc =>
      _localizedValues['allowSoftwareFallbackDesc']!;
  String get allowSoftwareFallbackEnabled =>
      _localizedValues['allowSoftwareFallbackEnabled']!;
  String get allowSoftwareFallbackDisabled =>
      _localizedValues['allowSoftwareFallbackDisabled']!;
  String get fastBuffer => _localizedValues['fastBuffer']!;
  String get balancedBuffer => _localizedValues['balancedBuffer']!;
  String get stableBuffer => _localizedValues['stableBuffer']!;

  // Developer and debug settings
  String get developerAndDebug => _localizedValues['developerAndDebug']!;
  String get logLevel => _localizedValues['logLevel']!;
  String get logLevelSubtitle => _localizedValues['logLevelSubtitle']!;
  String get logLevelDebug => _localizedValues['logLevelDebug']!;
  String get logLevelRelease => _localizedValues['logLevelRelease']!;
  String get logLevelOff => _localizedValues['logLevelOff']!;
  String get logLevelDebugDesc => _localizedValues['logLevelDebugDesc']!;
  String get logLevelReleaseDesc => _localizedValues['logLevelReleaseDesc']!;
  String get logLevelOffDesc => _localizedValues['logLevelOffDesc']!;
  String get exportLogs => _localizedValues['exportLogs']!;
  String get exportLogsSubtitle => _localizedValues['exportLogsSubtitle']!;
  String get clearLogs => _localizedValues['clearLogs']!;
  String get clearLogsSubtitle => _localizedValues['clearLogsSubtitle']!;
  String get logFileLocation => _localizedValues['logFileLocation']!;
  String get logsCleared => _localizedValues['logsCleared']!;
  String get clearLogsConfirm => _localizedValues['clearLogsConfirm']!;
  String get clearLogsConfirmMessage =>
      _localizedValues['clearLogsConfirmMessage']!;
  String get bufferSizeNotImplemented =>
      _localizedValues['bufferSizeNotImplemented']!;
  String get volumeBoostSet => _localizedValues['volumeBoostSet']!;
  String get noBoostValue => _localizedValues['noBoostValue']!;
  String get epgUrlSavedAndLoaded => _localizedValues['epgUrlSavedAndLoaded']!;
  String get epgUrlSavedButFailed => _localizedValues['epgUrlSavedButFailed']!;
  String get epgUrlCleared => _localizedValues['epgUrlCleared']!;
  String get epgUrlSaved => _localizedValues['epgUrlSaved']!;
  String get pinNotImplemented => _localizedValues['pinNotImplemented']!;
  String get enter4DigitPin => _localizedValues['enter4DigitPin']!;
  String get allSettingsReset => _localizedValues['allSettingsReset']!;
  String get languageSwitchedToChinese =>
      _localizedValues['languageSwitchedToChinese']!;
  String get languageSwitchedToEnglish =>
      _localizedValues['languageSwitchedToEnglish']!;
  String get themeChangedMessage => _localizedValues['themeChangedMessage']!;
  String get defaultVersion => _localizedValues['defaultVersion']!;

  // Color scheme strings
  String get colorScheme => _localizedValues['colorScheme']!;
  String get selectColorScheme => _localizedValues['selectColorScheme']!;
  String get colorSchemeLotus => _localizedValues['colorSchemeLotus']!;
  String get colorSchemeOcean => _localizedValues['colorSchemeOcean']!;
  String get colorSchemeForest => _localizedValues['colorSchemeForest']!;
  String get colorSchemeSunset => _localizedValues['colorSchemeSunset']!;
  String get colorSchemeLavender => _localizedValues['colorSchemeLavender']!;
  String get colorSchemeMidnight => _localizedValues['colorSchemeMidnight']!;
  String get colorSchemeLotusLight =>
      _localizedValues['colorSchemeLotusLight']!;
  String get colorSchemeSky => _localizedValues['colorSchemeSky']!;
  String get colorSchemeSpring => _localizedValues['colorSchemeSpring']!;
  String get colorSchemeCoral => _localizedValues['colorSchemeCoral']!;
  String get colorSchemeViolet => _localizedValues['colorSchemeViolet']!;
  String get colorSchemeClassic => _localizedValues['colorSchemeClassic']!;
  String get colorSchemeDescLotus => _localizedValues['colorSchemeDescLotus']!;
  String get colorSchemeDescOcean => _localizedValues['colorSchemeDescOcean']!;
  String get colorSchemeDescForest =>
      _localizedValues['colorSchemeDescForest']!;
  String get colorSchemeDescSunset =>
      _localizedValues['colorSchemeDescSunset']!;
  String get colorSchemeDescLavender =>
      _localizedValues['colorSchemeDescLavender']!;
  String get colorSchemeDescMidnight =>
      _localizedValues['colorSchemeDescMidnight']!;
  String get colorSchemeDescLotusLight =>
      _localizedValues['colorSchemeDescLotusLight']!;
  String get colorSchemeDescSky => _localizedValues['colorSchemeDescSky']!;
  String get colorSchemeDescSpring =>
      _localizedValues['colorSchemeDescSpring']!;
  String get colorSchemeDescCoral => _localizedValues['colorSchemeDescCoral']!;
  String get colorSchemeDescViolet =>
      _localizedValues['colorSchemeDescViolet']!;
  String get colorSchemeDescClassic =>
      _localizedValues['colorSchemeDescClassic']!;
  String get colorSchemeChanged => _localizedValues['colorSchemeChanged']!;
  String get customColorPicker => _localizedValues['customColorPicker']!;
  String get selectedColor => _localizedValues['selectedColor']!;
  String get apply => _localizedValues['apply']!;
  String get customColorApplied => _localizedValues['customColorApplied']!;
  String get colorSchemeCustom => _localizedValues['colorSchemeCustom']!;

  // Local server web page strings
  String get importPlaylistTitle => _localizedValues['importPlaylistTitle']!;
  String get importPlaylistSubtitle =>
      _localizedValues['importPlaylistSubtitle']!;
  String get importFromUrlTitle => _localizedValues['importFromUrlTitle']!;
  String get importFromFileTitle => _localizedValues['importFromFileTitle']!;
  String get playlistNameOptional => _localizedValues['playlistNameOptional']!;
  String get enterPlaylistUrl => _localizedValues['enterPlaylistUrl']!;
  String get importUrlButton => _localizedValues['importUrlButton']!;
  String get selectFile => _localizedValues['selectFile']!;
  String get fileNameOptional => _localizedValues['fileNameOptional']!;
  String get fileUploadButton => _localizedValues['fileUploadButton']!;
  String get or => _localizedValues['or']!;
  String get pleaseEnterUrl => _localizedValues['pleaseEnterUrl']!;
  String get sentToTV => _localizedValues['sentToTV']!;
  String get sendFailed => _localizedValues['sendFailed']!;
  String get networkError => _localizedValues['networkError']!;

  // Simple menu
  String get simpleMenu => _localizedValues['simpleMenu']!;
  String get simpleMenuSubtitle => _localizedValues['simpleMenuSubtitle']!;
  String get simpleMenuEnabled => _localizedValues['simpleMenuEnabled']!;
  String get simpleMenuDisabled => _localizedValues['simpleMenuDisabled']!;

  // Progress bar mode
  String get progressBarMode => _localizedValues['progressBarMode']!;
  String get progressBarModeSubtitle =>
      _localizedValues['progressBarModeSubtitle']!;
  String get progressBarModeAuto => _localizedValues['progressBarModeAuto']!;
  String get progressBarModeAlways =>
      _localizedValues['progressBarModeAlways']!;
  String get progressBarModeNever => _localizedValues['progressBarModeNever']!;
  String get progressBarModeAutoDesc =>
      _localizedValues['progressBarModeAutoDesc']!;
  String get progressBarModeAlwaysDesc =>
      _localizedValues['progressBarModeAlwaysDesc']!;
  String get progressBarModeNeverDesc =>
      _localizedValues['progressBarModeNeverDesc']!;
  String get progressBarModeSet => _localizedValues['progressBarModeSet']!;

  // Seek step settings
  String get seekStepSeconds => _localizedValues['seekStepSeconds']!;
  String get seekStepSecondsSubtitle => _localizedValues['seekStepSecondsSubtitle']!;
  String get seekStep5s => _localizedValues['seekStep5s']!;
  String get seekStep10s => _localizedValues['seekStep10s']!;
  String get seekStep30s => _localizedValues['seekStep30s']!;
  String get seekStep60s => _localizedValues['seekStep60s']!;
  String get seekStep120s => _localizedValues['seekStep120s']!;
  String get seekStepSet => _localizedValues['seekStepSet']!;

  // Home display settings
  String get showWatchHistoryOnHome => _localizedValues['showWatchHistoryOnHome']!;
  String get showWatchHistoryOnHomeSubtitle => _localizedValues['showWatchHistoryOnHomeSubtitle']!;
  String get showFavoritesOnHome => _localizedValues['showFavoritesOnHome']!;
  String get showFavoritesOnHomeSubtitle => _localizedValues['showFavoritesOnHomeSubtitle']!;
  String get watchHistoryOnHomeEnabled => _localizedValues['watchHistoryOnHomeEnabled']!;
  String get watchHistoryOnHomeDisabled => _localizedValues['watchHistoryOnHomeDisabled']!;
  String get favoritesOnHomeEnabled => _localizedValues['favoritesOnHomeEnabled']!;
  String get favoritesOnHomeDisabled => _localizedValues['favoritesOnHomeDisabled']!;

  // Map access for dynamic keys if needed
  String operator [](String key) => _localizedValues[key] ?? key;
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(
        AppStrings(locale, _getValues(locale)));
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;

  Map<String, String> _getValues(Locale locale) {
    if (locale.languageCode == 'zh') {
      return _zhValues;
    } else {
      return _enValues;
    }
  }

  static const Map<String, String> _zhValues = {
    'playlistManager': '播放列表管理',
    'playlistList': '直播源',
    'goToHomeToAdd': '前往首页添加播放列表',
    'addNewPlaylist': '添加新播放列表',
    'playlistName': '播放列表名称',
    'playlistUrl': 'M3U/M3U8/TXT 链接',
    'addFromUrl': '从链接添加',
    'fromFile': '从文件导入',
    'importing': '导入中...',
    'noPlaylists': '暂无播放列表',
    'addFirstPlaylist': '请在上方添加您的第一个播放列表',
    'deletePlaylist': '删除播放列表',
    'deleteConfirmation': '确定要删除 "{name}" 吗？这将同时删除该列表下的所有频道。',
    'cancel': '取消',
    'delete': '删除',
    'actions': '操作',
    'settings': '设置',
    'language': '语言',
    'general': '通用',
    'followSystem': '跟随系统',
    'languageFollowSystem': '已设置为跟随系统语言',
    'theme': '主题',
    'themeDark': '深色',
    'themeLight': '明亮',
    'themeSystem': '跟随系统',
    'themeChanged': '主题已切换',
    'fontFamily': '字体',
    'fontFamilyDesc': '选择应用显示字体',
    'fontChanged': '字体已更改为 {font}',
    'unknown': '未知',
    'save': '保存',
    'error': '错误',
    'success': '成功',
    'active': '当前使用',
    'refresh': '刷新',
    'updated': '更新于',
    'version': '版本',
    'categories': '分类',
    'allChannels': '所有频道',
    'channels': '频道',
    'noChannelsFound': '未找到频道',
    'removeFavorites': '取消收藏',
    'addFavorites': '添加到收藏',
    'channelInfo': '频道信息',
    'playback': '播放',
    'autoPlay': '启动时自动播放',
    'autoPlaySubtitle': '应用启动后自动继续播放上次观看的内容',
    'hardwareDecoding': '硬件解码',
    'hardwareDecodingSubtitle': '使用硬件加速进行视频播放',
    'bufferSize': '缓冲大小',
    'seconds': '秒',
    'playlists': '播放列表',
    'autoRefresh': '自动刷新',
    'autoRefreshSubtitle': '定期自动更新播放列表',
    'refreshInterval': '刷新间隔',
    'hours': '小时',
    'days': '天',
    'day': '天',
    'rememberLastChannel': '记忆最后播放',
    'rememberLastChannelSubtitle': '恢复播放上次观看的频道',
    'epg': '电子节目单 (EPG)',
    'enableEpg': '启用 EPG',
    'enableEpgSubtitle': '显示频道节目信息',
    'epgUrl': 'EPG 链接',
    'notConfigured': '未配置',
    'parentalControl': '家长控制',
    'enableParentalControl': '启用家长控制',
    'enableParentalControlSubtitle': '观看特定内容需要 PIN 码',
    'changePin': '修改 PIN 码',
    'changePinSubtitle': '更新家长控制 PIN 码',
    'about': '关于',
    'platform': '平台',
    'resetAllSettings': '重置所有设置',
    'resetSettingsSubtitle': '恢复所有设置到默认值',
    'enterEpgUrl': '输入 EPG XMLTV 链接',
    'setPin': '设置 PIN 码',
    'enterPin': '输入 4 位 PIN 码',
    'resetSettings': '重置设置',
    'resetConfirm': '确定要将所有设置重置为默认值吗？',
    'reset': '重置',
    'pleaseEnterPlaylistName': '请输入播放列表名称',
    'pleaseEnterPlaylistUrl': '请输入播放列表链接',
    'playlistAdded': '已添加 "{name}"',
    'playlistRefreshed': '播放列表刷新成功',
    'playlistRefreshFailed': '播放列表刷新失败',
    'playlistDeleted': '播放列表已删除',
    'playlistImported': '播放列表导入成功',
    'urlCopied': 'URL已复制到剪贴板',
    'errorPickingFile': '选择文件时出错: {error}',
    'minutesAgo': '分钟前',
    'hoursAgo': '小时前',
    'daysAgo': '天前',
    'live': '直播',
    'buffering': '缓冲中...',
    'paused': '暂停',
    'loading': '加载中...',
    'playbackError': '播放错误',
    'retry': '重试',
    'goBack': '返回',
    'playbackSettings': '播放设置',
    'playbackSpeed': '播放速度',
    'shortcutsHint': '左/右: 快进退 • 上/下: 换台 • 回车: 播放/暂停 • M: 静音',
    'lotusIptv': 'Lotus IPTV',
    'professionalIptvPlayer': '专业 IPTV 播放器',
    'searchChannels': '搜索频道',
    'searchHint': '搜索频道...',
    'typeToSearch': '输入频道名称或分类进行搜索',
    'popularCategories': '热门分类',
    'sports': '体育',
    'movies': '电影',
    'news': '新闻',
    'music': '音乐',
    'kids': '少儿',
    'noResultsFound': '未找到结果',
    'noChannelsMatch': '没有找到匹配 "{query}" 的频道',
    'resultsFor': '搜索 "{query}" 的结果: {count} 个',
    'favorites': '收藏',
    'clearAll': '清空',
    'noFavoritesYet': '暂无收藏',
    'favoritesHint': '长按频道可添加到收藏',
    'noProgramInfo': '暂无节目信息',
    'browseChannels': '浏览频道',
    'removedFromFavorites': '已从收藏中移除 "{name}"',
    'undo': '撤销',
    'clearAllFavorites': '清空所有收藏',
    'clearFavoritesConfirm': '确定要清空所有收藏的频道吗？',
    'allFavoritesCleared': '所有收藏已清空',
    'home': '首页',
    'managePlaylists': '管理播放列表',
    'noPlaylistsYet': '暂无播放列表',
    'addFirstPlaylistHint': '添加您的第一个 M3U 播放列表以开始观看',
    'addPlaylist': '添加播放列表',
    'totalChannels': '频道总数',
    // New translations
    'volumeNormalization': '音量平衡',
    'volumeNormalizationSubtitle': '自动调节不同频道的音量差异',
    'volumeBoost': '音量增益',
    'noBoost': '无增益',
    'checkUpdate': '检查更新',
    'checkUpdateSubtitle': '检查是否有新版本可用',
    'decodingMode': '解码模式',
    'decodingModeAuto': '自动',
    'decodingModeHardware': '硬解',
    'decodingModeSoftware': '软解',
    'decodingModeAutoDesc': '自动选择最佳方式，推荐',
    'decodingModeHardwareDesc': '强制硬解，部分设备可能报错',
    'decodingModeSoftwareDesc': '使用CPU解码，兼容性好但耗电',
    'channelMergeRule': '频道合并规则',
    'channelMergeRuleSubtitle': '控制如何合并重复频道',
    'channelMergeRuleSet': '频道合并规则已设置为：{rule}',
    'mergeByName': '按名称合并',
    'mergeByNameDesc': '合并所有组中同名的频道',
    'mergeByNameGroup': '按名称+组名合并',
    'mergeByNameGroupDesc': '仅合并同名且同组的频道',
    'volumeBoostLow': '大幅降低音量',
    'volumeBoostSlightLow': '略微降低音量',
    'volumeBoostNormal': '保持原始音量',
    'volumeBoostSlightHigh': '略微提高音量',
    'volumeBoostHigh': '大幅提高音量',
    'chinese': '中文',
    'english': '英文',
    'scanToImport': '扫码导入播放列表',
    'importingPlaylist': '正在导入',
    'importSuccess': '导入成功',
    'importFailed': '导入失败',
    'serverStartFailed': '无法启动本地服务器，请检查网络连接',
    'processing': '正在处理，请稍候...',
    'testChannel': '测试频道',
    'unavailable': '失效',
    'localFile': '本地文件',
    // Backup and Restore
    'backupAndRestore': '备份与恢复',
    'localBackup': '本地备份',
    'webdavBackup': 'WebDAV 云备份',
    'createBackup': '创建备份',
    'restoreBackup': '恢复备份',
    'backupList': '备份列表',
    'noBackupsYet': '暂无备份',
    'backupCreated': '备份创建成功',
    'backupFailed': '备份失败',
    'restoreSuccess': '恢复成功，应用将重启',
    'restoreFailed': '恢复失败',
    'restoreWarning': '恢复警告',
    'restoreWarningMessage': '恢复将完全覆盖当前所有数据，建议先创建当前数据的备份。是否继续？',
    'restoreConfirm': '确认恢复',
    'backupInfo': '备份信息',
    'webdavConfig': 'WebDAV 配置',
    'serverUrl': '服务器地址',
    'username': '用户名',
    'password': '密码',
    'remotePath': '远程路径',
    'testConnection': '测试连接',
    'connectionSuccess': '连接成功',
    'connectionFailed': '连接失败',
    'uploadToWebdav': '备份到 WebDAV',
    'downloadFromWebdav': '从 WebDAV 恢复',
    'backupSize': '大小',
    'backupDate': '日期',
    'deleteBackup': '删除备份',
    'deleteBackupConfirm': '确定要删除此备份吗？',
    'backupDeleted': '备份已删除',
    'creating': '创建中...',
    'restoring': '恢复中...',
    'uploading': '上传中...',
    'downloading': '下载中...',
    'versionIncompatible': '版本不兼容',
    'versionIncompatibleMessage': '备份文件来自更新版本的应用，请先更新应用到最新版本',
    'willAutoMigrate': '备份版本较旧，恢复后将自动升级数据库',
    'remoteConfig': '远程配置',
    'scanToConfig': '扫码配置 WebDAV',
    'configTimeout': '配置超时',
    'configReceived': '配置已接收',
    'appVersion': '应用版本',
    'backupTime': '备份时间',
    'browse': '浏览',
    'webdavConfigTitle': '扫码配置 WebDAV',
    'webdavConfigStep1': '使用手机扫描二维码',
    'webdavConfigStep2': '在网页中输入 WebDAV 配置',
    'webdavConfigStep3': '点击保存，电视自动接收配置',
    'preparingConfig': '正在准备配置...',
    'configReady': '配置已就绪',
    'backupAndRestoreSubtitle': '备份和恢复应用数据',
    // Home screen
    'recommendedChannels': '推荐频道',
    'watchHistory': '观看记录',
    'myFavorites': '我的收藏',
    'continueWatching': '继续观看',
    'channelStats': '{channels} 频道 · {categories} 分类 · {favorites} 收藏',
    'noPlaylistYet': '还没有播放列表',
    'addM3uToStart': '添加 M3U 播放列表开始观看',
    'search': '搜索',
    // Player hints
    'playerHintTV': '↑↓ 切换频道 · ←→ 切换源 · 长按← 分类 · OK 播放/暂停 · 长按OK 收藏',
    'playerHintDesktop': '左/右: 快进退 · 上/下: 换台 · 回车: 播放/暂停 · M: 静音',
    // More UI strings
    'more': '更多',
    'close': '关闭',
    'startingServer': '正在启动服务...',
    'selectM3uFile': '请在文件管理器中选择播放列表文件（M3U/M3U8/TXT）',
    'noFileSelected': '未选择文件。请确保您的设备已连接USB存储设备或已配置网络存储。',
    'epgAutoApplied': '已自动应用EPG源',
    'addFirstPlaylistTV': '通过USB设备导入或扫码导入',
    'addPlaylistSubtitle': '导入 M3U/M3U8 播放列表，支持 URL 或本地文件',
    'importFromUsb': '从USB或本地存储导入',
    'scanQrToImport': '使用手机扫描二维码导入',
    'playlistUrlHint': 'M3U/M3U8/TXT 链接',
    'qrStep1': '使用手机扫描左侧二维码',
    'qrStep2': '在网页中输入链接或上传文件',
    'qrStep3': '点击导入，电视自动接收',
    'qrSearchStep1': '使用手机扫描左侧二维码',
    'qrSearchStep2': '在网页中输入搜索内容',
    'qrSearchStep3': '搜索结果将自动显示在电视上',
    'scanToSearch': '扫码搜索',
    // Player gestures and EPG
    'nextChannel': '下一频道',
    'previousChannel': '上一频道',
    'source': '源',
    'nowPlaying': '正在播放',
    'endsInMinutes': '{minutes}分钟后结束',
    'upNext': '即将播放',
    // Update dialog
    'newVersionAvailable': '发现新版本',
    'whatsNew': '更新内容',
    'updateLater': '稍后更新',
    'updateNow': '立即更新',
    'noReleaseNotes': '暂无更新说明',
    // Settings messages
    'autoPlayEnabled': '已启用启动时自动播放',
    'autoPlayDisabled': '已关闭启动时自动播放',
    'bufferStrength': '缓冲强度',
    'showFps': '显示 FPS',
    'showFpsSubtitle': '在播放器右上角显示帧率',
    'fpsEnabled': '已启用 FPS 显示',
    'fpsDisabled': '已关闭 FPS 显示',
    'showClock': '显示时间',
    'showClockSubtitle': '在播放器右上角显示当前时间',
    'clockEnabled': '已启用时间显示',
    'clockDisabled': '已关闭时间显示',
    'showNetworkSpeed': '显示网速',
    'showNetworkSpeedSubtitle': '在播放器右上角显示下行网速',
    'networkSpeedEnabled': '已启用网速显示',
    'networkSpeedDisabled': '已关闭网速显示',
    'showVideoInfo': '显示分辨率',
    'showVideoInfoSubtitle': '在播放器右上角显示视频分辨率和码率',
    'videoInfoEnabled': '已启用分辨率显示',
    'videoInfoDisabled': '已关闭分辨率显示',
    'enableMultiScreen': '多屏模式',
    'enableMultiScreenSubtitle': '启用2x2分屏同时观看多个频道',
    'multiScreenEnabled': '已启用多屏模式',
    'multiScreenDisabled': '已关闭多屏模式',
    'showMultiScreenChannelName': '显示频道名称',
    'showMultiScreenChannelNameSubtitle': '在多屏播放时显示频道名称',
    'multiScreenChannelNameEnabled': '多屏频道名称显示已启用',
    'multiScreenChannelNameDisabled': '多屏频道名称显示已关闭',
    'defaultScreenPosition': '默认播放位置',
    'screenPosition1': '左上角 (1)',
    'screenPosition2': '右上角 (2)',
    'screenPosition3': '左下角 (3)',
    'screenPosition4': '右下角 (4)',
    'screenPositionDesc': '选择点击频道时默认使用的播放位置：',
    'screenPositionSet': '默认播放位置已设置为：{position}',
    'multiScreenMode': '多屏模式',
    // Multi-screen player strings
    'backToPlayer': '返回',
    'miniMode': '迷你模式',
    'exitMultiScreen': '退出分屏',
    'screenNumber': '屏幕 {number}',
    'clickToAddChannel': '点击添加频道',
    'selectChannel': '选择频道',
    // Channel test and update strings
    'collapse': '收起',
    'channelCountLabel': '{count} 频道',
    'showOnlyFailed': '仅显示失败 ({count})',
    'moveToUnavailable': '移至失效分类',
    'stopTest': '停止测试',
    'startTest': '开始测试',
    'complete': '完成',
    'runInBackground': '后台执行',
    'movedToUnavailable': '已将 {count} 个失效频道移至失效分类',
    'checkingUpdate': '正在检查更新...',
    'alreadyLatestVersion': '已是最新版本',
    'checkUpdateFailed': '检查更新失败: {error}',
    'updateFailed': '更新失败: {error}',
    'downloadUpdate': '下载更新',
    'downloadFailed': '下载失败: {error}',
    'downloadComplete': '下载完成',
    'runInstallerNow': '是否立即运行安装程序？',
    'later': '稍后',
    'installNow': '立即安装',
    'deletedChannels': '已删除 {count} 个失效频道',
    'testing': '正在测试: {name}',
    'channelAvailableRestored': '{name} 可用，已恢复到 "{group}" 分类',
    'testingInBackground': '测试已转入后台，剩余 {count} 个频道',
    'restoredToCategory': '已恢复 {name} 到原分类',
    'dlnaCast': 'DLNA 投屏',
    'notImplemented': '(未实现)',
    'volumeNormalizationNotImplemented': '音量标准化尚未实现，设置不会生效',
    'autoRefreshNotImplemented': '自动刷新尚未实现，设置不会生效',
    'rememberLastChannelEnabled': '已启用记住上次频道',
    'rememberLastChannelDisabled': '已关闭记住上次频道',
    'epgEnabledAndLoaded': 'EPG 已启用并加载成功',
    'epgEnabledButFailed': 'EPG 已启用，但加载失败',
    'epgEnabledPleaseConfigure': 'EPG 已启用，请配置 EPG 链接',
    'epgDisabled': 'EPG 已关闭',
    'weak': '弱',
    'medium': '中',
    'strong': '强',
    // More settings messages
    'dlnaCasting': 'DLNA 投屏',
    'enableDlnaService': '启用 DLNA 服务',
    'dlnaServiceStarted': '已启动: {deviceName}',
    'allowOtherDevicesToCast': '允许其他设备投屏到本设备',
    'dlnaServiceStartedMsg': 'DLNA 服务已启动',
    'dlnaServiceStoppedMsg': 'DLNA 服务已停止',
    'dlnaServiceStartFailed': 'DLNA 服务启动失败，请检查网络连接',
    'parentalControlNotImplemented': '家长控制尚未实现，设置不会生效',
    'changePinNotImplemented': '(未实现)',
    'decodingModeSet': '解码模式已设置为: {mode}',
    'videoOutput': '视频输出',
    'videoOutputAuto': '自动（嵌入）',
    'videoOutputLibmpv': 'libmpv（嵌入）',
    'videoOutputGpu': 'GPU（独立窗口）',
    'videoOutputAutoDesc': '默认嵌入输出（推荐）',
    'videoOutputLibmpvDesc': '使用 libmpv 嵌入渲染（推荐）',
    'videoOutputGpuDesc': '使用 GPU 输出，可能打开独立窗口',
    'videoOutputSet': '视频输出已设置为: {mode}',
    'windowsHwdecMode': 'Windows 硬解方案',
    'windowsHwdecModeSet': 'Windows 硬解方案已设置为: {mode}',
    'windowsHwdecAutoSafe': '自动（安全）',
    'windowsHwdecAutoCopy': '自动（拷回）',
    'windowsHwdecD3d11va': 'D3D11VA',
    'windowsHwdecDxva2': 'DXVA2',
    'windowsHwdecAutoSafeDesc': '推荐。仅使用安全的硬解器。',
    'windowsHwdecAutoCopyDesc': '兼容性更好，但拷回会更慢。',
    'windowsHwdecD3d11vaDesc': '优先 D3D11VA，部分显卡可能失败。',
    'windowsHwdecDxva2Desc': '优先 DXVA2，适合旧显卡。',
    'allowSoftwareFallback': '允许软解回退',
    'allowSoftwareFallbackDesc': '硬解失败时自动切换到软解。',
    'allowSoftwareFallbackEnabled': '已开启软解回退',
    'allowSoftwareFallbackDisabled': '已关闭软解回退',
    'fastBuffer': '快速 (切换快，可能卡顿)',
    'balancedBuffer': '平衡',
    'stableBuffer': '稳定 (切换慢，不易卡顿)',
    'bufferSizeNotImplemented': '缓冲大小设置尚未实现，设置不会生效',
    'volumeBoostSet': '音量增益已设置为 {value}',
    'noBoostValue': '无增益',
    'epgUrlSavedAndLoaded': 'EPG 链接已保存并加载成功',
    'epgUrlSavedButFailed': 'EPG 链接已保存，但加载失败',
    'epgUrlCleared': 'EPG 链接已清除',
    'epgUrlSaved': 'EPG 链接已保存',
    'pinNotImplemented': '家长控制尚未实现，PIN 设置不会生效',
    'enter4DigitPin': '请输入4位数字PIN',
    'allSettingsReset': '所有设置已重置为默认值',
    'languageSwitchedToChinese': '语言已切换为中文',
    'languageSwitchedToEnglish': '语言已切换为英文',
    'themeChangedMessage': '主题已切换: {theme}',
    'defaultVersion': '默认版本',
    // Color scheme strings
    'colorScheme': '配色方案',
    'selectColorScheme': '选择配色方案',
    'colorSchemeLotus': '莲花',
    'colorSchemeOcean': '海洋',
    'colorSchemeForest': '森林',
    'colorSchemeSunset': '日落',
    'colorSchemeLavender': '薰衣草',
    'colorSchemeMidnight': '午夜',
    'colorSchemeLotusLight': '莲花亮色',
    'colorSchemeSky': '天空',
    'colorSchemeSpring': '春天',
    'colorSchemeCoral': '珊瑚',
    'colorSchemeViolet': '紫罗兰',
    'colorSchemeClassic': '经典',
    'colorSchemeDescLotus': '优雅、现代、品牌色',
    'colorSchemeDescOcean': '冷静、专业、护眼',
    'colorSchemeDescForest': '自然、舒适、护眼',
    'colorSchemeDescSunset': '温暖、活力、醒目',
    'colorSchemeDescLavender': '神秘、高贵、柔和',
    'colorSchemeDescMidnight': '深邃、专注、低调',
    'colorSchemeDescLotusLight': '优雅、现代、品牌色',
    'colorSchemeDescSky': '清新、明亮、舒适',
    'colorSchemeDescSpring': '生机、活力、护眼',
    'colorSchemeDescCoral': '温暖、友好、醒目',
    'colorSchemeDescViolet': '优雅、柔和、高贵',
    'colorSchemeDescClassic': '简洁、专业、通用',
    'colorSchemeChanged': '配色方案已切换为: {scheme}',
    'customColorPicker': '自定义颜色选择器',
    'selectedColor': '选中的颜色',
    'apply': '应用',
    'customColorApplied': '自定义颜色已应用',
    'colorSchemeCustom': '自定义',
    // Local server web page strings
    'importPlaylistTitle': '导入播放列表',
    'importPlaylistSubtitle': '导入播放列表到您的电视',
    'importFromUrlTitle': '从链接导入',
    'importFromFileTitle': '从文件导入',
    'playlistNameOptional': '播放列表名称（可选）',
    'enterPlaylistUrl': '请输入 M3U/M3U8/TXT 链接',
    'importUrlButton': '导入链接',
    'selectFile': '选择文件',
    'fileNameOptional': '播放列表名称（可选）',
    'fileUploadButton': '上传文件',
    'or': '或者',
    'pleaseEnterUrl': '请输入链接',
    'sentToTV': '已发送到电视，请在电视上查看',
    'sendFailed': '发送失败',
    'networkError': '网络错误，请确保设备在同一局域网',
    // Simple menu
    'simpleMenu': '简易菜单',
    'simpleMenuSubtitle': '菜单栏保持收起状态（不自动展开）',
    'simpleMenuEnabled': '已启用简易菜单',
    'simpleMenuDisabled': '已关闭简易菜单',
    // Progress bar mode
    'progressBarMode': '进度条显示',
    'progressBarModeSubtitle': '控制播放进度条的显示方式',
    'progressBarModeAuto': '自动检测',
    'progressBarModeAlways': '始终显示',
    'progressBarModeNever': '不显示',
    'progressBarModeAutoDesc': '根据内容类型自动显示（点播/回放显示，直播隐藏）',
    'progressBarModeAlwaysDesc': '所有内容都显示进度条',
    'progressBarModeNeverDesc': '所有内容都不显示进度条',
    'progressBarModeSet': '进度条显示已设置为：{mode}',

    // Seek step settings
    'seekStepSeconds': '快进/快退跨度',
    'seekStepSecondsSubtitle': '设置长按左右键时的跳转秒数',
    'seekStep5s': '5秒',
    'seekStep10s': '10秒',
    'seekStep30s': '30秒',
    'seekStep60s': '60秒',
    'seekStep120s': '120秒',
    'seekStepSet': '快进/快退跨度已设置为：{seconds}秒',

    // Home display settings
    'showWatchHistoryOnHome': '首页显示观看记录',
    'showWatchHistoryOnHomeSubtitle': '在首页显示最近观看的频道',
    'showFavoritesOnHome': '首页显示收藏夹',
    'showFavoritesOnHomeSubtitle': '在首页显示收藏的频道',
    'watchHistoryOnHomeEnabled': '首页观看记录显示已启用',
    'watchHistoryOnHomeDisabled': '首页观看记录显示已关闭',
    'favoritesOnHomeEnabled': '首页收藏夹显示已启用',
    'favoritesOnHomeDisabled': '首页收藏夹显示已关闭',

    // Developer and debug settings
    'developerAndDebug': '开发者与调试',
    'logLevel': '日志级别',
    'logLevelSubtitle': '选择日志记录级别',
    'logLevelDebug': '调试',
    'logLevelRelease': '发布',
    'logLevelOff': '关闭',
    'logLevelDebugDesc': '记录所有日志，用于开发调试',
    'logLevelReleaseDesc': '只记录警告和错误，推荐',
    'logLevelOffDesc': '不记录任何日志',
    'exportLogs': '导出日志',
    'exportLogsSubtitle': '扫码查看或导出日志文件',
    'clearLogs': '清空日志',
    'clearLogsSubtitle': '删除所有日志文件',
    'logFileLocation': '日志文件位置',
    'logsCleared': '日志已清空',
    'clearLogsConfirm': '清空日志',
    'clearLogsConfirmMessage': '确定要删除所有日志文件吗？',
    'errorTimeout': '连接超时，请检查网络或链接',
    'errorNetwork': '网络连接失败，请检查网络',
    'usingCachedSource': '远程源不可用，使用缓存源',
  };

  static const Map<String, String> _enValues = {
    'playlistManager': 'Playlist Manager',
    'playlistList': 'Sources',
    'goToHomeToAdd': 'Go to Home to add playlists',
    'addNewPlaylist': 'Add New Playlist',
    'playlistName': 'Playlist Name',
    'playlistUrl': 'M3U/M3U8/TXT URL',
    'addFromUrl': 'Add from URL',
    'fromFile': 'From File',
    'importing': 'Importing...',
    'noPlaylists': 'No Playlists',
    'addFirstPlaylist': 'Add your first playlist above',
    'deletePlaylist': 'Delete Playlist',
    'deleteConfirmation':
        'Are you sure you want to delete "{name}"? This will also remove all channels from this playlist.',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'actions': 'Actions',
    'settings': 'Settings',
    'language': 'Language',
    'general': 'General',
    'followSystem': 'Follow System',
    'languageFollowSystem': 'Set to follow system language',
    'theme': 'Theme',
    'themeDark': 'Dark',
    'themeLight': 'Light',
    'themeSystem': 'Follow System',
    'themeChanged': 'Theme changed',
    'fontFamily': 'Font Family',
    'fontFamilyDesc': 'Choose application display font',
    'fontChanged': 'Font changed to {font}',
    'unknown': 'Unknown',
    'save': 'Save',
    'error': 'Error',
    'success': 'Success',
    'active': 'ACTIVE',
    'refresh': 'Refresh',
    'updated': 'Updated',
    'version': 'Version',
    'categories': 'Categories',
    'allChannels': 'All Channels',
    'channels': 'channels',
    'noChannelsFound': 'No channels found',
    'removeFavorites': 'Remove from Favorites',
    'addFavorites': 'Add to Favorites',
    'channelInfo': 'Channel Info',
    'playback': 'Playback',
    'autoPlay': 'Auto-play on Startup',
    'autoPlaySubtitle':
        'Automatically continue playing last watched content when app starts',
    'hardwareDecoding': 'Hardware Decoding',
    'hardwareDecodingSubtitle': 'Use hardware acceleration for video playback',
    'bufferSize': 'Buffer Size',
    'seconds': 'seconds',
    'playlists': 'Playlists',
    'autoRefresh': 'Auto-refresh',
    'autoRefreshSubtitle': 'Automatically update playlists periodically',
    'refreshInterval': 'Refresh Interval',
    'hours': 'hours',
    'days': 'days',
    'day': 'day',
    'rememberLastChannel': 'Remember Last Channel',
    'rememberLastChannelSubtitle': 'Resume playback from last watched channel',
    'epg': 'EPG (Electronic Program Guide)',
    'enableEpg': 'Enable EPG',
    'enableEpgSubtitle': 'Show program information for channels',
    'epgUrl': 'EPG URL',
    'notConfigured': 'Not configured',
    'parentalControl': 'Parental Control',
    'enableParentalControl': 'Enable Parental Control',
    'enableParentalControlSubtitle': 'Require PIN to access certain content',
    'changePin': 'Change PIN',
    'changePinSubtitle': 'Update your parental control PIN',
    'about': 'About',
    'platform': 'Platform',
    'resetAllSettings': 'Reset All Settings',
    'resetSettingsSubtitle': 'Restore all settings to default values',
    'enterEpgUrl': 'Enter EPG XMLTV URL',
    'setPin': 'Set PIN',
    'enterPin': 'Enter 4-digit PIN',
    'resetSettings': 'Reset Settings',
    'resetConfirm':
        'Are you sure you want to reset all settings to their default values?',
    'reset': 'Reset',
    'pleaseEnterPlaylistName': 'Please enter a playlist name',
    'pleaseEnterPlaylistUrl': 'Please enter a playlist URL',
    'playlistAdded': 'Added "{name}"',
    'playlistRefreshed': 'Playlist refreshed successfully',
    'playlistRefreshFailed': 'Failed to refresh playlist',
    'playlistDeleted': 'Playlist deleted',
    'playlistImported': 'Playlist imported successfully',
    'urlCopied': 'URL copied to clipboard',
    'errorPickingFile': 'Error picking file: {error}',
    'minutesAgo': 'm ago',
    'hoursAgo': 'h ago',
    'daysAgo': 'd ago',
    'live': 'LIVE',
    'buffering': 'Buffering...',
    'paused': 'Paused',
    'loading': 'Loading...',
    'playbackError': 'Playback Error',
    'retry': 'Retry',
    'goBack': 'Go Back',
    'playbackSettings': 'Playback Settings',
    'playbackSpeed': 'Playback Speed',
    'shortcutsHint':
        'Left/Right: Seek • Up/Down: Change Channel • Enter: Play/Pause • M: Mute',
    'lotusIptv': 'Lotus IPTV',
    'professionalIptvPlayer': 'Professional IPTV Player',
    'searchChannels': 'Search Channels',
    'searchHint': 'Search channels...',
    'typeToSearch': 'Type to search by channel name or category',
    'popularCategories': 'Popular Categories',
    'sports': 'Sports',
    'movies': 'Movies',
    'news': 'News',
    'music': 'Music',
    'kids': 'Kids',
    'noResultsFound': 'No Results Found',
    'noChannelsMatch': 'No channels match "{query}"',
    'resultsFor': '{count} result(s) for "{query}"',
    'favorites': 'Favorites',
    'clearAll': 'Clear All',
    'noFavoritesYet': 'No Favorites Yet',
    'favoritesHint': 'Long press on a channel to add it to favorites',
    'noProgramInfo': 'No Program Info',
    'browseChannels': 'Browse Channels',
    'removedFromFavorites': 'Removed "{name}" from favorites',
    'undo': 'Undo',
    'clearAllFavorites': 'Clear All Favorites',
    'clearFavoritesConfirm':
        'Are you sure you want to remove all channels from your favorites?',
    'allFavoritesCleared': 'All favorites cleared',
    'home': 'Home',
    'managePlaylists': 'Manage Playlists',
    'noPlaylistsYet': 'No Playlists Yet',
    'addFirstPlaylistHint': 'Add your first M3U playlist to start watching',
    'addPlaylist': 'Add Playlist',
    'totalChannels': 'Total Channels',
    // New translations
    'volumeNormalization': 'Volume Normalization',
    'volumeNormalizationSubtitle':
        'Auto-adjust volume differences between channels',
    'volumeBoost': 'Volume Boost',
    'noBoost': 'No boost',
    'checkUpdate': 'Check for Updates',
    'checkUpdateSubtitle': 'Check if a new version is available',
    'decodingMode': 'Decoding Mode',
    'decodingModeAuto': 'Auto',
    'decodingModeHardware': 'Hardware',
    'decodingModeSoftware': 'Software',
    'decodingModeAutoDesc': 'Automatically choose best option. Recommended.',
    'decodingModeHardwareDesc':
        'Force MediaCodec. May cause errors on some devices.',
    'decodingModeSoftwareDesc':
        'Use CPU decoding. More compatible but uses more power.',
    'channelMergeRule': 'Channel Merge Rule',
    'channelMergeRuleSubtitle': 'Control how duplicate channels are merged',
    'channelMergeRuleSet': 'Channel merge rule set to: {rule}',
    'mergeByName': 'Merge by Name',
    'mergeByNameDesc': 'Merge channels with same name across all groups',
    'mergeByNameGroup': 'Merge by Name + Group',
    'mergeByNameGroupDesc': 'Only merge channels with same name AND group',
    'volumeBoostLow': 'Significantly lower volume',
    'volumeBoostSlightLow': 'Slightly lower volume',
    'volumeBoostNormal': 'Keep original volume',
    'volumeBoostSlightHigh': 'Slightly higher volume',
    'volumeBoostHigh': 'Significantly higher volume',
    'chinese': '中文',
    'english': 'English',
    'scanToImport': 'Scan to Import Playlist',
    'importingPlaylist': 'Importing',
    'importSuccess': 'Import successful',
    'importFailed': 'Import failed',
    'serverStartFailed':
        'Failed to start local server. Please check network connection.',
    'processing': 'Processing, please wait...',
    'testChannel': 'Test Channel',
    'unavailable': 'Unavailable',
    'localFile': 'Local File',
    // Backup and Restore
    'backupAndRestore': 'Backup & Restore',
    'localBackup': 'Local Backup',
    'webdavBackup': 'WebDAV Cloud Backup',
    'createBackup': 'Create Backup',
    'restoreBackup': 'Restore Backup',
    'backupList': 'Backup List',
    'noBackupsYet': 'No backups yet',
    'backupCreated': 'Backup created successfully',
    'backupFailed': 'Backup failed',
    'restoreSuccess': 'Restore successful, app will restart',
    'restoreFailed': 'Restore failed',
    'restoreWarning': 'Restore Warning',
    'restoreWarningMessage': 'Restore will completely overwrite all current data. It is recommended to create a backup of current data first. Continue?',
    'restoreConfirm': 'Confirm Restore',
    'backupInfo': 'Backup Info',
    'webdavConfig': 'WebDAV Configuration',
    'serverUrl': 'Server URL',
    'username': 'Username',
    'password': 'Password',
    'remotePath': 'Remote Path',
    'testConnection': 'Test Connection',
    'connectionSuccess': 'Connection successful',
    'connectionFailed': 'Connection failed',
    'uploadToWebdav': 'Backup to WebDAV',
    'downloadFromWebdav': 'Restore from WebDAV',
    'backupSize': 'Size',
    'backupDate': 'Date',
    'deleteBackup': 'Delete Backup',
    'deleteBackupConfirm': 'Are you sure you want to delete this backup?',
    'backupDeleted': 'Backup deleted',
    'creating': 'Creating...',
    'restoring': 'Restoring...',
    'uploading': 'Uploading...',
    'downloading': 'Downloading...',
    'versionIncompatible': 'Version Incompatible',
    'versionIncompatibleMessage': 'Backup is from a newer version of the app. Please update the app first.',
    'willAutoMigrate': 'Backup is from an older version, database will be automatically upgraded after restore',
    'remoteConfig': 'Remote Configuration',
    'scanToConfig': 'Scan to Configure WebDAV',
    'configTimeout': 'Configuration timeout',
    'configReceived': 'Configuration received',
    'appVersion': 'App Version',
    'backupTime': 'Backup Time',
    'browse': 'Browse',
    'webdavConfigTitle': 'Scan to Configure WebDAV',
    'webdavConfigStep1': 'Scan the QR code with your phone',
    'webdavConfigStep2': 'Enter WebDAV configuration in the web page',
    'webdavConfigStep3': 'Click save, TV will receive configuration automatically',
    'preparingConfig': 'Preparing configuration...',
    'configReady': 'Configuration ready',
    'backupAndRestoreSubtitle': 'Backup and restore application data',
    // Home screen
    'recommendedChannels': 'Recommended',
    'watchHistory': 'Watch History',
    'myFavorites': 'My Favorites',
    'continueWatching': 'Continue Watching',
    'channelStats':
        '{channels} channels · {categories} categories · {favorites} favorites',
    'noPlaylistYet': 'No Playlists Yet',
    'addM3uToStart': 'Add M3U playlist to start watching',
    'search': 'Search',
    // Player hints
    'playerHintTV':
        '↑↓ Switch Channel · ←→ Switch Source · Hold← Categories · OK Play/Pause · Hold OK Favorite',
    'playerHintDesktop':
        'Left/Right: Seek · Up/Down: Switch · Enter: Play/Pause · M: Mute',
    // More UI strings
    'more': 'More',
    'close': 'Close',
    'startingServer': 'Starting server...',
    'selectM3uFile': 'Please select a playlist file (M3U/M3U8/TXT)',
    'noFileSelected':
        'No file selected. Please ensure your device has USB storage or network storage configured.',
    'epgAutoApplied': 'EPG source auto-applied',
    'addFirstPlaylistTV': 'Import via USB or scan QR code',
    'addPlaylistSubtitle': 'Import M3U/M3U8 playlist from URL or file',
    'importFromUsb': 'Import from USB or local storage',
    'scanQrToImport': 'Use your phone to scan QR code',
    'playlistUrlHint': 'M3U/M3U8/TXT URL',
    'qrStep1': 'Scan the QR code with your phone',
    'qrStep2': 'Enter URL or upload file on the webpage',
    'qrStep3': 'Click import, TV receives automatically',
    'qrSearchStep1': 'Scan the QR code with your phone',
    'qrSearchStep2': 'Enter search query on the webpage',
    'qrSearchStep3': 'Results will appear on TV automatically',
    'scanToSearch': 'Scan to Search',
    // Player gestures and EPG
    'nextChannel': 'Next channel',
    'previousChannel': 'Previous channel',
    'source': 'Source',
    'nowPlaying': 'Now playing',
    'endsInMinutes': 'Ends in {minutes} min',
    'upNext': 'Up next',
    // Update dialog
    'newVersionAvailable': 'New version available',
    'whatsNew': 'What\'s new',
    'updateLater': 'Update later',
    'updateNow': 'Update now',
    'noReleaseNotes': 'No release notes',
    // Settings messages
    'autoPlayEnabled': 'Auto-play on startup enabled',
    'autoPlayDisabled': 'Auto-play on startup disabled',
    'bufferStrength': 'Buffer Strength',
    'showFps': 'Show FPS',
    'showFpsSubtitle': 'Show frame rate in top-right corner of player',
    'fpsEnabled': 'FPS display enabled',
    'fpsDisabled': 'FPS display disabled',
    'showClock': 'Show Clock',
    'showClockSubtitle': 'Show current time in top-right corner of player',
    'clockEnabled': 'Clock display enabled',
    'clockDisabled': 'Clock display disabled',
    'showNetworkSpeed': 'Show Network Speed',
    'showNetworkSpeedSubtitle':
        'Show download speed in top-right corner of player',
    'networkSpeedEnabled': 'Network speed display enabled',
    'networkSpeedDisabled': 'Network speed display disabled',
    'showVideoInfo': 'Show Resolution',
    'showVideoInfoSubtitle':
        'Show video resolution and bitrate in top-right corner',
    'videoInfoEnabled': 'Resolution display enabled',
    'videoInfoDisabled': 'Resolution display disabled',
    'enableMultiScreen': 'Multi-Screen Mode',
    'enableMultiScreenSubtitle':
        'Enable 2x2 split screen for simultaneous viewing',
    'multiScreenEnabled': 'Multi-screen mode enabled',
    'multiScreenDisabled': 'Multi-screen mode disabled',
    'showMultiScreenChannelName': 'Show Channel Names',
    'showMultiScreenChannelNameSubtitle':
        'Display channel names in multi-screen playback',
    'multiScreenChannelNameEnabled':
        'Multi-screen channel name display enabled',
    'multiScreenChannelNameDisabled':
        'Multi-screen channel name display disabled',
    'defaultScreenPosition': 'Default Screen Position',
    'screenPosition1': 'Top Left (1)',
    'screenPosition2': 'Top Right (2)',
    'screenPosition3': 'Bottom Left (3)',
    'screenPosition4': 'Bottom Right (4)',
    'screenPositionDesc':
        'Choose which screen position to use by default when clicking a channel:',
    'screenPositionSet': 'Default screen position set to: {position}',
    'multiScreenMode': 'Multi-Screen Mode',
    // Multi-screen player strings
    'backToPlayer': 'Back',
    'miniMode': 'Mini Mode',
    'exitMultiScreen': 'Exit Multi-Screen',
    'screenNumber': 'Screen {number}',
    'clickToAddChannel': 'Click to add channel',
    'selectChannel': 'Select Channel',
    // Channel test and update strings
    'collapse': 'Collapse',
    'channelCountLabel': '{count} channels',
    'showOnlyFailed': 'Show only failed ({count})',
    'moveToUnavailable': 'Move to Unavailable',
    'stopTest': 'Stop Test',
    'startTest': 'Start Test',
    'complete': 'Complete',
    'runInBackground': 'Run in Background',
    'movedToUnavailable':
        'Moved {count} unavailable channels to Unavailable category',
    'checkingUpdate': 'Checking for updates...',
    'alreadyLatestVersion': 'Already up to date',
    'checkUpdateFailed': 'Check update failed: {error}',
    'updateFailed': 'Update failed: {error}',
    'downloadUpdate': 'Download Update',
    'downloadFailed': 'Download failed: {error}',
    'downloadComplete': 'Download Complete',
    'runInstallerNow': 'Run installer now?',
    'later': 'Later',
    'installNow': 'Install Now',
    'deletedChannels': 'Deleted {count} unavailable channels',
    'testing': 'Testing: {name}',
    'channelAvailableRestored':
        '{name} available, restored to "{group}" category',
    'testingInBackground': 'Testing in background, {count} channels remaining',
    'restoredToCategory': 'Restored {name} to original category',
    'dlnaCast': 'DLNA Cast',
    'notImplemented': '(Not implemented)',
    'volumeNormalizationNotImplemented':
        'Volume normalization not implemented, setting will not take effect',
    'autoRefreshNotImplemented':
        'Auto-refresh not implemented, setting will not take effect',
    'rememberLastChannelEnabled': 'Remember last channel enabled',
    'rememberLastChannelDisabled': 'Remember last channel disabled',
    'epgEnabledAndLoaded': 'EPG enabled and loaded successfully',
    'epgEnabledButFailed': 'EPG enabled but failed to load',
    'epgEnabledPleaseConfigure': 'EPG enabled, please configure EPG URL',
    'epgDisabled': 'EPG disabled',
    'weak': 'Weak',
    'medium': 'Medium',
    'strong': 'Strong',
    // More settings messages
    'dlnaCasting': 'DLNA Casting',
    'enableDlnaService': 'Enable DLNA Service',
    'dlnaServiceStarted': 'Started: {deviceName}',
    'allowOtherDevicesToCast': 'Allow other devices to cast to this device',
    'dlnaServiceStartedMsg': 'DLNA service started',
    'dlnaServiceStoppedMsg': 'DLNA service stopped',
    'dlnaServiceStartFailed':
        'Failed to start DLNA service, please check network connection',
    'parentalControlNotImplemented':
        'Parental control not implemented, setting will not take effect',
    'changePinNotImplemented': '(Not implemented)',
    'decodingModeSet': 'Decoding mode set to: {mode}',
    'videoOutput': 'Video Output',
    'videoOutputAuto': 'Auto (Embedded)',
    'videoOutputLibmpv': 'libmpv (Embedded)',
    'videoOutputGpu': 'GPU (External Window)',
    'videoOutputAutoDesc': 'Default embedded output (recommended)',
    'videoOutputLibmpvDesc': 'Use libmpv embedded renderer (recommended)',
    'videoOutputGpuDesc': 'Use GPU output; may open a separate window',
    'videoOutputSet': 'Video output set to: {mode}',
    'windowsHwdecMode': 'Windows HW Decoder',
    'windowsHwdecModeSet': 'Windows HW decode set to: {mode}',
    'windowsHwdecAutoSafe': 'Auto (Safe)',
    'windowsHwdecAutoCopy': 'Auto (Copy)',
    'windowsHwdecD3d11va': 'D3D11VA',
    'windowsHwdecDxva2': 'DXVA2',
    'windowsHwdecAutoSafeDesc':
        'Recommended. Only use safe hardware decoders.',
    'windowsHwdecAutoCopyDesc':
        'More compatible, but slower due to copy-back.',
    'windowsHwdecD3d11vaDesc': 'Prefer D3D11VA. Can fail on some GPUs.',
    'windowsHwdecDxva2Desc': 'Prefer DXVA2. Legacy path for older GPUs.',
    'allowSoftwareFallback': 'Allow Software Fallback',
    'allowSoftwareFallbackDesc':
        'If hardware decode fails, automatically switch to software decoding.',
    'allowSoftwareFallbackEnabled': 'Software fallback enabled',
    'allowSoftwareFallbackDisabled': 'Software fallback disabled',
    'fastBuffer': 'Fast (Quick switching, may stutter)',
    'balancedBuffer': 'Balanced',
    'stableBuffer': 'Stable (Slow switching, less stuttering)',
    'bufferSizeNotImplemented':
        'Buffer size setting not implemented, setting will not take effect',
    'volumeBoostSet': 'Volume boost set to {value}',
    'noBoostValue': 'No boost',
    'epgUrlSavedAndLoaded': 'EPG URL saved and loaded successfully',
    'epgUrlSavedButFailed': 'EPG URL saved but failed to load',
    'epgUrlCleared': 'EPG URL cleared',
    'epgUrlSaved': 'EPG URL saved',
    'pinNotImplemented':
        'Parental control not implemented, PIN setting will not take effect',
    'enter4DigitPin': 'Please enter 4-digit PIN',
    'allSettingsReset': 'All settings have been reset to default values',
    'languageSwitchedToChinese': 'Language switched to Chinese',
    'languageSwitchedToEnglish': 'Language switched to English',
    'themeChangedMessage': 'Theme changed: {theme}',
    'defaultVersion': 'Default version',
    // Color scheme strings
    'colorScheme': 'Color Scheme',
    'selectColorScheme': 'Select Color Scheme',
    'colorSchemeLotus': 'Lotus',
    'colorSchemeOcean': 'Ocean',
    'colorSchemeForest': 'Forest',
    'colorSchemeSunset': 'Sunset',
    'colorSchemeLavender': 'Lavender',
    'colorSchemeMidnight': 'Midnight',
    'colorSchemeLotusLight': 'Lotus Light',
    'colorSchemeSky': 'Sky',
    'colorSchemeSpring': 'Spring',
    'colorSchemeCoral': 'Coral',
    'colorSchemeViolet': 'Violet',
    'colorSchemeClassic': 'Classic',
    'colorSchemeDescLotus': 'Elegant, modern, brand color',
    'colorSchemeDescOcean': 'Calm, professional, eye-friendly',
    'colorSchemeDescForest': 'Natural, comfortable, eye-friendly',
    'colorSchemeDescSunset': 'Warm, energetic, eye-catching',
    'colorSchemeDescLavender': 'Mysterious, noble, soft',
    'colorSchemeDescMidnight': 'Deep, focused, low-key',
    'colorSchemeDescLotusLight': 'Elegant, modern, brand color',
    'colorSchemeDescSky': 'Fresh, bright, comfortable',
    'colorSchemeDescSpring': 'Vibrant, energetic, eye-friendly',
    'colorSchemeDescCoral': 'Warm, friendly, eye-catching',
    'colorSchemeDescViolet': 'Elegant, soft, noble',
    'colorSchemeDescClassic': 'Simple, professional, universal',
    'colorSchemeChanged': 'Color scheme changed to: {scheme}',
    'customColorPicker': 'Custom Color Picker',
    'selectedColor': 'Selected Color',
    'apply': 'Apply',
    'customColorApplied': 'Custom color applied',
    'colorSchemeCustom': 'Custom',
    // Local server web page strings
    'importPlaylistTitle': 'Import Playlist',
    'importPlaylistSubtitle': 'Import playlist to your TV',
    'importFromUrlTitle': 'Import from URL',
    'importFromFileTitle': 'Import from File',
    'playlistNameOptional': 'Playlist name (optional)',
    'enterPlaylistUrl': 'Please enter M3U/M3U8/TXT URL',
    'importUrlButton': 'Import URL',
    'selectFile': 'Select File',
    'fileNameOptional': 'Playlist name (optional)',
    'fileUploadButton': 'Upload File',
    'or': 'or',
    'pleaseEnterUrl': 'Please enter URL',
    'sentToTV': 'Sent to TV, please check on your TV',
    'sendFailed': 'Send failed',
    'networkError':
        'Network error, please ensure devices are on the same network',
    // Simple menu
    'simpleMenu': 'Simple Menu',
    'simpleMenuSubtitle': 'Keep menu collapsed (no auto-expand)',
    'simpleMenuEnabled': 'Simple menu enabled',
    'simpleMenuDisabled': 'Simple menu disabled',
    // Progress bar mode
    'progressBarMode': 'Progress Bar Display',
    'progressBarModeSubtitle':
        'Control how the playback progress bar is displayed',
    'progressBarModeAuto': 'Auto Detect',
    'progressBarModeAlways': 'Always Show',
    'progressBarModeNever': 'Never Show',
    'progressBarModeAutoDesc':
        'Auto show based on content type (VOD/replay show, live hide)',
    'progressBarModeAlwaysDesc': 'Show progress bar for all content',
    'progressBarModeNeverDesc': 'Never show progress bar',
    'progressBarModeSet': 'Progress bar display set to: {mode}',

    // Seek step settings
    'seekStepSeconds': 'Seek Step Duration',
    'seekStepSecondsSubtitle': 'Set jump duration when long-pressing left/right keys',
    'seekStep5s': '5 seconds',
    'seekStep10s': '10 seconds',
    'seekStep30s': '30 seconds',
    'seekStep60s': '60 seconds',
    'seekStep120s': '120 seconds',
    'seekStepSet': 'Seek step duration set to: {seconds} seconds',

    // Home display settings
    'showWatchHistoryOnHome': 'Show Watch History on Home',
    'showWatchHistoryOnHomeSubtitle': 'Display recently watched channels on home screen',
    'showFavoritesOnHome': 'Show Favorites on Home',
    'showFavoritesOnHomeSubtitle': 'Display favorite channels on home screen',
    'watchHistoryOnHomeEnabled': 'Watch history on home enabled',
    'watchHistoryOnHomeDisabled': 'Watch history on home disabled',
    'favoritesOnHomeEnabled': 'Favorites on home enabled',
    'favoritesOnHomeDisabled': 'Favorites on home disabled',

    // Developer and debug settings
    'developerAndDebug': 'Developer & Debug',
    'logLevel': 'Log Level',
    'logLevelSubtitle': 'Select logging level',
    'logLevelDebug': 'Debug',
    'logLevelRelease': 'Release',
    'logLevelOff': 'Off',
    'logLevelDebugDesc': 'Log everything for development and debugging',
    'logLevelReleaseDesc': 'Only log warnings and errors (recommended)',
    'logLevelOffDesc': 'Do not log anything',
    'exportLogs': 'Export Logs',
    'exportLogsSubtitle': 'Scan QR to view or export log files',
    'clearLogs': 'Clear Logs',
    'clearLogsSubtitle': 'Delete all log files',
    'logFileLocation': 'Log File Location',
    'logsCleared': 'Logs cleared',
    'clearLogsConfirm': 'Clear Logs',
    'clearLogsConfirmMessage': 'Are you sure you want to delete all log files?',
    'errorTimeout': 'Connection timeout, please check network or URL',
    'errorNetwork': 'Network connection failed, please check network',
    'usingCachedSource': 'Remote source unavailable, using cached source',
  };
}
