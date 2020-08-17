import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

class SickChill {
  final bool enableLogs;
  final Dio _dio;
  final String _baseUrl;

  SickChill._(this._baseUrl, this._dio, this.enableLogs) {
    if (enableLogs) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  /// [baseUrl] url of the transmission server instance, default to http://localhost:8081
  /// [enableLogs] boolean to show http logs or not
  factory SickChill({String baseUrl, @required String apiKey, bool enableLogs = false}) {
    baseUrl ??= 'http://localhost:8081';
    return SickChill._(baseUrl, Dio(BaseOptions(baseUrl: baseUrl + '/api/$apiKey')), enableLogs);
  }

  String _qualityToRawQuality(TvShowEpisodeQuality quality) {
    switch (quality) {
      case TvShowEpisodeQuality.all:
        return _rawEpisodeQuality.join('|');
        break;
      case TvShowEpisodeQuality.sd:
        return _rawEpisodeQuality.where((element) => element.contains('sd')).join('|');
        break;
      case TvShowEpisodeQuality.hd:
        return _rawEpisodeQuality.where((element) => element.contains('hd')).join('|');
        break;
      case TvShowEpisodeQuality.hd720:
        return _rawEpisodeQuality[2] + '|' + _rawEpisodeQuality[5] + '|' + _rawEpisodeQuality[7];
        break;
      case TvShowEpisodeQuality.hd1080:
        return _rawEpisodeQuality[4] + '|' + _rawEpisodeQuality[6] + '|' + _rawEpisodeQuality[8];
        break;
      case TvShowEpisodeQuality.uhd:
        return _rawEpisodeQuality.where((element) => element.contains('udh')).join('|');
        break;
      case TvShowEpisodeQuality.uhd4K:
        return _rawEpisodeQuality.where((element) => element.contains('4k')).join('|');
        break;
      case TvShowEpisodeQuality.uhd8K:
        return _rawEpisodeQuality.where((element) => element.contains('8k')).join('|');
        break;
    }
    return _rawEpisodeQuality.join('|');
  }

  Future<void> addShow({
    @required int indexerId,
    int tvdbid,
    TvShowEpisodeStatus status,
    TvShowEpisodeStatus futureStatus,
    bool scene = false,
    bool flattenFolders = true,
    bool isAnime = false,
    String location,
    String lang = 'en',
    bool searchSubtitles = true,
    bool seasonFolders = true,
    TvShowEpisodeQuality quality,
    TvShowEpisodeQuality archive,
  }) async {
    var command = 'show.addnew&indexerid=$indexerId&lang=$lang';

    if (tvdbid != null) {
      command += '&tvdbid=$tvdbid';
    }
    if (searchSubtitles != null) {
      command += '&subtitles=${searchSubtitles ? 1 : 0}';
    }
    if (isAnime != null) {
      command += '&anime=${isAnime ? 1 : 0}';
    }
    if (seasonFolders != null) {
      command += '&season_folders=${seasonFolders ? 1 : 0}';
    }
    if (flattenFolders != null) {
      command += '&flatten_folders=${flattenFolders ? 1 : 0}';
    }
    if (scene != null) {
      command += '&scene=${scene ? 1 : 0}';
    }
    if (quality != null) {
      command += '&initial=${_qualityToRawQuality(quality)}';
    }
    if (archive != null) {
      command += '&archive=${_qualityToRawQuality(archive)}';
    }
    if (status != null) {
      final statusStr = status.toString().split('.')[1];
      command += '&status=$statusStr';
    }
    if (futureStatus != null) {
      final statusStr = futureStatus.toString().split('.')[1];
      command += '&future_status=$statusStr';
    }
    await _makeRequest(command);
  }

  Future<TvShowEpisode> setEpisodeStatus({
    @required int showId,
    @required TvShowEpisodeStatus status,
    @required String seasonNumber,
    String episodeNumber,
    bool force = false,
  }) async {
    final statusStr = status.toString().split('.')[1];
    var command = 'episode.setstatus&indexerid=$showId&season=$seasonNumber&status=$statusStr';
    if (episodeNumber != null) {
      command += '&episode=$episodeNumber';
    }
    final result = await _makeRequest(command);
    return TvShowEpisode._(episodeNumber, result.data);
  }

  Future<TvShowEpisode> getEpisode(int showId, int seasonNumber, String episodeNumber) async {
    final command = 'episode&indexerid=$showId&season=$seasonNumber&episode=$episodeNumber';
    final result = await _makeRequest(command);
    return TvShowEpisode._(episodeNumber, result.data);
  }

  Future<TvShowEpisode> searchEpisode(int showId, int seasonNumber, String episodeNumber) async {
    final command = 'episode.search&indexerid=$showId&season=$seasonNumber&episode=$episodeNumber';
    await _makeRequest(command);
    return getEpisode(showId, seasonNumber, episodeNumber);
  }

  Future<List<TvShowResult>> searchShow(String name, {String language, bool onlyNew = true}) async {
    var command = 'sb.searchindexers&name=$name&only_new=${onlyNew ? 1 : 0}';
    if (language != null) {
      command += '&language=$language';
    }
    final results = await _makeRequest(command);
    return results.data['results'].map((e) => TvShowResult._(e)).cast<TvShowResult>().toList(growable: false);
  }

  Future<TvShowEpisode> searchEpisodeSubtitle(int showId, int seasonNumber, String episodeNumber) async {
    final command = 'episode.subtitlesearch&indexerid=$showId&season=$seasonNumber&episode=$episodeNumber';
    await _makeRequest(command);
    return getEpisode(showId, seasonNumber, episodeNumber);
  }

  Future<List<TvShowSeason>> getSeasons(int showId, {int seasonNumber}) async {
    var command = 'show.seasons&indexerid=$showId';
    if (seasonNumber != null) {
      command += '&season=$seasonNumber';
    }
    final result = await _makeRequest(command);

    final rawSeasons = result.data;
    final seasons = <TvShowSeason>[];
    if (seasonNumber == null) {
      rawSeasons.forEach((number, rawEpisodes) {
        final episodes = <TvShowEpisode>[];
        rawEpisodes.forEach((episodeNumber, episodeRawData) {
          episodes.add(TvShowEpisode._(episodeNumber, episodeRawData));
        });

        seasons.add(TvShowSeason._(number, episodes));
      });
    } else {
      final episodes = <TvShowEpisode>[];
      rawSeasons.forEach((episodeNumber, episodeRawData) {
        episodes.add(TvShowEpisode._(episodeNumber, episodeRawData));
      });

      seasons.add(TvShowSeason._(seasonNumber.toString(), episodes));
    }
    return seasons;
  }

  Future<void> forceFullUpdateShow(int id) async {
    final command = 'show.update&indexerid=$id';
    await _makeRequest(command);
  }

  Future<void> refreshShowFromDisk(int id) async {
    final command = 'show.refresh&indexerid=$id';
    await _makeRequest(command);
  }

  Future<void> pauseShow(int id, bool paused) async {
    final command = 'show.pause&indexerid=$id&pause=${paused ? 1 : 0}';
    await _makeRequest(command);
  }

  Future<void> removeShow(int id, {bool removeFiles = false}) async {
    final command = 'show.delete&indexerid=$id&removefiles=${removeFiles ? 1 : 0}';
    await _makeRequest(command);
  }

  Future<TvShowDetails> getShowDetails(int id, {bool loadSeasonInfo = false}) async {
    final command = 'show&indexerid=$id';
    final result = await _makeRequest(command);
    List<TvShowSeason> seasons;
    if (loadSeasonInfo) {
      seasons = await getSeasons(id);
    }
    return TvShowDetails._(seasons, result.data, _baseUrl + '/cache/images/', _baseUrl + '/images/');
  }

  Future<List<TvShow>> getShows({TvShowSort sort = TvShowSort.nextEpisode, bool paused}) async {
    var command = 'shows';
    if (sort == TvShowSort.id) {
      command = '$command&sort=id';
    } else if (sort == TvShowSort.name) {
      command = '$command&sort=name';
    }
    if (paused == true) {
      command = '$command&paused=1';
    } else if (paused == false) {
      command = '$command&paused=0';
    }

    final result = await _makeRequest(command);
    final list = result.data.values.map((e) => TvShow._(e, _baseUrl + '/cache/images/', _baseUrl + '/images/')).toList();
    var sortedList = list;
    if (sort == TvShowSort.nextEpisode) {
      final int Function(TvShow, TvShow) sortByName = (tv1, tv2) {
        return tv1.name.toLowerCase().compareTo(tv2.name.toLowerCase());
      };
      final nextEp = list.where((element) => element.nextEpisode != null && !element.isPaused).toList()
        ..sort((tv1, tv2) {
          final compareResult = tv1.nextEpisode.compareTo(tv2.nextEpisode);

          if (compareResult == 0) {
            return sortByName(tv1, tv2);
          }

          return compareResult;
        });
      final tvShowContinued = list.where((element) => element.nextEpisode == null && element.status == 'Continuing' && !element.isPaused).toList()
        ..sort(sortByName);
      final tvShowPaused = list.where((element) => element.isPaused).toList()..sort(sortByName);
      final tvShowEnded = list.where((element) => element.status == 'Ended' && !element.isPaused).toList()..sort(sortByName);
      sortedList = nextEp..addAll(tvShowContinued)..addAll(tvShowPaused)..addAll(tvShowEnded);
    }
    return sortedList;
  }

  Future<_Response> _makeRequest(String cmd) async {
    final result = await _dio.get('/?cmd=$cmd');
    if (result.statusCode == 200) {
      final response = _Response.fromJSON(result.data);
      _checkResults(response);
      return response;
    } else {
      throw SickChillHttpException._(result);
    }
  }

  void _checkResults(_Response response) {
    if (!response.isSuccess) {
      throw SickChillException._(response);
    }
  }

  /// close all connexions
  void dispose() {
    _dio.close();
  }
}

enum TvShowSort { id, name, nextEpisode }

enum TvShowEpisodeStatus { wanted, skipped, ignored, failed }

const _rawEpisodeQuality = [
  'sdtv',
  'sddv',
  'hdtv',
  'rawhdtv',
  'fullhdtv',
  'hdwebdl',
  'fullhdwebdl',
  'hdbluray',
  'fullhdbluray',
  'udh4ktv',
  'uhd4kbluray',
  'udh4kwebdl',
  'udh8ktv',
  'uhd8kbluray',
  'udh8kwebdl',
  'unknown',
];

enum TvShowEpisodeQuality {
  all,
  sd,
  hd,
  hd720,
  hd1080,
  uhd,
  uhd4K,
  uhd8K,
}

final _dateFormat = DateFormat("yyyy-MM-dd");

class TvShowSeason {
  final String number;
  final List<TvShowEpisode> episodes;

  TvShowSeason._(this.number, this.episodes);

  @override
  String toString() {
    return 'TvShowSeason{number: $number, episodes: $episodes}';
  }
}

class TvShowResult {
  final Map<String, dynamic> _rawData;

  TvShowResult._(this._rawData);

  String get name => _rawData['name'];

  String get firstAiredStr => _rawData['first_aired'];

  DateTime get firstAired {
    if (firstAiredStr == null || firstAiredStr.isEmpty || firstAiredStr.toLowerCase() == 'never') {
      return null;
    }
    return _dateFormat.parse(firstAiredStr);
  }

  int get tvdbid => _rawData['tvdbid'];

  @override
  String toString() {
    final data = JsonEncoder.withIndent('   ').convert(_rawData);
    return 'TvShowResult{_rawData: $data}';
  }
}

class TvShowEpisode {
  final String number;
  final Map<String, dynamic> _rawData;

  TvShowEpisode._(this.number, this._rawData);

  String get airdateStr => _rawData['airdate'];

  DateTime get airdate {
    if (airdateStr == null || airdateStr.isEmpty || airdateStr.toLowerCase() == 'never') {
      return null;
    }
    return _dateFormat.parse(airdateStr);
  }

  int get fileSize => _rawData['file_size'];

  String get location => _rawData['location'];

  String get releaseName => _rawData['release_name'];

  String get name => _rawData['name'];

  String get status => _rawData['status'];

  String get subtitles => _rawData['subtitles'];

  String get quality => _rawData['quality'];

  bool get isDownloaded => status.toLowerCase() == 'downloaded';

  @override
  String toString() {
    final data = JsonEncoder.withIndent('   ').convert(_rawData);
    return 'TvShowEpisode{number: $number, _rawData: $data}';
  }
}

class TvShowDetails extends TvShow {
  TvShowDetails._(
    this.seasons,
    Map<String, dynamic> rawData,
    String baseUrlImagesCache,
    String baseUrlImages,
  ) : super._(rawData, baseUrlImagesCache, baseUrlImages);

  List<TvShowSeason> seasons;

  String get imdbId => _rawData['imdbid'];

  List<String> get genre => _rawData['genre'].cast<String>();

  List<int> get seasonList => _rawData['season_list'].cast<int>();

  String get location => _rawData['location'];

  String get airs => _rawData['airs'];

  bool get isDvdOrder => _rawData['dvdorder'] == 1;

  bool get isArchiveFirstMatch => _rawData['archive_firstmatch'] == 1;

  bool get hasSceneNumbering => _rawData['scene'] == 1;

  bool get hasSeasonFolders => _rawData['season_folders'] == 1;
}

class TvShow {
  final Map<String, dynamic> _rawData;
  final String _baseUrlImages;
  final String _baseUrlImagesCache;

  TvShow._(this._rawData, this._baseUrlImagesCache, this._baseUrlImages);

  int get id => _rawData['indexerid'];

  String get nextEpisodeStr => _rawData['next_ep_airdate'];

  String get quality => _rawData['quality'];

  String get language => _rawData['language'];

  String get network => _rawData['network'];

  String get networkImage => _baseUrlImages + 'network/${network.toLowerCase()}.png';

  bool get hasBanner => _rawData['cache']['banner'] == 1;

  bool get hasBannerThumbnail => _rawData['cache']['banner_thumb'] == 1;

  bool get hasPoster => _rawData['cache']['poster'] == 1;

  bool get hasPosterThumbnail => _rawData['cache']['poster_thumb'] == 1;

  bool get hasFanart => _rawData['cache']['fanart'] == 1;

  String get poster => hasPoster ? _baseUrlImagesCache + '$id.poster.jpg' : _baseUrlImages + 'poster.png';

  String get posterThumbnail => hasPosterThumbnail ? _baseUrlImagesCache + 'thumbnails/$id.poster.jpg' : _baseUrlImages + 'poster.png';

  String get banner => hasBanner ? _baseUrlImagesCache + '$id.banner.jpg' : _baseUrlImages + 'banner.png';

  String get bannerThumbnail => hasBannerThumbnail ? _baseUrlImagesCache + 'thumbnails/$id.banner.jpg' : _baseUrlImages + 'banner.png';

  String get fanart => hasFanart ? _baseUrlImagesCache + '$id.fanart.jpg' : null;

  DateTime get nextEpisode {
    if (nextEpisodeStr == null || nextEpisodeStr.isEmpty) {
      return null;
    }
    return _dateFormat.parse(nextEpisodeStr);
  }

  int get tvdbid => _rawData['tvdbid'];

  String get name => _rawData['show_name'];

  String get status => _rawData['status'];

  bool get isAnime => _rawData['anime'] == 1;

  bool get isSports => _rawData['sports'] == 1;

  bool get needSubtitles => _rawData['subtitles'] == 1;

  bool get isAirByDate => _rawData['air_by_date'] == 1;

  bool get isPaused => _rawData['paused'] == 1;

  bool get isEnded => _rawData['status'].toLowerCase() == 'ended';

  @override
  String toString() {
    final data = JsonEncoder.withIndent('   ').convert(_rawData);
    return 'TvShow{_rawData: $data}';
  }
}

class SickChillHttpException {
  final Response cause;

  SickChillHttpException._(this.cause);

  int get status => cause.statusCode;

  @override
  String toString() {
    return 'SickChillHttpException($cause)';
  }
}

class SickChillException {
  final _Response cause;

  SickChillException._(this.cause);

  String get message => cause.message;

  @override
  String toString() {
    return 'SickChillException($cause)';
  }
}

class _Response {
  final String result;
  final String message;
  final Map data;

  _Response._(this.result, this.message, this.data);

  bool get isSuccess => result == 'success';

  factory _Response.fromJSON(Map<String, dynamic> data) {
    var mapData = data['data'];
    if (mapData is List) {
      mapData = {'data': mapData};
    }
    return _Response._(data['result'], data['message'], mapData);
  }

  @override
  String toString() {
    return '_Response{result: $result, message: $message, data: $data}';
  }
}
